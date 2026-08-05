/// Loads the live catalog snapshot as domain objects.
///
/// The fixture is a real capture of `https://monetta.mx/products.json` taken on
/// 2026-08-05: 271 products, 452 variants, 21 collections — including every
/// data-quality problem the normalizer exists to handle. Tests run against real
/// mess rather than tidy invented data, which is the point.
library;

import 'dart:convert';
import 'dart:io';

import 'package:monetta_app/domain/product.dart';

const String kFixturePath = 'test/fixtures/catalog_2026_08_05.json';

/// Snapshot date. Use as `now` in tests so `newArrival` is stable forever.
final DateTime kSnapshotDate = DateTime.utc(2026, 8, 5);

List<Product> loadCatalogFixture() {
  final raw = File(kFixturePath).readAsStringSync();
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final products = json['products'] as List<dynamic>;

  return products.map((entry) {
    final p = entry as Map<String, dynamic>;
    return Product(
      id: p['id'].toString(),
      handle: p['handle'] as String,
      title: p['title'] as String,
      vendor: p['vendor'] as String,
      productType: p['product_type'] as String,
      tags: (p['tags'] as List<dynamic>).cast<String>(),
      images: (p['images'] as List<dynamic>).cast<String>(),
      createdAt: DateTime.parse(p['created_at'] as String),
      updatedAt: DateTime.parse(p['updated_at'] as String),
      variants: (p['variants'] as List<dynamic>).map((v) {
        final variant = v as Map<String, dynamic>;
        return ProductVariant(
          id: variant['id'].toString(),
          title: variant['title'] as String,
          price: double.parse(variant['price'] as String),
          available: variant['available'] as bool,
          compareAtPrice: variant['compare_at_price'] == null
              ? null
              : double.parse(variant['compare_at_price'] as String),
        );
      }).toList(),
    );
  }).toList();
}
