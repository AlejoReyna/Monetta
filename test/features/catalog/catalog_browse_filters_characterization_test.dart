/// CHAR-13: which pieces the full-catalog browser shows, and in what order,
/// for each filter and each sort, reached only through the UI.
///
/// Characterization of `_filterCatalog` in `catalog_browse_screen.dart`.
/// RF-40 moves that logic into a pure module; the visible result must not
/// change. The assertions read the ids of the grid tiles (the screen keys each
/// tile `monetta:<product id>`), so they name no private type of the screen.
///
/// The text query of `_filterCatalog` cannot be reached from the UI: the
/// screen always passes `query: ''` and has no text field (search is a button
/// that opens the search screen). The last test pins exactly that.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/theme.dart';

import '../../support/catalog_browse_fixtures.dart';

String _gid(int i) => 'gid://shopify/Product/$i';

/// Six pieces, in catalog (featured) order 1..6. Every price is distinct so
/// the price orders have no ties.
///
/// | id | category | brand        | price | stock | updated | colour |
/// |----|----------|--------------|-------|-------|---------|--------|
/// | 1  | bolsa    | Guess        |   500 | yes   | Aug 1   | -      |
/// | 2  | cartera  | Coach        |  1500 | yes   | Aug 5   | Negro  |
/// | 3  | bolsa    | Coach        |  3000 | no    | Aug 3   | Rojo   |
/// | 4  | reloj    | Michael Kors |  7000 | yes   | Aug 9   | -      |
/// | 5  | bolsa    | Guess        |  2200 | no    | Aug 7   | Negro  |
/// | 6  | (none)   | Guess vendor |  2600 | yes   | Aug 2   | -      |
List<BrowseEntry> _catalog() => [
      browseEntry(
        1,
        title: 'Monetta Alfa',
        category: 'bolsa',
        brand: 'guess',
        price: 500,
        updatedAt: DateTime.utc(2026, 8, 1),
      ),
      browseEntry(
        2,
        title: 'Monetta Bravo Negro',
        category: 'cartera',
        brand: 'coach',
        price: 1500,
        updatedAt: DateTime.utc(2026, 8, 5),
      ),
      browseEntry(
        3,
        title: 'Monetta Charlie Rojo',
        category: 'bolsa',
        brand: 'coach',
        price: 3000,
        inStock: false,
        updatedAt: DateTime.utc(2026, 8, 3),
      ),
      browseEntry(
        4,
        title: 'Monetta Delta',
        category: 'reloj',
        brand: 'michael_kors',
        price: 7000,
        updatedAt: DateTime.utc(2026, 8, 9),
      ),
      browseEntry(
        5,
        title: 'Monetta Echo Negro',
        category: 'bolsa',
        brand: 'guess',
        price: 2200,
        inStock: false,
        updatedAt: DateTime.utc(2026, 8, 7),
      ),
      browseEntry(
        6,
        title: 'Monetta Foxtrot',
        price: 2600,
        updatedAt: DateTime.utc(2026, 8, 2),
      ),
    ];

List<String> _ids(List<int> numbers) => [for (final n in numbers) _gid(n)];

/// The ids of the tiles on screen, in grid order.
List<String> _shownIds(WidgetTester tester) => [
      for (final widget in tester.widgetList(
        find.byWidgetPredicate((w) {
          final key = w.key;
          return key is ValueKey<String> && key.value.startsWith('monetta:');
        }),
      ))
        (widget.key! as ValueKey<String>).value.substring('monetta:'.length),
    ];

