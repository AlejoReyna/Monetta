/// In-memory app state wiring normalize + reco together, now backed by
/// `data/local` for real persistence (`docs/ACCOUNTS_AND_SYNC_PLAN.md`
/// Phase 0).
///
/// The public surface is deliberately unchanged from the pre-Drift version:
/// every getter here stays synchronous, because `features/*` and five widget
/// test files read `.products`, `.bagLines`, `.wishlist` etc. off this store
/// mid-frame with no `await`. Persistence is write-through: a mutation
/// updates the in-memory field immediately (so the UI never waits on disk
/// I/O) and fires an unawaited write to Drift alongside it, the same
/// fire-and-forget shape `main.dart` already uses for
/// `ExternalCatalogController.loadAndRefresh()`.
///
/// The catalog itself still seeds from the bundled snapshot asset on a cold
/// cache — there is still no Storefront access token configured anywhere in
/// this app (see `lib/data/shopify/README.md` § 3) — but the seed now goes
/// *through* `CatalogRepository` into Drift instead of living only in
/// memory, and [syncWithShopify] is a real, tested delta-sync call that
/// simply has nothing to do yet. See `docs/ACCOUNTS_AND_SYNC_PLAN.md` § 4.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../data/local/bag_store.dart';
import '../data/local/catalog_cache_store.dart';
import '../data/local/database.dart' hide BagLine, InteractionEvent;
import '../data/local/interaction_event_store.dart';
import '../data/local/sync_cursor_store.dart';
import '../data/local/wishlist_store.dart';
import '../data/firestore/catalog_realtime_source.dart';
import '../data/normalize/facets.dart';
import '../data/normalize/normalizer.dart';
import '../data/normalize/rules.dart';
import '../data/repositories/catalog_repository.dart';
import '../data/repositories/catalog_write_coordinator.dart';
import '../data/repositories/realtime_catalog_repository.dart';
import '../data/shopify/catalog_item_mapper.dart';
import '../data/shopify/catalog_sync.dart' as shopify;
import '../domain/catalog_item.dart';
import '../domain/bag_line.dart';
import '../domain/product.dart';
import '../reco/events.dart';
import '../reco/explainer.dart';
import '../reco/profile.dart';
import '../reco/scorer.dart';
import 'mixed_feed.dart';

class Recommendation {
  const Recommendation({
    required this.product,
    required this.scored,
    required this.reason,
  });

  final Product product;
  final ScoredProduct scored;
  final RecoReason reason;
}

enum CatalogRealtimeStatus {
  disabled,
  connecting,
  live,
  empty,
  invalid,
  reconnecting,
}

class CatalogStore extends ChangeNotifier {
  /// [database] is required explicitly rather than defaulted — production
  /// call sites pass `AppDatabase.connect()` (real on-device file), test
  /// call sites pass `openTestDatabase()` (in-memory). Neither should be
  /// implicit: which one you get changes whether data survives a restart.
  ///
  /// [catalogSync] is the real `data/shopify` delta sync, null when no
  /// usable `StorefrontConfig` exists — today's honest default. See
  /// `lib/data/repositories/catalog_repository.dart`.
  CatalogStore({
    required AppDatabase database,
    shopify.CatalogSync? catalogSync,
    CatalogRealtimeSource? realtimeSource,
  })  : _database = database,
        _catalogSyncOverride = catalogSync,
        _realtimeSource = realtimeSource,
        _writeCoordinator = CatalogWriteCoordinator(
          expectsFirestore: realtimeSource != null,
        ),
        _cacheStore = CatalogCacheStore(database),
        _cursorStore = SyncCursorStore(database),
        _wishlistStore = WishlistStore(database),
        _bagStore = BagStore(database),
        _eventStore = InteractionEventStore(database);

  static String? _rulesAsset;
  static String? _catalogAsset;

