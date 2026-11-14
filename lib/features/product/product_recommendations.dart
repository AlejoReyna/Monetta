import '../../data/normalize/facets.dart';
import '../../domain/product.dart';

List<Product> uniqueProductSet(
  Iterable<Product> products, {
  required String excluding,
  int limit = 40,
}) {
  final seen = <String>{excluding};
  return products.where((p) => seen.add(p.id)).take(limit).toList();
}

/// The relationship is an observed canonical category/silhouette match;
/// brand and actual session history are distinct sets in the PDP.
List<Product> relatedProductSet(
  Product product,
  Iterable<Product> candidates,
  CanonicalFacets? Function(String) facetsFor,
) {
  final source = facetsFor(product.id);
  final category = source?.category?.value;
  if (category == null) return const [];
  final silhouette = source?.silhouette?.value;
  return uniqueProductSet(
    candidates.where((candidate) {
      final facets = facetsFor(candidate.id);
      return facets?.category?.value == category &&
          (silhouette == null || facets?.silhouette?.value == silhouette);
    }),
    excluding: product.id,
  );
}
