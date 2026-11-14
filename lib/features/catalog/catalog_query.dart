/// One matcher for "does this product answer this query".
///
/// Search and the collection screen both need it, and they must agree: the
/// count shown next to a result grid and the count a shopper reaches through
/// "Ver todo" come from the same function, so they can never drift apart.
library;

import '../../app/catalog_store.dart';
import '../../app/shopper_copy.dart';
import '../../domain/product.dart';
import '../../reco/explainer.dart';
import 'search_history.dart' show normalizeSearchText;

/// Everything a product can be found by: its own Shopify text plus the
/// shopper-facing labels of its canonical facets. Raw `vendor` is deliberately
/// absent — on this store it is the shop name on 36 products.
List<String> productSearchTerms(CatalogStore store, Product product) {
  final facets = store.facetsFor(product.id);
  return <String>[
    product.title,
    product.productType,
    ...product.tags,
    ...product.collectionHandles,
    for (final variant in product.variants) ...variant.selectedOptions.values,
    for (final variant in product.variants)
      for (final color in catalogVariantColors(store, product, variant))
        colorLabel(color),
    if (facets?.brand case final brand?) brandLabel(brand.value),
    if (facets?.category case final category?) categoryLabel(category.value),
    if (facets?.category case final category?) categoryPlural(category.value),
    if (facets?.silhouette case final silhouette?)
      silhouetteLabel(silhouette.value),
    ...?facets?.colors.map((facet) => colorLabel(facet.value)),
    ...?facets?.patterns.map((facet) => patternLabel(facet.value)),
  ].where((term) => term.trim().isNotEmpty).toList(growable: false);
}

/// True when every word of [normalizedQuery] appears in some search term.
///
/// Already normalized. "guess negro" matches a title such as
/// "Bolso Guess Crossbody Negro" even though those two words are not adjacent.
/// A single word keeps the previous containment check.
bool productMatchesNormalizedQuery(
  CatalogStore store,
  Product product,
  String normalizedQuery,
) {
  if (normalizedQuery.isEmpty) return true;
  final tokens = normalizedQuery
      .split(' ')
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
  if (tokens.isEmpty) return true;
  final terms = productSearchTerms(store, product)
      .map(normalizeSearchText)
      .toList(growable: false);
  return tokens.every(
    (token) => terms.any((term) => term.contains(token)),
  );
}

/// Every product answering [rawQuery], in catalog order. An empty query
/// returns nothing: search never silently means "everything".
List<Product> searchProducts(CatalogStore store, String rawQuery) {
  final normalized = normalizeSearchText(rawQuery);
  if (normalized.isEmpty) return const <Product>[];
  final seen = <String>{};
  return store.products
      .where((p) => seen.add(p.id))
      .where(
        (product) => productMatchesNormalizedQuery(store, product, normalized),
      )
      .toList(growable: false);
}

/// Matches when *any* of [rawTerms] does. Used by collection destinations that
/// are defined by a handful of words rather than one typed query.
bool productMatchesAnyTerm(
  CatalogStore store,
  Product product,
  Iterable<String> rawTerms,
) {
  final normalized = <String>{
    for (final term in rawTerms)
      if (normalizeSearchText(term) case final value when value.isNotEmpty)
        value,
  };
  if (normalized.isEmpty) return true;
  final terms = productSearchTerms(store, product)
      .map(normalizeSearchText)
      .toList(growable: false);
  return normalized.any(
    (query) => terms.any((term) => term.contains(query)),
  );
}

/// Shared applied/draft criteria. Commercial newness is disabled unless the
/// caller supplies an approved predicate; Shopify creation time is not approval.
enum CatalogOrder { newest, oldest, priceAsc, priceDesc }

/// Exact variants answering the same color/offer/availability intersection.
/// Explicit selectedOptions wins over legacy titles and product-level facets.
List<ProductVariant> matchingCatalogVariants(
  CatalogStore store,
  Product product, {
  String? color,
  String? priceBand,
  bool offersOnly = false,
  bool availableOnly = false,
}) =>
    product.variants.where((variant) {
      if (availableOnly && !variant.available) return false;
      if (priceBand != null &&
          store.rules.priceBandFor(variant.price) != priceBand) {
        return false;
      }
      if (offersOnly &&
          !(variant.compareAtPrice != null &&
              variant.compareAtPrice! > variant.price)) {
        return false;
      }
      if (color == null) return true;
      return catalogVariantColors(store, product, variant).contains(color);
    }).toList(growable: false);

Set<String> catalogVariantColors(
  CatalogStore store,
  Product product,
  ProductVariant variant,
) {
  final explicit = variant.selectedOptions.entries.where(
    (entry) =>
        const {'color', 'colour'}.contains(normalizeSearchText(entry.key)),
  );
  if (explicit.isEmpty && variant.isDefault) {
    return store.facetsFor(product.id)?.colors.map((c) => c.value).toSet() ??
        <String>{};
  }
  // Option data with no color option must not infer a hardware color from a
  // size/material title. Legacy payloads without options retain title matching.
  final source = explicit.isNotEmpty
      ? explicit.map((e) => e.value).join(' ')
      : variant.selectedOptions.isEmpty
          ? variant.title
          : '';
  final text =
      ' ${normalizeSearchText(source).replaceAll(RegExp(r'[^a-z0-9]+'), ' ')} ';
  return {
    for (final entry in store.rules.colors.entries)
      if (entry.value
          .any((alias) => text.contains(' ${normalizeSearchText(alias)} ')))
        entry.key,
  };
}

List<Product> selectCatalogProducts(
  CatalogStore store,
  Iterable<Product> scope, {
  String query = '',
  String? color,
  String? priceBand,
  bool offersOnly = false,
  bool availableOnly = false,
  bool newOnly = false,
  bool Function(Product)? approvedNewArrival,
  CatalogOrder order = CatalogOrder.newest,
}) {
  final seen = <String>{};
  final normalized = normalizeSearchText(query);
  final result = scope.where((product) {
    if (!seen.add(product.id)) return false;
    if (!productMatchesNormalizedQuery(store, product, normalized)) {
      return false;
    }
    if (newOnly && !(approvedNewArrival?.call(product) ?? false)) return false;
    return (color == null &&
            priceBand == null &&
            !offersOnly &&
            !availableOnly) ||
        matchingCatalogVariants(
          store,
          product,
          color: color,
          priceBand: priceBand,
          offersOnly: offersOnly,
          availableOnly: availableOnly,
        ).isNotEmpty;
  }).toList();
  double matchingPrice(Product product) {
    final variants = matchingCatalogVariants(
      store,
      product,
      color: color,
      priceBand: priceBand,
      offersOnly: offersOnly,
      availableOnly: availableOnly,
    );
    return variants.isEmpty
        ? product.price
        : variants.map((v) => v.price).reduce((a, b) => a < b ? a : b);
  }

  result.sort((a, b) {
    final comparison = switch (order) {
      CatalogOrder.newest => b.createdAt.compareTo(a.createdAt),
      CatalogOrder.oldest => a.createdAt.compareTo(b.createdAt),
      CatalogOrder.priceAsc => matchingPrice(a).compareTo(matchingPrice(b)),
      CatalogOrder.priceDesc => matchingPrice(b).compareTo(matchingPrice(a)),
    };
    return comparison == 0 ? a.id.compareTo(b.id) : comparison;
  });
  return result;
}
