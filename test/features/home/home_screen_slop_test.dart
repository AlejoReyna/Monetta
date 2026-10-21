import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/catalog/product_card.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/main.dart';

Future<CatalogStore> _loadedStore() async {
  final store = CatalogStore(database: openTestDatabase());
  await store.loadFromAsset();
  return store;
}

Widget _app(CatalogStore store) {
  return MaterialApp(
    theme: buildLightTheme(),
    home: StoreScope(
      notifier: store,
      child: const HomeScreen(),
    ),
  );
}

Finder _homeScroll() => find
    .byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    )
    .first;

void main() {
  testWidgets('first open is the store, not a questionnaire', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(_app(store));
    await tester.pump();

    expect(find.text('Personaliza tu experiencia'), findsNothing);
    expect(find.text('¿Qué le gusta?'), findsNothing);
    expect(find.byKey(const ValueKey('home-search-bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-compact-hero')), findsOneWidget);
    expect(find.text('Novedades'), findsOneWidget);
    expect(find.text('Compra por estilo'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-style-rail')), findsOneWidget);
  });

  testWidgets('shopper home does not narrate the engine or the scrape',
      (tester) async {
    final store = await _loadedStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(_app(store));
    await tester.pump();

    expect(find.text('extracted'), findsNothing);
    expect(find.textContaining('Investigación'), findsNothing);
    expect(find.textContaining('Candidato de compra'), findsNothing);
    expect(find.textContaining('propietario'), findsNothing);
    expect(find.textContaining('Porque te gustan'), findsNothing);
    expect(find.text('POPULAR AHORA'), findsNothing);
    expect(find.textContaining('interacciones'), findsNothing);
    expect(find.text('FILTRAR'), findsNothing);
    expect(find.text('ORDENAR'), findsNothing);
  });

  testWidgets('search sits above a banner that leaves room to shop', (
    tester,
  ) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    // A real phone viewport: the banner is sized as a share of it.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(_app(store));
    await tester.pump();

    final search = tester.getRect(
      find.byKey(const ValueKey('home-search-bar')),
    );
    final banner = tester.getRect(
      find.byKey(const ValueKey('home-compact-hero')),
    );

    expect(search.bottom, lessThanOrEqualTo(banner.top));
    // The brief's 25–32% of the viewport, never the whole first fold.
    expect(banner.height / 844, greaterThanOrEqualTo(0.25));
    expect(banner.height / 844, lessThanOrEqualTo(0.32));
    // Full bleed, as on figure 03 — the photograph runs rail to rail.
    expect(banner.left, 0);
    expect(banner.right, 390);
    expect(find.text('Ver novedades'), findsOneWidget);
  });

  testWidgets('modules sit on a 24–32px rhythm, not a 64–72px one', (
    tester,
  ) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(_app(store));
    await tester.pump();

    final banner = tester.getRect(
      find.byKey(const ValueKey('home-compact-hero')),
    );
    final newest = tester.getRect(
      find.byKey(const ValueKey('home-section-new-products')),
    );
    final style = tester.getRect(
      find.byKey(const ValueKey('home-section-bag-types')),
    );

    expect(newest.top - banner.bottom, inInclusiveRange(24, 40));
    expect(style.top - newest.bottom, inInclusiveRange(24, 40));
  });

  testWidgets('new arrivals are a rail of the shared product card', (
    tester,
  ) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(_app(store));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('home-new-products-rail')),
      findsOneWidget,
    );
    expect(find.text('Ver todo'), findsWidgets);
    // The catalog's own card, not a home-only lookalike.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-new-products-rail')),
        matching: find.byType(ProductCard),
      ),
      findsWidgets,
    );
  });

  testWidgets('the header is compact and opaque from the first frame', (
    tester,
  ) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(_app(store));
    await tester.pump();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.toolbarHeight, 60);
    expect(appBar.backgroundColor, isNot(Colors.transparent));
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).extendBodyBehindAppBar,
      isFalse,
    );

    final wordmark = find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(MonettaWordmark),
    );
    expect(
      tester.widget<MonettaWordmark>(wordmark).height,
      kAppBarWordmarkHeight,
    );
  });

  testWidgets('the in-page search field hands over to the app-bar icon', (
    tester,
  ) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(_app(store));
    await tester.pump();

    expect(
      tester
          .widget<Opacity>(
            find.byKey(const ValueKey('home-search-bar-transition')),
          )
          .opacity,
      closeTo(1, .00001),
    );
    expect(
      tester
          .widget<Opacity>(
            find.byKey(const ValueKey('home-appbar-search-transition')),
          )
          .opacity,
      0,
    );

    await tester.drag(
      find.byKey(const ValueKey('home-discovery-header')),
      const Offset(0, -180),
    );
    await tester.pump();

    expect(
      tester
          .widget<Opacity>(
            find.byKey(const ValueKey('home-search-bar-transition')),
          )
          .opacity,
      0,
    );
    expect(
      tester
          .widget<Opacity>(
            find.byKey(const ValueKey('home-appbar-search-transition')),
          )
          .opacity,
      closeTo(1, .00001),
    );
    expect(
      find.byKey(const ValueKey('home-appbar-search-button')).hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('home search field opens the product search', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(_app(store));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('home-search-bar')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('search-query-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-empty-state')), findsOneWidget);
  });

  testWidgets('mayoreo editorial banner opens wholesale', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(_app(store));
    await tester.pump();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home-wholesale-button')),
      800,
      scrollable: _homeScroll(),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-wholesale-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('wholesale-scroll')), findsOneWidget);
  });
}
