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
import '../domain/product.dart';
import '../reco/events.dart';
import '../reco/explainer.dart';
import '../reco/profile.dart';
import '../reco/scorer.dart';

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

  final List<InteractionEvent> _events = [];
  final Set<String> _viewed = {};
  final Set<String> _wishlist = {};

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

  Future<void> loadFromAsset() async {
    final rulesRaw = await rootBundle.loadString(
      'assets/rules/normalization_rules.json',
    );
    rules = NormalizationRules.fromJson(
      jsonDecode(rulesRaw) as Map<String, dynamic>,
    );
    _recommender = Recommender(facetWeights: rules.facetWeights);

    final catalogRaw = await rootBundle.loadString('assets/catalog/catalog.json');
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

  /// Seeds the profile from the onboarding taps so the very first feed is
  /// already personalized, with zero browsing history.
  void seedFrom({required List<String> brands, required List<String> categories}) {
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
    }
    _rebuildProfile();
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

  CanonicalFacets? facetsFor(String productId) => facetsById[productId];

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
