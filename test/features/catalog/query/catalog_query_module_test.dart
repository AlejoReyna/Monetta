/// CHAR-12b / CHAR-13b: the pure catalog query module (RF-40).
///
/// These run in a plain `test()`: no widget pump, no `CatalogStore`. The
/// screen-level behaviour stays pinned by CHAR-07, CHAR-12 and CHAR-13.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/normalize/facets.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/catalog/query/browse_filters.dart';
import 'package:monetta_app/features/catalog/query/collection_filter.dart';
import 'package:monetta_app/features/catalog/query/product_search.dart';
import 'package:monetta_app/features/catalog/query/search_text.dart';

Product _product(
  int i, {
  String title = 'Bolso',
  double price = 1500,
  List<String> handles = const [],
  DateTime? updatedAt,
}) =>
    Product(
      id: 'gid://shopify/Product/$i',
      handle: 'item-$i',
      title: title,
      vendor: 'Guess',
      productType: '',
      tags: const [],
      collectionHandles: handles,
      variants: [
        ProductVariant(
          id: 'gid://shopify/ProductVariant/$i',
          title: 'Default Title',
          price: price,
          available: true,
        ),
      ],
      images: const [],
      createdAt: DateTime.utc(2026, 8, 10),
      updatedAt: updatedAt ?? DateTime.utc(2026, 8, 10),
    );

CanonicalFacets _facets(Product product, {String? category, String? brand}) =>
    CanonicalFacets(
      productId: product.id,
      brand: brand == null ? null : FacetValue(brand, FacetSource.tag),
      category: category == null ? null : FacetValue(category, FacetSource.tag),
      priceBand: null,
      onSale: false,
      inStock: true,
      newArrival: false,
    );

void main() {
  group('CHAR-12b search module', () {
    test('normalizeSearchText folds accents, case and whitespace', () {
      expect(normalizeSearchText('  CAFÉ   Piña  '), 'cafe pina');
    });

    test('searchProductList matches accent-insensitively, in input order', () {
      final a = _product(1, title: 'Bolso Café');
      final b = _product(2, title: 'Cartera negra');
      final c = _product(3, title: 'Mochila CAFE');
      final hits = searchProductList([a, b, c], (_) => null, 'café');
      expect(hits.map((p) => p.id), [a.id, c.id]);
    });

    test('an empty query finds nothing but matches every product by term', () {
      final a = _product(1);
      expect(searchProductList([a], (_) => null, '   '), isEmpty);
      expect(matchesNormalizedQuery(a, null, ''), isTrue);
      expect(matchesAnyTerm(a, null, const ['  ']), isTrue);
    });

    test('facet labels are searchable without a store', () {
      final a = _product(1, title: 'Pieza');
      final facets = _facets(a, category: 'cartera');
      final terms = searchTermsFor(a, facets);
      expect(terms.first, 'Pieza');
      expect(terms.length, greaterThan(1));
      expect(
        searchProductList([a], (id) => id == a.id ? facets : null, 'cartera'),
        [a],
      );
    });
  });

  group('CHAR-12b collection filter', () {
    test('a product without handles passes the handle rule', () {
      final bare = _product(1);
      final tagged = _product(2, handles: const ['otra']);
      final match = _product(3, handles: const ['verano']);
      final result = filterCollectionProducts(
        [bare, tagged, match],
        (_) => null,
        const CollectionFilter(collectionHandle: 'verano'),
      );
      expect(result.map((p) => p.id), [bare.id, match.id]);
    });

    test('category and terms narrow the scope', () {
      final wallet = _product(1, title: 'Cartera azul');
      final bag = _product(2, title: 'Bolso azul');
      final facets = {
        wallet.id: _facets(wallet, category: 'cartera'),
        bag.id: _facets(bag, category: 'bolsa'),
      };
      final result = filterCollectionProducts(
        [wallet, bag],
        (id) => facets[id],
        const CollectionFilter(category: 'cartera', queryTerms: ['azul']),
      );
      expect(result, [wallet]);
    });
  });

  group('CHAR-13b browse filters', () {
    test('featured keeps order; price sorts both ways; empty keeps all', () {
      final a = _product(1, price: 3000);
      final b = _product(2, price: 500);
      final c = _product(3, price: 1500);
      List<String> ids(CatalogSort sort) => filterAndSortCatalog(
            [a, b, c],
            const {},
            CatalogBrowseFilters(sort: sort),
          ).map((p) => p.id).toList();
      expect(ids(CatalogSort.featured), [a.id, b.id, c.id]);
      expect(ids(CatalogSort.priceAsc), [b.id, c.id, a.id]);
      expect(ids(CatalogSort.priceDesc), [a.id, c.id, b.id]);
    });

    test('price band, deduced color and bag type filter independently', () {
      final tote = _product(1, title: 'Tote negro', price: 800);
      final other = _product(2, title: 'Cartera roja', price: 6000);
      List<Product> run(CatalogBrowseFilters filters) =>
          filterAndSortCatalog([tote, other], const {}, filters);
      expect(
        run(const CatalogBrowseFilters(priceBands: {'mxn-under-1000'})),
        [tote],
      );
      expect(run(const CatalogBrowseFilters(colors: {'Rojo'})), [other]);
      expect(run(const CatalogBrowseFilters(types: {'Tote'})), [tote]);
      expect(browsePriceBandFor(other), 'mxn-5000-plus');
    });

    test('category aliases fold onto the browser vocabulary', () {
      final p = _product(1);
      expect(browseCategoryFor(_facets(p, category: 'Handbags')), 'bolsa');
      expect(browseCategoryFor(null), 'otros');
      expect(browseBrandFor(p, null), 'Guess');
      expect(const CatalogBrowseFilters(colors: {'Rojo'}).activeCount, 1);
    });
  });
}
