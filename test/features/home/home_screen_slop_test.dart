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
    expect(find.text('VER CATÁLOGOS'), findsOneWidget);
    expect(find.text('VER LA PIEZA'), findsNothing);
    expect(find.text('Novedades'), findsOneWidget);
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

  testWidgets('newest pieces sit directly under a mid-height film',
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
    final newsTop = tester.getTopLeft(find.text('Novedades')).dy;
    expect(newsTop, greaterThan(heroBox.bottom));
    expect(newsTop - heroBox.bottom, lessThan(80));
    expect(find.text(newest.first.title), findsWidgets);
    expect(find.text('VER CATÁLOGOS'), findsOneWidget);
    final ctaCenter = tester.getCenter(find.text('VER CATÁLOGOS'));
    expect((ctaCenter.dy - heroBox.center.dy).abs(), lessThan(24));
  });
}