  final AppDatabase _database;
  final shopify.CatalogSync? _catalogSyncOverride;
  final CatalogRealtimeSource? _realtimeSource;
  final CatalogWriteCoordinator _writeCoordinator;
  final CatalogCacheStore _cacheStore;
  final SyncCursorStore _cursorStore;
  final WishlistStore _wishlistStore;
  final BagStore _bagStore;
  final InteractionEventStore _eventStore;
  late final CatalogRepository _catalogRepository;
  StreamSubscription<RealtimeCatalogUpdate>? _realtimeSubscription;
  Future<CatalogSyncResult>? _deltaSyncInFlight;

  final List<InteractionEvent> _events = [];
  final Set<String> _viewed = {};
  final List<String> _recentIds = [];
  final Set<String> _wishlist = {};
  final Map<String, int> _bagQuantities = {};

  List<Product> products = const [];
  Map<String, CanonicalFacets> facetsById = const {};
  late NormalizationRules rules;

  TasteProfile profile = const TasteProfile.empty();
  bool ready = false;
  CatalogRealtimeStatus realtimeStatus = CatalogRealtimeStatus.disabled;
  CatalogCacheMetadata? catalogMetadata;

  final _profileBuilder = const ProfileBuilder();
  final _explainer = const Explainer();
  late Recommender _recommender;

  Set<String> get wishlist => _wishlist;
  int get eventCount => _events.length;

  /// The bag remains local until the shopper commits to secure checkout.
  /// At that boundary these variant ids and quantities become Shopify Cart
  /// lines and Shopify owns address and payment collection.
  List<BagLine> get bagLines => [
        for (final entry in _bagQuantities.entries)
          if (_productById(entry.key) case final product?)
            if (_availableVariant(product) case final variant?)
              BagLine(
                product: product,
                variant: variant,
                quantity: entry.value,
              ),
      ];

  int get bagQuantity =>
      _bagQuantities.values.fold(0, (sum, quantity) => sum + quantity);

  double get bagSubtotal =>
      bagLines.fold(0, (sum, line) => sum + line.lineTotal);

  Future<void> loadFromAsset() async {
    final rulesRaw = _rulesAsset ??=
        await rootBundle.loadString('assets/rules/normalization_rules.json');
    rules = NormalizationRules.fromJson(
      jsonDecode(rulesRaw) as Map<String, dynamic>,
    );
    _recommender = Recommender(facetWeights: rules.facetWeights);

    _catalogRepository = CatalogRepository(
      cache: _cacheStore,
      cursorStore: _cursorStore,
      rules: rules,
      catalogSync: _catalogSyncOverride,
    );

    // `AssetBundle.loadString` moves files over 50 KB to a helper isolate.
    // The catalog is larger than that and helper isolates are not available
    // in every Flutter test/runtime surface, so decode the already-loaded
    // bytes directly. At ~235 KB this remains comfortably below a frame's
    // worth of work on supported devices and avoids a startup deadlock.
    final catalogRaw = _catalogAsset ??= await _loadCatalogAsset();
    final catalogJson = jsonDecode(catalogRaw) as Map<String, dynamic>;

    // A no-op once the cache already has rows — the common case after the
    // very first app open.
    await _catalogRepository.seedFromAssetIfEmpty(catalogJson);
    // Existing installs may have a partial cache from an older snapshot.
    // Keep the cache-first startup path, but add products that are present in
    // the bundled catalog and missing locally.
    await _catalogRepository.addMissingFromAsset(catalogJson);

    final snapshot = await _catalogRepository.loadCached();
    products = snapshot.products;
    facetsById = snapshot.facetsById;
    catalogMetadata =
        await _catalogRepository.loadOrCreateMetadata(snapshot.products);

    await _hydrateFromDrift();

    ready = true;
    notifyListeners();

    _startRealtimeCatalog();

    // Without a Firestore source, delta sync is the normal background writer.
    // With one, it waits until the listener reports an error/disconnection.
    if (_realtimeSource == null) unawaited(syncWithShopify());
  }

  Future<void> _hydrateFromDrift() async {
    final wishlisted = await _wishlistStore.allProductIds();
    _wishlist
      ..clear()
      ..addAll(wishlisted);

    final bagRows = await _bagStore.all();
    _bagQuantities
      ..clear()
      ..addEntries(
        bagRows.entries.map((e) => MapEntry(e.key, e.value.$2)),
      );

    final events = await _eventStore.all();
    _events
      ..clear()
      ..addAll(events);
    for (final event in events) {
      if (event.productId != null && event.type == EventType.productView) {
        _viewed.add(event.productId!);
      }
    }
    _rebuildProfile();
  }

