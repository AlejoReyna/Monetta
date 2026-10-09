/// CHAR-12: what product search matches today.
///
/// Characterization of `lib/features/catalog/catalog_query.dart`
/// (`productSearchTerms`, `productMatchesNormalizedQuery`, `searchProducts`,
/// `productMatchesAnyTerm`) and of the normalization they share
/// (`normalizeSearchText`). RF-40 moves these queries into a pure module; it
/// must keep every assertion here, changing only the imports below.
///
/// Synthetic products pin each term source exactly; the bundled catalog asset
/// covers the real data (order, raw `vendor`, empty query).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/normalize/facets.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/catalog/catalog_query.dart';
import 'package:monetta_app/features/catalog/search_history.dart';

import '../../support/product_screen_harness.dart';

String _gid(int i) => 'gid://shopify/Product/$i';

Product _product(
  int i, {
  String title = 'Pieza',
  String vendor = '',
  String productType = '',
  List<String> tags = const [],
  List<String> collectionHandles = const [],
}) =>
    Product(
      id: _gid(i),
      handle: 'pieza-$i',
      title: title,
      vendor: vendor,
      productType: productType,
      tags: tags,
      variants: [
        ProductVariant(
          id: 'gid://shopify/ProductVariant/$i',
          title: 'Default Title',
          price: 1000,
          available: true,
        ),
      ],
      images: const [],
      createdAt: DateTime.utc(2026, 8),
      updatedAt: DateTime.utc(2026, 8),
      collectionHandles: collectionHandles,
    );

CanonicalFacets _facets(
  int i, {
  String? brand,
  String? category,
  String? silhouette,
  List<String> colors = const [],
  List<String> patterns = const [],
}) =>
    CanonicalFacets(
      productId: _gid(i),
      brand: brand == null ? null : FacetValue(brand, FacetSource.tag),
      category: category == null ? null : FacetValue(category, FacetSource.tag),
      silhouette:
          silhouette == null ? null : FacetValue(silhouette, FacetSource.tag),
      colors: [for (final c in colors) FacetValue(c, FacetSource.tag)],
      patterns: [for (final p in patterns) FacetValue(p, FacetSource.tag)],
      priceBand: null,
      onSale: false,
      inStock: true,
      newArrival: false,
    );

/// A store holding exactly [products] (in that order) and [facets].
CatalogStore _store(
  List<Product> products, [
  List<CanonicalFacets> facets = const [],
]) {
  final store = CatalogStore(database: openTestDatabase());
  store.products = products;
  store.facetsById = {for (final f in facets) f.productId: f};
  return store;
}

