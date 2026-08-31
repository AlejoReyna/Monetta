import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/app/external_catalog_config.dart';
import 'package:monetta_app/app/external_catalog_controller.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/main.dart';

Future<CatalogStore> _loadedStore() async {
  final store = CatalogStore(database: openTestDatabase());
  await store.loadFromAsset();
  return store;
}

Widget _app(CatalogStore store) {
  return MaterialApp(
    home: StoreScope(
      notifier: store,
      child: ExternalCatalogScope(
        notifier: ExternalCatalogController(
          config: ExternalCatalogConfig.disabled,
        ),
        child: const HomeScreen(),
      ),
    ),
  );
}

void main() {
  testWidgets('first open is the store, not a questionnaire', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    await tester.pumpWidget(_app(store));
    await tester.pump();

    expect(find.text('Elige marcas'), findsNothing);
    expect(find.text('¿Qué le gusta?'), findsNothing);
    await tester.pump();
    expect(find.byKey(const ValueKey('home-search-bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-offers-rail')), findsOneWidget);
    expect(find.text('PARA COMPRAR, ESTRENAR O CRECER'), findsOneWidget);
    expect(find.text('Lo mejor de Monetta, hoy'), findsOneWidget);
    expect(find.text('VER LA PIEZA'), findsNothing);
    expect(find.text('Novedades'), findsNothing);
    expect(find.text('Piezas originales, elegidas una por una.'), findsNothing);
    expect(find.text('Ver el catálogo'), findsNothing);
  });

  testWidgets('shopper home does not narrate the engine or the scrape',
      (tester) async {
    final store = await _loadedStore();
    await tester.pumpWidget(_app(store));
    await tester.pump();

    expect(find.text('extracted'), findsNothing);
    expect(find.textContaining('Investigación'), findsNothing);
    expect(find.textContaining('Candidato de compra'), findsNothing);
    expect(find.textContaining('propietario'), findsNothing);
    expect(find.textContaining('Porque te gustan'), findsNothing);
    expect(find.text('POPULAR AHORA'), findsNothing);
    expect(find.textContaining('interacciones'), findsNothing);
    expect(find.text('TU EXPERIENCIA MONETTA'), findsNothing);
    expect(find.textContaining('definen la temporada'), findsNothing);
    expect(find.textContaining('Siluetas versátiles'), findsNothing);
    expect(find.text('FILTRAR'), findsNothing);
    expect(find.text('ORDENAR'), findsNothing);
  });

  testWidgets('compact discovery header replaces full-screen campaign pages', (
    tester,
  ) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    await tester.pumpWidget(_app(store));
    await tester.pump();

    await tester.pump();
    final headerBox = tester.getRect(
      find.byKey(const ValueKey('home-discovery-header')),
    );
    final mediaBox = tester.getRect(
      find.byKey(const ValueKey('home-compact-hero')),
    );
    expect(mediaBox.width, closeTo(390, .1));
    expect(mediaBox.height, 280);
    expect(headerBox.height, 280);
    expect(find.byKey(const ValueKey('home-offer-card-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-offer-card-1')), findsOneWidget);
    expect(find.text('BIENVENID@'), findsNothing);
    expect(find.text('20% en bolsos seleccionados'), findsOneWidget);
    expect(find.text('Ver la selección'), findsOneWidget);
    expect(find.text('No requiere código.'), findsNothing);
    final offerCard = find.byKey(const ValueKey('home-offer-card-0'));
    final offerMedia = find.descendant(
      of: offerCard,
      matching: find.byKey(const ValueKey('home-offer-media')),
    );
    final offerContent = find.descendant(
      of: offerCard,
      matching: find.byKey(const ValueKey('home-offer-content')),
    );
    expect(tester.getRect(offerMedia).height, closeTo(250, .1));
    expect(tester.getRect(offerContent).height, closeTo(250, .1));
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('home-section-collections')))
          .dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('home-section-offers'))).dy,
      ),
    );
    expect(find.byKey(const ValueKey('campaign-slide-media-0')), findsNothing);
  });

  testWidgets('mayoreo editorial card opens the partner view', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    await tester.pumpWidget(_app(store));
    await tester.pump();

    await tester.drag(
      find.byKey(const ValueKey('home-offers-rail')),
      const Offset(-620, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conocer mayoreo'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('partner-hub-scroll')),
      findsOneWidget,
    );
  });

  testWidgets(
    'hero starts behind a transparent bar and collapses to a surface',
    (
      tester,
    ) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      tester.view.physicalSize = const Size(390, 2000);
      tester.view.devicePixelRatio = 1.0;

      final store = await _loadedStore();
      await tester.pumpWidget(_app(store));
      await tester.pump();

      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).extendBodyBehindAppBar,
        isTrue,
      );
      expect(
        tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
        Colors.transparent,
      );

      await tester.dragFrom(const Offset(190, 300), const Offset(0, -180));
      await tester.pump();

      final colors = tester.element(find.byType(AppBar)).monettaColors;
      expect(
        tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
        colors.surface,
      );
    },
  );

  testWidgets('search pill is replaced by the app-bar icon while scrolling', (
    tester,
  ) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
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

  testWidgets('navbar wordmark keeps its canonical size while home collapses',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    await tester.pumpWidget(_app(store));
    await tester.pump();

    final appBarWordmark = find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(MonettaWordmark),
    );
    expect(
      tester.widget<MonettaWordmark>(appBarWordmark).height,
      kAppBarWordmarkHeight,
    );
    expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 68);

    await tester.drag(
      find.byKey(const ValueKey('home-discovery-header')),
      const Offset(0, -260),
    );
    await tester.pump();

    expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 52);
    expect(
      tester.widget<MonettaWordmark>(appBarWordmark).height,
      kAppBarWordmarkHeight,
    );
  });

  testWidgets('home search pill opens the product search', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    await tester.pumpWidget(_app(store));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('home-search-bar')));
    await tester.pumpAndSettle();

    expect(find.text('BÚSQUEDAS FRECUENTES'), findsOneWidget);
    expect(find.text('Buscar'), findsOneWidget);
  });
}
