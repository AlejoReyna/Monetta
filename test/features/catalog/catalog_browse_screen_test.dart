import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/domain/catalog_item.dart';
import 'package:monetta_app/features/catalog/catalog_browse_screen.dart';

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

CatalogItem _external(int i) => CatalogItem(
      sourceScopedId: 'coach_us:$i',
      source: CatalogSourceType.coachUs,
      merchant: 'Coach',
      title: 'External Item $i',
      brand: 'Coach',
      category: 'Handbags',
      imageUrl: null,
      price: const Money(amount: 300, currency: Currency.usd),
      availability: CatalogAvailability.inStock,
      detailUrl: 'https://www.coach.com/products/item-$i/C$i.html',
      marketRestriction: MarketRestriction.unitedStates,
      lastObservedAt: DateTime.utc(2026, 8, 10),
      purchaseMode: PurchaseMode.externalResearch,
    );

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(MaterialApp(home: child));
}

void main() {
  testWidgets('shows an empty state for zero items', (tester) async {
    await _pump(tester, const CatalogBrowseScreen(items: []));
    expect(find.text('Sin resultados'), findsOneWidget);
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

  testWidgets(
      'separates Monetta items from external items into two clearly labeled sections',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;

    final items = [_monetta(1), _monetta(2), _external(1), _external(2)];
    await _pump(tester, CatalogBrowseScreen(items: items));
    await tester.pump();

    expect(find.text('Catálogo Monetta'), findsOneWidget);
    expect(
      find.text('También en marcas de Estados Unidos'),
      findsOneWidget,
    );

    // The Monetta heading must appear before the external heading.
    final monettaHeadingY = tester.getTopLeft(find.text('Catálogo Monetta')).dy;
    final externalHeadingY =
        tester.getTopLeft(find.text('También en marcas de Estados Unidos')).dy;
    expect(monettaHeadingY, lessThan(externalHeadingY));
  });

  testWidgets('shows only the external heading when there are no Monetta items',
      (tester) async {
    final items = [_external(1)];
    await _pump(tester, CatalogBrowseScreen(items: items));
    await tester.pump();

    expect(find.text('Catálogo Monetta'), findsNothing);
    expect(
      find.text('También en marcas de Estados Unidos'),
      findsOneWidget,
    );
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

  testWidgets('tapping an external tile validates the URL before opening it',
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
