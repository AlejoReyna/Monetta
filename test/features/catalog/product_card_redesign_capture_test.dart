/// 390×844 captures of the «tarjetas y barra» redesign, with the real bundled
/// fonts and the fixture photograph.
///
/// Writes PNGs only when `MONETTA_1TO1_CAPTURE_DIR` is set. The assertions
/// (a card per product, no layout exception) run either way.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/media/monetta_image.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/catalog/catalog_browse_screen.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/catalog/product_tile.dart';
import 'package:monetta_app/features/catalog/search_history.dart';
import 'package:monetta_app/features/catalog/search_screen.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/main.dart';

import '../../support/client_guide_capture.dart';

const _phone = Size(390, 844);

Future<CatalogStore> _catalog() async {
  final db = openTestDatabase();
  final store = CatalogStore(database: db);
  addTearDown(() async {
    store.dispose();
    await db.close();
  });
  await store.loadFromAsset();
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => '/tmp',
    );
    final fixture = File('test/support/fixture_product.jpg');
    if (fixture.existsSync()) {
      debugMonettaFixtureImage = MemoryImage(fixture.readAsBytesSync());
    }
  });

  tearDown(() {
    debugMonettaFixtureImage = null;
  });

  void expectCards(WidgetTester tester) {
    expect(tester.takeException(), isNull);
    final tiles =
        tester.widgetList<MonettaProductTile>(find.byType(MonettaProductTile));
    expect(tiles, isNotEmpty);
    expect(
      tiles.every((tile) => tile.variant == ProductTileVariant.card),
      isTrue,
    );
    expect(find.text('VER PRODUCTO'), findsWidgets);
  }

  testWidgets('a-01 coleccion Bolsas (claro)', (tester) async {
    final catalog = await _catalog();
    await pumpClientGuide(
      tester,
      StoreScope(
        notifier: catalog,
        child: const CollectionScreen(
          title: 'Bolsas',
          filter: CollectionFilter(category: 'bolsa'),
        ),
      ),
      size: _phone,
    );
    expectCards(tester);
    await captureClientGuide(tester, 'a-01-coleccion-bolsas');
  });

  testWidgets('a-02 catalogo completo (claro)', (tester) async {
    final catalog = await _catalog();
    await pumpClientGuide(
      tester,
      StoreScope(
        notifier: catalog,
        child: CatalogBrowseScreen(items: catalog.catalogItems),
      ),
      size: _phone,
    );
    expectCards(tester);
    await captureClientGuide(tester, 'a-02-catalogo');
  });

  testWidgets('a-03 resultados de busqueda (claro)', (tester) async {
    final catalog = await _catalog();
    await pumpClientGuide(
      tester,
      StoreScope(
        notifier: catalog,
        child: SearchScreen(history: SearchHistory()),
      ),
      size: _phone,
    );
    await tester.enterText(
      find.byKey(const ValueKey('search-query-field')),
      'Bolso coach',
    );
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search-result-grid')), findsOneWidget);
    expectCards(tester);
    await captureClientGuide(tester, 'a-03-busqueda');
  });

  testWidgets('a-04 inicio hasta un riel de productos (claro)', (tester) async {
    final catalog = await _catalog();
    await pumpClientGuide(
      tester,
      StoreScope(notifier: catalog, child: const HomeScreen()),
      size: _phone,
    );
    final scroll = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .first;
    final rail = find.byKey(const ValueKey('home-section-new-products'));
    await tester.scrollUntilVisible(rail, 400, scrollable: scroll);
    await tester.pumpAndSettle();
    expect(rail, findsOneWidget);
    expectCards(tester);
    await captureClientGuide(tester, 'a-04-inicio-riel');
  });

  testWidgets('a-05 coleccion Bolsas (oscuro)', (tester) async {
    final catalog = await _catalog();
    await pumpClientGuide(
      tester,
      StoreScope(
        notifier: catalog,
        child: const CollectionScreen(
          title: 'Bolsas',
          filter: CollectionFilter(category: 'bolsa'),
        ),
      ),
      size: _phone,
      brightness: Brightness.dark,
    );
    expectCards(tester);
    await captureClientGuide(tester, 'a-05-coleccion-bolsas-oscuro');
  });
}
