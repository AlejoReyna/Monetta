/// In-memory app state wiring normalize + reco together.
///
/// **This is a Phase-1 stand-in for `data/local`.** It holds the catalog, the
/// event log and the derived profile in memory, so nothing survives a restart.
/// When the drift layer lands it replaces this class wholesale; the screens
/// talk to this interface and should not need to change.
///
/// The catalog is read from the bundled snapshot asset rather than the
/// Storefront API, because we do not have an access token yet. Swapping in
/// `CatalogSync` is a one-method change — see [loadFromAsset].
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../data/normalize/facets.dart';
import '../data/normalize/normalizer.dart';
import '../data/normalize/rules.dart';
import '../data/shopify/catalog_item_mapper.dart';
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

class CatalogStore extends ChangeNotifier {
  CatalogStore();

  static String? _rulesAsset;
  static String? _catalogAsset;

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

    // `AssetBundle.loadString` moves files over 50 KB to a helper isolate.
    // The catalog is larger than that and helper isolates are not available
    // in every Flutter test/runtime surface, so decode the already-loaded
    // bytes directly. At ~235 KB this remains comfortably below a frame's
    // worth of work on supported devices and avoids a startup deadlock.
    final catalogRaw = _catalogAsset ??= await _loadCatalogAsset();
    final catalog = jsonDecode(catalogRaw) as Map<String, dynamic>;
    products = (catalog['products'] as List<dynamic>)
        .map((e) => _productFromSnapshot(e as Map<String, dynamic>))
        .toList();

    final normalizer = Normalizer(rules);
    final now = DateTime.now();
    facetsById = {
      for (final product in products)
        product.id: normalizer.normalize(product, now: now),
    };

    ready = true;
    notifyListeners();
  }

  static Future<String> _loadCatalogAsset() async {
    final data = await rootBundle.load('assets/catalog/catalog.json');
    return utf8.decode(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
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
    _events.add(
      InteractionEvent(
        type: type,
        timestamp: DateTime.now(),
        productId: productId,
        dwellMs: dwellMs,
      ),
    );
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

  List<Product> moreFromBrand(String brandSlug, {String? excluding, int limit = 8}) {
    final out = <Product>[];
    for (final product in products) {
      if (product.id == excluding) continue;
      if (facetsById[product.id]?.brand?.value != brandSlug) continue;
      out.add(product);
      if (out.length >= limit) break;
    }
    return out;
  }

  Product? firstInStockWhere(bool Function(Product product, CanonicalFacets? facets) test) {
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
      record(EventType.wishlistRemove, productId: productId);
    } else {
      _wishlist.add(productId);
      record(EventType.wishlistAdd, productId: productId);
    }
  }

  void addToBag(Product product) {
    if (_availableVariant(product) == null) return;
    _bagQuantities.update(
      product.id,
      (quantity) => quantity + 1,
      ifAbsent: () => 1,
    );
    record(EventType.addToCart, productId: product.id);
  }

  void updateBagQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeFromBag(productId);
      return;
    }
    if (!_bagQuantities.containsKey(productId)) return;
    _bagQuantities[productId] = quantity.clamp(1, 10);
    notifyListeners();
  }

  void removeFromBag(String productId) {
    if (_bagQuantities.remove(productId) != null) notifyListeners();
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

  Product _productFromSnapshot(Map<String, dynamic> json) => Product(
        id: json['id'].toString(),
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
}
