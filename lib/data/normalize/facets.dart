/// The canonical facet vocabulary — the output of normalization and the input
/// to the recommendation engine.
///
/// Pure Dart, no Flutter, no codegen.
library;

/// Where a facet value came from. Determines its confidence, and appears in the
/// catalog health report so the owner can see *why* a product was classified.
enum FacetSource {
  /// `app.brand_override` / `app.category_override` metafield set by the owner.
  /// Always wins.
  metafieldOverride(1.0),

  /// Matched a Shopify tag. The best automatic signal on this catalog.
  tag(0.9),

  /// Matched the `product_type` field.
  productType(0.75),

  /// Matched a keyword in the product title.
  title(0.6),

  /// Inferred from which collections the product sits in. Weak: collections on
  /// this store are duplicated and mislabelled (`guess` is titled "Bolsas").
  collection(0.45),

  /// Matched the `vendor` field. Only usable when vendor is a real brand — it
  /// is the store name on 36 products.
  vendor(0.5),

  /// Nothing matched.
  none(0.0);

  const FacetSource(this.confidence);

  /// Base confidence contributed by this source, 0..1.
  final double confidence;
}

/// A single resolved facet value plus the evidence for it.
class FacetValue {
  const FacetValue(this.value, this.source, {this.evidence});

  /// Canonical slug, e.g. `guess`, `crossbody`, `negro`.
  final String value;

  final FacetSource source;

  /// The raw string that produced the match, kept for the health report and for
  /// debugging misclassifications.
  final String? evidence;

  double get confidence => source.confidence;

  @override
  String toString() => '$value(${source.name}'
      '${evidence == null ? '' : ':$evidence'})';

  @override
  bool operator ==(Object other) =>
      other is FacetValue && other.value == value && other.source == source;

  @override
  int get hashCode => Object.hash(value, source);
}

/// Everything the app knows about a product *after* repair.
///
/// Feature code and the recommender read this, never the raw Shopify fields.
class CanonicalFacets {
  const CanonicalFacets({
    required this.productId,
    this.brand,
    this.category,
    this.silhouette,
    this.colors = const [],
    this.patterns = const [],
    required this.priceBand,
    required this.onSale,
    required this.inStock,
    required this.newArrival,
  });

  final String productId;

  /// `guess`, `coach`, `michael_kors`, … Null when unresolvable — which is the
  /// signal that this product needs owner attention.
  final FacetValue? brand;

  /// `bolsa`, `cartera`, `monedero`, `reloj`, `cosmetiquera`, `set`, `accesorio`.
  final FacetValue? category;

  /// Bag shape: `tote`, `crossbody`, `shoulder`, `satchel`, `hobo`, `clutch`,
  /// `mini`, `wristlet`. Only meaningful when [category] is `bolsa`.
  final FacetValue? silhouette;

  final List<FacetValue> colors;
  final List<FacetValue> patterns;

  /// `accesible`, `medio`, `alto`, `premium`.
  final String priceBand;

  final bool onSale;
  final bool inStock;

  /// Created within the newArrivalDays window in the rules file.
  final bool newArrival;

  /// Overall classification confidence, 0..1.
  ///
  /// Weighted toward brand and category because those are what the recommender
  /// leans on hardest, and what a shopper notices being wrong.
  double get confidence {
    const brandWeight = 0.45;
    const categoryWeight = 0.35;
    const silhouetteWeight = 0.20;
    final score = (brand?.confidence ?? 0) * brandWeight +
        (category?.confidence ?? 0) * categoryWeight +
        (silhouette?.confidence ?? 0) * silhouetteWeight;
    // Silhouette is only expected for bags; don't punish a wallet for lacking one.
    final applicable = category?.value == 'bolsa'
        ? 1.0
        : brandWeight + categoryWeight;
    return (score / applicable).clamp(0.0, 1.0);
  }

  /// True when this product is too poorly classified to recommend confidently.
  /// These surface in the catalog health report.
  bool get needsAttention => brand == null || category == null || confidence < 0.5;

  /// Sparse facet vector consumed by `reco/`.
  ///
  /// Keys are namespaced (`brand:guess`) so different facet kinds can never
  /// collide. Values are the facet weights from the rules file scaled by the
  /// confidence of the match — a brand guessed from the title contributes less
  /// than one read off a tag, which is exactly what we want when ranking.
  Map<String, double> toVector(Map<String, double> facetWeights) {
    final vector = <String, double>{};

    void put(String kind, FacetValue? facet) {
      if (facet == null) return;
      final weight = facetWeights[kind] ?? 1.0;
      vector['$kind:${facet.value}'] = weight * facet.confidence;
    }

    put('brand', brand);
    put('category', category);
    put('silhouette', silhouette);
    for (final color in colors) {
      put('color', color);
    }
    for (final pattern in patterns) {
      put('pattern', pattern);
    }

    final priceWeight = facetWeights['price_band'] ?? 1.0;
    vector['price_band:$priceBand'] = priceWeight;

    return vector;
  }

  @override
  String toString() => 'CanonicalFacets($productId, brand: $brand, '
      'category: $category, silhouette: $silhouette, '
      'colors: $colors, band: $priceBand, confidence: '
      '${confidence.toStringAsFixed(2)})';
}
