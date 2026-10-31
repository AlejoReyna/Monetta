/// Public, read-only Loox reviews for the Monetta storefront.
///
/// Live source: the same public widget JSON that `monetta.mx` loads for
/// `loox-dynamic-carousel-widget`:
/// `https://loox.io/widget/{publicStoreId}/dynamic-carousel/reviews/`.
///
/// That endpoint is the storefront authority for the compact home carousel.
/// The full widget endpoint is also paginated and powers the dedicated review
/// screen without exposing a merchant credential.
///
/// Exact from that JSON: reviewer, rating, body, verified flag, HTTPS photo,
/// product name (image description only). Widget-only: Swiper material-effect
/// peek, iframe chrome, merchant empty-state. Bundled testimonials are
/// offline/error fallback, never mixed into a successful live payload.
library;

import 'dart:async';
import 'dart:convert';

import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../../domain/home_content.dart';
import '../http/timeout_http_client.dart';

typedef LooxGet = Future<http.Response> Function(Uri uri);

/// Public Loox widget client id published in the live storefront HTML.
const String kLooxPublicStoreId = 'o68QLEOJFW';

const int kLooxReviewBatchSize = 20;

// Kept as a named carousel constant because the compact home feed and its
// tests still describe the original Loox widget behavior.
const int kLooxCarouselLimit = kLooxReviewBatchSize;

const int kLooxReviewBodyLimit = 2000;

class LooxConfig {
  const LooxConfig({required this.publicStoreId});

  final String publicStoreId;

  bool get isUsable => publicStoreId.trim().isNotEmpty;

  String get _id => publicStoreId.trim();

  Uri get reviewsEndpoint => Uri.https(
        'loox.io',
        '/widget/$_id/dynamic-carousel/reviews/',
      );

  Uri reviewsPageEndpoint({
    required int page,
    int limit = kLooxReviewBatchSize,
    int? total,
  }) {
    return Uri.https(
      'loox.io',
      '/widget/$_id/reviews',
      <String, String>{
        'page': '$page',
        'limit': '$limit',
        if (total != null) 'total': '$total',
        'language': 'es',
      },
    );
  }

  Uri get summaryEndpoint => Uri.https(
        'loox.io',
        '/widget/$_id/reviews',
      );

  factory LooxConfig.fromEnvironment() {
    const id = String.fromEnvironment(
      'LOOX_PUBLIC_STORE_ID',
      defaultValue: kLooxPublicStoreId,
    );
    return const LooxConfig(publicStoreId: id);
  }
}

class LooxReviewsResult {
  const LooxReviewsResult({
    required this.reviews,
    this.average,
    this.count,
    this.fromRemote = false,
  });

  final List<HomeTestimonial> reviews;
  final double? average;
  final int? count;
  final bool fromRemote;
}

class LooxReviewsPage {
  const LooxReviewsPage({
    required this.reviews,
    required this.page,
    required this.limit,
    required this.hasMore,
    this.total,
    this.average,
    this.fromRemote = false,
  });

  final List<HomeTestimonial> reviews;
  final int page;
  final int limit;
  final bool hasMore;
  final int? total;
  final double? average;
  final bool fromRemote;
}

class LooxReviewsRepository {
  LooxReviewsRepository({
    required this.config,
    LooxGet? get,
    Duration timeout = kDefaultHttpTimeout,
  })  : _get = get ?? http.get,
        _timeout = timeout;

  final LooxConfig config;
  final LooxGet _get;
  final Duration _timeout;

  /// One bounded call to [_get]; a call that never answers fails as an
  /// [http.ClientException], like any other transport failure here.
  Future<http.Response> _getWithin(Uri uri) async {
    try {
      return await _get(uri).timeout(_timeout);
    } on TimeoutException {
      throw http.ClientException('Reviews request timed out', uri);
    }
  }

