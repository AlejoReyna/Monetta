/// RF-41: how `CollectionScreen` owns its ViewModel (lifecycle, rebuilds and
/// what a new `filter` or `title` does; rendering is pinned by
/// `collection_screen_test.dart`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/catalog/product_card.dart';
import 'package:monetta_app/features/catalog/query/collection_filter.dart';
import 'package:monetta_app/features/navigation/monetta_bottom_navigation.dart';
import 'package:monetta_app/main.dart';
import 'package:monetta_app/reco/events.dart';

import '../../support/product_screen_harness.dart' show mockPathProvider;
import '../../support/rebuild_counter.dart';

class _CountingStore extends CatalogStore {
  _CountingStore({required super.database});

  int listeners = 0;

  @override
  void addListener(VoidCallback listener) {
    listeners++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    listeners--;
    super.removeListener(listener);
  }
}

Widget _app(_CountingStore store, Widget? screen) => StoreScope(
      notifier: store,
      child: MaterialApp(
        theme: buildLightTheme(),
        home: screen ?? const SizedBox.shrink(),
      ),
    );

Product _extraProduct() => Product(
      id: 'gid://shopify/Product/rf41-collection',
      handle: 'rf41-collection',
      title: 'Bolso de prueba RF-41',
      vendor: 'Monetta',
      productType: 'Bolsa',
      tags: const <String>[],
      images: const <String>['https://cdn.example/x.jpg'],
      createdAt: DateTime.utc(2030),
      updatedAt: DateTime.utc(2030),
      collectionHandles: const <String>['rf41'],
      variants: const <ProductVariant>[
        ProductVariant(
          id: 'gid://shopify/ProductVariant/rf41-collection',
          title: 'Unica',
          price: 100,
          available: true,
        ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CountingStore store;

  setUp(() async {
    mockPathProvider();
    store = _CountingStore(database: openTestDatabase());
    await store.loadFromAsset();
  });

  tearDown(() => store.dispose());

  List<String> visibleIds(WidgetTester tester) => tester
      .widgetList<ProductCard>(find.byType(ProductCard))
      .map((card) => card.product.id)
      .toList();

  Future<void> applyInStockOnly(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('collection-filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('collection-filter-availability')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('collection-filter-stock')));
    await tester.tap(find.byKey(const Key('collection-filter-apply')));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'RF-41 CollectionScreen releases its listeners when it is removed',
      (tester) async {
    final storeBefore = store.listeners;

    await tester.pumpWidget(
      _app(
        store,
        const CollectionScreen(
          title: 'Bolsas',
          filter: CollectionFilter(category: 'bolsa'),
        ),
      ),
    );
    // The StoreScope inherited notifier is a listener of its own.
    final mounted = store.listeners;
    expect(mounted, greaterThan(storeBefore + 1));

    await tester.pumpWidget(_app(store, null));

    expect(
      store.listeners,
      storeBefore + 1,
      reason: 'only the StoreScope itself still listens to the store',
    );
  });

  testWidgets(
      'RF-41 CollectionScreen does not rebuild itself for a notification that '
      'does not concern it', (tester) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(375, 812) * 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        store,
        const CollectionScreen(
          title: 'Bolsas',
          filter: CollectionFilter(category: 'bolsa'),
        ),
      ),
    );
    await tester.pump();
    final counter = RebuildCounter(
      tester.element(find.byType(CollectionScreen)),
    )..start();
    addTearDown(counter.stop);

    store.record(
      EventType.galleryInteraction,
      productId: store.products.last.id,
    );
    await tester.pump();
    counter.stop();

    expect(counter.own, 0);
  });

  testWidgets('RF-41 CollectionScreen draws a product that joins the scope',
      (tester) async {
    await tester.pumpWidget(
      _app(
        store,
        const CollectionScreen(
          title: 'Nuevo',
          filter: CollectionFilter(collectionHandle: 'rf41'),
        ),
      ),
    );
    await tester.pump();
    final extra = _extraProduct();
    expect(visibleIds(tester), isNot(contains(extra.id)));

    store.products = <Product>[...store.products, extra];
    store.record(EventType.galleryInteraction, productId: extra.id);
    await tester.pump();

    expect(visibleIds(tester).first, extra.id);
  });

  testWidgets('RF-41 CollectionScreen follows the bag count in its bottom bar',
      (tester) async {
    await tester.pumpWidget(
      _app(
        store,
        const CollectionScreen(
          title: 'Bolsas',
          filter: CollectionFilter(category: 'bolsa'),
        ),
      ),
    );
    await tester.pump();
    int bagCount() => tester
        .widget<MonettaBottomNavigation>(find.byType(MonettaBottomNavigation))
        .bagCount;
    expect(bagCount(), 0);

    await tester.runAsync(() => store.addToBag(store.products.first));
    await tester.pump();

    expect(bagCount(), 1);
  });

  testWidgets(
      'RF-41 CollectionScreen keeps the applied filters when rebuilt with '
      'another filter and title', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        store,
        const CollectionScreen(
          title: 'Bolsas',
          filter: CollectionFilter(category: 'bolsa'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final bagIds = visibleIds(tester);
    await applyInStockOnly(tester);
    expect(find.byKey(const Key('collection-filter-count')), findsOneWidget);
    final inStockBags = visibleIds(tester);

    // Same State, other destination: the scope and the title follow the
    // widget, the shopper's choice stays.
    await tester.pumpWidget(
      _app(
        store,
        const CollectionScreen(
          title: 'Relojes',
          filter: CollectionFilter(category: 'reloj'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Relojes'), findsWidgets);
    expect(find.text('Bolsas'), findsNothing);
    expect(find.byKey(const Key('collection-filter-count')), findsOneWidget);
    final watches = visibleIds(tester);
    expect(watches, isNotEmpty);
    expect(watches.toSet().intersection(bagIds.toSet()), isEmpty);
    expect(inStockBags, isNotEmpty);
    expect(
      tester
          .widgetList<ProductCard>(find.byType(ProductCard))
          .every((card) => card.product.isInStock),
      isTrue,
    );
  });

  testWidgets(
      'RF-41 CollectionScreen applies the sheet through the ViewModel and '
      'clears back to the destination', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        store,
        const CollectionScreen(
          title: 'Bolsas',
          filter: CollectionFilter(category: 'bolsa'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final initial = visibleIds(tester);

    await applyInStockOnly(tester);
    expect(find.byKey(const Key('collection-filter-count')), findsOneWidget);
    expect(find.byKey(const Key('collection-clear-inline')), findsOneWidget);

    await tester.tap(find.byKey(const Key('collection-clear-inline')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('collection-filter-count')), findsNothing);
    expect(find.byKey(const Key('collection-clear-inline')), findsNothing);
    expect(visibleIds(tester), initial);
  });
}
