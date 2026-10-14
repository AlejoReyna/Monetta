import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/catalog/catalog_controls.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/catalog/product_card.dart';
import 'package:monetta_app/main.dart';

import '../../support/catalog_browse_fixtures.dart';

// The filter panel is the only entry to filtering (FICHA-T1, BRIEF 2.2): the
// quick-filter pills of the catalog and the silhouette / sort pills of the
// collections are gone, and every capability they offered is reachable, and
// works, from the panel. FLT-02 and FLT-03 characterize the panel as it is
// today; FLT-01* are the target state and fail until the pills are removed.

BrowseEntry _item(
  int i, {
  required String title,
  required String brand,
  required double price,
  String category = 'bolsa',
  bool inStock = true,
}) =>
    browseEntry(
      i,
      title: title,
      vendor: brand,
      category: category,
      price: price,
      inStock: inStock,
      updatedAt: DateTime.utc(2026, 8, 10, i),
    );

/// Feed order is 1..6; prices are all different so any sort is unambiguous.
final _items = [
  _item(1, title: 'Bolsa Crossbody Negra', brand: 'Guess', price: 3000),
  _item(2, title: 'Bolsa Tote Roja', brand: 'Coach', price: 6000),
  _item(3, title: 'Bolsa Satchel Beige', brand: 'Guess', price: 1500),
  _item(
    4,
    title: 'Cartera Negra',
    brand: 'Coach',
    price: 800,
    category: 'cartera',
  ),
  _item(
    5,
    title: 'Bolsa Crossbody Azul',
    brand: 'Michael Kors',
    price: 4000,
    inStock: false,
  ),
  _item(6, title: 'Bolsa Tote Negra', brand: 'Guess', price: 2000),
];

String _name(int i) => _items[i - 1].tileData.title;

List<String> _feedOrder() => [for (var i = 1; i <= 6; i++) _name(i)];

void _view(WidgetTester tester, {double width = 390, double height = 1600}) {
  addTearDown(tester.view.reset);
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, height);
}

Widget _app(Widget home, {double scale = 1.0}) => MaterialApp(
      theme: buildLightTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: home,
    );

