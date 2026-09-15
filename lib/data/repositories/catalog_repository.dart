/// Wires `data/local` (cache + sync cursor), `data/shopify` (real delta
/// sync) and `data/normalize` (facets) together — the `data/repositories/`
/// module `docs/ARCHITECTURE.md`'s module map has described since Phase 1
/// planning. See `docs/ACCOUNTS_AND_SYNC_PLAN.md` § 4 (Phase 0) for why this
/// exists now: `data/local` was documented but never built, so nothing
/// wired `data/shopify`'s already-tested `CatalogSync` to a database that
/// could remember a cursor between app opens.
library;

import '../local/bag_store.dart';
import '../local/catalog_cache_store.dart';
import '../local/wishlist_store.dart';
import '../local/sync_cursor_store.dart';
import '../normalize/facets.dart';
import '../normalize/normalizer.dart';
import '../normalize/rules.dart';
import '../shopify/catalog_sync.dart' as shopify;
import '../shopify/shopify_gid.dart';
import '../../domain/product.dart';

class CatalogSnapshot {
  const CatalogSnapshot({required this.products, required this.facetsById});

  final List<Product> products;
  final Map<String, CanonicalFacets> facetsById;

  static const empty = CatalogSnapshot(products: [], facetsById: {});
}

enum CatalogSyncOutcome {
  /// No `StorefrontClient` was supplied — today's honest default, since
  /// there is no Storefront access token yet (see
  /// `lib/data/shopify/README.md` § 3, "The access token comes from Remote
  /// Config, not the binary").
  skippedNotConfigured,

  /// Firestore is connected or still establishing its initial authority.
  /// A Storefront delta must not compete with that writer.
  skippedRealtimeAuthoritative,
  upToDate,
  updated,
  failed,
}

class CatalogSyncResult {
  const CatalogSyncResult({
    required this.outcome,
    this.changedCount = 0,
    this.error,
  });

  final CatalogSyncOutcome outcome;
  final int changedCount;
  final Object? error;
}

class CatalogRepository {
  CatalogRepository({
    required this.cache,
    required this.cursorStore,
    required this.rules,
    shopify.CatalogSync? catalogSync,
    this.shopDomain,
    BagStore? bagStore,
    WishlistStore? wishlistStore,
  })  : _catalogSync = catalogSync,
        _bagStore = bagStore,
        _wishlistStore = wishlistStore;

  final CatalogCacheStore cache;
  final SyncCursorStore cursorStore;
  final NormalizationRules rules;
  final shopify.CatalogSync? _catalogSync;

  /// Configured Storefront host. When set, cursors/metadata from another shop
  /// are rejected and the local catalog is cleared before the next full sync.
  final String? shopDomain;
  final BagStore? _bagStore;
  final WishlistStore? _wishlistStore;

  /// False whenever `StorefrontConfig.isUsable` was false at construction —
  /// see `app/catalog_store.dart` for how the caller decides this today.
  bool get canSyncWithShopify => _catalogSync != null;

  /// First-run seed: if the cache is empty (a fresh install, before any
  /// Shopify sync has ever succeeded), parse the bundled snapshot asset and
  /// write it in, so [loadCached] never returns nothing. A cache that
  /// already has rows is left untouched — this is a seed, not a reset.
  Future<void> seedFromAssetIfEmpty(Map<String, dynamic> catalogJson) async {
    await prepareConfiguredShop();
    if (!await cache.isEmpty()) return;
    final metadata = await cache.metadata();
    final cursor = await cursorStore.load();
    if (metadata?.source == CatalogCacheSource.shopify ||
        cursor.lastFullSyncAt != null) {
      return;
    }
    final products = (catalogJson['products'] as List<dynamic>)
        .map((e) => productFromCatalogSnapshot(e as Map<String, dynamic>))
        .toList();
    await cache.seedProducts(
      products,
      CatalogCacheMetadata.forProducts(
        source: CatalogCacheSource.asset,
        products: products,
        syncedAt: DateTime.tryParse('${catalogJson['_snapshot'] ?? ''}'),
        status: CatalogCacheStatus.fallback,
      ),
    );
  }

