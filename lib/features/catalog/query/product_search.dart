/// Pure product search: "does this product answer this query".
///
/// Search and the collection screen both need it, and they must agree: the
/// count shown next to a result grid and the count a shopper reaches through
/// "Ver todo" come from the same function, so they can never drift apart.
///
/// Nothing here knows about `CatalogStore`: callers hand in the products and a
/// lookup for their canonical facets.
library;

import '../../../app/shopper_copy.dart';
import '../../../data/normalize/facets.dart';
import '../../../domain/product.dart';
import '../../../reco/explainer.dart';
import 'search_text.dart';

/// Canonical facets of a product id, or null when it has none.
typedef FacetsLookup = CanonicalFacets? Function(String productId);

/// Everything a product can be found by: its own Shopify text plus the
/// shopper-facing labels of its canonical [facets]. Raw `vendor` is
/// deliberately absent — on this store it is the shop name on 36 products.
List<String> searchTermsFor(Product product, CanonicalFacets? facets) {
  return <String>[
    product.title,
    product.productType,
    ...product.tags,
    ...product.collectionHandles,
    if (facets?.brand case final brand?) brandLabel(brand.value),
    if (facets?.category case final category?) categoryLabel(category.value),
    if (facets?.category case final category?) categoryPlural(category.value),
    if (facets?.silhouette case final silhouette?)
      silhouetteLabel(silhouette.value),
    ...?facets?.colors.map((facet) => colorLabel(facet.value)),
    ...?facets?.patterns.map((facet) => patternLabel(facet.value)),
  ].where((term) => term.trim().isNotEmpty).toList(growable: false);
}

/// True when any term contains [normalizedQuery] (already normalized).
bool matchesNormalizedQuery(
  Product product,
  CanonicalFacets? facets,
  String normalizedQuery,
) {
  if (normalizedQuery.isEmpty) return true;
  return searchTermsFor(product, facets).any(
    (term) => normalizeSearchText(term).contains(normalizedQuery),
  );
}

/// Every product in [products] answering [rawQuery], in the given order. An
/// empty query returns nothing: search never silently means "everything".
List<Product> searchProductList(
  Iterable<Product> products,
  FacetsLookup facetsFor,
  String rawQuery,
) {
  final normalized = normalizeSearchText(rawQuery);
  if (normalized.isEmpty) return const <Product>[];
  return products
      .where(
        (product) =>
            matchesNormalizedQuery(product, facetsFor(product.id), normalized),
      )
      .toList(growable: false);
}

/// Matches when *any* of [rawTerms] does. Used by collection destinations that
/// are defined by a handful of words rather than one typed query.
bool matchesAnyTerm(
  Product product,
  CanonicalFacets? facets,
  Iterable<String> rawTerms,
) {
  final normalized = <String>{
    for (final term in rawTerms)
      if (normalizeSearchText(term) case final value when value.isNotEmpty)
        value,
  };
  if (normalized.isEmpty) return true;
  final terms = searchTermsFor(product, facets)
      .map(normalizeSearchText)
      .toList(growable: false);
  return normalized.any(
    (query) => terms.any((term) => term.contains(query)),
  );
}