  Future<LooxReviewsPage> fetchPage({
    int page = 1,
    int limit = kLooxReviewBatchSize,
    int? total,
    List<HomeTestimonial>? fallback,
  }) async {
    final fallbackReviews = fallback ?? HomeContent.fallback.testimonials;
    final safePage = page < 1 ? 1 : page;
    final safeLimit = limit < 1
        ? 1
        : limit > 250
            ? 250
            : limit;
    if (!config.isUsable) {
      return LooxReviewsPage(
        reviews: fallbackReviews,
        page: safePage,
        limit: safeLimit,
        hasMore: false,
        total: fallbackReviews.length,
      );
    }

    final endpoint = config.reviewsPageEndpoint(
      page: safePage,
      limit: safeLimit,
      total: total,
    );
    final response = await _getWithin(endpoint);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Reviews page returned HTTP ${response.statusCode}',
        endpoint,
      );
    }

    final document = html_parser.parse(response.body);
    final items = document.querySelectorAll('.grid-item-wrap[data-id]');
    final reviews = <HomeTestimonial>[];
    for (var index = 0; index < items.length; index++) {
      final mapped = _reviewElement(items[index], fallbackReviews, index);
      if (mapped != null) reviews.add(mapped);
    }

    final loadMore = document.querySelector('#loadMore');
    final nextQuery = loadMore?.attributes['data-url'];
    final parsedTotal =
        _htmlReviewCount(document) ?? _queryInt(nextQuery, 'total') ?? total;
    return LooxReviewsPage(
      reviews: List.unmodifiable(reviews),
      page: safePage,
      limit: safeLimit,
      hasMore: nextQuery != null && reviews.isNotEmpty,
      total: parsedTotal,
      average: _htmlReviewAverage(document),
      fromRemote: true,
    );
  }

  Future<LooxReviewsResult> fetch({List<HomeTestimonial>? fallback}) async {
    final fallbackReviews = fallback ?? HomeContent.fallback.testimonials;
    if (!config.isUsable) {
      return LooxReviewsResult(reviews: fallbackReviews);
    }

    final response = await _getWithin(config.reviewsEndpoint);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Reviews returned HTTP ${response.statusCode}',
        config.reviewsEndpoint,
      );
    }
    final decoded = jsonDecode(response.body);
    final maps = _reviewMaps(decoded);
    final reviews = <HomeTestimonial>[];
    for (var index = 0; index < maps.length; index++) {
      final mapped = _review(maps[index], fallbackReviews, index);
      if (mapped != null) reviews.add(mapped);
      if (reviews.length == kLooxCarouselLimit) break;
    }

    var average = _numberAt(decoded, const [
      'average_rating',
      'averageRating',
      'rating_average',
    ]);
    var count = _numberAt(decoded, const [
      'total_reviews',
      'totalReviews',
      'review_count',
      'count',
    ])?.round();

    if (average == null || count == null) {
      final summary = await _summary();
      average ??= summary.average;
      count ??= summary.count;
    }

    return LooxReviewsResult(
      reviews: List.unmodifiable(reviews),
      average: average,
      count: count,
      fromRemote: true,
    );
  }

  HomeTestimonial? _reviewElement(
    html_dom.Element item,
    List<HomeTestimonial> fallback,
    int index,
  ) {
    final id = item.attributes['data-id'];
    if (id == null || id.isEmpty) return null;

    final bodyElement = _testId(item, 'review-$id-text');
    final body = _sanitizeBody(bodyElement?.text);
    if (body == null) return null;

    final titleElement = _testId(item, 'review-$id-title');
    final reviewerElement =
        titleElement?.querySelector('.title') ?? titleElement;
    final reviewer = _publicReviewer(_directText(reviewerElement)) ??
        _publicReviewer(reviewerElement?.text) ??
        'Cliente Monetta';
    final stars = _testId(item, 'review-$id-stars');
    final fullStars =
        stars?.querySelectorAll('[data-lx-fill="full"]').length ?? 0;
    final rating = (fullStars == 0 ? 5 : fullStars).clamp(1, 5).toInt();
    final media = _testId(item, 'review-$id-media');
    final image = media?.querySelector('img');
    final imageUrl = _httpsUrl(
      image?.attributes['src'] ??
          image?.attributes['data-src'] ??
          image?.attributes['thesrc'],
    );
    final productName = _sanitizePlain(
      item.querySelector('.product-box .name')?.text,
    );
    final imageAlt = _sanitizePlain(image?.attributes['alt']) ??
        (productName == null ? null : 'Foto de $productName');
    final seed = fallback.isEmpty ? null : fallback[index % fallback.length];
    return HomeTestimonial(
      reviewer: reviewer,
      body: body,
      rating: rating,
      imageUrl: imageUrl,
      imageAlt: imageAlt,
      productName: productName,
      fallbackAsset: seed?.fallbackAsset ?? '',
      verified: item.querySelector('.loox-verified-badge') != null,
    );
  }

  html_dom.Element? _testId(html_dom.Element root, String value) {
    for (final element in root.querySelectorAll('[data-testid]')) {
      if (element.attributes['data-testid'] == value) return element;
    }
    return null;
  }

  String? _directText(html_dom.Element? element) {
    if (element == null) return null;
    final value = element.nodes
        .whereType<html_dom.Text>()
        .map((node) => node.data)
        .join(' ');
    return value.trim().isEmpty ? null : value;
  }

  double? _htmlReviewAverage(html_dom.Document document) {
    final summary =
        document.querySelector('[data-testid="rating-summary-avg"]');
    return _numberInText(summary?.attributes['aria-label'] ?? summary?.text);
  }

  int? _htmlReviewCount(html_dom.Document document) {
    final summary =
        document.querySelector('[data-testid="rating-summary-count"]');
    final value = _numberInText(summary?.text);
    return value?.round();
  }

  double? _numberInText(String? value) {
    if (value == null) return null;
    final match = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(value);
    if (match == null) return null;
    return double.tryParse(match.group(0)!.replaceAll(',', '.'));
  }

  int? _queryInt(String? query, String key) {
    if (query == null) return null;
    try {
      return int.tryParse(Uri.splitQueryString(query)[key] ?? '');
    } on FormatException {
      return null;
    }
  }

  Future<({double? average, int? count})> _summary() async {
    try {
      final response = await _getWithin(config.summaryEndpoint);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return (average: null, count: null);
      }
      return _summaryFromHtml(response.body);
    } on Object {
      return (average: null, count: null);
    }
  }

  ({double? average, int? count}) _summaryFromHtml(String html) {
    final averageMatch =
        RegExp(r'Average rating:\s*([0-9]+(?:\.[0-9]+)?)').firstMatch(html);
    final countMatch = RegExp(
      r'rating-summary-count[^>]*>\s*<span>\s*([0-9]+)',
      caseSensitive: false,
    ).firstMatch(html);
    return (
      average:
          averageMatch == null ? null : double.tryParse(averageMatch.group(1)!),
      count: countMatch == null ? null : int.tryParse(countMatch.group(1)!),
    );
  }

  List<Map<String, dynamic>> _reviewMaps(Object? raw) {
    if (raw is List) return raw.whereType<Map<String, dynamic>>().toList();
    if (raw is! Map) return const [];
    final map = raw.cast<Object?, Object?>();
    final agg = map['agg'];
    if (agg is Map) {
      final nested = _reviewMaps(agg);
      if (nested.isNotEmpty) return nested;
    }
    for (final key in const ['reviews', 'items', 'results', 'data']) {
      final found = _reviewMaps(map[key]);
      if (found.isNotEmpty) return found;
    }
    return const [];
  }

  HomeTestimonial? _review(
    Map<String, dynamic> raw,
    List<HomeTestimonial> fallback,
    int index,
  ) {
    final body = _sanitizeBody(
      _text(raw, const ['review', 'body', 'text', 'content']),
    );
    if (body == null) return null;
    final seed = fallback.isEmpty ? null : fallback[index % fallback.length];
    final rating =
        (_number(raw, const ['rating', 'score']) ?? 5).round().clamp(1, 5);
    final productName = _sanitizePlain(
      _text(raw, const ['productName', 'product_name', 'product']),
    );
    final imageAlt = _sanitizePlain(
          _text(raw, const ['altText', 'alt_text', 'alt']),
        ) ??
        (productName == null ? null : 'Foto de $productName');
    return HomeTestimonial(
      reviewer: _publicReviewer(
            _text(
              raw,
              const [
                'reviewer',
                'reviewer_name',
                'reviewerName',
                'author',
                'name',
              ],
            ),
          ) ??
          'Cliente Monetta',
      body: body,
      rating: rating,
      imageUrl: _imageUrl(raw),
      imageAlt: imageAlt,
      productName: productName,
      fallbackAsset: seed?.fallbackAsset ?? '',
      verified: _bool(raw, const ['verified', 'verified_purchase']) ?? true,
    );
  }

  String? _imageUrl(Map<String, dynamic> raw) {
    final direct = _httpsUrl(
      _text(
        raw,
        const [
          'midImage',
          'poster',
          'image_url',
          'imageUrl',
          'photo_url',
          'photoUrl',
        ],
      ),
    );
    if (direct != null) return direct;
    for (final key in const ['images', 'photos', 'media']) {
      final value = raw[key];
      if (value is! List || value.isEmpty) continue;
      final first = value.first;
      if (first is String) {
        final url = _httpsUrl(first);
        if (url != null) return url;
      }
      if (first is Map) {
        final nested = _httpsUrl(
          _text(
            first.cast<String, dynamic>(),
            const ['url', 'src', 'image_url', 'imageUrl', 'midImage', 'poster'],
          ),
        );
        if (nested != null) return nested;
      }
    }
    return null;
  }

  double? _numberAt(Object? raw, List<String> keys) {
    if (raw is! Map) return null;
    final map = raw.cast<Object?, Object?>();
    for (final key in keys) {
      final value = map[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    for (final key in const [
      'summary',
      'metadata',
      'pagination',
      'data',
      'agg',
    ]) {
      final found = _numberAt(map[key], keys);
      if (found != null) return found;
    }
    return null;
  }

  double? _number(Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      final value = raw[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  String? _text(Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      final value = raw[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  bool? _bool(Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      final value = raw[key];
      if (value is bool) return value;
      if (value is String) {
        if (value.toLowerCase() == 'true') return true;
        if (value.toLowerCase() == 'false') return false;
      }
    }
    return null;
  }

  String? _httpsUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var value = raw.trim();
    if (value.startsWith('//')) value = 'https:$value';
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.isScheme('https') || uri.host.isEmpty) {
      return null;
    }
    if (uri.userInfo.isNotEmpty) return null;
    return uri.toString();
  }

  String? _sanitizeBody(String? raw) {
    final plain = _sanitizePlain(raw);
    if (plain == null) return null;
    if (plain.length <= kLooxReviewBodyLimit) return plain;
    return plain.substring(0, kLooxReviewBodyLimit).trim();
  }

  String? _sanitizePlain(String? raw) {
    if (raw == null) return null;
    final stripped = raw
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'&nbsp;', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (stripped.isEmpty) return null;
    return stripped;
  }

  String? _publicReviewer(String? raw) {
    final value = _sanitizePlain(raw);
    if (value == null) return null;
    if (value.contains('@')) return 'Cliente Monetta';
    if (RegExp(r'\d{6,}')
        .hasMatch(value.replaceAll(RegExp(r'[\s\-\(\)]'), ''))) {
      return 'Cliente Monetta';
    }
    return value;
  }
}
