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
    super.key,
  });

  final String? url;
  final BoxFit fit;
  final int cacheWidth;
  final VoidCallback? onFailed;

  @override
  State<MonettaImage> createState() => _MonettaImageState();
}

class _MonettaImageState extends State<MonettaImage> {
  int _attempt = 0;
  bool _gaveUp = false;

  static const _delays = <Duration>[
    Duration(milliseconds: 400),
    Duration(milliseconds: 1200),
  ];

  void _onError() {
    if (_attempt >= _delays.length) {
      if (!_gaveUp) {
        _gaveUp = true;
        widget.onFailed?.call();
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

  @override
  void didUpdateWidget(covariant MonettaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _attempt = 0;
      _gaveUp = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final raw = widget.url;
    if (raw == null || raw.isEmpty || !MediaUrl.isHttps(raw)) {
      return const _ImageFallback();
    }
    if (_gaveUp) return const _ImageFallback();

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
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: kMist,
      child: Center(child: MonettaWordmark(height: 18)),
    );
  }
}
