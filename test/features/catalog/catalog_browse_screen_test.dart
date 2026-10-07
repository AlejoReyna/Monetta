import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/domain/catalog_item.dart';
import 'package:monetta_app/features/catalog/catalog_browse_screen.dart';
import 'package:monetta_app/features/product/external_product_screen.dart';

CatalogItem _monetta(
  int i, {
  String? title,
  String? category,
  CatalogVertical vertical = CatalogVertical.general,
}) =>
    CatalogItem(
      sourceScopedId: 'monetta:$i',
      source: CatalogSourceType.monettaShopify,
      merchant: 'Monetta',
      title: title ?? 'Monetta Item $i',
      brand: 'Guess',
      category: category,
      imageUrl: null,
      price: const Money(amount: 1999, currency: Currency.mxn),
      availability: CatalogAvailability.inStock,
      detailUrl: 'https://monetta.mx/products/item-$i',
      marketRestriction: MarketRestriction.mexico,
      lastObservedAt: DateTime.utc(2026, 8, 10),
      purchaseMode: PurchaseMode.monettaCheckout,
      shopifyProductId: '$i',
      vertical: vertical,
    );

CatalogItem _external(
  int i, {
  String? title,
  String brand = 'Coach',
  double price = 300,
}) =>
    CatalogItem(
      sourceScopedId: 'coach_us:$i',
      source: CatalogSourceType.coachUs,
      merchant: 'Coach',
      title: title ?? 'External Item $i',
      brand: brand,
      category: 'Handbags',
      imageUrl: null,
      price: Money(amount: price, currency: Currency.usd),
      availability: CatalogAvailability.inStock,
      detailUrl: 'https://www.coach.com/products/item-$i/C$i.html',
      marketRestriction: MarketRestriction.unitedStates,
      lastObservedAt: DateTime.utc(2026, 8, 10),
      purchaseMode: PurchaseMode.externalResearch,
    );

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: child,
    ),
  );
}

/// Replaces whatever is on screen so a test can start from a pristine
/// [CatalogBrowseScreen] state (no applied filters).
Future<void> _pumpFresh(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await _pump(tester, child);
}

void _useTallPhone(WidgetTester tester) {
  addTearDown(() => tester.view.resetPhysicalSize());
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
}

