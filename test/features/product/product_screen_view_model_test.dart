/// RF-41: how `ProductScreen` owns its ViewModel (lifecycle, rebuilds and what
/// a new `productId` or `initialVariantIndex` does; rendering is pinned by the
/// existing product tests).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/product/product_screen.dart';
import 'package:monetta_app/features/product/product_selection.dart';
import 'package:monetta_app/main.dart';
import 'package:monetta_app/reco/events.dart';

import '../../support/product_screen_harness.dart'
    show chipVariants, mockPathProvider, optionChip, scrollTo, syntheticProduct;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CountingStore store;

  setUp(() async {
    mockPathProvider();
    store = _CountingStore(database: openTestDatabase());
    await store.loadFromAsset();
  });

  tearDown(() => store.dispose());

  int selectedIndexOf(WidgetTester tester) => tester
      .widget<ProductOptionSelector>(find.byType(ProductOptionSelector))
      .selectedIndex!;

  testWidgets('RF-41 ProductScreen releases its listeners when it is removed',
      (tester) async {
    final storeBefore = store.listeners;
    final product = store.products.first;

    await tester.pumpWidget(
      _app(store, ProductScreen(productId: product.id)),
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
      'RF-41 ProductScreen does not rebuild itself for a notification that '
      'does not concern it', (tester) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(375, 812) * 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final shown = store.products.first;
    final other = store.products.lastWhere((p) => p.id != shown.id);
    await tester.pumpWidget(
      _app(store, ProductScreen(productId: shown.id)),
    );
    await tester.pump();
    final counter = RebuildCounter(
      tester.element(find.byType(ProductScreen)),
    )..start();
    addTearDown(counter.stop);

    store.record(
      EventType.galleryInteraction,
      productId: other.id,
    );
    await tester.pump();
    counter.stop();

    expect(counter.own, 0);
  });

  testWidgets(
      'RF-41 ProductScreen shows the unavailable state when its product '
      'leaves the catalog and the product when it returns', (tester) async {
    final shown = store.products.first;
    final remaining = store.products.where((p) => p.id != shown.id).toList();

    await tester.pumpWidget(
      _app(store, ProductScreen(productId: shown.id)),
    );
    await tester.pump();
    expect(find.byKey(const Key('purchase-dock-primary')), findsOneWidget);

    store.products = remaining;
    store.record(
      EventType.galleryInteraction,
      productId: remaining.first.id,
    );
    await tester.pump();

    expect(find.text('Este artículo ya no está disponible'), findsOneWidget);

    store.products = <Product>[...remaining, shown];
    store.record(
      EventType.galleryInteraction,
      productId: remaining.first.id,
    );
    await tester.pump();

    expect(find.text('Este artículo ya no está disponible'), findsNothing);
    expect(find.byKey(const Key('purchase-dock-primary')), findsOneWidget);
  });

  testWidgets(
      'RF-41 ProductScreen keeps the chosen variant when rebuilt with another '
      'product and initialVariantIndex', (tester) async {
    final a = syntheticProduct(
      id: 'gid://shopify/Product/rf41-a',
      title: 'Bolso A',
      variants: chipVariants(),
    );
    final b = syntheticProduct(
      id: 'gid://shopify/Product/rf41-b',
      title: 'Bolso B',
      variants: chipVariants(),
    );
    store.products = <Product>[a, b];

    await tester.pumpWidget(
      _app(store, ProductScreen(productId: a.id, initialVariantIndex: 1)),
    );
    await tester.pump();
    await scrollTo(tester, find.text('OPCIÓN'));
    expect(selectedIndexOf(tester), 1);

    // Same State, other piece and other initial index: the piece follows the
    // widget, the shopper's choice stays.
    await tester.pumpWidget(
      _app(store, ProductScreen(productId: b.id, initialVariantIndex: 0)),
    );
    await tester.pump();

    expect(find.text('Bolso B'), findsWidgets);
    expect(find.text('Bolso A'), findsNothing);
    await scrollTo(tester, find.text('OPCIÓN'));
    expect(selectedIndexOf(tester), 1);
  });

  testWidgets(
      'RF-41 ProductScreen picks the tapped option through the ViewModel',
      (tester) async {
    final product = syntheticProduct(
      id: 'gid://shopify/Product/rf41-opts',
      title: 'Bolso de opciones',
      variants: chipVariants(),
    );
    store.products = <Product>[product];

    await tester.pumpWidget(
      _app(store, ProductScreen(productId: product.id)),
    );
    await tester.pump();
    await scrollTo(tester, optionChip('Talla chica'));
    expect(selectedIndexOf(tester), 0);

    await scrollTo(tester, optionChip('Talla mediana'));
    await tester.tap(optionChip('Talla mediana'));
    await tester.pump();

    expect(selectedIndexOf(tester), 1);
  });
}
