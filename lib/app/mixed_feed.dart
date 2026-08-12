/// Merge rules for presenting owner-procurement listings alongside
/// Monetta's own catalog — the *unified, deduplicated* [CatalogItem]
/// collection described in `docs/ARCHITECTURE.md` § "External catalog
/// prototype". Pure functions, no widget or store dependency, so the
/// dedupe/relevance/ranking rules are unit-testable on their own — see
/// `test/app/mixed_feed_test.dart`.
///
/// Rules:
///  - Dedupe only on an *exact* normalized brand+title match, preferring the
///    Monetta item. No fuzzy matching without SKU/UPC evidence.
///  - External items participate in the *same* ranked candidate set as
///    Monetta products (see [unifiedRecommendations]), through normalized
///    brand/category facets and a currency-neutral price-band facet — never
///    through a numeric comparison of USD and MXN amounts. This is what lets
///    an external item appear naturally interleaved among Monetta
///    recommendations, not only in a separate rail.
///  - [relevantExternalItems] remains as a lighter-weight relevance filter
///    for a dedicated rail: external items may surface when they match the
///    shopper's top brands; on a cold-start profile with no brand signal
///    yet, an unfiltered sample is shown instead of nothing. It is no longer
///    capped at a fixed count — the rail renders lazily (`ListView.builder`
///    semantics), and the full deduplicated catalog is always reachable
///    through [fullDeduplicatedCatalog] regardless of what a rail chooses to
///    show.
library;

import '../data/normalize/facets.dart';
import '../data/shopify/catalog_item_mapper.dart';
import '../domain/catalog_item.dart';
import '../domain/product.dart';
import '../reco/explainer.dart';
import '../reco/external_facets.dart';
import '../reco/profile.dart';
import '../reco/scorer.dart';

/// Deprecated fixed cap. No longer applied by default anywhere in this file
/// — kept only because a caller may still want an explicit cap for a small
/// UI surface. See the library doc comment.
const int kExternalSectionLimit = 8;

/// External items whose normalized `brand::title` exactly matches a Monetta
/// item are dropped, preferring the Monetta item. This is the one and only
/// dedupe rule — no fuzzy matching without SKU/UPC evidence.
List<CatalogItem> dedupeExternalAgainstMonetta({
  required List<CatalogItem> external,
  required List<CatalogItem> monettaItems,
}) {
  final monettaKeys = monettaItems.map((m) => m.dedupeKey).toSet();
  return external.where((e) => !monettaKeys.contains(e.dedupeKey)).toList();
}

/// A lighter-weight relevance filter for a dedicated external rail. Kept
/// alongside [unifiedRecommendations] because a short "También en marcas de
/// Estados Unidos" rail is still a reasonable surface on its own — the
/// spec requires external items not be confined to *only* a separate rail,
/// not that the rail be removed.
///
/// [limit] is optional; when omitted, every relevant (deduped, brand-matched
/// or cold-start-sampled) item is returned — the fixed eight-item cap this
/// function used to apply unconditionally is gone. Callers rendering this
/// list must use a lazily-built scrolling widget (`ListView.builder`/
/// `.separated`), not an eagerly-built one.
List<CatalogItem> relevantExternalItems({
  required List<CatalogItem> external,
  required List<CatalogItem> monettaItems,
  required List<String> topBrands,
  int? limit,
}) {
  final deduped = dedupeExternalAgainstMonetta(
    external: external,
    monettaItems: monettaItems,
  );

  final normalizedTopBrands =
      topBrands.map((b) => b.toLowerCase().trim()).toSet();
  final relevant = normalizedTopBrands.isEmpty
      ? deduped
      : deduped
          .where(
            (e) => normalizedTopBrands.contains(e.brand.toLowerCase().trim()),
          )
          .toList();

  return limit == null ? relevant : relevant.take(limit).toList();
}

