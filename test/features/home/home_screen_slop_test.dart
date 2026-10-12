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

  testWidgets('search floats over the bottom of a full-bleed hero', (
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

    final hero = tester.getRect(
      find.byKey(const ValueKey('home-compact-hero')),
    );
    final search = tester.getRect(
      find.byKey(const ValueKey('home-search-bar')),
    );

    // Full bleed: the photograph opens at the very top of the
    // screen — behind the status bar and the floating app bar — rail to rail.
    expect(hero.top, 0);
    expect(hero.left, 0);
    expect(hero.right, 390);
    // Tall enough to hold the headline, the action and the overlaid search.
    expect(hero.height, greaterThan(400));
    // The search pill floats over the hero's bottom, not above the banner.
    expect(search.top, greaterThan(hero.top));
    expect(search.bottom, lessThanOrEqualTo(hero.bottom));
    expect(search.left, greaterThanOrEqualTo(hero.left));
    expect(search.right, lessThanOrEqualTo(hero.right));
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

  testWidgets('the header floats transparent over the full-bleed hero', (
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
    // Transparent over the photograph, not opaque grey: the hero
    // opens behind the status bar and the bar.
    expect(appBar.backgroundColor, Colors.transparent);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).extendBodyBehindAppBar,
      isTrue,
    );

    final wordmark = find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(MonettaWordmark),
    );
    expect(
      tester.widget<MonettaWordmark>(wordmark).height,
      kAppBarWordmarkHeight,
    );

    // Once the hero scrolls away the bar takes its grey surface.
    await tester.drag(
      find.byKey(const ValueKey('home-discovery-header')),
      const Offset(0, -600),
    );
    await tester.pump();
    expect(
      tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
      isNot(Colors.transparent),
    );
  });

  testWidgets('the hero search field hands over to the app-bar icon', (
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

  testWidgets('mayoreo editorial card opens the partner view', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(_app(store));
    await tester.pump();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home-offers-rail')),
      800,
      scrollable: _homeScroll(),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('home-offers-rail')),
      const Offset(-620, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conocer mayoreo'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('partner-hub-scroll')), findsOneWidget);
  });
}
