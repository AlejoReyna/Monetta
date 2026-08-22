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
    expect(find.text('Ver el catálogo'), findsOneWidget);
    expect(find.text('VER LA PIEZA'), findsNothing);
    expect(find.text('Novedades'), findsOneWidget);
    expect(
      find.text('Piezas originales, elegidas una por una.'),
      findsOneWidget,
    );
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

  testWidgets('hero media fills its padded card and copy sits underneath',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    await tester.pumpWidget(_app(store));
    await tester.pump();

    await tester.pump();
    final newest = [...store.products]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final heroBox = tester.getRect(find.byKey(const Key('campaign-hero')));
    final mediaBox = tester.getRect(
      find.byKey(const ValueKey('campaign-slide-media-0')),
    );
    final breathBox = tester.getRect(find.byKey(const Key('editorial-breath')));
    final newsTop = tester.getTopLeft(find.text('Novedades')).dy;
    expect(mediaBox.left - heroBox.left, greaterThanOrEqualTo(16));
    expect(heroBox.right - mediaBox.right, greaterThanOrEqualTo(16));
    expect(mediaBox.height, greaterThan(320));
    expect(breathBox.top, closeTo(mediaBox.bottom, 0.5));
    expect(breathBox.bottom, lessThanOrEqualTo(heroBox.bottom - 28));
    expect(newsTop, greaterThanOrEqualTo(heroBox.bottom));
    expect(find.textContaining(newest.first.title), findsWidgets);
    expect(find.text('Ver el catálogo'), findsOneWidget);
    final ctaCenter = tester.getCenter(find.text('Ver el catálogo'));
    expect(ctaCenter.dy, greaterThan(mediaBox.bottom));
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
      find.text('Piezas originales, elegidas una por una.').hitTestable(),
      findsOneWidget,
    );
    expect(
      find.text('Nuevas siluetas para todos los días.').hitTestable(),
      findsNothing,
    );

    await tester.pump(const Duration(milliseconds: 3500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.text('Nuevas siluetas para todos los días.').hitTestable(),
      findsOneWidget,
    );
  });
}
