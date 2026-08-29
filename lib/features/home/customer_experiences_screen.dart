/// Full, lazy-loaded review browsing for Monetta.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/media/monetta_image.dart';
import '../../app/theme.dart';
import '../../data/media/media_url.dart';
import '../../data/reviews/loox_reviews_repository.dart';
import '../../domain/home_content.dart';

const double _kReviewPageMaxWidth = 1120;
const double _kReviewCardRadius = 22;
const int _kReviewPrefetchExtent = 600;

class CustomerExperiencesScreen extends StatefulWidget {
  const CustomerExperiencesScreen({
    this.repository,
    this.fallbackReviews = const <HomeTestimonial>[],
    this.average,
    this.count,
    super.key,
  });

  final LooxReviewsRepository? repository;
  final List<HomeTestimonial> fallbackReviews;
  final double? average;
  final int? count;

  @override
  State<CustomerExperiencesScreen> createState() =>
      _CustomerExperiencesScreenState();
}

class _CustomerExperiencesScreenState extends State<CustomerExperiencesScreen> {
  late final ScrollController _scroll;
  late final LooxReviewsRepository _repository;
  late List<HomeTestimonial> _reviews;

  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  Object? _initialError;
  Object? _loadMoreError;
  int _nextPage = 1;
  int? _total;
  double? _average;
  int? _count;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
        LooxReviewsRepository(config: LooxConfig.fromEnvironment());
    _reviews = List<HomeTestimonial>.of(widget.fallbackReviews);
    _average = widget.average;
    _count = widget.count;
    _scroll = ScrollController()..addListener(_onScroll);
    unawaited(_loadFirstPage());
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients ||
        _scroll.position.extentAfter > _kReviewPrefetchExtent) {
      return;
    }
    unawaited(_loadMore());
  }

  Future<void> _loadFirstPage() async {
    try {
      final page = await _repository.fetchPage(
        fallback: widget.fallbackReviews,
      );
      if (!mounted) return;
      setState(() {
        _reviews = _uniqueReviews(page.reviews);
        _initialLoading = false;
        _initialError = null;
        _hasMore = page.hasMore && _reviews.isNotEmpty;
        _nextPage = page.page + 1;
        _total = page.total ?? widget.count;
        _average = page.average ?? widget.average;
        _count = page.total ?? widget.count;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onScroll();
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _initialLoading = false;
        _initialError = error;
        _hasMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_initialLoading || _loadingMore || !_hasMore) return;
    setState(() {
      _loadingMore = true;
      _loadMoreError = null;
    });
    try {
      final page = await _repository.fetchPage(
        page: _nextPage,
        limit: kLooxReviewBatchSize,
        total: _total,
        fallback: widget.fallbackReviews,
      );
      if (!mounted) return;
      final additions = _withoutExisting(page.reviews);
      setState(() {
        _reviews = [..._reviews, ...additions];
        _loadingMore = false;
        _hasMore = page.hasMore && additions.isNotEmpty;
        _nextPage = page.page + 1;
        _total = page.total ?? _total;
        _average = page.average ?? _average;
        _count = page.total ?? _count;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _loadMoreError = error;
      });
    }
  }

  void _retryInitial() {
    if (_initialLoading) return;
    setState(() {
      _initialLoading = true;
      _initialError = null;
      _hasMore = true;
    });
    unawaited(_loadFirstPage());
  }

  List<HomeTestimonial> _uniqueReviews(Iterable<HomeTestimonial> reviews) {
    final result = <HomeTestimonial>[];
    final seen = <String>{};
    for (final review in reviews) {
      final key = _reviewKey(review);
      if (seen.add(key)) result.add(review);
    }
    return result;
  }

  List<HomeTestimonial> _withoutExisting(Iterable<HomeTestimonial> reviews) {
    final seen = _reviews.map(_reviewKey).toSet();
    return _uniqueReviews(reviews).where((review) {
      return seen.add(_reviewKey(review));
    }).toList();
  }

  String _reviewKey(HomeTestimonial review) =>
      '${review.reviewer}\u0000${review.body}\u0000${review.imageUrl ?? ''}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Experiencias',
          style: display(20, weight: FontWeight.w500, height: 1.1),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Divider(height: 0.5, color: kLine),
        ),
      ),
      body: CustomScrollView(
        key: const ValueKey('customer-experiences-scroll'),
        controller: _scroll,
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          if (_initialLoading && _reviews.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => const _ReviewSkeleton(),
                  childCount: 3,
                ),
              ),
            )
          else if (_reviews.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyReviews(
                hasError: _initialError != null,
                onRetry: _initialError == null ? null : _retryInitial,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == _reviews.length) return _buildFooter();
                    return _ReviewListCard(
                      key: ValueKey('customer-experience-review-$index'),
                      review: _reviews[index],
                    );
                  },
                  childCount: _reviews.length + _footerCount,
                ),
              ),
            ),
        ],
      ),
    );
  }

  int get _footerCount {
    if (_initialLoading ||
        _loadingMore ||
        _loadMoreError != null ||
        !_hasMore) {
      return 1;
    }
    return 0;
  }

  Widget _buildHeader() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kReviewPageMaxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 42, 20, 30),
          child: Column(
            children: [
              Text(
                'EXPERIENCIAS DE CLIENTES',
                textAlign: TextAlign.center,
                style: editorial(26, height: 1.3),
              ),
              const SizedBox(height: 14),
              Text(
                'Historias reales de quienes ya compraron en Monetta.',
                textAlign: TextAlign.center,
                style: sans(size: 14, color: kInkMuted, height: 1.55),
              ),
              if (_average != null || _count != null) ...[
                const SizedBox(height: 18),
                _ReviewTrustSummary(average: _average, count: _count),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    if (_initialLoading || _loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: kGold,
          ),
        ),
      );
    }
    if (_initialError != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        child: Column(
          children: [
            Text(
              'No pudimos actualizar las reseñas.',
              textAlign: TextAlign.center,
              style: sans(size: 13, color: kInkMuted),
            ),
            TextButton(
              key: const ValueKey('customer-experiences-retry-initial'),
              onPressed: _retryInitial,
              child: const Text('REINTENTAR'),
            ),
          ],
        ),
      );
    }
    if (_loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        child: Column(
          children: [
            Text(
              'No pudimos cargar más reseñas.',
              textAlign: TextAlign.center,
              style: sans(size: 13, color: kInkMuted),
            ),
            TextButton(
              key: const ValueKey('customer-experiences-retry-more'),
              onPressed: () => unawaited(_loadMore()),
              child: const Text('REINTENTAR'),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Text(
        _total == null
            ? 'Has visto todas las reseñas disponibles.'
            : 'Has visto $_total reseñas.',
        textAlign: TextAlign.center,
        style: sans(size: 12, color: kInkMuted),
      ),
    );
  }
}

class _ReviewListCard extends StatelessWidget {
  const _ReviewListCard({required this.review, super.key});

  final HomeTestimonial review;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 700;
          final photo = _ReviewListPhoto(review: review);
          final copy = _ReviewListCopy(review: review, wide: wide);
          return Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: kMist,
              borderRadius: BorderRadius.circular(_kReviewCardRadius),
            ),
            child: wide
                ? SizedBox(
                    height: 300,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: 300, child: photo),
                        Expanded(child: copy),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: 250, child: photo),
                      SizedBox(height: 300, child: copy),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _ReviewListPhoto extends StatelessWidget {
  const _ReviewListPhoto({required this.review});

  final HomeTestimonial review;

  @override
  Widget build(BuildContext context) {
    final url = review.imageUrl;
    final hasUrl = url != null && MediaUrl.isHttps(url);
    return Semantics(
      image: true,
      label: review.imageAlt ?? 'Foto de ${review.reviewer}',
      excludeSemantics: true,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasUrl)
            MonettaImage(
              url: url,
              fit: BoxFit.cover,
              cacheWidth: MediaUrl.cardWidth,
            )
          else if (review.fallbackAsset.isNotEmpty)
            Image.asset(review.fallbackAsset, fit: BoxFit.cover)
          else
            const ColoredBox(
              color: kMist,
              child: Center(child: MonettaWordmark(height: 20)),
            ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Colors.transparent, Color(0x66000000)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewListCopy extends StatelessWidget {
  const _ReviewListCopy({required this.review, required this.wide});

  final HomeTestimonial review;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(wide ? 36 : 24, 26, wide ? 36 : 24, 28),
      child: Column(
        crossAxisAlignment:
            wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          _ReviewStars(rating: review.rating),
          const SizedBox(height: 14),
          Expanded(
            child: Align(
              alignment: wide ? Alignment.topLeft : Alignment.topCenter,
              child: Text(
                review.body,
                maxLines: wide ? 7 : 8,
                overflow: TextOverflow.ellipsis,
                textAlign: wide ? TextAlign.start : TextAlign.center,
                style: display(wide ? 21 : 18, height: 1.4),
              ),
            ),
          ),
          if (review.productName != null) ...[
            const SizedBox(height: 14),
            Text(
              review.productName!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: wide ? TextAlign.start : TextAlign.center,
              style: sans(size: 12, color: kInkMuted),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment:
                wide ? MainAxisAlignment.start : MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  review.reviewer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: sans(size: 14, weight: FontWeight.w500),
                ),
              ),
              if (review.verified) ...[
                const SizedBox(width: 4),
                const Icon(Icons.verified, size: 16, color: Color(0xFF0994D4)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewStars extends StatelessWidget {
  const _ReviewStars({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$rating de 5 estrellas',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < 5; index++) ...[
            if (index > 0) const SizedBox(width: 3),
            Icon(
              index < rating ? Icons.star : Icons.star_border,
              color: kGold,
              size: 18,
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewTrustSummary extends StatelessWidget {
  const _ReviewTrustSummary({this.average, this.count});

  final double? average;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _ReviewStars(rating: 5),
        if (average != null) ...[
          const SizedBox(width: 8),
          Text(average!.toStringAsFixed(1), style: sans(size: 15)),
        ],
        if (count != null) ...[
          const SizedBox(width: 8),
          Text('$count reseñas', style: sans(size: 15, color: kInkMuted)),
        ],
      ],
    );
  }
}

class _ReviewSkeleton extends StatelessWidget {
  const _ReviewSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 330,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: kMist,
        borderRadius: BorderRadius.circular(_kReviewCardRadius),
      ),
    );
  }
}

class _EmptyReviews extends StatelessWidget {
  const _EmptyReviews({required this.hasError, this.onRetry});

  final bool hasError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hasError
                  ? 'No pudimos cargar las reseñas.'
                  : 'Aún no hay reseñas publicadas.',
              textAlign: TextAlign.center,
              style: display(22, height: 1.3),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              TextButton(
                onPressed: onRetry,
                child: const Text('REINTENTAR'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