  static Future<String> _loadCatalogAsset() async {
    final data = await rootBundle.load('assets/catalog/catalog.json');
    return utf8.decode(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }

  /// Runs a real Shopify delta sync (`data/repositories/catalog_repository.dart`)
  /// and applies whatever changed to the in-memory catalog. It is a normal
  /// writer without Firestore, an error/disconnection fallback with Firestore,
  /// and returns `skippedRealtimeAuthoritative` while that listener is
  /// connecting or live.
  Future<CatalogSyncResult> syncWithShopify() {
    final active = _deltaSyncInFlight;
    if (active != null) return active;

    final future = _writeCoordinator.runDeltaWrite(
      write: _syncWithShopifyFallback,
      blocked: () => const CatalogSyncResult(
        outcome: CatalogSyncOutcome.skippedRealtimeAuthoritative,
      ),
    );
    _deltaSyncInFlight = future;
    unawaited(
      future.then<void>(
        (_) => _clearDeltaSync(future),
        onError: (Object _, StackTrace __) => _clearDeltaSync(future),
      ),
    );
    return future;
  }

  void _clearDeltaSync(Future<CatalogSyncResult> completed) {
    if (identical(_deltaSyncInFlight, completed)) _deltaSyncInFlight = null;
  }

  Future<CatalogSyncResult> _syncWithShopifyFallback() async {
    final result = await _catalogRepository.sync();
    if (result.outcome == CatalogSyncOutcome.updated) {
      final snapshot = await _catalogRepository.loadCached();
      products = snapshot.products;
      facetsById = snapshot.facetsById;
    }
    catalogMetadata = await _cacheStore.metadata();
    notifyListeners();
    return result;
  }

  void _startRealtimeCatalog() {
    final source = _realtimeSource;
    if (source == null || _realtimeSubscription != null) return;
    realtimeStatus = CatalogRealtimeStatus.connecting;
    notifyListeners();

    final repository = RealtimeCatalogRepository(
      source: source,
      cache: _cacheStore,
      writeCoordinator: _writeCoordinator,
    );
    _realtimeSubscription = repository.watch().listen(_applyRealtimeUpdate);
  }

  void _applyRealtimeUpdate(RealtimeCatalogUpdate update) {
    switch (update.outcome) {
      case RealtimeCatalogOutcome.applied:
        products = update.products;
        catalogMetadata = update.metadata;
        final normalizer = Normalizer(rules);
        final now = DateTime.now();
        facetsById = {
          for (final product in products)
            product.id: normalizer.normalize(product, now: now),
        };
        realtimeStatus = CatalogRealtimeStatus.live;
      case RealtimeCatalogOutcome.empty:
        realtimeStatus = CatalogRealtimeStatus.empty;
        unawaited(_recordCatalogStatus(CatalogCacheStatus.invalid, 'Vacío'));
      case RealtimeCatalogOutcome.invalid:
        realtimeStatus = CatalogRealtimeStatus.invalid;
        unawaited(
          _recordCatalogStatus(
            CatalogCacheStatus.invalid,
            'Documentos inválidos: ${update.invalidDocumentIds.length}',
          ),
        );
      case RealtimeCatalogOutcome.error:
      case RealtimeCatalogOutcome.disconnected:
        _writeCoordinator.markFirestoreUnavailable();
        realtimeStatus = CatalogRealtimeStatus.reconnecting;
        unawaited(
          _recordCatalogStatus(
            CatalogCacheStatus.unavailable,
            update.error?.runtimeType.toString() ?? 'Desconectado',
          ),
        );
        unawaited(syncWithShopify());
    }
    notifyListeners();
  }

  Future<void> _recordCatalogStatus(
    CatalogCacheStatus status,
    String detail,
  ) async {
    final current = catalogMetadata ?? await _cacheStore.metadata();
    if (current == null) return;
    final updated = current.copyWith(status: status, detail: detail);
    await _cacheStore.saveMetadata(updated);
    catalogMetadata = updated;
    notifyListeners();
  }

  /// Seeds the profile from the onboarding taps so the very first feed is
  /// already personalized, with zero browsing history.
  void seedFrom({
    required List<String> brands,
    required List<String> categories,
  }) {
    profile = seedProfileFromOnboarding(
      brands: brands,
      categories: categories,
      now: DateTime.now(),
    );
    notifyListeners();
  }

  /// Record an interaction and rebuild the profile.
  ///
  /// Rebuilding on every event is fine at this catalog size and makes the
  /// learning visible in the demo: open two Coach watches, go back, and the
  /// feed has reordered.
  void record(EventType type, {String? productId, int? dwellMs}) {
    final event = InteractionEvent(
      type: type,
      timestamp: DateTime.now(),
      productId: productId,
      dwellMs: dwellMs,
    );
    _events.add(event);
    unawaited(_eventStore.record(event));
    if (productId != null && type == EventType.productView) {
      _viewed.add(productId);
      markRecentlyViewed(productId);
    }
    _rebuildProfile();
  }

  /// Newest first, capped. Survives only for the session (this store is
  /// still the in-memory stand-in for `data/local`).
  void markRecentlyViewed(String productId) {
    _recentIds.remove(productId);
    _recentIds.insert(0, productId);
    if (_recentIds.length > 12) _recentIds.removeLast();
  }

  List<Product> recentlyViewed({String? excluding, int limit = 8}) {
    final out = <Product>[];
    for (final id in _recentIds) {
      if (id == excluding) continue;
      final product = _productById(id);
      if (product == null) continue;
      out.add(product);
      if (out.length >= limit) break;
    }
    return out;
  }

  List<Product> moreFromBrand(
    String brandSlug, {
    String? excluding,
    int limit = 8,
  }) {
    final out = <Product>[];
    for (final product in products) {
      if (product.id == excluding) continue;
      if (facetsById[product.id]?.brand?.value != brandSlug) continue;
      out.add(product);
      if (out.length >= limit) break;
    }
    return out;
  }

  Product? firstInStockWhere(
    bool Function(Product product, CanonicalFacets? facets) test,
  ) {
    for (final product in products) {
      if (!product.isInStock || product.primaryImage == null) continue;
      if (test(product, facetsById[product.id])) return product;
    }
    return null;
  }

  void toggleWishlist(String productId) {
    final removing = _wishlist.contains(productId);
    if (removing) {
      _wishlist.remove(productId);
      unawaited(_wishlistStore.remove(productId));
      record(EventType.wishlistRemove, productId: productId);
    } else {
      _wishlist.add(productId);
      unawaited(_wishlistStore.add(productId));
      record(EventType.wishlistAdd, productId: productId);
    }
  }

  void addToBag(Product product) {
    final variant = _availableVariant(product);
    if (variant == null) return;
    _bagQuantities.update(
      product.id,
      (quantity) => quantity + 1,
      ifAbsent: () => 1,
    );
    unawaited(
      _bagStore.upsert(
        productId: product.id,
        variantId: variant.id,
        quantity: _bagQuantities[product.id]!,
      ),
    );
    record(EventType.addToCart, productId: product.id);
  }

  void updateBagQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeFromBag(productId);
      return;
    }
    if (!_bagQuantities.containsKey(productId)) return;
    final clamped = quantity.clamp(1, 10);
    _bagQuantities[productId] = clamped;
    final product = _productById(productId);
    final variant = product == null ? null : _availableVariant(product);
    if (variant != null) {
      unawaited(
        _bagStore.upsert(
          productId: productId,
          variantId: variant.id,
          quantity: clamped,
        ),
      );
    }
    notifyListeners();
  }

  void removeFromBag(String productId) {
    if (_bagQuantities.remove(productId) != null) {
      unawaited(_bagStore.remove(productId));
      notifyListeners();
    }
  }

  /// Clears durable and in-memory bag state after a trusted checkout event.
  /// Persistence completes first so a storage failure never hides the bag.
  Future<void> clearBagAfterCheckout() async {
    await _bagStore.clear();
    if (_bagQuantities.isEmpty) return;
    _bagQuantities.clear();
    notifyListeners();
  }

  Product? _productById(String id) {
    for (final product in products) {
      if (product.id == id) return product;
    }
    return null;
  }

  ProductVariant? _availableVariant(Product product) {
    ProductVariant? cheapest;
    for (final variant in product.variants) {
      if (!variant.available) continue;
      if (cheapest == null || variant.price < cheapest.price) {
        cheapest = variant;
      }
    }
    return cheapest;
  }

  void _rebuildProfile() {
    final rebuilt = _profileBuilder.build(
      events: _events,
      facetsByProductId: facetsById,
      facetWeights: rules.facetWeights,
      now: DateTime.now(),
    );
    // Keep the onboarding seed until real behaviour outweighs it.
    if (!rebuilt.isEmpty) profile = rebuilt;
    notifyListeners();
  }

  /// The personalized feed, each item carrying its explanation.
  List<Recommendation> feed({int limit = 40}) {
    if (!ready) return const [];

    final byId = {for (final p in products) p.id: p};
    final discounts = <String, double>{
      for (final p in products)
        if (p.isOnSale) p.id: p.discountFraction,
    };

    final ranked = _recommender.rank(
      profile: profile,
      candidates: facetsById.values.toList(),
      context: ScoringContext(
        viewedProductIds: _viewed,
        wishlistedProductIds: _wishlist,
        discountByProductId: discounts,
      ),
      limit: limit,
    );

    final topBrands = profile.topOf('brand');
    final topSilhouettes = profile.topOf('silhouette');

    return ranked
        .map((scored) {
          final product = byId[scored.productId];
          if (product == null) return null;
          return Recommendation(
            product: product,
            scored: scored,
            reason: _explainer.explain(
              scored,
              topBrands: topBrands,
              topSilhouettes: topSilhouettes,
              discountFraction: product.discountFraction,
            ),
          );
        })
        .whereType<Recommendation>()
        .toList();
  }

  /// The unified feed: Monetta products and external research items ranked
  /// through the same [Recommender], deduplicated (Monetta preferred on an
  /// exact brand+title match), so an external item can appear naturally
  /// interleaved among Monetta recommendations rather than only in a
  /// separate rail. See `app/mixed_feed.dart#unifiedRecommendations`.
  List<MixedRecommendation> mixedFeed({
    required List<CatalogItem> external,
    int limit = 40,
  }) {
    if (!ready) return const [];

    final discounts = <String, double>{
      for (final p in products)
        if (p.isOnSale) p.id: p.discountFraction,
    };

    return unifiedRecommendations(
      recommender: _recommender,
      explainer: _explainer,
      profile: profile,
      monettaProducts: products,
      monettaFacetsById: facetsById,
      externalItems: external,
      context: ScoringContext(
        viewedProductIds: _viewed,
        wishlistedProductIds: _wishlist,
        discountByProductId: discounts,
      ),
      limit: limit,
    );
  }

  CanonicalFacets? facetsFor(String productId) => facetsById[productId];

  /// Every Monetta product mapped into the source-independent [CatalogItem]
  /// shape. Used by the mixed-feed dedupe rule (`app/mixed_feed.dart`) — the
  /// external section must know Monetta's brand+title set even though it
  /// never re-ranks Monetta items through this list.
  List<CatalogItem> get catalogItems => [
        for (final product in products)
          catalogItemFromShopifyProduct(
            product,
            facets: facetsById[product.id],
          ),
      ];

  /// Brands present in the catalog, most stocked first — drives onboarding.
  List<String> get availableBrands {
    final counts = <String, int>{};
    for (final facets in facetsById.values) {
      final brand = facets.brand?.value;
      if (brand == null) continue;
      counts.update(brand, (v) => v + 1, ifAbsent: () => 1);
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => e.key).toList();
  }

  @override
  void dispose() {
    unawaited(_realtimeSubscription?.cancel());
    unawaited(_database.close());
    super.dispose();
  }
}
