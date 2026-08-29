/// The only shopper-facing network image. Sized URL, mem cache, retry,
/// a fallback that is not empty mist.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../data/media/media_url.dart';
import '../motion.dart';
import '../theme.dart';

class MonettaImage extends StatefulWidget {
  const MonettaImage({
    required this.url,
    this.fit = BoxFit.cover,
    this.cacheWidth = MediaUrl.cardWidth,
    this.onFailed,
    this.fallbackLabel,
    super.key,
  });

  final String? url;
  final BoxFit fit;
  final int cacheWidth;
  final VoidCallback? onFailed;
  final String? fallbackLabel;

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
    final raw = widget.url;
    if (raw == null || raw.isEmpty || !MediaUrl.isHttps(raw)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _notifyFailure());
      return _ImageFallback(label: widget.fallbackLabel);
    }
    if (_gaveUp) return _ImageFallback(label: widget.fallbackLabel);

    final url = MediaUrl.sized(raw, width: widget.cacheWidth);
    return ColoredBox(
      color: kMist,
      child: CachedNetworkImage(
        key: ValueKey('$url#$_attempt'),
        imageUrl: url,
        fit: widget.fit,
        width: double.infinity,
        height: double.infinity,
        memCacheWidth: widget.cacheWidth,
        fadeInDuration: reduceMotion(context) ? Duration.zero : kSwap,
        placeholder: (_, __) => const ColoredBox(color: kMist),
        errorWidget: (_, __, ___) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _onError());
          return const ColoredBox(color: kMist);
        },
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kMist,
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
                  style: sans(size: 9, color: kInkMuted),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
