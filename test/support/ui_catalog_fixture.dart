import 'dart:convert';
import 'dart:io';

import 'package:monetta_app/data/local/catalog_cache_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/repositories/catalog_repository.dart';

/// Keeps UI-04's approved visual inputs independent of live catalog refreshes.
Future<void> seedUi04Catalog(AppDatabase database) async {
  final snapshot = jsonDecode(
    File('test/fixtures/ui04_catalog_2026_10_07.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final products = (snapshot['products'] as List<dynamic>)
      .map((row) => productFromCatalogSnapshot(row as Map<String, dynamic>))
      .toList(growable: false);
  await CatalogCacheStore(database).replaceProducts(
    products,
    metadata: CatalogCacheMetadata.forProducts(
      // An authoritative fixture prevents bootstrap from backfilling live rows.
      source: CatalogCacheSource.shopify,
      products: products,
      syncedAt: DateTime.parse(snapshot['_snapshot'] as String),
      status: CatalogCacheStatus.healthy,
      shopDomain: Uri.parse(snapshot['_source'] as String).host,
    ),
  );
}
