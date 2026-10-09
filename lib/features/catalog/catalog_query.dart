/// One matcher for "does this product answer this query".
///
/// Search and the collection screen both need it, and they must agree: the
/// count shown next to a result grid and the count a shopper reaches through
/// "Ver todo" come from the same function, so they can never drift apart.
library;

import '../../app/catalog_store.dart';
import '../../domain/product.dart';
import 'query/product_search.dart';

/// Everything a product can be found by: its own Shopify text plus the
/// shopper-facing labels of its canonical facets. Raw `vendor` is deliberately
/// absent — on this store it is the shop name on 36 products.
///
/// Thin wrapper over the pure `query/product_search.dart`.
List<String> productSearchTerms(CatalogStore store, Product product) =>
    searchTermsFor(product, store.facetsFor(product.id));

/// True when any term contains [normalizedQuery] (already normalized).
bool productMatchesNormalizedQuery(
  CatalogStore store,
  Product product,
  String normalizedQuery,
) =>
    matchesNormalizedQuery(
      product,
      store.facetsFor(product.id),
      normalizedQuery,
    );

/// Every product answering [rawQuery], in catalog order. An empty query
/// returns nothing: search never silently means "everything".
List<Product> searchProducts(CatalogStore store, String rawQuery) =>
    searchProductList(store.products, store.facetsFor, rawQuery);

/// Matches when *any* of [rawTerms] does. Used by collection destinations that
/// are defined by a handful of words rather than one typed query.
bool productMatchesAnyTerm(
  CatalogStore store,
  Product product,
  Iterable<String> rawTerms,
) =>
    matchesAnyTerm(product, store.facetsFor(product.id), rawTerms);
