/// CHAR-01 (objective state, red until RF-11): the product page must show an
/// "unavailable" state instead of throwing when its product leaves the
/// catalog, or was never in it.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/firestore/catalog_realtime_source.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/product/product_screen.dart';
import 'package:monetta_app/main.dart';

const _unavailableTitle = 'Este artículo ya no está disponible';
const _exploreLabel = 'Explorar el catálogo';
const _backLabel = 'Volver';
const _missingProductId = 'gid://shopify/Product/0';

class _ControlledSource implements CatalogRealtimeSource {
  final controller = StreamController<List<CatalogRealtimeDocument>>();

  @override
  Stream<List<CatalogRealtimeDocument>> watchProducts() => controller.stream;
}

CatalogRealtimeDocument _document(String legacyId, String title) =>
    CatalogRealtimeDocument(
      documentId: legacyId,
      data: {
        'schemaVersion': 1,
        'source': 'shopify',
        'id': 'gid://shopify/Product/$legacyId',
        'shopifyLegacyId': legacyId,
        'handle': 'handle-$legacyId',
        'title': title,
        'vendor': 'Monetta',
        'productType': 'Bolsa',
        'tags': <String>[],
        'descriptionHtml': '',
        'images': <String>[],
        'collectionHandles': <String>[],
        'brandOverride': null,
        'categoryOverride': null,
        'variants': <Map<String, Object?>>[
          {
            'id': 'gid://shopify/ProductVariant/$legacyId$legacyId',
            'title': 'Default Title',
            'price': 1200,
            'available': true,
            'compareAtPrice': null,
            'sku': null,
          },
        ],
        'createdAt': '2026-08-01T00:00:00Z',
        'updatedAt': '2026-08-27T00:00:00Z',
        'publishedAt': '2026-08-01T00:00:00Z',
        'isPublished': true,
        'isInStock': true,
        'minPrice': 1200,
      },
    );

class _Harness {
  _Harness(this.tester, this.store, this.source);

  final WidgetTester tester;
  final CatalogStore store;
  final _ControlledSource source;

