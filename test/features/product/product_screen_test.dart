import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/media/monetta_image.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/features/product/product_screen.dart';
import 'package:monetta_app/main.dart';

Future<CatalogStore> _loadedStore() async {
  final store = CatalogStore(database: openTestDatabase());
  await store.loadFromAsset();
  return store;
}

void main() {
  testWidgets('product hero covers the complete detail viewport', (
    tester,
  ) async {
    final store = await _loadedStore();
    final product = store.products.firstWhere(
      (item) => item.isInStock && item.images.isNotEmpty,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: StoreScope(
          notifier: store,
          child: ProductScreen(productId: product.id),
        ),
      ),
    );

    final heroImage = find.descendant(
      of: find.byType(InteractiveViewer),
      matching: find.byType(MonettaImage),
    );
    expect(heroImage, findsOneWidget);
    // Package C (Fig.07): the photo is contained so handles and straps are
    // never cropped — `cover` is the bug this asserts against.
    expect(tester.widget<MonettaImage>(heroImage).fit, BoxFit.contain);
  });

  testWidgets('product page sells with facts, not internal facets', (
    tester,
  ) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    final product = store.products.firstWhere((item) => item.isInStock);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: StoreScope(
          notifier: store,
          child: ProductScreen(productId: product.id),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(product.title), findsWidgets);
    expect(find.text('Agregar al carrito'), findsOneWidget);
    expect(find.text('Comprar ahora'), findsOneWidget);
    // UI v4.1: apartados wait for confirmed rules; the ficha offers none.
    expect(find.text('Apartar'), findsNothing);
    expect(find.text('Gama'), findsNothing);
    expect(find.text('extracted'), findsNothing);
    expect(find.textContaining('Popular ahora'), findsNothing);
  });

  testWidgets('add to bag confirms on the ficha without opening the cart', (
    tester,
  ) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    final product = store.products.firstWhere((item) => item.isInStock);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: StoreScope(
          notifier: store,
          child: ProductScreen(productId: product.id),
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('Agregar al carrito'));
    await tester.pump();
    await tester.tap(find.text('Agregar al carrito'));
    await tester.pumpAndSettle();

    expect(store.bagQuantity, 1);
    // UI v4.1: «Agregar conserva PDP» — the confirmation stays on the page.
    expect(find.text('Agregado al carrito'), findsOneWidget);
    expect(find.text('En tu bolsa'), findsNothing);
    expect(find.byType(ProductScreen), findsOneWidget);
  });
}
