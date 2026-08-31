/// Coalesced, bounded-freshness shopper state for Today's Picks.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/shopify/featured_catalog_repository.dart';
import '../domain/product.dart';

enum FeaturedCatalogStatus { idle, loading, live, empty, unavailable }

class FeaturedCatalogController extends ChangeNotifier {
  FeaturedCatalogController({
    required FeaturedCatalogRepository repository,
    Future<void> Function(List<Product> products)? cacheProducts,
    this.freshness = const Duration(seconds: 60),
  })  : _repository = repository,
        _cacheProducts = cacheProducts;

  final FeaturedCatalogRepository _repository;
  final Future<void> Function(List<Product> products)? _cacheProducts;
  final Duration freshness;
  Future<void>? _inFlight;

  List<Product> products = const [];
  FeaturedCatalogStatus status = FeaturedCatalogStatus.idle;
  DateTime? lastFetchedAt;
  Object? lastError;

  Future<void> refresh() {
    final active = _inFlight;
    if (active != null) return active;
    status = FeaturedCatalogStatus.loading;
    notifyListeners();
    final future = _refresh();
    _inFlight = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_inFlight, future)) _inFlight = null;
      }),
    );
    return future;
  }

  Future<void> refreshIfStale() {
    final fetched = lastFetchedAt;
    if (fetched != null && DateTime.now().difference(fetched) < freshness) {
      return Future<void>.value();
    }
    return refresh();
  }

  Future<void> _refresh() async {
    try {
      final next = await _repository.fetch();
      // Make returned Shopify rows available to the normal local catalog
      // before notifying the widget tree that the rail can render.
      await _cacheProducts?.call(next);
      products = next;
      status = next.isEmpty
          ? FeaturedCatalogStatus.empty
          : FeaturedCatalogStatus.live;
      lastError = null;
      lastFetchedAt = DateTime.now();
    } on Object catch (error) {
      // A failed refresh must not present yesterday's IDs as today's truth.
      products = const [];
      status = FeaturedCatalogStatus.unavailable;
      lastError = error;
    }
    notifyListeners();
  }
}