  /// Repairs an older local cache without replacing rows that may have been
  /// updated by a real Shopify sync. This matters for installs that were
  /// seeded with an earlier snapshot: the cache is persistent, so the old
  /// "seed only when empty" rule otherwise hides every product added later.
  Future<void> addMissingFromAsset(Map<String, dynamic> catalogJson) async {
    final metadata = await cache.metadata();
    if (metadata != null &&
        metadata.source != CatalogCacheSource.asset &&
        metadata.source != CatalogCacheSource.legacyCache) {
      return;
    }
    final cachedProducts = await cache.allProducts();
    final cachedById = {
      for (final product in cachedProducts) product.id: product,
    };
    if (cachedById.isEmpty) return;

    final repairs = (catalogJson['products'] as List<dynamic>)
        .map((e) => productFromCatalogSnapshot(e as Map<String, dynamic>))
        .map((assetProduct) {
          final cached = cachedById[assetProduct.id];
          if (cached == null) return assetProduct;
          if (cached.descriptionHtml.trim().isNotEmpty ||
              assetProduct.descriptionHtml.trim().isEmpty) {
            return null;
          }
          // Backfill only the newly preserved description. Keep every other
          // cached field so a bundled fallback cannot roll catalog data back.
          return Product(
            id: cached.id,
            handle: cached.handle,
            title: cached.title,
            vendor: cached.vendor,
            productType: cached.productType,
            tags: cached.tags,
            variants: cached.variants,
            images: cached.images,
            createdAt: cached.createdAt,
            updatedAt: cached.updatedAt,
            descriptionHtml: assetProduct.descriptionHtml,
            collectionHandles: cached.collectionHandles,
            brandOverride: cached.brandOverride,
            categoryOverride: cached.categoryOverride,
          );
        })
        .whereType<Product>()
        .toList();
    await cache.upsertProducts(repairs);
  }

  Future<CatalogCacheMetadata?> loadOrCreateMetadata(
    List<Product> products,
  ) async {
    final existing = await cache.metadata();
    if (existing != null) return existing;
    if (products.isEmpty) return null;
    final inferred = CatalogCacheMetadata.forProducts(
      source: CatalogCacheSource.legacyCache,
      products: products,
      syncedAt: null,
      status: CatalogCacheStatus.fallback,
      detail: 'Cache creado antes de registrar procedencia.',
    );
    await cache.saveMetadata(inferred);
    return inferred;
  }

  /// Cached products, normalized. Reads only — the UI should paint from
  /// this immediately, even offline, per `docs/ARCHITECTURE.md`'s "Data
  /// flow: opening the app".
  Future<CatalogSnapshot> loadCached() async {
    final products = await cache.allProducts();
    if (products.isEmpty) return CatalogSnapshot.empty;

    final normalizer = Normalizer(rules);
    final now = DateTime.now();
    return CatalogSnapshot(
      products: products,
      facetsById: {
        for (final product in products)
          product.id: normalizer.normalize(product, now: now),
      },
    );
  }

