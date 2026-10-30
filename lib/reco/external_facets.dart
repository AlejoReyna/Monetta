/// Maps an external [CatalogItem] into the same [CanonicalFacets] shape the
/// recommender already scores Monetta products against, so external items
/// can participate in one unified ranked candidate set — see
/// `app/mixed_feed.dart`.
///
/// Pure Dart, no Flutter, no store dependency — same rationale as
/// `data/normalize`.
///
/// The price band is the one facet that needs care: Monetta's price bands
/// (`data/normalize/rules.dart`) are MXN thresholds tuned to Monetta's own
/// catalog. Reusing those thresholds on a USD amount would silently compare
/// MXN and USD prices through the back door — exactly what the spec
/// prohibits. [externalPriceBandFor] is therefore an entirely separate,
/// USD-denominated threshold table. Its band *labels* (`accesible`, `medio`,
/// `alto`, `premium`) intentionally reuse Monetta's vocabulary so the
/// resulting facet key (`price_band:accesible`) can line up with a shopper's
/// learned tier preference — but that is a categorical/taste signal, never a
/// numeric comparison: no USD amount and no MXN amount are ever read
/// together, added, or compared in this file or anywhere downstream.
library;

import '../data/normalize/facets.dart';
import '../domain/catalog_item.dart';

const Map<CatalogSourceType, String> _kExternalBrandSlugs = {
  CatalogSourceType.coachUs: 'coach',
  CatalogSourceType.michaelKorsUs: 'michael_kors',
  CatalogSourceType.guessUs: 'guess',
  CatalogSourceType.steveMaddenUs: 'steve_madden',
  CatalogSourceType.marcJacobsUs: 'marc_jacobs',
  CatalogSourceType.toryBurchUs: 'tory_burch',
  CatalogSourceType.kateSpadeUs: 'kate_spade',
  CatalogSourceType.guessFactoryUs: 'guess_factory',
  CatalogSourceType.gpMcallenPerfumes: 'perfumes',
};

/// Best-effort English → Monetta category slug. Deliberately small and
/// conservative: an unmapped category contributes no category facet at all
/// rather than guessing, which is the same "don't fabricate a signal" rule
/// Fix 8 applies to price.
const Map<String, String> _kExternalCategorySlugs = {
  'handbags': 'bolsa',
  'crossbody bags': 'bolsa',
  'shoulder bags': 'bolsa',
  'totes': 'bolsa',
  'satchels': 'bolsa',
  'wallets': 'cartera',
  'card cases': 'tarjetero',
  'watches': 'reloj',
  'cosmetic cases': 'cosmetiquera',
  'jewelry': 'accesorio',
  'accessories': 'accesorio',
  'perfume': 'perfume',
  'perfumes': 'perfume',
  'cologne': 'perfume',
  'colognes': 'perfume',
  'fragrance': 'perfume',
  'fragrances': 'perfume',
};

/// USD-only price-band thresholds — see the library doc comment for why
/// these are independent of `data/normalize/rules.dart`'s MXN table.
/// Exclusive upper bounds, last band unbounded, same shape as
/// `NormalizationRules.priceBandFor`.
const List<({String id, double? maxExclusive})> _kExternalUsdPriceBands = [
  (id: 'accesible', maxExclusive: 150),
  (id: 'medio', maxExclusive: 300),
  (id: 'alto', maxExclusive: 500),
  (id: 'premium', maxExclusive: null),
];

/// The neutral price-band signal for a USD amount. Never compares this
/// amount to an MXN amount — only ever assigns it to one of the bands above.
String externalPriceBandFor(double usdAmount) {
  for (final band in _kExternalUsdPriceBands) {
    final max = band.maxExclusive;
    if (max == null || usdAmount < max) return band.id;
  }
  return _kExternalUsdPriceBands.last.id;
}

/// Builds the [CanonicalFacets] the recommender scores an external
/// [CatalogItem] against. A missing USD source price simply omits the
/// price-band facet — an unknown price contributes no price-tier signal
/// rather than a fabricated one.
CanonicalFacets externalItemFacets(CatalogItem item) {
  final brandSlug = _kExternalBrandSlugs[item.source];
  final categorySlug =
      _kExternalCategorySlugs[item.category?.toLowerCase().trim() ?? ''];
  // A commission-enabled response presents MXN in `price` and preserves the
  // merchant's USD amount in `sourcePrice`. Recommendation price bands are
  // intentionally USD-only, so never feed the suggested MXN value into the
  // USD thresholds.
  final candidatePrice = item.sourcePrice ?? item.price;
  final sourcePrice =
      candidatePrice?.currency == Currency.usd ? candidatePrice : null;

  return CanonicalFacets(
    productId: item.sourceScopedId,
    brand: brandSlug == null ? null : FacetValue(brandSlug, FacetSource.tag),
    category:
        categorySlug == null ? null : FacetValue(categorySlug, FacetSource.tag),
    // Silhouette, color and pattern are not part of the wire schema — no
    // fabricated signal. An unknown price (Fix 8) contributes no price-band
    // facet at all, rather than a fabricated tier.
    priceBand:
        sourcePrice == null ? null : externalPriceBandFor(sourcePrice.amount),
    onSale: false, // No historical price tracking on external sources yet.
    inStock: item.availability == CatalogAvailability.inStock,
    newArrival: false,
  );
}
