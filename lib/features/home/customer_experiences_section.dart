/// Home section that mirrors the live Loox “EXPERIENCIAS DE CLIENTES” carousel.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/home_content_controller.dart';
import '../../app/media/monetta_image.dart';
import '../../app/theme.dart';
import '../../data/media/media_url.dart';
import '../../domain/home_content.dart';

const Color _kVerifiedBadge = Color(0xFF0994D4);
const double _kDesktopBreakpoint = 720;
const double _kPageMaxWidth = 1200;
const double _kCornerRadius = 24;
const double _kDesktopTextWidth = 384;
const double _kDesktopPaneHeight = 424;
const double _kMobileImageHeight = 336;
const double _kMobileTextHeight = 208;
const double _kDesktopGap = 16;
const double _kMobileGap = 8;
const double _kImageGap = 8;
const int _kMaxCharacters = 200;
const int _kHomeReviewLimit = 5;
const Duration _kAutoplayDelay = Duration(seconds: 7);
const Duration _kSlideDuration = Duration(milliseconds: 500);

class CustomerExperiencesSection extends StatelessWidget {
  const CustomerExperiencesSection({
    required this.testimonials,
    required this.status,
    this.average,
    this.count,
    this.onSeeMore,
    super.key,
  });

  final List<HomeTestimonial> testimonials;
  final HomeReviewsStatus status;
  final double? average;
  final int? count;
  final VoidCallback? onSeeMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('home-section-testimonials'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeading(
          key: ValueKey('customer-experiences-heading'),
          kicker: 'LO QUE DICEN',
          title: 'Experiencias de clientes',
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kPageMaxWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _CarouselBody(
                testimonials: testimonials,
                status: status,
                average: average,
                count: count,
                onSeeMore: onSeeMore,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CarouselBody extends StatelessWidget {
  const _CarouselBody({
    required this.testimonials,
    required this.status,
    required this.average,
    required this.count,
    required this.onSeeMore,
  });

  final List<HomeTestimonial> testimonials;
  final HomeReviewsStatus status;
  final double? average;
  final int? count;
  final VoidCallback? onSeeMore;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = _isWideWidth(constraints.maxWidth);
        if (status == HomeReviewsStatus.loading) {
          return _LoadingSkeleton(wide: wide);
        }
        if (status == HomeReviewsStatus.empty || testimonials.isEmpty) {
          return const SizedBox(height: 20);
        }
        return Column(
          children: [
            _ExperiencesCarousel(
              testimonials: testimonials.take(_kHomeReviewLimit).toList(),
              wide: wide,
            ),
            const SizedBox(height: 20),
            _TrustBadge(average: average, count: count),
            if (onSeeMore != null) ...[
              const SizedBox(height: 14),
              TextButton.icon(
                key: const ValueKey('customer-experiences-see-more'),
                onPressed: onSeeMore,
                icon: const Icon(Icons.arrow_forward, size: 17),
                label: const Text('VER TODAS LAS RESEÑAS'),
                style: TextButton.styleFrom(
                  foregroundColor: context.monettaColors.contentPrimary,
                  textStyle: eyebrow(
                    size: 10,
                    color: context.monettaColors.contentPrimary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }
}

bool _isWideWidth(double width) => width >= _kDesktopBreakpoint;

bool _reduceMotion(BuildContext context) {
  final media = MediaQuery.maybeOf(context);
  if (media == null) return false;
  return media.disableAnimations || media.accessibleNavigation;
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final pane = _MistPane(
      height: wide ? _kDesktopPaneHeight : _kMobileImageHeight,
    );
    final text = _MistPane(
      height: wide ? _kDesktopPaneHeight : _kMobileTextHeight,
      width: wide ? _kDesktopTextWidth : null,
    );
    return Column(
      key: const ValueKey('customer-experiences-loading'),
      children: [
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: _kDesktopTextWidth, child: text),
              const SizedBox(width: _kDesktopGap),
              Expanded(
                child: SizedBox(
                  height: _kDesktopPaneHeight,
                  child: Row(
                    children: [
                      const Expanded(
                        child: _MistPane(height: _kDesktopPaneHeight),
                      ),
                      const SizedBox(width: _kImageGap),
                      const Expanded(
                        child: _MistPane(height: _kDesktopPaneHeight),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              pane,
              const SizedBox(height: _kMobileGap),
              text,
            ],
          ),
        const SizedBox(height: 100),
      ],
    );
  }
}

class _MistPane extends StatelessWidget {
  const _MistPane({required this.height, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: context.monettaColors.surfaceMuted,
        borderRadius: BorderRadius.circular(_kCornerRadius),
      ),
    );
  }
}

class _ExperiencesCarousel extends StatefulWidget {
  const _ExperiencesCarousel({
    required this.testimonials,
    required this.wide,
  });

  final List<HomeTestimonial> testimonials;
  final bool wide;

  @override
  State<_ExperiencesCarousel> createState() => _ExperiencesCarouselState();
}

class _ExperiencesCarouselState extends State<_ExperiencesCarousel> {
  PageController? _controller;
  int _index = 0;
  Timer? _autoplay;
  bool? _wide;

  List<HomeTestimonial> get _reviews => widget.testimonials;

  @override
  void initState() {
    super.initState();
    _ensureController(widget.wide);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleAutoplay();
  }

  @override
  void didUpdateWidget(covariant _ExperiencesCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wide != widget.wide) {
      _ensureController(widget.wide);
    }
    if (oldWidget.testimonials != widget.testimonials) {
      _index = _index.clamp(0, math.max(0, _reviews.length - 1));
    }
  }

  @override
  void dispose() {
    _autoplay?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _ensureController(bool wide) {
    if (_wide == wide && _controller != null) return;
    final previous = _controller;
    final page = previous?.hasClients == true
        ? previous!.page?.round() ?? _index
        : _index;
    _wide = wide;
    _controller = PageController(
      initialPage: page.clamp(0, math.max(0, _reviews.length - 1)),
      viewportFraction: wide ? 0.5 : 1.0,
    );
    _index = page.clamp(0, math.max(0, _reviews.length - 1));
    previous?.dispose();
  }

  void _scheduleAutoplay() {
    _autoplay?.cancel();
    if (!mounted || _reviews.length < 2) return;
    if (_reduceMotion(context)) return;
    _autoplay = Timer(_kAutoplayDelay, _advance);
  }

  void _advance() {
    if (!mounted || _controller == null || !_controller!.hasClients) return;
    if (_index >= _reviews.length - 1) return;
    _goTo(_index + 1);
  }

  void _goTo(int page) {
    final next = page.clamp(0, _reviews.length - 1);
    final controller = _controller;
    if (controller == null || !controller.hasClients) return;
    if (_reduceMotion(context)) {
      controller.jumpToPage(next);
    } else {
      unawaited(
        controller.animateToPage(
          next,
          duration: _kSlideDuration,
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  void _onPageChanged(int page) {
    setState(() => _index = page);
    _scheduleAutoplay();
  }

  @override
  Widget build(BuildContext context) {
    final wide = widget.wide;
    return Column(
      children: [
        Semantics(
          key: const ValueKey('customer-experiences-live-region'),
          liveRegion: true,
          container: true,
          label: 'Reseña ${_index + 1} de ${_reviews.length}',
          child: const SizedBox.shrink(),
        ),
        wide ? _buildDesktop(context) : _buildMobile(context),
        const SizedBox(height: 16),
        _Pagination(
          count: _reviews.length,
          index: _index,
          wide: wide,
          onPrevious: _index == 0 ? null : () => _goTo(_index - 1),
          onNext:
              _index >= _reviews.length - 1 ? null : () => _goTo(_index + 1),
        ),
      ],
    );
  }

  Widget _buildDesktop(BuildContext context) {
    final current = _reviews[_index];
    return SizedBox(
      height: _kDesktopPaneHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _kDesktopTextWidth,
            child: _TextCard(testimonial: current, wide: true),
          ),
          const SizedBox(width: _kDesktopGap),
          Expanded(child: _imagePageView()),
        ],
      ),
    );
  }

  Widget _buildMobile(BuildContext context) {
    return SizedBox(
      height: _kMobileImageHeight + _kMobileGap + _kMobileTextHeight,
      child: PageView.builder(
        key: const ValueKey('customer-experiences-carousel'),
        controller: _controller,
        onPageChanged: _onPageChanged,
        itemCount: _reviews.length,
        itemBuilder: (context, index) {
          final review = _reviews[index];
          return Column(
            children: [
              SizedBox(
                height: _kMobileImageHeight,
                width: double.infinity,
                child: _ReviewPhoto(testimonial: review),
              ),
              const SizedBox(height: _kMobileGap),
              SizedBox(
                height: _kMobileTextHeight,
                width: double.infinity,
                child: _TextCard(testimonial: review, wide: false),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _imagePageView() {
    return PageView.builder(
      key: const ValueKey('customer-experiences-carousel'),
      controller: _controller,
      onPageChanged: _onPageChanged,
      padEnds: false,
      itemCount: _reviews.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(
            right: index == _reviews.length - 1 ? 0 : _kImageGap / 2,
            left: index == 0 ? 0 : _kImageGap / 2,
          ),
          child: _ReviewPhoto(testimonial: _reviews[index]),
        );
      },
    );
  }
}

class _TextCard extends StatelessWidget {
  const _TextCard({required this.testimonial, required this.wide});

  final HomeTestimonial testimonial;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final body = _clampedBody(testimonial.body);
    final starSize = wide ? 24.0 : 16.0;
    return Container(
      decoration: BoxDecoration(
        color: context.monettaColors.surfaceRaised,
        borderRadius: BorderRadius.circular(_kCornerRadius),
      ),
      padding: wide
          ? const EdgeInsets.fromLTRB(40, 56, 40, 56)
          : const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment:
            wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          _StarRow(
            key: const ValueKey('customer-experiences-stars'),
            rating: testimonial.rating,
            size: starSize,
          ),
          SizedBox(height: wide ? 16 : 8),
          Expanded(
            child: Align(
              alignment: wide ? Alignment.topLeft : Alignment.topCenter,
              child: Text(
                body,
                maxLines: wide ? 6 : 3,
                overflow: TextOverflow.ellipsis,
                textAlign: wide ? TextAlign.start : TextAlign.center,
                style: display(
                  wide ? 24 : 20,
                  height: 1.4,
                ),
              ),
            ),
          ),
          SizedBox(height: wide ? 16 : 8),
          Row(
            mainAxisAlignment:
                wide ? MainAxisAlignment.start : MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  testimonial.reviewer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: sans(
                    size: wide ? 16 : 14,
                    color: context.monettaColors.contentPrimary,
                  ),
                ),
              ),
              if (testimonial.verified) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.verified,
                  size: 16,
                  color: _kVerifiedBadge,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewPhoto extends StatelessWidget {
  const _ReviewPhoto({required this.testimonial});

  final HomeTestimonial testimonial;

  @override
  Widget build(BuildContext context) {
    final url = testimonial.imageUrl;
    final https = url != null && MediaUrl.isHttps(url);
    final label = testimonial.imageAlt ??
        (testimonial.productName == null
            ? 'Foto de ${testimonial.reviewer}'
            : 'Foto de ${testimonial.productName}');
    return Semantics(
      image: true,
      label: label,
      excludeSemantics: true,
      child: ClipRRect(
        key: ValueKey('customer-experiences-photo-${testimonial.reviewer}'),
        borderRadius: BorderRadius.circular(_kCornerRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (https)
              MonettaImage(
                url: url,
                fit: BoxFit.cover,
                cacheWidth: MediaUrl.cardWidth,
              )
            else if (testimonial.fallbackAsset.isNotEmpty)
              Image.asset(
                testimonial.fallbackAsset,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                filterQuality: FilterQuality.medium,
              )
            else
              const MonettaImage(url: null),
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color(0x00091218),
                      Color(0xB3091218),
                    ],
                    stops: <double>[0.665, 0.98],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating, required this.size, super.key});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$rating de 5 estrellas',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 5; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Icon(
              i < rating ? Icons.star : Icons.star_border,
              color: context.monettaColors.accent,
              size: size,
            ),
          ],
        ],
      ),
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.count,
    required this.index,
    required this.wide,
    required this.onPrevious,
    required this.onNext,
  });

  final int count;
  final int index;
  final bool wide;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (wide)
          _NavButton(
            key: const ValueKey('customer-experiences-prev'),
            tooltip: 'Reseña anterior',
            icon: Icons.chevron_left,
            onPressed: onPrevious,
          )
        else
          const SizedBox(width: 44),
        Expanded(
          child: Semantics(
            label: 'Paginación de reseñas, ${index + 1} de $count',
            child: Row(
              key: const ValueKey('customer-experiences-page-indicator'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < count; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _Dot(active: i == index),
                ],
              ],
            ),
          ),
        ),
        if (wide)
          _NavButton(
            key: const ValueKey('customer-experiences-next'),
            tooltip: 'Reseña siguiente',
            icon: Icons.chevron_right,
            onPressed: onNext,
          )
        else
          const SizedBox(width: 44),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: tooltip,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 28, color: context.monettaColors.accent),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: _reduceMotion(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      width: active ? 24 : 5,
      height: active ? 8 : 5,
      decoration: BoxDecoration(
        color: active
            ? context.monettaColors.accent
            : context.monettaColors.divider,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.average, required this.count});

  final double? average;
  final int? count;

  @override
  Widget build(BuildContext context) {
    if (average == null && count == null) return const SizedBox.shrink();
    final filled = ((average ?? 5).round()).clamp(1, 5);
    return Semantics(
      container: true,
      label: [
        if (average != null) '${average!.toStringAsFixed(1)} de 5',
        if (count != null) '$count reseñas',
      ].join('. '),
      child: Row(
        key: const ValueKey('customer-experiences-trust-badge'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StarRow(rating: filled, size: 18),
          if (count != null) ...[
            const SizedBox(width: 8),
            Text(
              '$count reseñas',
              style: sans(size: 18),
            ),
          ],
        ],
      ),
    );
  }
}

String _clampedBody(String body) {
  if (body.length <= _kMaxCharacters) return body;
  return '${body.substring(0, _kMaxCharacters).trimRight()}…';
}
