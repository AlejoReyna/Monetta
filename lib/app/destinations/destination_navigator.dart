/// Opens an [AppDestination] on a Navigator.
///
/// It is the single place that knows how each destination is mounted. A
/// product that is not in the cache is looked up (one catalog refresh) rather
/// than silently sending the shopper home.
///
/// The refresh is [CatalogStore.syncWithShopify], which writes through the
/// catalog write coordinator; this file adds no cache writer.
library;

import 'package:flutter/material.dart';

import '../../data/repositories/catalog_repository.dart';
import '../../features/catalog/collection_screen.dart';
import '../../features/catalog/query/collection_filter.dart';
import '../../features/product/product_screen.dart';
import '../catalog_store.dart';
import '../composition/app_scopes.dart';
import '../motion.dart';
import 'app_destination.dart';
import 'destination_screens.dart';

/// Refreshes the catalog and reports how it ended.
typedef CatalogRefresh = Future<CatalogSyncResult> Function();

class DestinationNavigator {
  DestinationNavigator({required CatalogStore store, CatalogRefresh? refresh})
      : _store = store,
        _refresh = refresh ?? store.syncWithShopify;

  final CatalogStore _store;
  final CatalogRefresh _refresh;

  /// Opens [destination]. Every pushed route is wrapped in a [StoreScope] so
  /// the screen sees the store even when it is mounted above the scope.
  ///
  /// The push happens synchronously, before the first `await`.
  Future<void> open(
    NavigatorState navigator,
    AppDestination destination,
  ) async {
    switch (destination) {
      case ProductDestination():
        if (_store.products.any((p) => p.id == destination.productId)) {
          await navigator.push<void>(
            _route(
              ProductScreen(
                productId: destination.productId,
                initialVariantIndex: destination.initialVariantIndex,
              ),
            ),
          );
        } else {
          await navigator.push<void>(
            _route(
              ProductLookupScreen(
                store: _store,
                refresh: _refresh,
                productId: destination.productId,
                initialVariantIndex: destination.initialVariantIndex,
              ),
            ),
          );
        }
      case CollectionDestination():
        await navigator.push<void>(
          _route(
            CollectionScreen(
              title: destination.title ?? destination.handle,
              filter: CollectionFilter(collectionHandle: destination.handle),
            ),
          ),
        );
      case UnavailableLinkDestination():
        await navigator.push<void>(
          _route(const UnavailableLinkScreen()),
        );
      case HomeDestination():
        navigator.popUntil((route) => route.isFirst);
    }
  }

  Route<void> _route(Widget page) =>
      monettaFadeRoute<void>(StoreScope(notifier: _store, child: page));
}