Future<void> _pumpBrowser(
  WidgetTester tester, [
  List<BrowseEntry>? entries,
]) async {
  addTearDown(tester.view.reset);
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(800, 2400);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: browseScreen(entries ?? _catalog()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder target) async {
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// [text] inside the open filter sheet (the grid below also prints brands).
Finder _inSheet(String text) => find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text(text),
    );

Future<void> _openSheet(WidgetTester tester) =>
    _tapVisible(tester, find.byKey(const Key('catalog-filter-button')));

Future<void> _expandSection(WidgetTester tester, String section) =>
    _tapVisible(tester, find.byKey(Key('catalog-filter-$section')));

Future<void> _apply(WidgetTester tester) =>
    _tapVisible(tester, find.byKey(const Key('catalog-filter-apply')));

/// Opens the sheet, optionally expands [section], taps each [options] label and
/// applies. [section] `null` means the sort section, which opens expanded.
Future<void> _applyOptions(
  WidgetTester tester, {
  String? section,
  required List<String> options,
}) async {
  await _openSheet(tester);
  if (section != null) await _expandSection(tester, section);
  for (final option in options) {
    await _tapVisible(tester, _inSheet(option));
  }
  await _apply(tester);
}

Future<void> _applyCategories(
  WidgetTester tester,
  List<String> categories,
) async {
  await _openSheet(tester);
  await _tapVisible(
    tester,
    find.byKey(const Key('catalog-filter-section-category')),
  );
  for (final category in categories) {
    await _tapVisible(
      tester,
      find.byKey(Key('catalog-filter-category-$category')),
    );
  }
  await _apply(tester);
}

void main() {
  group('CHAR-13 unfiltered', () {
    testWidgets('CHAR-13 the default view shows every piece in catalog order', (
      tester,
    ) async {
      await _pumpBrowser(tester);
      expect(_shownIds(tester), _ids([1, 2, 3, 4, 5, 6]));
      expect(find.byKey(const Key('catalog-filter-count')), findsNothing);
    });

    testWidgets('CHAR-13 the default sort is "Destacados"', (tester) async {
      await _pumpBrowser(tester);
      await _openSheet(tester);
      // The sort section opens expanded and lists the four orders.
      for (final label in const [
        'Destacados',
        'Más recientes',
        'Precio: de menor a mayor',
        'Precio: de mayor a menor',
      ]) {
        expect(_inSheet(label), findsOneWidget, reason: label);
      }
    });
  });

  group('CHAR-13 sort', () {
    testWidgets('CHAR-13 "Destacados" keeps the catalog order', (tester) async {
      await _pumpBrowser(tester);
      await _applyOptions(tester, options: ['Más recientes']);
      expect(_shownIds(tester), isNot(_ids([1, 2, 3, 4, 5, 6])));

      await _applyOptions(tester, options: ['Destacados']);
      expect(_shownIds(tester), _ids([1, 2, 3, 4, 5, 6]));
    });

    testWidgets('CHAR-13 "Más recientes" orders by updatedAt, newest first', (
      tester,
    ) async {
      await _pumpBrowser(tester);
      await _applyOptions(tester, options: ['Más recientes']);
      expect(_shownIds(tester), _ids([4, 5, 2, 3, 6, 1]));
    });

    testWidgets('CHAR-13 "Precio: de menor a mayor" orders ascending', (
      tester,
    ) async {
      await _pumpBrowser(tester);
      await _applyOptions(tester, options: ['Precio: de menor a mayor']);
      expect(_shownIds(tester), _ids([1, 2, 5, 6, 3, 4]));
    });

    testWidgets('CHAR-13 "Precio: de mayor a menor" orders descending', (
      tester,
    ) async {
      await _pumpBrowser(tester);
      await _applyOptions(tester, options: ['Precio: de mayor a menor']);
      expect(_shownIds(tester), _ids([4, 3, 6, 5, 2, 1]));
    });

    testWidgets('CHAR-13 a sort is applied on top of the filters', (
      tester,
    ) async {
      await _pumpBrowser(tester);
      await _applyCategories(tester, ['bolsa']);
      expect(_shownIds(tester), _ids([1, 3, 5]));

      await _applyOptions(tester, options: ['Precio: de mayor a menor']);
      expect(_shownIds(tester), _ids([3, 5, 1]));
    });
  });

  group('CHAR-13 filters', () {
    testWidgets('CHAR-13 a category keeps only that category', (tester) async {
      await _pumpBrowser(tester);
      await _applyCategories(tester, ['bolsa']);
      expect(_shownIds(tester), _ids([1, 3, 5]));
    });

    testWidgets('CHAR-13 a piece without a category facet is "otros"', (
      tester,
    ) async {
      await _pumpBrowser(tester);
      await _applyCategories(tester, ['otros']);
      expect(_shownIds(tester), _ids([6]));
    });

    testWidgets('CHAR-13 several categories show their union', (tester) async {
      await _pumpBrowser(tester);
      await _applyCategories(tester, ['bolsa', 'reloj']);
      expect(_shownIds(tester), _ids([1, 3, 4, 5]));
    });

    testWidgets('CHAR-13 a brand keeps only that brand', (tester) async {
      await _pumpBrowser(tester);
      await _applyOptions(tester, section: 'brand', options: ['Coach']);
      expect(_shownIds(tester), _ids([2, 3]));
    });

    testWidgets('CHAR-13 a piece without a brand facet uses its raw vendor', (
      tester,
    ) async {
      // Piece 6 has no facets and vendor "Guess": it is a "Guess" piece.
      await _pumpBrowser(tester);
      await _applyOptions(tester, section: 'brand', options: ['Guess']);
      expect(_shownIds(tester), _ids([1, 5, 6]));
    });

    testWidgets('CHAR-13 a brand slug is shown humanized and filters by it', (
      tester,
    ) async {
      await _pumpBrowser(tester);
      await _applyOptions(tester, section: 'brand', options: ['Michael Kors']);
      expect(_shownIds(tester), _ids([4]));
    });

    testWidgets('CHAR-13 a price band keeps only prices inside it', (
      tester,
    ) async {
      await _pumpBrowser(tester);
      await _applyOptions(
        tester,
        section: 'price',
        options: ['\$1,000 – \$2,499 MXN'],
      );
      expect(_shownIds(tester), _ids([2, 5]));
    });

    testWidgets('CHAR-13 price bands are open at the top and closed below', (
      tester,
    ) async {
      await _pumpBrowser(tester);
      await _applyOptions(
        tester,
        section: 'price',
        options: ['Menos de \$1,000 MXN', '\$5,000 MXN o más'],
      );
      expect(_shownIds(tester), _ids([1, 4]));
    });

    testWidgets(
        'CHAR-13 a price exactly on a band edge falls in the upper band',
        (tester) async {
      final entries = [
        browseEntry(1, title: 'Monetta Alfa', price: 999),
        browseEntry(2, title: 'Monetta Bravo', price: 1000),
        browseEntry(3, title: 'Monetta Charlie', price: 2499),
        browseEntry(4, title: 'Monetta Delta', price: 2500),
      ];
      await _pumpBrowser(tester, entries);
      await _applyOptions(
        tester,
        section: 'price',
        options: ['\$1,000 – \$2,499 MXN'],
      );
      expect(_shownIds(tester), _ids([2, 3]));
    });

    testWidgets('CHAR-13 a colour is read from the title', (tester) async {
      await _pumpBrowser(tester);
      await _applyOptions(tester, section: 'color', options: ['Negro']);
      expect(_shownIds(tester), _ids([2, 5]));
    });

    testWidgets('CHAR-13 several colours show pieces having any of them', (
      tester,
    ) async {
      await _pumpBrowser(tester);
      await _applyOptions(
        tester,
        section: 'color',
        options: ['Negro', 'Rojo'],
      );
      expect(_shownIds(tester), _ids([2, 3, 5]));
    });

    testWidgets('CHAR-13 "En existencia" hides sold-out pieces', (
      tester,
    ) async {
      await _pumpBrowser(tester);
      await _applyOptions(
        tester,
        section: 'availability',
        options: ['En existencia'],
      );
      expect(_shownIds(tester), _ids([1, 2, 4, 6]));
    });

    testWidgets('CHAR-13 a bag type is read from the category and the title', (
      tester,
    ) async {
      await _pumpBrowser(tester);
      await _applyOptions(tester, section: 'type', options: ['Cartera']);
      expect(_shownIds(tester), _ids([2]));
    });

    testWidgets('CHAR-13 different filters combine as an intersection', (
      tester,
    ) async {
      await _pumpBrowser(tester);
      await _applyCategories(tester, ['bolsa']);
      await _applyOptions(
        tester,
        section: 'availability',
        options: ['En existencia'],
      );
      expect(_shownIds(tester), _ids([1]));
      // Two active filters: the badge on the filter button says so.
      expect(
        find.descendant(
          of: find.byKey(const Key('catalog-filter-count')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('CHAR-13 filters that match nothing show the empty state', (
      tester,
    ) async {
      await _pumpBrowser(tester);
      await _applyCategories(tester, ['reloj']);
      await _applyOptions(tester, section: 'brand', options: ['Coach']);
      expect(_shownIds(tester), isEmpty);
      expect(find.text('Sin resultados'), findsOneWidget);

      await _tapVisible(tester, find.text('Limpiar filtros'));
      expect(_shownIds(tester), _ids([1, 2, 3, 4, 5, 6]));
    });

    testWidgets('CHAR-13 closing the sheet keeps the filters already applied', (
      tester,
    ) async {
      await _pumpBrowser(tester);
      await _applyCategories(tester, ['bolsa']);
      expect(_shownIds(tester), _ids([1, 3, 5]));

      await _openSheet(tester);
      await _tapVisible(
        tester,
        find.byKey(const Key('catalog-filter-section-category')),
      );
      await _tapVisible(
        tester,
        find.byKey(const Key('catalog-filter-category-reloj')),
      );
      await _tapVisible(tester, find.byKey(const Key('catalog-filter-close')));
      expect(find.byKey(const Key('catalog-filter-apply')), findsNothing);
      expect(_shownIds(tester), _ids([1, 3, 5]));
    });

    testWidgets('CHAR-13 "Limpiar" in the sheet resets every filter', (
      tester,
    ) async {
      await _pumpBrowser(tester);
      await _applyCategories(tester, ['bolsa']);
      await _openSheet(tester);
      await _tapVisible(tester, find.byKey(const Key('catalog-filter-clear')));
      await _apply(tester);
      expect(_shownIds(tester), _ids([1, 2, 3, 4, 5, 6]));
      expect(find.byKey(const Key('catalog-filter-count')), findsNothing);
    });
  });

  group('CHAR-13 query', () {
    testWidgets(
      'CHAR-13 (vigente) the browser has no text query of its own; search is '
      'a button',
      (tester) async {
        // `_filterCatalog` takes a `query` (title + brand + "Monetta" +
        // category, lower-cased and WITHOUT accent folding), but the screen
        // always passes ''. No input in the browser can feed it today.
        await _pumpBrowser(tester);
        expect(find.byType(TextField), findsNothing);
        expect(find.byType(TextFormField), findsNothing);
        expect(find.byType(EditableText), findsNothing);
        expect(find.byKey(const Key('catalog-search-button')), findsOneWidget);
        expect(_shownIds(tester), _ids([1, 2, 3, 4, 5, 6]));
      },
    );
  });
}
