import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/app/external_catalog_config.dart';
import 'package:monetta_app/app/external_catalog_controller.dart';
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
    expect(
      find.byKey(const ValueKey('campaign-slide-media-0')),
      findsOneWidget,
    );
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
    expect(find.text('PARA TI'), findsNothing);
    expect(find.textContaining('interacciones'), findsNothing);
    expect(find.text('TU EXPERIENCIA MONETTA'), findsNothing);
    expect(find.textContaining('definen la temporada'), findsNothing);
    expect(find.textContaining('Siluetas versátiles'), findsNothing);
    expect(find.text('FILTRAR'), findsNothing);
    expect(find.text('ORDENAR'), findsNothing);
  });

  testWidgets('hero is media-only and hides newest until the user scrolls',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    await tester.pumpWidget(_app(store));
    await tester.pump();

    await tester.pump();
    final heroBox = tester.getRect(find.byKey(const Key('campaign-hero')));
    final mediaBox = tester.getRect(
      find.byKey(const ValueKey('campaign-slide-media-0')),
    );
    expect(mediaBox.left - heroBox.left, greaterThanOrEqualTo(16));
    expect(heroBox.right - mediaBox.right, greaterThanOrEqualTo(16));
    expect(mediaBox.top - heroBox.top, closeTo(12, 0.5));
    expect(heroBox.bottom - mediaBox.bottom, closeTo(12, 0.5));
    expect(mediaBox.height, greaterThan(heroBox.height * 0.9));
    expect(find.text('Novedades'), findsNothing);
    expect(find.text('Ver el catálogo'), findsNothing);

    await tester.drag(
      find.byKey(const Key('campaign-hero')),
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();

    expect(find.text('Novedades').hitTestable(), findsOneWidget);
  });

  testWidgets('hero advances to the next of three cards every 3.5 seconds',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    await tester.pumpWidget(_app(store));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('campaign-slide-media-0')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('campaign-slide-media-1')).hitTestable(),
      findsNothing,
    );

    await tester.pump(const Duration(milliseconds: 3500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.byKey(const ValueKey('campaign-slide-media-1')).hitTestable(),
      findsOneWidget,
    );
  });
}
