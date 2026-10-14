/// The only shopper-facing network image. Sized URL, mem cache, retry,
/// a fallback that is not empty mist.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../data/media/media_url.dart';
import '../motion.dart';
import '../theme.dart';

/// The most `BoxFit.cover` may crop from each side of a packshot, as a
/// fraction of its own width or height.
///
/// Measured on the 98 real catalog photographs: 41 are 3:4, 20 are 4:5, 13
/// square, 15 tall (watches, A-series) and one landscape. In a 4:5 frame,
/// `cover` trims 3.1% per side from a 3:4 photo and never touches the product,
/// while square, tall or landscape photos would lose handles or straps
/// (3.5-14% per side). 3.3% sits between those two groups.
const double kPackshotMaxCoverTrim = 0.033;

/// The white every catalog packshot is photographed on (the files range from
/// #F9F9F9 to #FFFFFF). Used to extend a `contain`ed photo to the frame edge
/// without a visible seam.
const Color kPackshotGround = Color(0xFFFFFFFF);

/// Chooses between `cover` and `contain` for a photo in a frame.
///
/// Returns [BoxFit.cover] only when it would crop at most [maxCoverTrim] from
/// each side of the photo; otherwise [BoxFit.contain] so the product is shown
/// whole. Empty or non-finite sizes never cover.
BoxFit packshotFit(
  Size photo,
  Size frame, {
  double maxCoverTrim = kPackshotMaxCoverTrim,
}) {
  bool usable(Size size) =>
      size.width.isFinite &&
      size.height.isFinite &&
      size.width > 0 &&
      size.height > 0;
  if (!usable(photo) || !usable(frame)) return BoxFit.contain;

  final photoAspect = photo.width / photo.height;
  final frameAspect = frame.width / frame.height;
  final kept = photoAspect > frameAspect
      ? frameAspect / photoAspect
      : photoAspect / frameAspect;
  return (1 - kept) / 2 <= maxCoverTrim ? BoxFit.cover : BoxFit.contain;
}

/// Paints [image] filling its frame when the crop is negligible
/// ([packshotFit]) and whole, on [kPackshotGround], otherwise.
///
/// It reads only the photo's pixel size from the image stream; it never keeps
/// the decoded image.
class PackshotImage extends StatefulWidget {
  const PackshotImage({
    required this.image,
    this.maxCoverTrim = kPackshotMaxCoverTrim,
    super.key,
  });

  final ImageProvider image;
  final double maxCoverTrim;

  @override
  State<PackshotImage> createState() => _PackshotImageState();
}

class _PackshotImageState extends State<PackshotImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _size;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant PackshotImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) _resolve();
  }

  void _resolve() {
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;

    _stream?.removeListener(_listener!);
    _size = null;
    _stream = stream;
    _listener = ImageStreamListener(_onImage);
    stream.addListener(_listener!);
  }

  void _onImage(ImageInfo info, bool synchronousCall) {
    final size =
        Size(info.image.width.toDouble(), info.image.height.toDouble());
    info.dispose();
    if (size == _size) return;
    // A cached image is delivered synchronously, during didChangeDependencies,
    // where the first build has not happened yet: no setState is needed.
    if (synchronousCall) {
      _size = size;
    } else if (mounted) {
      setState(() => _size = size);
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = _size;
    if (size == null) return const SizedBox.expand();

    return LayoutBuilder(
      builder: (context, constraints) {
        final fit = packshotFit(
          size,
          constraints.biggest,
          maxCoverTrim: widget.maxCoverTrim,
        );
        final image = Image(
          image: widget.image,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          excludeFromSemantics: true,
        );
        return fit == BoxFit.contain
            ? ColoredBox(color: kPackshotGround, child: image)
            : image;
      },
    );
  }
}

class MonettaImage extends StatefulWidget {
  const MonettaImage({
    required this.url,
    this.fit = BoxFit.cover,
    this.cacheWidth = MediaUrl.cardWidth,
    this.onFailed,
    this.fallbackLabel,
    this.maxCoverTrim,
    this.backgroundColor,
    super.key,
  });

  final String? url;
  final BoxFit fit;
  final int cacheWidth;
  final VoidCallback? onFailed;
  final String? fallbackLabel;

  /// When set, the photo is drawn by [PackshotImage]: it fills the frame if
  /// `cover` crops at most this fraction per side, and is shown whole
  /// otherwise (and [fit] is ignored). Null keeps [fit] as is.
  final double? maxCoverTrim;
  final Color? backgroundColor;

  @override
  State<MonettaImage> createState() => _MonettaImageState();
}

class _MonettaImageState extends State<MonettaImage> {
  int _attempt = 0;
  bool _gaveUp = false;
  bool _failureNotified = false;

  static const _delays = <Duration>[
    Duration(milliseconds: 400),
    Duration(milliseconds: 1200),
  ];

  void _onError() {
    if (_attempt >= _delays.length) {
      if (!_gaveUp) {
        _gaveUp = true;
        _notifyFailure();
        if (mounted) setState(() {});
      }
      return;
    }
    final wait = _delays[_attempt];
    Future<void>.delayed(wait, () {
      if (!mounted) return;
      setState(() => _attempt += 1);
    });
  }

  void _notifyFailure() {
    if (_failureNotified) return;
    _failureNotified = true;
    widget.onFailed?.call();
  }

  @override
  void didUpdateWidget(covariant MonettaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _attempt = 0;
      _gaveUp = false;
      _failureNotified = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.monettaColors;
    final raw = widget.url;
    if (raw == null || raw.isEmpty || !MediaUrl.isHttps(raw)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _notifyFailure());
      return _ImageFallback(
        label: widget.fallbackLabel,
        backgroundColor: widget.backgroundColor,
      );
    }
    if (_gaveUp) {
      return _ImageFallback(
        label: widget.fallbackLabel,
        backgroundColor: widget.backgroundColor,
      );
    }

    final url = MediaUrl.sized(raw, width: widget.cacheWidth);
    return ColoredBox(
      color: widget.backgroundColor ?? colors.mediaPlaceholder,
      child: CachedNetworkImage(
        key: ValueKey('$url#$_attempt'),
        imageUrl: url,
        fit: widget.fit,
        width: double.infinity,
        height: double.infinity,
        memCacheWidth: widget.cacheWidth,
        imageBuilder: widget.maxCoverTrim == null
            ? null
            : (context, provider) => PackshotImage(
                  // The builder receives the provider without the resize that
                  // `memCacheWidth` applies. `ResizeImage` here yields the same
                  // cache key, so the frame decoded for the placeholder swap is
                  // reused instead of decoding the photo a second time.
                  image: ResizeImage.resizeIfNeeded(
                    widget.cacheWidth,
                    null,
                    provider,
                  ),
                  maxCoverTrim: widget.maxCoverTrim!,
                ),
        fadeInDuration: reduceMotion(context) ? Duration.zero : kSwap,
        placeholder: (_, __) => ColoredBox(
          color: widget.backgroundColor ?? colors.mediaPlaceholder,
        ),
        errorWidget: (_, __, ___) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _onError());
          return ColoredBox(
            color: widget.backgroundColor ?? colors.mediaPlaceholder,
          );
        },
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({this.label, this.backgroundColor});

  final String? label;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.monettaColors;
    return ColoredBox(
      color: backgroundColor ?? colors.mediaPlaceholder,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MonettaWordmark(height: 18),
            if (label != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  label!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: sans(size: 9, color: colors.contentMuted),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
