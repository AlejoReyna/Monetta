/// Pure collection-destination scoping.
library;

import '../../../data/normalize/facets.dart';
import '../../../domain/product.dart';
import 'product_search.dart';

/// What a collection destination is defined by.
class CollectionFilter {
  const CollectionFilter({
    this.category,
    this.brand,
    this.silhouette,
    this.query,
    this.queryTerms = const [],
    this.collectionHandle,
  });

  final String? category;
  final String? brand;
  final String? silhouette;
  final String? query;
  final List<String> queryTerms;
  final String? collectionHandle;
}

/// Everything [filter] contains, in the order of [products].
///
/// A product without `collectionHandles` always passes the handle rule: the
/// handles are optional metadata, not a gate. Terms are matched with the same
/// matcher search counts with, so "Ver todo" lands on the same number of
/// pieces the shopper was just looking at.
List<Product> filterCollectionProducts(
  Iterable<Product> products,
  FacetsLookup facetsFor,
  CollectionFilter filter,
) {
  final queryTerms = <String>{
    if (filter.query?.trim() case final query? when query.isNotEmpty) query,
    for (final term in filter.queryTerms)
      if (term.trim().isNotEmpty) term.trim(),
  };
  return products.where((product) {
    final CanonicalFacets? facets = facetsFor(product.id);
    if (filter.category != null && facets?.category?.value != filter.category) {
      return false;
    }
    if (filter.collectionHandle != null &&
        product.collectionHandles.isNotEmpty &&
        !product.collectionHandles.contains(filter.collectionHandle)) {
      return false;
    }
    return matchesAnyTerm(product, facets, queryTerms);
  }).toList(growable: false);
}
