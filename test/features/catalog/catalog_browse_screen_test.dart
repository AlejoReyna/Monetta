import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/domain/catalog_item.dart';
import 'package:monetta_app/features/catalog/catalog_browse_screen.dart';
import 'package:monetta_app/features/product/external_product_screen.dart';

CatalogItem _monetta(int i) => CatalogItem(
      sourceScopedId: 'monetta:$i',
      source: CatalogSourceType.monettaShopify,
      merchant: 'Monetta',
      title: 'Monetta Item $i',
      brand: 'Guess',
      category: null,
      imageUrl: null,
      price: const Money(amount: 1999, currency: Currency.mxn),
      availability: CatalogAvailability.inStock,
      detailUrl: 'https://monetta.mx/products/item-$i',
      marketRestriction: MarketRestriction.mexico,
      lastObservedAt: DateTime.utc(2026, 8, 10),
      purchaseMode: PurchaseMode.monettaCheckout,
      shopifyProductId: '$i',
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

void main() {
  testWidgets('shows an empty state for zero items', (tester) async {
    await _pump(tester, const CatalogBrowseScreen(items: []));
    expect(find.text('Sin resultados'), findsOneWidget);
  });

  testWidgets('shows header and category pills', (tester) async {
    await _pump(tester, CatalogBrowseScreen(items: [_monetta(1)]));

    expect(find.text('Productos'), findsOneWidget);
    expect(find.text('Colección'), findsOneWidget);
    expect(find.text('Monetta'), findsOneWidget);
    expect(find.text('Bolsas'), findsOneWidget);
    expect(find.text('Perfumes'), findsOneWidget);

    final collection = tester.widget<ChoiceChip>(
      find.byKey(const Key('catalog-category-collection')),
    );
    final monetta = tester.widget<ChoiceChip>(
      find.byKey(const Key('catalog-category-monetta')),
    );
    expect(collection.selected, isTrue);
    expect(monetta.selected, isFalse);
    expect(
      collection.color?.resolve(const <WidgetState>{WidgetState.selected}),
      MonettaColors.light.navigationSelection,
    );
    expect(
      monetta.color?.resolve(const <WidgetState>{}),
      Colors.transparent,
    );
  });

  testWidgets('category selection moves the pill motion state', (tester) async {
    await _pump(tester, CatalogBrowseScreen(items: [_monetta(1)]));

    AnimatedScale motionFor(String category) => tester.widget<AnimatedScale>(
          find.byKey(Key('catalog-category-$category-motion')),
        );

    expect(motionFor('collection').scale, 1.025);
    expect(motionFor('monetta').scale, 1);

    await tester.tap(find.byKey(const Key('catalog-category-monetta')));
    await tester.pumpAndSettle();

    expect(motionFor('collection').scale, 1);
    expect(motionFor('monetta').scale, 1.025);
  });

  testWidgets('category content uses the smooth section transition', (
    tester,
  ) async {
    await _pump(
      tester,
      CatalogBrowseScreen(items: [_monetta(1), _external(1)]),
    );

    expect(
      find.byKey(const Key('catalog-section-transition')),
      findsOneWidget,
    );
    final switcher = tester.widget<AnimatedSwitcher>(
      find.byKey(const Key('catalog-section-transition')),
    );
    const current = SizedBox(key: ValueKey('current'));
    const previous = SizedBox(key: ValueKey('previous'));
    expect(
      switcher.layoutBuilder(current, const [previous]),
      same(current),
      reason: 'the outgoing product grid must not remain in the layout',
    );
    expect(
      find.byKey(const ValueKey('catalog-section-Colección')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('catalog-category-monetta')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('catalog-section-Colección')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('catalog-section-Monetta')),
      findsOneWidget,
    );
  });

  testWidgets('humanizes canonical brand and product tokens', (tester) async {
    await _pump(
      tester,
      CatalogBrowseScreen(
        items: [_external(1, title: 'jet_set_bag', brand: 'michael_kors')],
      ),
    );

    expect(find.text('Michael Kors'), findsOneWidget);
    expect(find.text('Jet Set Bag'), findsOneWidget);
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
    expect(find.text('External Item 1'), findsOneWidget);
    expect(find.text('extracted'), findsNWidgets(2));
  });

  testWidgets('keeps the same grid chrome when there are only external items',
      (tester) async {
    final items = [_external(1)];
    await _pump(tester, CatalogBrowseScreen(items: items));
    await tester.pump();

    expect(find.text('Selección Monetta'), findsNothing);
    expect(find.text('Edición internacional'), findsNothing);
    expect(find.text('External Item 1'), findsOneWidget);
  });

  testWidgets('filters by selected category pill correctly', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;

    final perfume = CatalogItem(
      sourceScopedId: 'perfume:1',
      source: CatalogSourceType.monettaShopify,
      merchant: 'Monetta',
      title: 'Monetta Perfume 1',
      brand: 'Guess',
      category: null,
      imageUrl: null,
      price: const Money(amount: 1999, currency: Currency.mxn),
      availability: CatalogAvailability.inStock,
      detailUrl: 'https://monetta.mx/products/perfume-1',
      marketRestriction: MarketRestriction.mexico,
      lastObservedAt: DateTime.utc(2026, 8, 10),
      purchaseMode: PurchaseMode.monettaCheckout,
      shopifyProductId: 'p1',
      vertical: CatalogVertical.perfumes,
    );

    final bag = CatalogItem(
      sourceScopedId: 'bag:1',
      source: CatalogSourceType.monettaShopify,
      merchant: 'Monetta',
      title: 'Monetta Item 2',
      brand: 'Guess',
      category: null,
      imageUrl: null,
      price: const Money(amount: 1999, currency: Currency.mxn),
      availability: CatalogAvailability.inStock,
      detailUrl: 'https://monetta.mx/products/item-2',
      marketRestriction: MarketRestriction.mexico,
      lastObservedAt: DateTime.utc(2026, 8, 10),
      purchaseMode: PurchaseMode.monettaCheckout,
      shopifyProductId: '2',
      vertical: CatalogVertical.bagsWallets,
    );

    final extBag = CatalogItem(
      sourceScopedId: 'ext:1',
      source: CatalogSourceType.coachUs,
      merchant: 'Coach',
      title: 'External Item 3',
      brand: 'Coach',
      category: null,
      imageUrl: null,
      price: const Money(amount: 1999, currency: Currency.mxn),
      availability: CatalogAvailability.inStock,
      detailUrl: 'https://monetta.mx/products/ext-3',
      marketRestriction: MarketRestriction.mexico,
      lastObservedAt: DateTime.utc(2026, 8, 10),
      purchaseMode: PurchaseMode.externalResearch,
      vertical: CatalogVertical.bagsWallets,
    );

    final general = CatalogItem(
      sourceScopedId: 'general:1',
      source: CatalogSourceType.monettaShopify,
      merchant: 'Monetta',
      title: 'Monetta General 4',
      brand: 'Guess',
      category: null,
      imageUrl: null,
      price: const Money(amount: 1999, currency: Currency.mxn),
      availability: CatalogAvailability.inStock,
      detailUrl: 'https://monetta.mx/products/general-4',
      marketRestriction: MarketRestriction.mexico,
      lastObservedAt: DateTime.utc(2026, 8, 10),
      purchaseMode: PurchaseMode.monettaCheckout,
      shopifyProductId: 'g4',
    );

    await _pump(
      tester,
      CatalogBrowseScreen(items: [perfume, bag, extBag, general]),
    );

    expect(find.text('Monetta Perfume 1'), findsOneWidget);
    expect(find.text('Monetta Item 2'), findsOneWidget);
    expect(find.text('External Item 3'), findsOneWidget);
    expect(find.text('Monetta General 4'), findsOneWidget);

    await tester.tap(find.byKey(const Key('catalog-category-monetta')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const Key('catalog-category-monetta')),
          )
          .selected,
      isTrue,
    );
    expect(find.text('Selección Monetta'), findsOneWidget);
    expect(find.text('Monetta Perfume 1'), findsOneWidget);
    expect(find.text('Monetta Item 2'), findsOneWidget);
    expect(find.text('External Item 3'), findsNothing);
    expect(find.text('Monetta General 4'), findsOneWidget);

    await tester.tap(find.byKey(const Key('catalog-category-bags')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const Key('catalog-category-bags')),
          )
          .selected,
      isTrue,
    );
    expect(find.text('Selección Monetta'), findsNothing);
    expect(find.text('Monetta Perfume 1'), findsNothing);
    expect(find.text('Monetta Item 2'), findsOneWidget);
    expect(find.text('External Item 3'), findsOneWidget);
    expect(find.text('Monetta General 4'), findsNothing);

    await tester.tap(find.byKey(const Key('catalog-category-perfumes')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const Key('catalog-category-perfumes')),
          )
          .selected,
      isTrue,
    );
    expect(find.text('Monetta Item 2'), findsNothing);
    expect(find.text('External Item 3'), findsNothing);
    expect(find.text('Monetta Perfume 1'), findsOneWidget);
    expect(find.text('Monetta General 4'), findsNothing);
  });

  testWidgets('category pills do not show article counts', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;

    final cafe = CatalogItem(
      sourceScopedId: 'coach_us:1',
      source: CatalogSourceType.coachUs,
      merchant: 'Coach',
      title: 'Bolsa Tote Café',
      brand: 'Coach',
      category: 'Handbags',
      imageUrl: null,
      price: const Money(amount: 300, currency: Currency.usd),
      availability: CatalogAvailability.inStock,
      detailUrl: 'https://www.coach.com/1',
      marketRestriction: MarketRestriction.unitedStates,
      lastObservedAt: DateTime.utc(2026, 8, 10),
      purchaseMode: PurchaseMode.externalResearch,
      vertical: CatalogVertical.bagsWallets,
    );
    final negra = CatalogItem(
      sourceScopedId: 'coach_us:2',
      source: CatalogSourceType.coachUs,
      merchant: 'Coach',
      title: 'Crossbody Negra',
      brand: 'Coach',
      category: 'Handbags',
      imageUrl: null,
      price: const Money(amount: 300, currency: Currency.usd),
      availability: CatalogAvailability.inStock,
      detailUrl: 'https://www.coach.com/2',
      marketRestriction: MarketRestriction.unitedStates,
      lastObservedAt: DateTime.utc(2026, 8, 10),
      purchaseMode: PurchaseMode.externalResearch,
      vertical: CatalogVertical.bagsWallets,
    );
    final monettaBag = CatalogItem(
      sourceScopedId: 'monetta:3',
      source: CatalogSourceType.monettaShopify,
      merchant: 'Monetta',
      title: 'Bolsa Monetta Café',
      brand: 'Guess',
      category: null,
      imageUrl: null,
      price: const Money(amount: 1999, currency: Currency.mxn),
      availability: CatalogAvailability.inStock,
      detailUrl: 'https://monetta.mx/products/item-3',
      marketRestriction: MarketRestriction.mexico,
      lastObservedAt: DateTime.utc(2026, 8, 10),
      purchaseMode: PurchaseMode.monettaCheckout,
      shopifyProductId: '3',
      vertical: CatalogVertical.bagsWallets,
    );
    final monettaPerfume = CatalogItem(
      sourceScopedId: 'monetta:4',
      source: CatalogSourceType.monettaShopify,
      merchant: 'Monetta',
      title: 'Perfume Monetta',
      brand: 'Guess',
      category: null,
      imageUrl: null,
      price: const Money(amount: 1999, currency: Currency.mxn),
      availability: CatalogAvailability.inStock,
      detailUrl: 'https://monetta.mx/products/item-4',
      marketRestriction: MarketRestriction.mexico,
      lastObservedAt: DateTime.utc(2026, 8, 10),
      purchaseMode: PurchaseMode.monettaCheckout,
      shopifyProductId: '4',
      vertical: CatalogVertical.perfumes,
    );
    await _pump(
      tester,
      CatalogBrowseScreen(items: [cafe, negra, monettaBag, monettaPerfume]),
    );
    await tester.pump();

    expect(find.text(' 4'), findsNothing);

    await tester.tap(find.byKey(const Key('catalog-filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog-filter-color')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Café'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog-filter-apply')));
    await tester.pumpAndSettle();

    expect(find.text(' 2'), findsNothing);

    await tester.tap(find.byKey(const Key('catalog-category-monetta')));
    await tester.pumpAndSettle();
    expect(find.text(' 1'), findsNothing);

    await tester.tap(find.byKey(const Key('catalog-category-bags')));
    await tester.pumpAndSettle();
    expect(find.text(' 2'), findsNothing);

    await tester.tap(find.byKey(const Key('catalog-category-perfumes')));
    await tester.pumpAndSettle();
    expect(find.text('Perfumes'), findsOneWidget);
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
    expect(find.text('Marca'), findsOneWidget);
    expect(find.text('Precio'), findsOneWidget);
    expect(find.text('Color'), findsNothing);
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

    expect(find.text('External Item 1'), findsOneWidget);
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
    expect(find.text('Bolsa Tote Café'), findsOneWidget);
    expect(find.text('Crossbody Negra'), findsNothing);
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

  testWidgets('category rail fits a compact phone without overflow',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;

    await _pump(
      tester,
      const CatalogBrowseScreen(items: []),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('catalog-category-collection')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('catalog-category-monetta')), findsOneWidget);

    final categoryRail = find.byWidgetPredicate(
      (widget) =>
          widget is ListView && widget.scrollDirection == Axis.horizontal,
    );
    await tester.drag(categoryRail, const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('catalog-category-perfumes')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'every deduplicated item is reachable by scrolling — nothing is silently capped',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;

    final items = [for (var i = 0; i < 30; i++) _external(i)];
    await _pump(tester, CatalogBrowseScreen(items: items));
    await tester.pump();

    expect(find.text('External Item 0'), findsOneWidget);

    // Scroll to the bottom and confirm the last item eventually renders —
    // i.e. it was never excluded by a hidden cap.
    await tester.scrollUntilVisible(
      find.text('External Item 29'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('External Item 29'), findsOneWidget);
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

    await tester.tap(find.text('External Item 1'));
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