  /// Emits a live snapshot and waits until the store has published it.
  Future<void> emit(List<CatalogRealtimeDocument> documents) async {
    final expectedIds = {
      for (final document in documents)
        'gid://shopify/Product/${document.documentId}',
    };
    await tester.runAsync(() async {
      source.controller.add(documents);
      for (var attempt = 0; attempt < 500; attempt += 1) {
        final ids = {for (final product in store.products) product.id};
        if (ids.length == expectedIds.length && ids.containsAll(expectedIds)) {
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
    });
    expect(
      {for (final product in store.products) product.id},
      expectedIds,
      reason: 'the store must publish the emitted snapshot',
    );
  }
}

Future<_Harness> _openHarness(WidgetTester tester) async {
  final source = _ControlledSource();
  // The database and the store are created in the real-async zone: their
  // queries would otherwise wait on timers that fake async never fires.
  final (database, store) = (await tester.runAsync(() async {
    final database = openTestDatabase();
    final store = CatalogStore(database: database, realtimeSource: source);
    await store.loadFromAsset();
    return (database, store);
  }))!;
  addTearDown(() async {
    store.dispose();
    await tester.runAsync(() async {
      await source.controller.close();
      await database.close();
    });
  });
  return _Harness(tester, store, source);
}

Widget _app(CatalogStore store, Widget home) => StoreScope(
      notifier: store,
      child: MaterialApp(theme: buildTheme(), home: home),
    );

/// Root route -> intermediate route -> product page for [productId].
Widget _stackedApp(CatalogStore store, String productId) {
  return _app(
    store,
    Builder(
      builder: (context) => Scaffold(
        body: Column(
          children: [
            const Text('RAÍZ'),
            TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    body: Column(
                      children: [
                        const Text('INTERMEDIA'),
                        TextButton(
                          onPressed: () => Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ProductScreen(productId: productId),
                            ),
                          ),
                          child: const Text('abrir ficha'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              child: const Text('abrir intermedia'),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _openStackedProduct(WidgetTester tester) async {
  await tester.tap(find.text('abrir intermedia'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('abrir ficha'));
  await tester.pumpAndSettle();
}

void _usePhoneSurface(WidgetTester tester) {
  addTearDown(() => tester.view.resetPhysicalSize());
  addTearDown(() => tester.view.resetDevicePixelRatio());
  tester.view.physicalSize = const Size(390, 1200);
  tester.view.devicePixelRatio = 1.0;
}

void _expectUnavailableState() {
  expect(find.text(_unavailableTitle), findsOneWidget);
  expect(find.text(_exploreLabel), findsOneWidget);
  expect(find.text(_backLabel), findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'CHAR-01 product page shows the unavailable state when its product '
    'leaves the live catalog',
    (tester) async {
      _usePhoneSurface(tester);
      final harness = await _openHarness(tester);
      final store = harness.store;
      const title = 'Satchel Aurora Dorado';
      final leaving = _document('111', title);
      final remaining = _document('222', 'Cartera Boreal Marino');

      await harness.emit([leaving, remaining]);
      await tester.pumpWidget(
        _app(
          store,
          const ProductScreen(productId: 'gid://shopify/Product/111'),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(title), findsWidgets);
      expect(find.text(_unavailableTitle), findsNothing);

      await harness.emit([remaining]);
      await tester.pump();

      expect(tester.takeException(), isNull);
      _expectUnavailableState();
    },
  );

  testWidgets(
    'CHAR-01 product page shows the unavailable state for an id that was '
    'never in the catalog',
    (tester) async {
      final harness = await _openHarness(tester);
      final store = harness.store;
      expect(
        store.products.any((item) => item.id == _missingProductId),
        isFalse,
      );

      await tester.pumpWidget(
        _app(store, const ProductScreen(productId: _missingProductId)),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      _expectUnavailableState();
    },
  );

  testWidgets(
    'CHAR-01 "Volver" closes the unavailable product page and shows the '
    'previous screen',
    (tester) async {
      final harness = await _openHarness(tester);

      await tester.pumpWidget(_stackedApp(harness.store, _missingProductId));
      await _openStackedProduct(tester);
      expect(tester.takeException(), isNull);
      _expectUnavailableState();

      await tester.tap(find.text(_backLabel));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ProductScreen), findsNothing);
      expect(find.text('INTERMEDIA'), findsOneWidget);
      expect(find.text('RAÍZ'), findsNothing);
    },
  );

  testWidgets(
    'CHAR-01 "Explorar el catálogo" returns to the first route',
    (tester) async {
      final harness = await _openHarness(tester);

      await tester.pumpWidget(_stackedApp(harness.store, _missingProductId));
      await _openStackedProduct(tester);
      expect(tester.takeException(), isNull);
      _expectUnavailableState();

      await tester.tap(find.text(_exploreLabel));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ProductScreen), findsNothing);
      expect(find.text('INTERMEDIA'), findsNothing);
      expect(find.text('RAÍZ'), findsOneWidget);
    },
  );

  testWidgets(
    'CHAR-01 product page shows the product again when it returns to the '
    'catalog',
    (tester) async {
      _usePhoneSurface(tester);
      final harness = await _openHarness(tester);
      final store = harness.store;
      const title = 'Satchel Aurora Dorado';
      final returning = _document('111', title);
      final other = _document('222', 'Cartera Boreal Marino');

      await harness.emit([returning, other]);
      await tester.pumpWidget(
        _app(
          store,
          const ProductScreen(productId: 'gid://shopify/Product/111'),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(title), findsWidgets);

      await harness.emit([other]);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text(_unavailableTitle), findsOneWidget);

      await harness.emit([returning, other]);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text(_unavailableTitle), findsNothing);
      expect(find.text(title), findsWidgets);
    },
  );
}
