/// Pure filter and sort for the full-catalog browser.
///
/// The browser has no text field: it narrows the catalog by facets only, so
/// nothing here takes a query. Bag type and colors are deliberately deduced
/// from the title and category text, as the screen always did.
library;

import '../../../app/shopper_copy.dart';
import '../../../data/normalize/facets.dart';
import '../../../domain/product.dart';

enum CatalogSort { featured, newest, priceAsc, priceDesc }

/// The browser's applied selection.
class CatalogBrowseFilters {
  const CatalogBrowseFilters({
    this.sort = CatalogSort.featured,
    this.categories = const <String>{},
    this.types = const <String>{},
    this.brands = const <String>{},
    this.priceBands = const <String>{},
    this.colors = const <String>{},
    this.inStockOnly = false,
  });

  final CatalogSort sort;

  /// Canonical category keys as produced by [browseCategoryFor].
  final Set<String> categories;
  final Set<String> types;
  final Set<String> brands;
  final Set<String> priceBands;
  final Set<String> colors;
  final bool inStockOnly;

  int get activeCount =>
      categories.length +
      types.length +
      brands.length +
      priceBands.length +
      colors.length +
      (inStockOnly ? 1 : 0);

  @override
  bool operator ==(Object other) =>
      other is CatalogBrowseFilters &&
      other.sort == sort &&
      other.inStockOnly == inStockOnly &&
      _sameMembers(other.categories, categories) &&
      _sameMembers(other.types, types) &&
      _sameMembers(other.brands, brands) &&
      _sameMembers(other.priceBands, priceBands) &&
      _sameMembers(other.colors, colors);

  @override
  int get hashCode => Object.hash(
        sort,
        inStockOnly,
        Object.hashAllUnordered(categories),
        Object.hashAllUnordered(types),
        Object.hashAllUnordered(brands),
        Object.hashAllUnordered(priceBands),
        Object.hashAllUnordered(colors),
      );
}

bool _sameMembers(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);

const Map<String, List<String>> kBrowseBagTypeTerms = {
  'Crossbody': ['crossbody', 'bandolera', 'messenger'],
  'Tote': ['tote'],
  'Bolsa de hombro': ['shoulder', 'hombro'],
  'Satchel': ['satchel'],
  'Bolsa de mano': ['handbag', 'top handle', 'bolsa de mano'],
  'Mochila': ['backpack', 'mochila'],
  'Clutch': ['clutch'],
  'Cangurera': ['belt bag', 'waist bag', 'cangurera'],
  'Bolsa cubeta': ['bucket', 'cubeta'],
  'Cartera': ['wallet', 'cartera'],
  'Tarjetero': ['card holder', 'cardholder', 'tarjetero'],
};

const Map<String, List<String>> kBrowseColorTerms = {
  'Negro': ['negro', 'negra', 'black'],
  'Café': ['cafe', 'café', 'brown', 'cognac'],
  'Beige': ['beige', 'arena', 'sand', 'camel', 'nude'],
  'Blanco': ['blanco', 'blanca', 'white', 'ivory', 'hueso'],
  'Gris': ['gris', 'gray', 'grey'],
  'Azul': ['azul', 'blue', 'navy', 'marino', 'mezclilla'],
  'Rosa': ['rosa', 'pink', 'blush'],
  'Rojo': ['rojo', 'roja', 'red'],
  'Vino': ['vino', 'burgundy', 'bordo'],
  'Verde': ['verde', 'green', 'olive', 'oliva'],
  'Morado': ['morado', 'morada', 'purple', 'lila'],
  'Amarillo': ['amarillo', 'amarilla', 'yellow'],
  'Naranja': ['naranja', 'orange'],
  'Dorado': ['dorado', 'gold'],
  'Plateado': ['plateado', 'silver'],
};

/// The price band keys, in display order.
const List<String> kBrowsePriceBands = [
  'mxn-under-1000',
  'mxn-1000-2499',
  'mxn-2500-4999',
  'mxn-5000-plus',
];