List<String> _ids(Iterable<Product> products) =>
    products.map((p) => p.id).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CHAR-12 normalization', () {
    test('CHAR-12 normalizeSearchText folds case, accents and whitespace', () {
      expect(normalizeSearchText('  BOLSA   Pequeña  '), 'bolsa pequena');
      expect(normalizeSearchText('Áé Íó Úü Ññ'), 'ae io uu nn');
      expect(normalizeSearchText('a\t\nb'), 'a b');
      expect(normalizeSearchText('   '), '');
      // Only the Spanish set is folded; other accents survive.
      expect(normalizeSearchText('Ç à'), 'ç à');
    });

    test(
      'CHAR-12 upper case, accents and repeated spaces find the same piece',
      () {
        final store = _store([
          _product(1, title: 'Bolsa  Pequeña   Ñandú'),
          _product(2, title: 'Reloj clásico'),
        ]);

        for (final query in const [
          'bolsa pequena nandu',
          'BOLSA PEQUEÑA ÑANDÚ',
          '  bolsa    pequena  nandu  ',
          'Bolsa Pequeña Ñandú',
          'pequeña',
          'NANDU',
        ]) {
          expect(
            _ids(searchProducts(store, query)),
            [_gid(1)],
            reason: 'query "$query"',
          );
        }
        // Accent folding works in both directions.
        expect(_ids(searchProducts(store, 'clasico')), [_gid(2)]);
        expect(_ids(searchProducts(store, 'CLÁSICO')), [_gid(2)]);
      },
    );

    test('CHAR-12 the query matches as a substring, not by whole word', () {
      final store = _store([_product(1, title: 'Mochila Urbana')]);
      expect(_ids(searchProducts(store, 'chila urb')), [_gid(1)]);
      expect(searchProducts(store, 'urbana mochila'), isEmpty);
    });
  });

  group('CHAR-12 term sources', () {
    // One piece carries a distinct word in every source; a decoy carries none.
    // Each query below can only be answered by the named source.
    late CatalogStore store;

    setUp(() {
      store = _store(
        [
          _product(
            1,
            title: 'Zafiro',
            productType: 'Valija',
            tags: const ['edicion-limitada'],
            collectionHandles: const ['coleccion-otono'],
          ),
          _product(2, title: 'Decoy', productType: 'Otro'),
        ],
        [
          _facets(
            1,
            brand: 'michael_kors',
            category: 'reloj',
            silhouette: 'shoulder',
            colors: const ['cafe', 'rosa'],
            patterns: const ['animal_print'],
          ),
          _facets(2, brand: 'coach', category: 'bolsa'),
        ],
      );
    });

    const sources = <String, String>{
      'title': 'zafiro',
      'productType': 'valija',
      'tag': 'edicion-limitada',
      'collection handle': 'coleccion-otono',
      'brand label': 'michael kors',
      'category singular': 'reloj',
      'category plural': 'relojes',
      'silhouette label': 'de hombro',
      'first colour label': 'cafe',
      'second colour label': 'rosa',
      'pattern label': 'animal print',
    };

    for (final entry in sources.entries) {
      test('CHAR-12 a piece is found by its ${entry.key}', () {
        expect(
          _ids(searchProducts(store, entry.value)),
          [_gid(1)],
          reason: 'query "${entry.value}"',
        );
      });
    }

    test('CHAR-12 labels are matched with accents and case folded', () {
      expect(_ids(searchProducts(store, 'CAFÉ')), [_gid(1)]);
      expect(_ids(searchProducts(store, 'Animal Print')), [_gid(1)]);
      expect(_ids(searchProducts(store, 'MICHAEL   KORS')), [_gid(1)]);
    });

    test('CHAR-12 the raw facet slugs are not searchable, only their labels',
        () {
      // `michael_kors` and `animal_print` are identifiers; only the humanized
      // label ("Michael Kors") is a search term.
      expect(searchProducts(store, 'michael_kors'), isEmpty);
      expect(searchProducts(store, 'animal_print'), isEmpty);
    });

    test('CHAR-12 the singular category label does not satisfy the plural', () {
      // "relojes" is found only through the plural label; a piece whose only
      // category source is the singular would not match it.
      final single = _store(
        [_product(1, title: 'Zafiro')],
        [_facets(1, category: 'reloj')],
      );
      expect(_ids(searchProducts(single, 'reloj')), [_gid(1)]);
      expect(_ids(searchProducts(single, 'relojes')), [_gid(1)]);
      // A different category matches neither.
      expect(searchProducts(single, 'bolsas'), isEmpty);
    });

    test('CHAR-12 productSearchTerms lists the own text then the facet labels',
        () {
      final terms = productSearchTerms(store, store.products.first);
      expect(
        terms,
        [
          'Zafiro',
          'Valija',
          'edicion-limitada',
          'coleccion-otono',
          'Michael Kors',
          'Reloj',
          'Relojes',
          'De hombro',
          'Café',
          'Rosa',
          'Animal print',
        ],
      );
    });

    test('CHAR-12 blank terms are dropped from productSearchTerms', () {
      final blank = _store([
        _product(1, title: 'Solo', productType: '  ', tags: const ['', ' ']),
      ]);
      expect(productSearchTerms(blank, blank.products.first), ['Solo']);
    });

    test('CHAR-12 a piece without facets is found only by its own text', () {
      final bare = _store([
        _product(1, title: 'Zafiro', tags: const ['viaje']),
      ]);
      expect(_ids(searchProducts(bare, 'viaje')), [_gid(1)]);
      expect(searchProducts(bare, 'bolsa'), isEmpty);
      expect(productSearchTerms(bare, bare.products.first), [
        'Zafiro',
        'viaje',
      ]);
    });
  });

  group('CHAR-12 raw vendor', () {
    test('CHAR-12 the raw vendor does not find a piece (synthetic)', () {
      final store = _store([
        _product(1, title: 'Zafiro', vendor: 'Zorbatex'),
      ]);
      expect(searchProducts(store, 'zorbatex'), isEmpty);
      expect(searchProducts(store, 'ZORBATEX'), isEmpty);
      expect(
        productSearchTerms(store, store.products.first)
            .map(normalizeSearchText),
        isNot(contains('zorbatex')),
      );
    });

    test('CHAR-12 a vendor identical to the brand is found by the brand label',
        () {
      // The vendor itself is not a term; the canonical brand facet is.
      final store = _store(
        [_product(1, title: 'Zafiro', vendor: 'Guess')],
        [_facets(1, brand: 'guess')],
      );
      expect(_ids(searchProducts(store, 'guess')), [_gid(1)]);
      final unresolved = _store([
        _product(1, title: 'Zafiro', vendor: 'Guess'),
      ]);
      expect(searchProducts(unresolved, 'guess'), isEmpty);
    });

    test('CHAR-12 the raw vendor of the asset catalog is not a term', () async {
      final store = await loadedStore();
      bool vendorIsATerm(Product p) => productSearchTerms(store, p)
          .map(normalizeSearchText)
          .any((t) => t.contains(normalizeSearchText(p.vendor)));

      final unreachable = store.products
          .where((p) => p.vendor.trim().isNotEmpty && !vendorIsATerm(p))
          .toList();
      // The store name and some brands are not among their own pieces' terms.
      expect(unreachable, isNotEmpty);
      for (final product in unreachable.take(10)) {
        expect(
          searchProducts(store, product.vendor),
          isNot(contains(product)),
          reason: '${product.title} found through vendor "${product.vendor}"',
        );
      }
    });
  });

  group('CHAR-12 empty queries', () {
    test('CHAR-12 an empty or whitespace-only query returns nothing', () {
      final store = _store([_product(1, title: 'Zafiro')]);
      for (final query in const ['', ' ', '    ', '\t', '\n', ' \t \n ']) {
        expect(
          searchProducts(store, query),
          isEmpty,
          reason: 'query ${query.codeUnits}',
        );
      }
    });

    test('CHAR-12 an empty query returns nothing over the asset catalog',
        () async {
      final store = await loadedStore();
      expect(store.products, isNotEmpty);
      expect(searchProducts(store, ''), isEmpty);
      expect(searchProducts(store, '   '), isEmpty);
    });

    test(
        'CHAR-12 productMatchesNormalizedQuery treats an empty query as a match',
        () {
      final store = _store([_product(1, title: 'Zafiro')]);
      expect(
        productMatchesNormalizedQuery(store, store.products.first, ''),
        isTrue,
      );
      expect(
        productMatchesNormalizedQuery(store, store.products.first, 'zafiro'),
        isTrue,
      );
      expect(
        productMatchesNormalizedQuery(store, store.products.first, 'otro'),
        isFalse,
      );
    });

    test('CHAR-12 a query matching nothing returns an empty list', () {
      final store = _store([_product(1, title: 'Zafiro')]);
      expect(searchProducts(store, 'xyzzy'), isEmpty);
    });
  });

  group('CHAR-12 result order', () {
    test('CHAR-12 results come in catalog order, not sorted by any field', () {
      final store = _store([
        _product(30, title: 'Bolsa Zeta'),
        _product(10, title: 'Bolsa Alfa'),
        _product(20, title: 'Reloj'),
        _product(5, title: 'Bolsa Mini'),
      ]);
      expect(
        _ids(searchProducts(store, 'bolsa')),
        [_gid(30), _gid(10), _gid(5)],
      );

      // Reordering the catalog reorders the result: nothing re-ranks it.
      store.products = store.products.reversed.toList();
      expect(
        _ids(searchProducts(store, 'bolsa')),
        [_gid(5), _gid(10), _gid(30)],
      );
    });

    test('CHAR-12 a piece appears once even when several terms match', () {
      final store = _store(
        [
          _product(
            1,
            title: 'Bolsa de hombro',
            productType: 'Bolsa',
            tags: const ['bolsa'],
          ),
        ],
        [_facets(1, category: 'bolsa')],
      );
      expect(_ids(searchProducts(store, 'bolsa')), [_gid(1)]);
    });

    test('CHAR-12 asset results keep the catalog order', () async {
      final store = await loadedStore();
      final order = {
        for (var i = 0; i < store.products.length; i++) store.products[i].id: i,
      };
      for (final query in const ['bolsa', 'guess', 'negro', 'a']) {
        final result = searchProducts(store, query);
        expect(result, isNotEmpty, reason: query);
        final positions = result.map((p) => order[p.id]!).toList();
        expect(positions, orderedEquals([...positions]..sort()), reason: query);
        expect(positions.toSet().length, positions.length, reason: query);
      }
    });

    test('CHAR-12 an asset piece is found by its own title', () async {
      final store = await loadedStore();
      for (final product in store.products.take(25)) {
        if (normalizeSearchText(product.title).isEmpty) continue;
        final result = searchProducts(store, product.title);
        expect(result, contains(product), reason: product.title);
        expect(
          result.every(
            (p) => productMatchesNormalizedQuery(
              store,
              p,
              normalizeSearchText(product.title),
            ),
          ),
          isTrue,
          reason: product.title,
        );
      }
    });
  });

  group('CHAR-12 productMatchesAnyTerm', () {
    late CatalogStore store;
    late Product piece;

    setUp(() {
      store = _store(
        [
          _product(1, title: 'Bolsa Pequeña', tags: const ['viaje']),
        ],
        [_facets(1, brand: 'guess', category: 'bolsa')],
      );
      piece = store.products.first;
    });

    test('CHAR-12 no terms at all matches every piece', () {
      expect(productMatchesAnyTerm(store, piece, const []), isTrue);
    });

    test('CHAR-12 only blank terms match every piece', () {
      expect(productMatchesAnyTerm(store, piece, const ['', '   ']), isTrue);
    });

    test('CHAR-12 one matching term among several is enough', () {
      expect(
        productMatchesAnyTerm(
          store,
          piece,
          const ['reloj', 'viaje', 'perfume'],
        ),
        isTrue,
      );
      expect(
        productMatchesAnyTerm(store, piece, const ['reloj', 'bolsa']),
        isTrue,
      );
    });

    test('CHAR-12 no matching term means no match', () {
      expect(
        productMatchesAnyTerm(store, piece, const ['reloj', 'perfume']),
        isFalse,
      );
    });

    test('CHAR-12 blank terms are ignored when a real term is present', () {
      // A blank term does not turn "reloj" into "everything".
      expect(
        productMatchesAnyTerm(store, piece, const ['', 'reloj']),
        isFalse,
      );
      expect(
        productMatchesAnyTerm(store, piece, const ['', 'viaje']),
        isTrue,
      );
    });

    test('CHAR-12 terms are normalized and matched against facet labels', () {
      expect(productMatchesAnyTerm(store, piece, const ['PEQUEÑA']), isTrue);
      expect(productMatchesAnyTerm(store, piece, const ['pequena']), isTrue);
      expect(productMatchesAnyTerm(store, piece, const ['Guess']), isTrue);
      expect(productMatchesAnyTerm(store, piece, const ['bolsas']), isTrue);
    });

    test('CHAR-12 a term is a substring match, like a typed query', () {
      expect(productMatchesAnyTerm(store, piece, const ['pequ']), isTrue);
      expect(
        productMatchesAnyTerm(store, piece, const ['pequeña bolsa']),
        isFalse,
      );
    });
  });
}