Future<void> _tapVisible(WidgetTester tester, Finder target) async {
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _openFilterPanel(WidgetTester tester) =>
    _tapVisible(tester, find.byKey(const Key('catalog-filter-button')));

/// The category section is collapsed when the panel opens, like every section
/// except the one a quick-filter chip asked for.
Future<void> _expandCategorySection(WidgetTester tester) => _tapVisible(
      tester,
      find.byKey(const Key('catalog-filter-section-category')),
    );

Finder _categoryOption(String category) =>
    find.byKey(Key('catalog-filter-category-$category'));

Future<void> _toggleCategories(
  WidgetTester tester,
  List<String> categories,
) async {
  for (final category in categories) {
    await _tapVisible(tester, _categoryOption(category));
  }
}

Future<void> _applyFilters(WidgetTester tester) =>
    _tapVisible(tester, find.byKey(const Key('catalog-filter-apply')));

/// Opens the panel, marks [categories] and applies.
Future<void> _applyCategories(
  WidgetTester tester,
  List<String> categories,
) async {
  await _openFilterPanel(tester);
  await _expandCategorySection(tester);
  await _toggleCategories(tester, categories);
  await _applyFilters(tester);
}

Finder _checkMarkIn(Finder option) =>
    find.descendant(of: option, matching: find.byIcon(Icons.check_rounded));

/// The number on the filter button's badge, or `null` when it is hidden.
void _expectFilterBadge(int? count) {
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

void _expectGridShows(Set<String> shown, Iterable<String> all) {
  for (final title in all) {
    expect(
      find.text(title),
      shown.contains(title) ? findsOneWidget : findsNothing,
      reason: '"$title" should ${shown.contains(title) ? '' : 'not '}be shown',
    );
  }
}

const _perfumeTitle = 'Monetta Perfume 1';
const _bagTitle = 'Monetta Item 2';
const _externalBagTitle = 'External Item 3';
const _generalTitle = 'Monetta General 4';
const _walletTitle = 'Monetta Wallet 5';
const _watchTitle = 'Monetta Watch 6';
const _mixedTitles = [
  _perfumeTitle,
  _bagTitle,
  _externalBagTitle,
  _generalTitle,
  _walletTitle,
  _watchTitle,
];

CatalogItem _uncategorized(
  String id, {
  required String title,
  required CatalogVertical vertical,
  CatalogSourceType source = CatalogSourceType.monettaShopify,
}) {
  final isExternal = source != CatalogSourceType.monettaShopify;
  return CatalogItem(
    sourceScopedId: id,
    source: source,
    merchant: isExternal ? 'Coach' : 'Monetta',
    title: title,
    brand: isExternal ? 'Coach' : 'Guess',
    category: null,
    imageUrl: null,
    price: const Money(amount: 1999, currency: Currency.mxn),
    availability: CatalogAvailability.inStock,
    detailUrl: 'https://monetta.mx/products/$id',
    marketRestriction: MarketRestriction.mexico,
    lastObservedAt: DateTime.utc(2026, 8, 10),
    purchaseMode: isExternal
        ? PurchaseMode.externalResearch
        : PurchaseMode.monettaCheckout,
    shopifyProductId: isExternal ? null : id,
    vertical: vertical,
  );
}

/// One product per category the screen can derive: perfume (by vertical),
/// bolsa (Monetta and external, by vertical), otros (no vertical, no category),
/// cartera and reloj (by the category field).
List<CatalogItem> _mixedCatalog() => [
      _uncategorized(
        'perfume:1',
        title: _perfumeTitle,
        vertical: CatalogVertical.perfumes,
      ),
      _uncategorized(
        'bag:2',
        title: _bagTitle,
        vertical: CatalogVertical.bagsWallets,
      ),
      _uncategorized(
        'ext:3',
        title: _externalBagTitle,
        vertical: CatalogVertical.bagsWallets,
        source: CatalogSourceType.coachUs,
      ),
      _uncategorized(
        'general:4',
        title: _generalTitle,
        vertical: CatalogVertical.general,
      ),
      _monetta(
        5,
        title: _walletTitle,
        category: 'cartera',
        vertical: CatalogVertical.bagsWallets,
      ),
      _monetta(6, title: _watchTitle, category: 'reloj'),
    ];

void main() {
  testWidgets('shows an empty state for zero items', (tester) async {
    await _pump(tester, const CatalogBrowseScreen(items: []));
    expect(find.text('Sin resultados'), findsOneWidget);
  });

  testWidgets('shows the header and no category rail or pills', (tester) async {
    await _pump(
      tester,
      CatalogBrowseScreen(
        items: [
          _external(1),
          _monetta(1, category: 'cartera'),
          _monetta(2, category: 'reloj'),
          _monetta(3, category: 'perfume'),
        ],
      ),
    );

    expect(find.text('Productos'), findsOneWidget);
    expect(find.byKey(const Key('catalog-search-button')), findsOneWidget);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.byKey(const Key('catalog-filter-button')), findsOneWidget);

    // The category bar is gone: neither its container nor any pill remains.
    expect(find.byKey(const Key('catalog-category-rail')), findsNothing);
    for (final pill in ['collection', 'cartera', 'reloj', 'perfume', 'bolsa']) {
      expect(find.byKey(Key('catalog-category-$pill')), findsNothing);
      expect(find.byKey(Key('catalog-category-$pill-motion')), findsNothing);
    }
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('Colección'), findsNothing);
    for (final label in ['Bolsas', 'Carteras', 'Relojes', 'Perfumes']) {
      expect(find.text(label), findsNothing, reason: label);
    }
    expect(find.text('Selección Monetta'), findsNothing);
    expect(find.textContaining('artículos'), findsNothing);
    expect(find.text('Destacados'), findsNothing);
  });

  testWidgets(
      'the quick filter rail still offers Marca, Precio, Color, Ordenar',
      (tester) async {
    await _pump(
      tester,
      CatalogBrowseScreen(
        items: [
          _monetta(1, title: 'Cartera Negra', category: 'cartera'),
          _external(1),
        ],
      ),
    );

    for (final entry in {
      'catalog-quick-brand': 'Marca',
      'catalog-quick-price': 'Precio',
      'catalog-quick-color': 'Color',
      'catalog-quick-sort': 'Ordenar',
    }.entries) {
      final chip = find.byKey(Key(entry.key));
      expect(chip, findsOneWidget, reason: entry.key);
      expect(
        find.descendant(of: chip, matching: find.text(entry.value)),
        findsOneWidget,
        reason: entry.key,
      );
    }
  });

  testWidgets(
      'the filter panel offers the present categories in canonical order',
      (tester) async {
    _useTallPhone(tester);
    // Deliberately listed out of canonical order; the external bag is a
    // "Handbags" listing so the "Tipo de bolsa" section exists too.
    await _pump(
      tester,
      CatalogBrowseScreen(
        items: [
          _monetta(1, category: 'perfume'),
          _monetta(2, category: 'reloj'),
          _monetta(3, category: 'cartera'),
          _external(1),
          _monetta(4),
        ],
      ),
    );

    await _openFilterPanel(tester);
    final header = find.byKey(const Key('catalog-filter-section-category'));
    expect(header, findsOneWidget);
    expect(
      find.descendant(of: header, matching: find.text('Categoría')),
      findsOneWidget,
    );
    await _expandCategorySection(tester);

    const expected = {
      'bolsa': 'Bolsas',
      'cartera': 'Carteras',
      'reloj': 'Relojes',
      'perfume': 'Perfumes',
      'otros': 'Otros',
    };
    var previousTop = -1.0;
    for (final entry in expected.entries) {
      final option = _categoryOption(entry.key);
      expect(option, findsOneWidget, reason: entry.key);
      expect(
        find.descendant(of: option, matching: find.text(entry.value)),
        findsOneWidget,
        reason: entry.key,
      );
      final top = tester.getTopLeft(option).dy;
      expect(top, greaterThan(previousTop), reason: '${entry.key} order');
      previousTop = top;
    }

    // Only categories that exist in the products; no "Colección" option.
    for (final absent in ['monedero', 'tarjetero', 'collection', 'monetta']) {
      expect(_categoryOption(absent), findsNothing, reason: absent);
    }
    expect(find.text('Colección'), findsNothing);

    // "Categoría" is the first section after "Ordenar por".
    final sortTop =
        tester.getTopLeft(find.byKey(const Key('catalog-filter-sort'))).dy;
    final categoryTop = tester.getTopLeft(header).dy;
    expect(categoryTop, greaterThan(sortTop));
    for (final later in ['type', 'brand', 'price', 'availability']) {
      expect(
        tester.getTopLeft(find.byKey(Key('catalog-filter-$later'))).dy,
        greaterThan(categoryTop),
        reason: 'catalog-filter-$later comes after Categoría',
      );
    }
  });

  testWidgets('category options show no article counts', (tester) async {
    _useTallPhone(tester);
    final cafe = _external(1, title: 'Bolsa Tote Café');
    final negra = _external(2, title: 'Crossbody Negra');
    final monettaBag = _uncategorized(
      'monetta:3',
      title: 'Bolsa Monetta Café',
      vertical: CatalogVertical.bagsWallets,
    );
    final monettaPerfume = _uncategorized(
      'monetta:4',
      title: 'Perfume Monetta',
      vertical: CatalogVertical.perfumes,
    );
    await _pump(
      tester,
      CatalogBrowseScreen(items: [cafe, negra, monettaBag, monettaPerfume]),
    );

    Future<void> expectBareLabels() async {
      await _openFilterPanel(tester);
      await _expandCategorySection(tester);
      for (final entry in {'bolsa': 'Bolsas', 'perfume': 'Perfumes'}.entries) {
        final option = _categoryOption(entry.key);
        expect(option, findsOneWidget, reason: entry.key);
        final labels = find.descendant(
          of: option,
          matching: find.byType(Text),
        );
        expect(labels, findsOneWidget, reason: '${entry.key} has only a label');
        expect(tester.widget<Text>(labels).data, entry.value);
      }
    }

    await expectBareLabels();
    await _tapVisible(tester, find.byKey(const Key('catalog-filter-close')));
    expect(find.text(' 4'), findsNothing);

    // With another filter applied the options keep showing bare labels.
    await _openFilterPanel(tester);
    await _tapVisible(tester, find.byKey(const Key('catalog-filter-color')));
    await _tapVisible(tester, find.text('Café'));
    await _applyFilters(tester);
    expect(find.text(' 2'), findsNothing);

    await expectBareLabels();
    expect(find.text('Perfumes'), findsOneWidget);
  });

  testWidgets('category content uses the smooth section transition', (
    tester,
  ) async {
    _useTallPhone(tester);
    await _pump(
      tester,
      CatalogBrowseScreen(
        items: [_monetta(1, category: 'cartera'), _external(1)],
      ),
    );

    final switcherFinder = find.byKey(const Key('catalog-section-transition'));
    expect(switcherFinder, findsOneWidget);
    final switcher = tester.widget<AnimatedSwitcher>(switcherFinder);
    const current = SizedBox(key: ValueKey('current'));
    const previous = SizedBox(key: ValueKey('previous'));
    expect(
      switcher.layoutBuilder(current, const [previous]),
      same(current),
      reason: 'the outgoing product grid must not remain in the layout',
    );
    final keyBefore = switcher.child?.key;
    expect(keyBefore, isNotNull);

    await _applyCategories(tester, ['cartera']);

    final switcherAfter = tester.widget<AnimatedSwitcher>(switcherFinder);
    expect(
      switcherAfter.child?.key,
      isNot(keyBefore),
      reason: 'a new category must swap the grid through the transition',
    );
    expect(find.text('Monetta Item 1'), findsOneWidget);
    expect(find.text('Bolsa External Item 1'), findsNothing);

    // Changing the applied categories again swaps the grid again.
    final keyAfterFirst = switcherAfter.child?.key;
    await _applyCategories(tester, ['cartera', 'bolsa']);
    expect(
      tester.widget<AnimatedSwitcher>(switcherFinder).child?.key,
      isNot(keyAfterFirst),
    );
    expect(find.text('Bolsa External Item 1'), findsOneWidget);
  });

  testWidgets('humanizes canonical brand and product tokens', (tester) async {
    await _pump(
      tester,
      CatalogBrowseScreen(
        items: [_external(1, title: 'jet_set_bag', brand: 'michael_kors')],
      ),
    );

    expect(find.text('Michael Kors'), findsOneWidget);
    expect(find.text('Bolsa Jet Set'), findsOneWidget);
    expect(find.text('michael_kors'), findsNothing);
    expect(find.text('jet_set_bag'), findsNothing);
  });

  testWidgets(
      'uses a lazily-built CustomScrollView/SliverGrid so a large catalog never eagerly renders every tile',
      (tester) async {
    final items = [
      for (var i = 0; i < 500; i++) (i.isEven ? _monetta(i) : _external(i)),
    ];
    await _pump(tester, CatalogBrowseScreen(items: items));
    await tester.pump();

    // A top-level CustomScrollView (not a shrinkWrap-forced grid nested in
    // another scrollable) only builds what fits the viewport plus cache
    // extent — the opposite of eagerly materializing all 500 tiles.
    expect(find.byType(CustomScrollView), findsOneWidget);
    final builtTitles = find.textContaining('Item ').evaluate().length;
    expect(builtTitles, lessThan(100));
  });

  testWidgets('uses one uninterrupted photography grid for every source',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;

    final items = [_monetta(1), _monetta(2), _external(1), _external(2)];
    await _pump(tester, CatalogBrowseScreen(items: items));
    await tester.pump();

    expect(find.text('Selección Monetta'), findsNothing);
    expect(find.text('Edición internacional'), findsNothing);
    expect(find.text('Monetta Item 1'), findsOneWidget);
    expect(find.text('Bolsa External Item 1'), findsOneWidget);
    expect(find.text('extracted'), findsNWidgets(2));
  });

  testWidgets('keeps the same grid chrome when there are only external items',
      (tester) async {
    final items = [_external(1)];
    await _pump(tester, CatalogBrowseScreen(items: items));
    await tester.pump();

    expect(find.text('Selección Monetta'), findsNothing);
    expect(find.text('Edición internacional'), findsNothing);
    expect(find.text('Bolsa External Item 1'), findsOneWidget);
  });

  testWidgets('filters by the categories applied in the panel', (tester) async {
    _useTallPhone(tester);
    final catalog = _mixedCatalog();

    // Nothing marked means everything.
    await _pump(tester, CatalogBrowseScreen(items: catalog));
    _expectGridShows({..._mixedTitles}, _mixedTitles);
    _expectFilterBadge(null);

    const expectations = {
      'cartera': {_walletTitle},
      'bolsa': {_bagTitle, _externalBagTitle},
      'reloj': {_watchTitle},
      'perfume': {_perfumeTitle},
      'otros': {_generalTitle},
    };
    for (final entry in expectations.entries) {
      await _pumpFresh(tester, CatalogBrowseScreen(items: catalog));
      await _applyCategories(tester, [entry.key]);

      expect(find.byKey(const Key('catalog-filter-apply')), findsNothing);
      _expectGridShows(entry.value, _mixedTitles);
      _expectFilterBadge(1);
      expect(find.text('Selección Monetta'), findsNothing);
    }
  });

  testWidgets('several categories show the union of their products',
      (tester) async {
    _useTallPhone(tester);
    await _pump(tester, CatalogBrowseScreen(items: _mixedCatalog()));

    await _applyCategories(tester, ['cartera', 'reloj']);
    _expectGridShows({_walletTitle, _watchTitle}, _mixedTitles);
    _expectFilterBadge(2);

    // Reopening shows the applied categories as selected, and only them.
    await _openFilterPanel(tester);
    await _expandCategorySection(tester);
    for (final category in ['cartera', 'reloj']) {
      expect(_checkMarkIn(_categoryOption(category)), findsOneWidget);
    }
    for (final category in ['bolsa', 'perfume', 'otros']) {
      expect(_checkMarkIn(_categoryOption(category)), findsNothing);
    }

    // Unmarking one and marking another narrows the union accordingly.
    await _toggleCategories(tester, ['cartera', 'perfume']);
    await _applyFilters(tester);
    _expectGridShows({_watchTitle, _perfumeTitle}, _mixedTitles);
    _expectFilterBadge(2);
  });

  testWidgets('a category combines with the other filters by intersection',
      (tester) async {
    _useTallPhone(tester);
    await _pump(
      tester,
      CatalogBrowseScreen(
        items: [
          _monetta(1, title: 'Cartera Negra', category: 'cartera'),
          _monetta(2, title: 'Cartera Café', category: 'cartera'),
          _monetta(3, title: 'Reloj Negro', category: 'reloj'),
        ],
      ),
    );

    await _openFilterPanel(tester);
    await _expandCategorySection(tester);
    await _toggleCategories(tester, ['cartera']);
    await _tapVisible(tester, find.byKey(const Key('catalog-filter-color')));
    await _tapVisible(tester, find.text('Negro'));
    await _applyFilters(tester);

    expect(find.text('Cartera Negra'), findsOneWidget);
    expect(find.text('Cartera Café'), findsNothing);
    expect(find.text('Reloj Negro'), findsNothing);
    // One category plus one colour: each selection counts once.
    _expectFilterBadge(2);
  });

  testWidgets('the panel result count follows the draft category',
      (tester) async {
    _useTallPhone(tester);
    await _pump(
      tester,
      CatalogBrowseScreen(
        items: [
          _monetta(1, title: 'Cartera Uno', category: 'cartera'),
          _monetta(2, title: 'Cartera Dos', category: 'cartera'),
          _monetta(3, title: 'Reloj Tres', category: 'reloj'),
        ],
      ),
    );

    await _openFilterPanel(tester);
    await _expandCategorySection(tester);
    expect(find.text('Ver 3 artículos'), findsOneWidget);

    await _toggleCategories(tester, ['cartera']);
    expect(find.text('Ver 2 artículos'), findsOneWidget);

    await _toggleCategories(tester, ['reloj']);
    expect(find.text('Ver 3 artículos'), findsOneWidget);

    await _toggleCategories(tester, ['cartera']);
    expect(find.text('Ver 1 artículo'), findsOneWidget);

    // Dismissing without applying leaves the grid and the badge untouched.
    await _tapVisible(tester, find.byKey(const Key('catalog-filter-close')));
    expect(find.text('Cartera Uno'), findsOneWidget);
    expect(find.text('Cartera Dos'), findsOneWidget);
    expect(find.text('Reloj Tres'), findsOneWidget);
    _expectFilterBadge(null);
  });

  testWidgets('clearing in the panel also removes the categories',
      (tester) async {
    _useTallPhone(tester);
    await _pump(tester, CatalogBrowseScreen(items: _mixedCatalog()));

    await _applyCategories(tester, ['cartera', 'reloj']);
    _expectFilterBadge(2);

    await _openFilterPanel(tester);
    await _expandCategorySection(tester);
    expect(_checkMarkIn(_categoryOption('cartera')), findsOneWidget);

    await _tapVisible(tester, find.byKey(const Key('catalog-filter-clear')));
    for (final category in ['bolsa', 'cartera', 'reloj', 'perfume', 'otros']) {
      expect(_checkMarkIn(_categoryOption(category)), findsNothing);
    }
    expect(find.text('Ver 6 artículos'), findsOneWidget);

    await _applyFilters(tester);
    _expectGridShows({..._mixedTitles}, _mixedTitles);
    _expectFilterBadge(null);
  });

  testWidgets('resetting from the empty state also removes the categories',
      (tester) async {
    _useTallPhone(tester);
    await _pump(
      tester,
      CatalogBrowseScreen(
        items: [
          _monetta(1, title: 'Cartera Café', category: 'cartera'),
          _monetta(2, title: 'Reloj Negro', category: 'reloj'),
        ],
      ),
    );

    // A wallet in black does not exist: the combination is empty.
    await _openFilterPanel(tester);
    await _expandCategorySection(tester);
    await _toggleCategories(tester, ['cartera']);
    await _tapVisible(tester, find.byKey(const Key('catalog-filter-color')));
    await _tapVisible(tester, find.text('Negro'));
    await _applyFilters(tester);

    expect(find.text('Sin resultados'), findsOneWidget);
    expect(find.text('Cartera Café'), findsNothing);
    expect(find.text('Reloj Negro'), findsNothing);

    await tester.tap(find.text('Limpiar filtros'));
    await tester.pumpAndSettle();

    expect(find.text('Sin resultados'), findsNothing);
    expect(find.text('Cartera Café'), findsOneWidget);
    expect(find.text('Reloj Negro'), findsOneWidget);
    _expectFilterBadge(null);

    await _openFilterPanel(tester);
    await _expandCategorySection(tester);
    for (final category in ['cartera', 'reloj']) {
      expect(_categoryOption(category), findsOneWidget);
      expect(_checkMarkIn(_categoryOption(category)), findsNothing);
    }
  });

  testWidgets('filters through bag-specific expandable options',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;

    await _pump(
      tester,
      CatalogBrowseScreen(items: [_monetta(1), _external(1)]),
    );

    await tester.tap(find.byKey(const Key('catalog-filter-button')));
    await tester.pumpAndSettle();

    expect(find.text('Filtrar y ordenar'), findsOneWidget);
    expect(find.text('Tipo de bolsa'), findsOneWidget);
    // Asserted by key: "Marca" and "Precio" also name the quick-filter chips
    // on the screen behind the sheet, so the section itself is the subject.
    expect(find.byKey(const Key('catalog-filter-brand')), findsOneWidget);
    expect(find.byKey(const Key('catalog-filter-price')), findsOneWidget);
    expect(find.byKey(const Key('catalog-filter-color')), findsNothing);
    expect(find.text('Tipo de fit'), findsNothing);
    expect(find.text('Talla'), findsNothing);

    final titleRect = tester.getRect(find.text('Filtrar y ordenar'));
    final closeRect = tester.getRect(
      find.byKey(const Key('catalog-filter-close')),
    );
    expect(closeRect.left, greaterThan(titleRect.right));

    final applyButton = tester.widget<FilledButton>(
      find.byKey(const Key('catalog-filter-apply')),
    );
    expect(
      applyButton.style?.backgroundColor?.resolve(const <WidgetState>{}),
      MonettaColors.light.navigationSelection,
    );
    expect(
      applyButton.style?.foregroundColor?.resolve(const <WidgetState>{}),
      MonettaColors.light.accentContent,
    );

    await tester.tap(find.byKey(const Key('catalog-filter-type')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Bolsa de mano'));
    await tester.tap(find.text('Bolsa de mano'));
    await tester.pump();
    expect(find.text('Ver 1 artículo'), findsOneWidget);

    await tester.tap(find.byKey(const Key('catalog-filter-apply')));
    await tester.pumpAndSettle();

    expect(find.text('Bolsa External Item 1'), findsOneWidget);
    expect(find.text('Monetta Item 1'), findsNothing);
    expect(find.byKey(const Key('catalog-filter-count')), findsOneWidget);
  });

  testWidgets('only offers colors and bag styles that exist in the catalog',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;

    final cafe = _external(1, title: 'Bolsa Tote Café');
    final negra = _external(2, title: 'Crossbody Negra');
    await _pump(tester, CatalogBrowseScreen(items: [cafe, negra]));

    await tester.tap(find.byKey(const Key('catalog-filter-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('catalog-filter-color')));
    await tester.pumpAndSettle();
    expect(find.text('Café'), findsOneWidget);
    expect(find.text('Negro'), findsOneWidget);
    expect(find.text('Verde'), findsNothing);

    await tester.ensureVisible(find.text('Café'));
    await tester.tap(find.text('Café'));
    await tester.pump();
    expect(find.text('Ver 1 artículo'), findsOneWidget);

    await tester.tap(find.byKey(const Key('catalog-filter-apply')));
    await tester.pumpAndSettle();
    expect(find.text('Bolsa Bolsa Café tote'), findsOneWidget);
    expect(find.text('Bolsa Negra crossbody'), findsNothing);
  });

  testWidgets('the filter sheet fits a compact phone without overflow',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;

    await _pump(
      tester,
      CatalogBrowseScreen(
        items: [_external(1, title: 'Bolsa Tote Café')],
      ),
    );
    await tester.tap(find.byKey(const Key('catalog-filter-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('catalog-filter-apply')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(360, 640), Size(320, 568)]) {
    testWidgets(
        'category options fit a compact ${size.width.toInt()}x${size.height.toInt()} '
        'phone without overflow', (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      await _pump(
        tester,
        CatalogBrowseScreen(
          items: [
            _external(1),
            _monetta(1, category: 'cartera'),
            _monetta(2, category: 'reloj'),
            _monetta(3, category: 'perfume'),
            _monetta(4),
          ],
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'screen without the rail');

      await _openFilterPanel(tester);
      await _expandCategorySection(tester);
      // Reaching the last option must scroll within the panel, not overflow.
      await _toggleCategories(tester, ['bolsa', 'perfume', 'otros']);
      expect(_checkMarkIn(_categoryOption('otros')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'expanded panel');

      await _applyFilters(tester);
      expect(tester.takeException(), isNull, reason: 'after applying');
      _expectFilterBadge(3);
    });
  }

  testWidgets(
      'every deduplicated item is reachable by scrolling — nothing is silently capped',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;

    final items = [for (var i = 0; i < 30; i++) _external(i)];
    await _pump(tester, CatalogBrowseScreen(items: items));
    await tester.pump();

    expect(find.text('Bolsa External Item 0'), findsOneWidget);

    // Scroll to the bottom and confirm the last item eventually renders —
    // i.e. it was never excluded by a hidden cap.
    await tester.scrollUntilVisible(
      find.text('Bolsa External Item 29'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Bolsa External Item 29'), findsOneWidget);
  });

  testWidgets(
      'tapping an external tile opens its in-app description; only its CTA opens the merchant',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;

    Uri? openedUri;
    final items = [_external(1)];
    await _pump(
      tester,
      CatalogBrowseScreen(
        items: items,
        openExternalLink: (uri) async {
          openedUri = uri;
          return true;
        },
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Bolsa External Item 1'));
    await tester.pumpAndSettle();

    expect(openedUri, isNull);
    expect(find.byType(ExternalProductScreen), findsOneWidget);
    expect(find.text('DESCRIPCIÓN DEL PRODUCTO'), findsOneWidget);

    await tester.tap(find.text('VER EN COACH'));
    await tester.pumpAndSettle();

    expect(
      openedUri,
      Uri.parse('https://www.coach.com/products/item-1/C1.html'),
    );
  });

  testWidgets('an external tile shows no wishlist affordance', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;

    final items = [_external(1)];
    await _pump(tester, CatalogBrowseScreen(items: items));
    await tester.pump();

    expect(find.byIcon(Icons.favorite), findsNothing);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });
}
