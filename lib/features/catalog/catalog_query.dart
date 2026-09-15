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
bool productMatchesNormalizedQuery(
  CatalogStore store,
  Product product,
  String normalizedQuery,
) {
  if (normalizedQuery.isEmpty) return true;
  return productSearchTerms(store, product).any(
    (term) => normalizeSearchText(term).contains(normalizedQuery),
  );
}

/// Every product answering [rawQuery], in catalog order. An empty query
/// returns nothing: search never silently means "everything".
List<Product> searchProducts(CatalogStore store, String rawQuery) {
  final normalized = normalizeSearchText(rawQuery);
  if (normalized.isEmpty) return const <Product>[];
  return store.products
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
