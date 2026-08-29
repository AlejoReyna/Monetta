/// Wires `data/local` (cache + sync cursor), `data/shopify` (real delta
/// sync) and `data/normalize` (facets) together — the `data/repositories/`
/// module `docs/ARCHITECTURE.md`'s module map has described since Phase 1
/// planning. See `docs/ACCOUNTS_AND_SYNC_PLAN.md` § 4 (Phase 0) for why this
/// exists now: `data/local` was documented but never built, so nothing
/// wired `data/shopify`'s already-tested `CatalogSync` to a database that
/// could remember a cursor between app opens.
library;

import '../local/catalog_cache_store.dart';
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
  }) : _catalogSync = catalogSync;

  final CatalogCacheStore cache;
  final SyncCursorStore cursorStore;
  final NormalizationRules rules;
  final shopify.CatalogSync? _catalogSync;

  /// False whenever `StorefrontConfig.isUsable` was false at construction —
  /// see `app/catalog_store.dart` for how the caller decides this today.
  bool get canSyncWithShopify => _catalogSync != null;

  /// First-run seed: if the cache is empty (a fresh install, before any
  /// Shopify sync has ever succeeded), parse the bundled snapshot asset and
  /// write it in, so [loadCached] never returns nothing. A cache that
  /// already has rows is left untouched — this is a seed, not a reset.
  Future<void> seedFromAssetIfEmpty(Map<String, dynamic> catalogJson) async {
    if (!await cache.isEmpty()) return;
    final products = (catalogJson['products'] as List<dynamic>)
        .map((e) => productFromCatalogSnapshot(e as Map<String, dynamic>))
        .toList();
    await cache.upsertProducts(products);
  }

  /// Repairs an older local cache without replacing rows that may have been
  /// updated by a real Shopify sync. This matters for installs that were
  /// seeded with an earlier snapshot: the cache is persistent, so the old
  /// "seed only when empty" rule otherwise hides every product added later.
  Future<void> addMissingFromAsset(Map<String, dynamic> catalogJson) async {
    final cachedIds = (await cache.allProducts()).map((p) => p.id).toSet();
    if (cachedIds.isEmpty) return;

    final missing = (catalogJson['products'] as List<dynamic>)
        .map((e) => productFromCatalogSnapshot(e as Map<String, dynamic>))
        .where((product) => !cachedIds.contains(product.id))
        .toList();
    await cache.upsertProducts(missing);
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
  Future<CatalogSyncResult> sync() async {
    final catalogSync = _catalogSync;
    if (catalogSync == null) {
      return const CatalogSyncResult(
        outcome: CatalogSyncOutcome.skippedNotConfigured,
      );
    }
    try {
      final cursor = await cursorStore.load();
      final result = await catalogSync.run(cursor: cursor, now: DateTime.now());
      if (result.hasChanges) {
        await cache.upsertProducts(result.products);
      }
      await cursorStore.save(result.cursor);
      return CatalogSyncResult(
        outcome: result.hasChanges
            ? CatalogSyncOutcome.updated
            : CatalogSyncOutcome.upToDate,
        changedCount: result.products.length,
      );
    } catch (error) {
      // A failed sync must never clear or corrupt what's already cached —
      // same contract as `ExternalCatalogRepository.refresh`.
      return CatalogSyncResult(
        outcome: CatalogSyncOutcome.failed,
        error: error,
      );
    }
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
