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

enum CatalogCacheSource { asset, legacyCache, firestore, shopify }

enum CatalogCacheStatus { fallback, healthy, unavailable, invalid }

class CatalogCacheMetadata {
  const CatalogCacheMetadata({
    required this.source,
    required this.syncedAt,
    required this.productCount,
    required this.fingerprint,
    required this.status,
    this.detail,
    this.shopDomain,
  });

  factory CatalogCacheMetadata.forProducts({
    required CatalogCacheSource source,
    required List<Product> products,
    required DateTime? syncedAt,
    required CatalogCacheStatus status,
    String? detail,
    String? shopDomain,
  }) =>
      CatalogCacheMetadata(
        source: source,
        syncedAt: syncedAt?.toUtc(),
        productCount: products.length,
        fingerprint: catalogFingerprint(products),
        status: status,
        detail: detail,
        shopDomain: shopDomain,
      );

  final CatalogCacheSource source;
  final DateTime? syncedAt;
  final int productCount;
  final String fingerprint;
  final CatalogCacheStatus status;
  final String? detail;
  final String? shopDomain;

  CatalogCacheMetadata copyWith({
    CatalogCacheSource? source,
    DateTime? syncedAt,
    int? productCount,
    String? fingerprint,
    CatalogCacheStatus? status,
    String? detail,
    String? shopDomain,
  }) =>
      CatalogCacheMetadata(
        source: source ?? this.source,
        syncedAt: syncedAt ?? this.syncedAt,
        productCount: productCount ?? this.productCount,
        fingerprint: fingerprint ?? this.fingerprint,
        status: status ?? this.status,
        detail: detail,
        shopDomain: shopDomain ?? this.shopDomain,
      );
}

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

  Future<CatalogCacheMetadata?> metadata() async {
    final row = await (_db.select(_db.catalogStates)
          ..where((table) => table.id.equals(0)))
        .getSingleOrNull();
    if (row == null) return null;
    return CatalogCacheMetadata(
      source: CatalogCacheSource.values.byName(row.source),
      syncedAt: row.syncedAt?.toUtc(),
      productCount: row.productCount,
      fingerprint: row.fingerprint,
      status: CatalogCacheStatus.values.byName(row.status),
      detail: row.detail,
      shopDomain: row.shopDomain,
    );
  }

  /// Replaces the stored rows for every product in [products] — an insert or
  /// a full overwrite of an existing row, never a partial patch. Variants are
  /// replaced wholesale per product so a removed variant disappears from the
  /// cache instead of lingering.
  Future<void> upsertProducts(List<Product> products) async {
    if (products.isEmpty) return;
    await _db.transaction(() async {
      await _upsertProducts(products);
    });
  }

  Future<void> seedProducts(
    List<Product> products,
    CatalogCacheMetadata metadata,
  ) async {
    if (products.isEmpty) return;
    await _db.transaction(() async {
      await _upsertProducts(products);
      await _writeMetadata(metadata);
    });
  }

  /// Atomically replaces the complete catalog after a validated authoritative
  /// snapshot. A legitimate empty [products] list clears the cache — failed
  /// partial syncs must not call this.
  Future<void> replaceProducts(
    List<Product> products, {
    CatalogCacheMetadata? metadata,
  }) async {
    await _db.transaction(() async {
      await _db.delete(_db.cachedVariants).go();
      await _db.delete(_db.cachedProducts).go();
      if (products.isNotEmpty) await _upsertProducts(products);
      if (metadata != null) await _writeMetadata(metadata);
    });
  }

  /// Drops every cached product/variant row without touching shopper bag or
  /// wishlist state. Used when the configured shop domain changes.
  Future<void> clearCatalog() async {
    await _db.transaction(() async {
      await _db.delete(_db.cachedVariants).go();
      await _db.delete(_db.cachedProducts).go();
      await _db.delete(_db.catalogStates).go();
    });
  }

  Future<void> saveMetadata(CatalogCacheMetadata metadata) =>
      _writeMetadata(metadata);

  Future<void> _writeMetadata(CatalogCacheMetadata metadata) {
    return _db.into(_db.catalogStates).insertOnConflictUpdate(
          CatalogStatesCompanion.insert(
            id: const Value(0),
            source: metadata.source.name,
            syncedAt: Value(metadata.syncedAt),
            productCount: metadata.productCount,
            fingerprint: metadata.fingerprint,
            status: metadata.status.name,
            detail: Value(metadata.detail),
            shopDomain: Value(metadata.shopDomain),
          ),
        );
  }

  Future<void> _upsertProducts(List<Product> products) async {
    for (final product in products) {
      await _upsertProduct(product);
    }
  }

  Future<void> _upsertProduct(Product product) async {
    await _db.into(_db.cachedProducts).insertOnConflictUpdate(
          _productToCompanion(product),
        );
    await (_db.delete(_db.cachedVariants)
          ..where((table) => table.productId.equals(product.id)))
        .go();
    for (final variant in product.variants) {
      await _db.into(_db.cachedVariants).insertOnConflictUpdate(
            _variantToCompanion(product.id, variant),
          );
    }
  }

  Future<void> upsertCollections(List<domain.Collection> collections) async {
    if (collections.isEmpty) return;
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(
        _db.cachedCollections,
        [
          for (final collection in collections)
            _collectionToCompanion(collection),
        ],
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

  CachedCollectionsCompanion _collectionToCompanion(
    domain.Collection collection,
  ) {
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

/// Stable, non-cryptographic identity for one catalog observation.
String catalogFingerprint(List<Product> products) {
  final ordered = [...products]..sort((a, b) => a.id.compareTo(b.id));
  var hash = 0x811c9dc5;
  for (final product in ordered) {
    final value =
        '${product.id}\u001f${product.updatedAt.toUtc().toIso8601String()}'
        '\u001f${product.images.join('\u001e')}';
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
