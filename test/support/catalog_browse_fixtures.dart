import 'package:monetta_app/data/normalize/facets.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/catalog/catalog_browse_screen.dart';
import 'package:monetta_app/features/catalog/product_tile.dart';

/// Synthetic Monetta pieces for the full-catalog browser tests.
///
/// A piece is a [Product] plus, when it has a category or a canonical brand,
/// its [CanonicalFacets] — the two inputs the browser takes. Nothing here
/// reads a clock or the network.
class BrowseEntry {
  const BrowseEntry(this.product, this.facets);

  final Product product;
  final CanonicalFacets? facets;

  /// The view data the browser builds for this piece.
  ProductTileData get tileData =>
      ProductTileData.forCatalogBrowse(product, facets: facets);
}

/// Piece number [i]: title `Monetta Item <i>`, vendor `Guess`, one variant
/// priced [price] MXN. [category] and [brand] become canonical facet slugs;
/// without either the piece has no facets at all.
BrowseEntry browseEntry(
  int i, {
  String? title,
  String vendor = 'Guess',
  String? category,
  String? brand,
  double price = 1999,
  bool inStock = true,
  DateTime? updatedAt,
}) {
  final id = 'gid://shopify/Product/$i';
  final product = Product(
    id: id,
    handle: 'item-$i',
    title: title ?? 'Monetta Item $i',
    vendor: vendor,
    productType: '',
    tags: const [],
    variants: [
      ProductVariant(
        id: 'gid://shopify/ProductVariant/$i',
        title: 'Default Title',
        price: price,
        available: inStock,
      ),
    ],
    images: const [],
    createdAt: DateTime.utc(2026, 8, 10),
    updatedAt: updatedAt ?? DateTime.utc(2026, 8, 10),
  );
  final facets = category == null && brand == null
      ? null
      : CanonicalFacets(
          productId: id,
          brand: brand == null ? null : FacetValue(brand, FacetSource.tag),
          category:
              category == null ? null : FacetValue(category, FacetSource.tag),
          priceBand: null,
          onSale: false,
          inStock: inStock,
          newArrival: false,
        );
  return BrowseEntry(product, facets);
}

/// [CatalogBrowseScreen] over [entries], with the facets keyed by product id.
CatalogBrowseScreen browseScreen(
  Iterable<BrowseEntry> entries, {
  int bagCount = 0,
}) =>
    CatalogBrowseScreen(
      products: [for (final entry in entries) entry.product],
      facetsById: {
        for (final entry in entries)
          if (entry.facets != null) entry.product.id: entry.facets!,
      },
      bagCount: bagCount,
    );