Future<void> _pumpCatalog(
  WidgetTester tester, {
  List<BrowseEntry>? items,
  double scale = 1.0,
}) async {
  await tester.pumpWidget(
    _app(browseScreen(items ?? _items), scale: scale),
  );
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// Catalog tile names in reading order (top to bottom, then left to right).
List<String> _catalogOrder(WidgetTester tester) {
  final tiles = find.byType(MonettaProductTile);
  final entries = <(Offset, String)>[
    for (var i = 0; i < tiles.evaluate().length; i++)
      (
        tester.getTopLeft(tiles.at(i)),
        tester.widget<MonettaProductTile>(tiles.at(i)).data.title,
      ),
  ]..sort((a, b) {
      final byRow = a.$1.dy.compareTo(b.$1.dy);
      return byRow != 0 ? byRow : a.$1.dx.compareTo(b.$1.dx);
    });
  return [for (final entry in entries) entry.$2];
}

// --- catalog panel helpers ---------------------------------------------------

final _sheet = find.byType(BottomSheet);

Finder _inSheet(String text) =>
    find.descendant(of: _sheet, matching: find.text(text));

Future<void> _openCatalogPanel(WidgetTester tester) =>
    _tap(tester, find.byKey(const Key('catalog-filter-button')));

Future<void> _openSection(WidgetTester tester, String name) =>
    _tap(tester, find.byKey(Key('catalog-filter-$name')));

Future<void> _applyCatalogPanel(WidgetTester tester) =>
    _tap(tester, find.byKey(const Key('catalog-filter-apply')));

String _applyLabel(WidgetTester tester) {
  final label = find.descendant(
    of: find.byKey(const Key('catalog-filter-apply')),
    matching: find.byType(Text),
  );
  return tester.widget<Text>(label.first).data!;
}

void _expectCatalogBadge(int? count) {
  final badge = find.byKey(const Key('catalog-filter-count'));
  if (count == null) {
    expect(badge, findsNothing);
    return;
  }
  expect(badge, findsOneWidget);
  expect(
    find.descendant(of: badge, matching: find.text('$count')),
    findsOneWidget,
  );
}

// --- collection helpers ------------------------------------------------------

Future<CatalogStore> _loadedStore() async {
  final store = CatalogStore(database: openTestDatabase());
  await store.loadFromAsset();
  return store;
}

Future<void> _pumpCollection(
  WidgetTester tester,
  CatalogStore store, {
  double scale = 1.0,
}) async {
  await tester.pumpWidget(
    _app(
      StoreScope(
        notifier: store,
        child: const CollectionScreen(
          title: 'Bolsas',
          filter: CollectionFilter(category: 'bolsa'),
        ),
      ),
      scale: scale,
    ),
  );
  await tester.pumpAndSettle();
}

List<String> _cardIds(WidgetTester tester) => tester
    .widgetList<ProductCard>(find.byType(ProductCard))
    .map((card) => card.product.id)
    .toList();

Future<void> _openCollectionPanel(WidgetTester tester) =>
    _tap(tester, find.byKey(const Key('collection-filter-button')));

Future<void> _applyCollectionPanel(WidgetTester tester) =>
    _tap(tester, find.byKey(const Key('collection-filter-apply')));

void _expectCollectionBadge(int? count) {
  final badge = find.byKey(const Key('collection-filter-count'));
  if (count == null) {
    expect(badge, findsNothing);
    return;
  }
  expect(badge, findsOneWidget);
  expect(
    find.descendant(of: badge, matching: find.text('$count')),
    findsOneWidget,
  );
}

bool _isSilhouettePill(Widget widget) =>
    widget.key is ValueKey<String> &&
    (widget.key! as ValueKey<String>)
        .value
        .startsWith('collection-silhouette-');

void main() {
  group('FLT-01 the catalog has no duplicated filter pills', () {
    testWidgets('FLT-01 no chip rail, capsule chips or quick-filter keys',
        (tester) async {
      _view(tester);
      await _pumpCatalog(tester, items: _items.take(3).toList());

      expect(find.byType(MonettaChipRail), findsNothing);
      expect(find.byType(MonettaCapsuleChip), findsNothing);
      for (final key in ['brand', 'price', 'color', 'sort']) {
        expect(
          find.byKey(Key('catalog-quick-$key')),
          findsNothing,
          reason: 'catalog-quick-$key',
        );
      }
      for (final text in ['Marca', 'Precio', 'Color', 'Ordenar']) {
        expect(find.text(text), findsNothing, reason: text);
      }
      // The single entry stays.
      expect(find.byKey(const Key('catalog-filter-button')), findsOneWidget);
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'FLT-01b header-to-photos gap is 8-16 px at text scale $scale',
          (tester) async {
        _view(tester);
        await _pumpCatalog(tester, scale: scale);

        expect(tester.takeException(), isNull);
        final header = tester.getRect(find.byType(AppBar));
        final firstTile = tester.getRect(find.byType(MonettaProductTile).first);
        final gap = firstTile.top - header.bottom;
        expect(gap, inInclusiveRange(8, 16), reason: 'no empty band');
      });
    }
  });

  group('FLT-02 every pill capability works from the panel only', () {
    testWidgets('FLT-02 (vigente) the panel offers every section',
        (tester) async {
      _view(tester);
      await _pumpCatalog(tester);
      await _openCatalogPanel(tester);

      for (final label in [
        'Ordenar por',
        'Categoría',
        'Tipo de bolsa',
        'Marca',
        'Precio',
        'Color',
        'Disponibilidad',
      ]) {
        expect(_inSheet(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('FLT-02 (vigente) Ordenar: lowest price first reorders',
        (tester) async {
      _view(tester);
      await _pumpCatalog(tester);
      expect(_catalogOrder(tester), _feedOrder());

      await _openCatalogPanel(tester);
      await _tap(tester, _inSheet('Precio: de menor a mayor'));
      await _applyCatalogPanel(tester);

      expect(_catalogOrder(tester), [
        _name(4), // 800
        _name(3), // 1,500
        _name(6), // 2,000
        _name(1), // 3,000
        _name(5), // 4,000
        _name(2), // 6,000
      ]);
    });

    testWidgets('FLT-02 (vigente) Marca filters the grid', (tester) async {
      _view(tester);
      await _pumpCatalog(tester);
      await _openCatalogPanel(tester);
      await _openSection(tester, 'brand');
      await _tap(tester, _inSheet('Coach'));

      expect(_applyLabel(tester), 'Ver 2 artículos');
      await _applyCatalogPanel(tester);

      expect(_catalogOrder(tester), [_name(2), _name(4)]);
    });

    testWidgets('FLT-02 (vigente) Precio band filters the grid',
        (tester) async {
      _view(tester);
      await _pumpCatalog(tester);
      await _openCatalogPanel(tester);
      await _openSection(tester, 'price');
      await _tap(tester, _inSheet('Menos de \$1,000 MXN'));

      expect(_applyLabel(tester), 'Ver 1 artículo');
      await _applyCatalogPanel(tester);

      expect(_catalogOrder(tester), [_name(4)]);
    });

    testWidgets('FLT-02 (vigente) Color filters the grid', (tester) async {
      _view(tester);
      await _pumpCatalog(tester);
      await _openCatalogPanel(tester);
      await _openSection(tester, 'color');
      await _tap(tester, _inSheet('Negro'));

      expect(_applyLabel(tester), 'Ver 3 artículos');
      await _applyCatalogPanel(tester);

      expect(_catalogOrder(tester), [_name(1), _name(4), _name(6)]);
    });

    testWidgets('FLT-02 (vigente) Disponibilidad hides the sold-out piece',
        (tester) async {
      _view(tester);
      await _pumpCatalog(tester);
      await _openCatalogPanel(tester);
      await _openSection(tester, 'availability');
      await _tap(tester, _inSheet('En existencia'));

      expect(_applyLabel(tester), 'Ver 5 artículos');
      await _applyCatalogPanel(tester);

      expect(_catalogOrder(tester), [
        _name(1),
        _name(2),
        _name(3),
        _name(4),
        _name(6),
      ]);
    });

    testWidgets('FLT-02 (vigente) Cerrar keeps the filters already applied',
        (tester) async {
      _view(tester);
      await _pumpCatalog(tester);
      await _openCatalogPanel(tester);
      await _openSection(tester, 'brand');
      await _tap(tester, _inSheet('Guess'));
      await _applyCatalogPanel(tester);
      final applied = _catalogOrder(tester);
      expect(applied, [_name(1), _name(3), _name(6)]);
      _expectCatalogBadge(1);

      await _openCatalogPanel(tester);
      await _openSection(tester, 'color');
      await _tap(tester, _inSheet('Negro'));
      await _tap(tester, find.byKey(const Key('catalog-filter-close')));

      expect(_sheet, findsNothing);
      expect(_catalogOrder(tester), applied);
      _expectCatalogBadge(1);
    });

    testWidgets('FLT-02 (vigente) Limpiar leaves an empty draft',
        (tester) async {
      _view(tester);
      await _pumpCatalog(tester);
      await _openCatalogPanel(tester);
      await _openSection(tester, 'brand');
      await _tap(tester, _inSheet('Guess'));
      await _tap(tester, _inSheet('Precio: de menor a mayor'));
      await _applyCatalogPanel(tester);
      expect(_catalogOrder(tester), [_name(3), _name(6), _name(1)]);

      await _openCatalogPanel(tester);
      await _openSection(tester, 'brand');
      expect(
        find.descendant(of: _sheet, matching: find.byIcon(Icons.check_rounded)),
        findsOneWidget,
        reason: 'Guess is selected before clearing',
      );

      await _tap(tester, find.byKey(const Key('catalog-filter-clear')));
      expect(
        find.descendant(of: _sheet, matching: find.byIcon(Icons.check_rounded)),
        findsNothing,
      );
      expect(_applyLabel(tester), 'Ver 6 artículos');

      await _applyCatalogPanel(tester);
      expect(_catalogOrder(tester), _feedOrder());
      _expectCatalogBadge(null);
    });
  });

  group('FLT-03 the badge counts filters, never the ordering', () {
    testWidgets('FLT-03 (vigente) only an order: no badge', (tester) async {
      _view(tester);
      await _pumpCatalog(tester);
      await _openCatalogPanel(tester);
      await _tap(tester, _inSheet('Precio: de mayor a menor'));
      await _applyCatalogPanel(tester);

      expect(_catalogOrder(tester).first, _name(2));
      _expectCatalogBadge(null);
    });

    testWidgets('FLT-03 (vigente) brand + color count as 2', (tester) async {
      _view(tester);
      await _pumpCatalog(tester);
      await _openCatalogPanel(tester);
      await _openSection(tester, 'brand');
      await _tap(tester, _inSheet('Guess'));
      await _openSection(tester, 'color');
      await _tap(tester, _inSheet('Negro'));
      await _applyCatalogPanel(tester);

      expect(_catalogOrder(tester), [_name(1), _name(6)]);
      _expectCatalogBadge(2);
    });

    testWidgets(
        'FLT-03 (vigente) no matches: "Sin resultados" and Limpiar filtros '
        'restores everything', (tester) async {
      _view(tester);
      await _pumpCatalog(tester);
      await _openCatalogPanel(tester);
      await _openSection(tester, 'brand');
      await _tap(tester, _inSheet('Michael Kors'));
      await _openSection(tester, 'color');
      await _tap(tester, _inSheet('Negro'));
      await _applyCatalogPanel(tester);

      expect(find.text('Sin resultados'), findsOneWidget);
      expect(find.byType(MonettaProductTile), findsNothing);
      _expectCatalogBadge(2);

      await _tap(tester, find.text('Limpiar filtros'));

      expect(find.text('Sin resultados'), findsNothing);
      expect(_catalogOrder(tester), _feedOrder());
      _expectCatalogBadge(null);
    });
  });

  group('FLT-01c collections have no duplicated pills', () {
    testWidgets('FLT-01c no sort chip, silhouette pills or chip rail',
        (tester) async {
      _view(tester, height: 844);
      final store = await _loadedStore();
      addTearDown(store.dispose);
      await _pumpCollection(tester, store);

      expect(find.byKey(const Key('collection-sort-chip')), findsNothing);
      expect(find.byWidgetPredicate(_isSilhouettePill), findsNothing);
      expect(find.byType(MonettaChipRail), findsNothing);
      expect(find.byType(MonettaCapsuleChip), findsNothing);
      // The single entry stays.
      expect(find.byKey(const Key('collection-filter-button')), findsOneWidget);
    });

    testWidgets(
        'FLT-01c with no brand link, no active filter and no owner count '
        'there is no empty band under the banner', (tester) async {
      _view(tester, height: 844);
      final store = await _loadedStore();
      addTearDown(store.dispose);
      await _pumpCollection(tester, store);

      expect(find.byKey(const Key('collection-open-brand')), findsNothing);
      expect(find.byKey(const Key('collection-clear-inline')), findsNothing);
      final banner = tester.getRect(find.byType(AppBar));
      final firstCard = tester.getRect(find.byType(ProductCard).first);
      expect(firstCard.top - banner.bottom, inInclusiveRange(8, 16));
    });
  });

  group('FLT-02c collection filtering lives in the panel', () {
    testWidgets(
        'FLT-02c (vigente) a silhouette from the panel counts as 1 and '
        'Cancelar keeps what was applied', (tester) async {
      _view(tester);
      final store = await _loadedStore();
      addTearDown(store.dispose);
      await _pumpCollection(tester, store);
      final unfiltered = _cardIds(tester);

      await _openCollectionPanel(tester);
      await _tap(tester, find.byKey(const Key('collection-filter-type')));
      final rows = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>)
                .value
                .startsWith('collection-filter-silhouette-'),
      );
      expect(rows, findsWidgets);
      final slug = (tester.widget(rows.first).key! as ValueKey<String>)
          .value
          .replaceFirst('collection-filter-silhouette-', '');
      final expected = {
        for (final p in store.products)
          if (store.facetsFor(p.id)?.category?.value == 'bolsa' &&
              store.facetsFor(p.id)?.silhouette?.value == slug)
            p.id,
      };
      expect(expected, isNotEmpty);
      expect(unfiltered.where((id) => !expected.contains(id)), isNotEmpty);

      await _tap(tester, rows.first);
      await _applyCollectionPanel(tester);

      final filtered = _cardIds(tester);
      expect(filtered, isNotEmpty);
      expect(filtered.every(expected.contains), isTrue);
      _expectCollectionBadge(1);

      // A pending change in the panel is dropped by Cancelar.
      await _openCollectionPanel(tester);
      await _tap(
        tester,
        find.byKey(const Key('collection-filter-availability')),
      );
      await _tap(tester, find.byKey(const Key('collection-filter-stock')));
      await _tap(tester, find.byKey(const Key('collection-filter-cancel')));

      expect(find.byKey(const Key('collection-filter-apply')), findsNothing);
      expect(_cardIds(tester), filtered);
      _expectCollectionBadge(1);
    });

    testWidgets('FLT-02c (vigente) the order is not counted by the badge',
        (tester) async {
      _view(tester);
      final store = await _loadedStore();
      addTearDown(store.dispose);
      await _pumpCollection(tester, store);

      await _openCollectionPanel(tester);
      await _tap(
        tester,
        find.byKey(const Key('collection-filter-sort-priceAsc')),
      );
      await _applyCollectionPanel(tester);

      _expectCollectionBadge(null);
      final prices = tester
          .widgetList<ProductCard>(find.byType(ProductCard))
          .map((card) => card.product.price)
          .toList();
      expect(prices.length, greaterThan(1));
      expect(prices, [...prices]..sort(), reason: 'cheapest first');
      expect(prices.first, lessThan(prices.last));
    });

    testWidgets(
        'FLT-02c (vigente) no matches: "Sin resultados" and Limpiar filtros '
        'restore the collection', (tester) async {
      _view(tester);
      final store = await _loadedStore();
      addTearDown(store.dispose);

      final bags = store.products
          .where((p) => store.facetsFor(p.id)?.category?.value == 'bolsa')
          .toList();
      final brands = {
        for (final p in bags)
          if (store.facetsFor(p.id)?.brand?.value case final v?) v,
      };
      final silhouettes = {
        for (final p in bags)
          if (store.facetsFor(p.id)?.silhouette?.value case final v?) v,
      };
      final existing = {
        for (final p in bags)
          (
            store.facetsFor(p.id)?.brand?.value,
            store.facetsFor(p.id)?.silhouette?.value,
          ),
      };
      (String, String)? emptyPair;
      for (final b in brands) {
        for (final s in silhouettes) {
          if (!existing.contains((b, s))) emptyPair ??= (b, s);
        }
      }
      expect(
        emptyPair,
        isNotNull,
        reason: 'the asset catalog needs a brand/silhouette pair with no bags',
      );

      await _pumpCollection(tester, store);
      final unfiltered = _cardIds(tester);

      await _openCollectionPanel(tester);
      await _tap(tester, find.byKey(const Key('collection-filter-brand')));
      await _tap(
        tester,
        find.byKey(Key('collection-filter-brand-${emptyPair!.$1}')),
      );
      await _tap(tester, find.byKey(const Key('collection-filter-type')));
      await _tap(
        tester,
        find.byKey(Key('collection-filter-silhouette-${emptyPair.$2}')),
      );
      await _applyCollectionPanel(tester);

      expect(find.text('Sin resultados'), findsOneWidget);
      expect(find.byType(ProductCard), findsNothing);
      _expectCollectionBadge(2);

      await _tap(tester, find.text('Limpiar filtros'));

      expect(find.text('Sin resultados'), findsNothing);
      expect(_cardIds(tester), unfiltered);
      _expectCollectionBadge(null);
    });
  });
}