/// Canonical category key of a product: the facet folded onto the browser's
/// vocabulary, else the facet itself, else `otros`.
String browseCategoryFor(CanonicalFacets? facets) {
  final rawCategory = facets?.category?.value.trim().toLowerCase();

  // A piece without a category facet has no bag/wallet/perfume vertical to
  // fall back on (the vertical was itself derived from the category), so it
  // is simply "otros".
  return switch (rawCategory) {
    'bolsas' || 'handbag' || 'handbags' => 'bolsa',
    'carteras' || 'wallet' || 'wallets' => 'cartera',
    'monederos' => 'monedero',
    'tarjeteros' || 'card case' || 'card cases' => 'tarjetero',
    'relojes' || 'watch' || 'watches' => 'reloj',
    'cosmetiqueras' || 'cosmetic case' || 'cosmetic cases' => 'cosmetiquera',
    'sets' => 'set',
    'accesorios' || 'accessory' || 'accessories' => 'accesorio',
    'perfumes' ||
    'fragancia' ||
    'fragancias' ||
    'fragrance' ||
    'fragrances' =>
      'perfume',
    final value? when value.isNotEmpty => value,
    _ => 'otros',
  };
}

/// The humanized brand the full-catalog browser shows and filters by: the
/// canonical brand facet, else the raw vendor, else the store name.
String browseBrandFor(Product product, CanonicalFacets? facets) {
  final brand = (facets?.brand?.value ?? product.vendor).trim();
  return humanizeCatalogValue(brand.isEmpty ? 'Monetta' : brand);
}

/// The first bag type whose terms appear in the category or title.
String? browseBagTypeFor(Product product, CanonicalFacets? facets) {
  final terms =
      '${facets?.category?.value ?? ''} ${product.title}'.toLowerCase();
  for (final entry in kBrowseBagTypeTerms.entries) {
    if (entry.value.any(terms.contains)) return entry.key;
  }
  return null;
}

/// Every color whose terms appear in the title or category.
Set<String> browseColorsFor(Product product, CanonicalFacets? facets) {
  final terms = [
    product.title,
    facets?.category?.value ?? '',
  ].join(' ').toLowerCase();
  return {
    for (final entry in kBrowseColorTerms.entries)
      if (entry.value.any(terms.contains)) entry.key,
  };
}

/// The MXN price band key of a product.
String browsePriceBandFor(Product product) {
  final amount = product.price;
  if (amount < 1000) return 'mxn-under-1000';
  if (amount < 2500) return 'mxn-1000-2499';
  if (amount < 5000) return 'mxn-2500-4999';
  return 'mxn-5000-plus';
}

/// [products] narrowed by [filters] and ordered by [CatalogBrowseFilters.sort].
/// `featured` keeps the catalog order.
List<Product> filterAndSortCatalog(
  List<Product> products,
  Map<String, CanonicalFacets> facetsById,
  CatalogBrowseFilters filters,
) {
  final result = products.where((product) {
    final facets = facetsById[product.id];
    if (filters.categories.isNotEmpty &&
        !filters.categories.contains(browseCategoryFor(facets))) {
      return false;
    }
    if (filters.types.isNotEmpty &&
        !filters.types.contains(browseBagTypeFor(product, facets))) {
      return false;
    }
    if (filters.brands.isNotEmpty &&
        !filters.brands.contains(browseBrandFor(product, facets))) {
      return false;
    }
    if (filters.priceBands.isNotEmpty &&
        !filters.priceBands.contains(browsePriceBandFor(product))) {
      return false;
    }
    if (filters.colors.isNotEmpty &&
        filters.colors.intersection(browseColorsFor(product, facets)).isEmpty) {
      return false;
    }
    if (filters.inStockOnly && !product.isInStock) return false;
    return true;
  }).toList(growable: false);

  switch (filters.sort) {
    case CatalogSort.featured:
      break;
    case CatalogSort.newest:
      result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    case CatalogSort.priceAsc:
      result.sort(_comparePriceAsc);
    case CatalogSort.priceDesc:
      result.sort((a, b) => _comparePriceAsc(b, a));
  }
  return result;
}

int _comparePriceAsc(Product a, Product b) => a.price.compareTo(b.price);
