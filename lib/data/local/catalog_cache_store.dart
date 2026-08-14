/// Read/write access to the cached catalog — `CachedProducts`,
/// `CachedVariants` and `CachedCollections` — plus conversion to and from
/// the domain types (`domain/product.dart`, `domain/collection.dart`).
///
/// This class only talks to Drift. It does not know about Shopify or the
/// bundled asset seed — see `lib/data/repositories/catalog_repository.dart`
/// for the layer that wires this together with `data/shopify`.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/collection.dart' as domain;
import '../../domain/product.dart';
import 'database.dart';

class CatalogCacheStore {
  CatalogCacheStore(this._db);

  final AppDatabase _db;

  /// True on a brand-new install — nothing has ever been written here.
  Future<bool> isEmpty() async {
    final row = await _db.select(_db.cachedProducts).get();
    return row.isEmpty;
  }

  Future<List<Product>> allProducts() async {
    final productRows = await _db.select(_db.cachedProducts).get();
    if (productRows.isEmpty) return const [];

    final variantRows = await _db.select(_db.cachedVariants).get();
    final variantsByProduct = <String, List<ProductVariant>>{};
    for (final row in variantRows) {
      (variantsByProduct[row.productId] ??= []).add(_variantFromRow(row));
    }

    return [
      for (final row in productRows)
        _productFromRow(row, variantsByProduct[row.id] ?? const []),
    ];
  }

  Future<List<domain.Collection>> allCollections() async {
    final rows = await _db.select(_db.cachedCollections).get();
    return [for (final row in rows) _collectionFromRow(row)];
  }

  /// Replaces the stored rows for every product in [products] — an insert or
  /// a full overwrite of an existing row, never a partial patch. Variants are
  /// replaced wholesale per product so a removed variant disappears from the
  /// cache instead of lingering.
  Future<void> upsertProducts(List<Product> products) async {
    if (products.isEmpty) return;
    await _db.transaction(() async {
      for (final product in products) {
        await _db.into(_db.cachedProducts).insertOnConflictUpdate(
              _productToCompanion(product),
            );
        await (_db.delete(_db.cachedVariants)
              ..where((t) => t.productId.equals(product.id)))
            .go();
        for (final variant in product.variants) {
          await _db.into(_db.cachedVariants).insertOnConflictUpdate(
                _variantToCompanion(product.id, variant),
              );
        }
      }
    });
  }

  Future<void> upsertCollections(List<domain.Collection> collections) async {
    if (collections.isEmpty) return;
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(
        _db.cachedCollections,
        [for (final collection in collections) _collectionToCompanion(collection)],
      );
    });
  }

  Product _productFromRow(CachedProduct row, List<ProductVariant> variants) {
    return Product(
      id: row.id,
      handle: row.handle,
      title: row.title,
      vendor: row.vendor,
      productType: row.productType,
      tags: _decodeStringList(row.tags),
      variants: variants,
      images: _decodeStringList(row.images),
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
      descriptionHtml: row.descriptionHtml,
      collectionHandles: _decodeStringList(row.collectionHandles),
      brandOverride: row.brandOverride,
      categoryOverride: row.categoryOverride,
    );
  }

  CachedProductsCompanion _productToCompanion(Product product) {
    return CachedProductsCompanion.insert(
      id: product.id,
      handle: product.handle,
      title: product.title,
      vendor: product.vendor,
      productType: product.productType,
      tags: Value(_encodeStringList(product.tags)),
      images: Value(_encodeStringList(product.images)),
      descriptionHtml: Value(product.descriptionHtml),
      collectionHandles: Value(_encodeStringList(product.collectionHandles)),
      brandOverride: Value(product.brandOverride),
      categoryOverride: Value(product.categoryOverride),
      createdAt: product.createdAt,
      updatedAt: product.updatedAt,
    );
  }

  ProductVariant _variantFromRow(CachedVariant row) {
    return ProductVariant(
      id: row.id,
      title: row.title,
      price: row.price,
      available: row.available,
      compareAtPrice: row.compareAtPrice,
      sku: row.sku,
    );
  }

  CachedVariantsCompanion _variantToCompanion(
    String productId,
    ProductVariant variant,
  ) {
    return CachedVariantsCompanion.insert(
      id: variant.id,
      productId: productId,
      title: variant.title,
      price: variant.price,
      available: variant.available,
      compareAtPrice: Value(variant.compareAtPrice),
      sku: Value(variant.sku),
    );
  }

  domain.Collection _collectionFromRow(CachedCollection row) {
    return domain.Collection(
      id: row.id,
      handle: row.handle,
      title: row.title,
      description: row.description,
      imageUrl: row.imageUrl,
      productCount: row.productCount,
    );
  }

  CachedCollectionsCompanion _collectionToCompanion(domain.Collection collection) {
    return CachedCollectionsCompanion.insert(
      id: collection.id,
      handle: collection.handle,
      title: collection.title,
      description: Value(collection.description),
      imageUrl: Value(collection.imageUrl),
      productCount: Value(collection.productCount),
    );
  }
}

List<String> _decodeStringList(String jsonText) =>
    (jsonDecode(jsonText) as List<dynamic>).cast<String>();

String _encodeStringList(List<String> values) => jsonEncode(values);