/// Every deduplicated catalog item — Monetta and external, Monetta
/// preferred on an exact brand+title collision — with no ranking and no
/// cap. Backs the full-catalog browsing screen
/// (`features/catalog/catalog_browse_screen.dart`); render it with a lazy
/// builder, never by eagerly materializing every tile.
List<CatalogItem> fullDeduplicatedCatalog({
  required List<CatalogItem> monettaItems,
  required List<CatalogItem> externalItems,
}) {
  final deduped = dedupeExternalAgainstMonetta(
    external: externalItems,
    monettaItems: monettaItems,
  );
  return [...monettaItems, ...deduped];
}

/// One entry in the unified, ranked feed — either a Monetta product or an
/// external research listing, carrying its score and its explanation the
/// same way either type would on its own.
class MixedRecommendation {
  const MixedRecommendation({
    required this.item,
    required this.score,
    required this.reason,
    this.product,
  });

  final CatalogItem item;
  final double score;
  final RecoReason reason;

  /// Non-null only for a Monetta item — the raw [Product] the UI needs to
  /// route into the existing in-app product screen, wishlist and cart
  /// actions. Always null for an external item: those actions must never be
  /// reachable for research listings, see [CatalogItem.isExternal] and
  /// `features/home/external_catalog_section.dart`.
  final Product? product;

  bool get isExternal => item.isExternal;
}

/// Builds one ranked candidate set out of Monetta's own products *and*
/// external research items, using the same [Recommender] both already share.
///
/// This is the "unified recommendation candidate set" the spec asks for:
/// every candidate is keyed by its source-scoped id (a Monetta product's
/// Shopify id, or an external item's `sourceScopedId`), external items
/// participate through [externalItemFacets] (normalized brand/category, plus
/// a currency-neutral price-band facet — never a numeric price), and the
/// existing diversification rule in [Recommender] applies across the whole
/// merged set exactly as it already does for Monetta-only candidates.
List<MixedRecommendation> unifiedRecommendations({
  required Recommender recommender,
  required Explainer explainer,
  required TasteProfile profile,
  required List<Product> monettaProducts,
  required Map<String, CanonicalFacets> monettaFacetsById,
  required List<CatalogItem> externalItems,
  ScoringContext context = const ScoringContext(),
  int limit = 40,
}) {
  final monettaCatalogItems = [
    for (final p in monettaProducts)
      catalogItemFromShopifyProduct(p, facets: monettaFacetsById[p.id]),
  ];
  final dedupedExternal = dedupeExternalAgainstMonetta(
    external: externalItems,
    monettaItems: monettaCatalogItems,
  );

  final externalItemsById = <String, CatalogItem>{
    for (final item in dedupedExternal) item.sourceScopedId: item,
  };
  final externalFacets = [
    for (final item in dedupedExternal) externalItemFacets(item),
  ];

  final candidates = [...monettaFacetsById.values, ...externalFacets];

  final ranked = recommender.rank(
    profile: profile,
    candidates: candidates,
    context: context,
    limit: limit,
  );

  final monettaById = {for (final p in monettaProducts) p.id: p};
  final topBrands = profile.topOf('brand');
  final topSilhouettes = profile.topOf('silhouette');

  final result = <MixedRecommendation>[];
  for (final scored in ranked) {
    final reason = explainer.explain(
      scored,
      topBrands: topBrands,
      topSilhouettes: topSilhouettes,
      discountFraction: monettaById[scored.productId]?.discountFraction ?? 0,
    );

    final product = monettaById[scored.productId];
    if (product != null) {
      result.add(
        MixedRecommendation(
          item: catalogItemFromShopifyProduct(
            product,
            facets: monettaFacetsById[product.id],
          ),
          score: scored.score,
          reason: reason,
          product: product,
        ),
      );
      continue;
    }

    final externalItem = externalItemsById[scored.productId];
    if (externalItem == null) continue; // Defensive: should be unreachable.
    result.add(
      MixedRecommendation(
        item: externalItem,
        score: scored.score,
        reason: reason,
      ),
    );
  }
  return result;
}
