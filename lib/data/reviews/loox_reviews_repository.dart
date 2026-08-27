/// Public, read-only Loox Storefront API integration for mobile/headless use.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/home_content.dart';

typedef LooxGet = Future<http.Response> Function(Uri uri);

class LooxConfig {
  const LooxConfig({required this.publicStoreId});

  final String publicStoreId;

  bool get isUsable => publicStoreId.trim().isNotEmpty;

  Uri get reviewsEndpoint => Uri.https(
        'storefront-api.loox.io',
        '/storefront/v1/store/${publicStoreId.trim()}/product-reviews',
      );

  factory LooxConfig.fromEnvironment() {
    const id = String.fromEnvironment('LOOX_PUBLIC_STORE_ID');
    return const LooxConfig(publicStoreId: id);
  }
}

class LooxReviewsResult {
  const LooxReviewsResult({
    required this.reviews,
    this.average,
    this.count,
  });

  final List<HomeTestimonial> reviews;
  final double? average;
  final int? count;
}

class LooxReviewsRepository {
  LooxReviewsRepository({required this.config, LooxGet? get})
      : _get = get ?? http.get;

  final LooxConfig config;
  final LooxGet _get;

  Future<LooxReviewsResult> fetch({List<HomeTestimonial>? fallback}) async {
    final fallbackReviews = fallback ?? HomeContent.fallback.testimonials;
    if (!config.isUsable) {
      return LooxReviewsResult(reviews: fallbackReviews);
    }
    final response = await _get(config.reviewsEndpoint);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Loox returned HTTP ${response.statusCode}',
        config.reviewsEndpoint,
      );
    }
    final decoded = jsonDecode(response.body);
    final maps = _reviewMaps(decoded);
    final reviews = <HomeTestimonial>[];
    for (var index = 0; index < maps.length; index++) {
      final mapped = _review(maps[index], fallbackReviews, index);
      if (mapped != null) reviews.add(mapped);
      if (reviews.length == 12) break;
    }
    return LooxReviewsResult(
      reviews: reviews.isEmpty ? fallbackReviews : List.unmodifiable(reviews),
      average: _numberAt(decoded, const [
        'average_rating',
        'averageRating',
        'rating_average',
      ]),
      count: _numberAt(decoded, const [
        'total_reviews',
        'totalReviews',
        'review_count',
        'count',
      ])?.round(),
    );
  }

  List<Map<String, dynamic>> _reviewMaps(Object? raw) {
    if (raw is List) return raw.whereType<Map<String, dynamic>>().toList();
    if (raw is! Map) return const [];
    for (final key in const ['reviews', 'items', 'results', 'data']) {
      final value = raw[key];
      final found = _reviewMaps(value);
      if (found.isNotEmpty) return found;
    }
    return const [];
  }

  HomeTestimonial? _review(
    Map<String, dynamic> raw,
    List<HomeTestimonial> fallback,
    int index,
  ) {
    final body = _text(raw, const ['body', 'review', 'text', 'content']);
    if (body == null) return null;
    final seed = fallback[index % fallback.length];
    final rating =
        (_number(raw, const ['rating', 'score']) ?? 5).round().clamp(1, 5);
    return HomeTestimonial(
      reviewer: _text(
            raw,
            const ['reviewer_name', 'reviewerName', 'author', 'name'],
          ) ??
          'Cliente Monetta',
      body: body,
      rating: rating,
      imageUrl: _imageUrl(raw),
      fallbackAsset: seed.fallbackAsset,
      verified: _bool(raw, const ['verified', 'verified_purchase']) ?? true,
    );
  }

  String? _imageUrl(Map<String, dynamic> raw) {
    final direct = _text(
      raw,
      const ['image_url', 'imageUrl', 'photo_url', 'photoUrl'],
    );
    if (_validUrl(direct)) return direct;
    for (final key in const ['images', 'photos', 'media']) {
      final value = raw[key];
      if (value is! List || value.isEmpty) continue;
      final first = value.first;
      if (first is String && _validUrl(first)) return first;
      if (first is Map) {
        final nested = _text(
          first.cast<String, dynamic>(),
          const ['url', 'src', 'image_url', 'imageUrl'],
        );
        if (_validUrl(nested)) return nested;
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
    for (final key in const ['summary', 'metadata', 'pagination', 'data']) {
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

  bool _validUrl(String? raw) {
    final uri = raw == null ? null : Uri.tryParse(raw);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }
}