  /// Runs a real delta sync against Shopify and writes whatever changed into
  /// the cache. A no-op returning [CatalogSyncOutcome.skippedNotConfigured]
  /// when no token is configured — never throws for that case, since an
  /// unconfigured store is expected, not exceptional.
  ///
  /// Incomplete pagination (see [shopify.CatalogSyncIncompleteException]) and
  /// any other failure leave the last-known-good cache and cursor untouched
  /// aside from marking metadata unavailable. A verified full sync replaces
  /// the catalog atomically — including a legitimate empty result.
  Future<CatalogSyncResult> sync() async {
    final catalogSync = _catalogSync;
    if (catalogSync == null) {
      return const CatalogSyncResult(
        outcome: CatalogSyncOutcome.skippedNotConfigured,
      );
    }
    try {
      final cursor = await _cursorForConfiguredShop();
      final result = await catalogSync.run(cursor: cursor, now: DateTime.now());
      final shop = shopDomain ?? result.cursor.shopDomain;

      if (result.wasFullSync) {
        final metadata = CatalogCacheMetadata.forProducts(
          source: CatalogCacheSource.shopify,
          products: result.products,
          syncedAt: DateTime.now(),
          status: CatalogCacheStatus.healthy,
          shopDomain: shop,
        );
        await cache.transaction(() async {
          await cache.replaceProducts(result.products, metadata: metadata);
          await cursorStore.save(result.cursor);
        });
        return CatalogSyncResult(
          outcome: result.hasChanges || metadata.productCount == 0
              ? CatalogSyncOutcome.updated
              : CatalogSyncOutcome.upToDate,
          changedCount: result.products.length,
        );
      }

      if (result.hasChanges) {
        await cache.upsertProducts(result.products);
      }
      await cursorStore.save(result.cursor);
      final products = await cache.allProducts();
      await cache.saveMetadata(
        CatalogCacheMetadata.forProducts(
          source: CatalogCacheSource.shopify,
          products: products,
          syncedAt: DateTime.now(),
          status: CatalogCacheStatus.healthy,
          shopDomain: shop,
        ),
      );
      return CatalogSyncResult(
        outcome: result.hasChanges
            ? CatalogSyncOutcome.updated
            : CatalogSyncOutcome.upToDate,
        changedCount: result.products.length,
      );
    } catch (error) {
      // A failed / incomplete sync must never clear or corrupt what's already
      // cached — same contract as `ExternalCatalogRepository.refresh`.
      final existing = await cache.metadata();
      if (existing != null) {
        await cache.saveMetadata(
          existing.copyWith(
            status: CatalogCacheStatus.unavailable,
            detail: error is shopify.CatalogSyncIncompleteException
                ? error.message
                : error.runtimeType.toString(),
          ),
        );
      }
      return CatalogSyncResult(
        outcome: CatalogSyncOutcome.failed,
        error: error,
      );
    }
  }

  Future<void> prepareConfiguredShop() async {
    await _cursorForConfiguredShop();
  }

  /// Rejects a cursor/catalog belonging to another shop before syncing.
  Future<shopify.SyncCursor> _cursorForConfiguredShop() async {
    final configured = shopDomain;
    final cursor = await cursorStore.load();
    if (configured == null || configured.isEmpty) return cursor;

    final metadata = await cache.metadata();
    final cursorShop = cursor.shopDomain;
    final metaShop = metadata?.shopDomain;
    final mismatch = cursorShop != configured || metaShop != configured;

    if (!mismatch) {
      return cursor;
    }

    // A genuinely fresh install may use the bundled offline preview. Any
    // persisted commerce/session state without provenance requires migration.
    if (metadata == null &&
        cursor.lastUpdatedAt == null &&
        cursor.lastFullSyncAt == null &&
        await cache.isEmpty() &&
        !await cache.hasShopSpecificState()) {
      return shopify.SyncCursor(shopDomain: configured);
    }
    await cache.resetShopState(configured);
    await _bagStore?.clearAllScopes();
    await _wishlistStore?.clearAllScopes();
    return shopify.SyncCursor(shopDomain: configured);
  }
}

/// Maps one product from `assets/catalog/catalog.json`'s snapshot shape —
/// the public Ajax `/products.json` shape, per `domain/product.dart`'s doc
/// comment — into the domain `Product`. Moved from `app/catalog_store.dart`,
/// which owned this before there was a repository layer to own it instead.
Product productFromCatalogSnapshot(Map<String, dynamic> json) => Product(
      id: shopifyProductGid(json['id']),
      handle: json['handle'] as String,
      title: json['title'] as String,
      vendor: json['vendor'] as String,
      productType: json['product_type'] as String,
      tags: (json['tags'] as List<dynamic>).cast<String>(),
      images: (json['images'] as List<dynamic>).cast<String>(),
      descriptionHtml: json['description_html'] as String? ??
          json['body_html'] as String? ??
          '',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      variants: (json['variants'] as List<dynamic>).map((v) {
        final variant = v as Map<String, dynamic>;
        return ProductVariant(
          id: shopifyVariantGid(variant['id']),
          title: variant['title'] as String,
          price: double.parse(variant['price'] as String),
          available: variant['available'] as bool,
          compareAtPrice: variant['compare_at_price'] == null
              ? null
              : double.parse(variant['compare_at_price'] as String),
        );
      }).toList(),
    );
