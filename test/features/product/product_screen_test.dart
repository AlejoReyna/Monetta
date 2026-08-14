import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
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
  testWidgets('product page sells with facts, not internal facets',
      (tester) async {
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
    expect(find.text('AGREGAR A LA BOLSA'), findsOneWidget);
    expect(find.text('APARTAR · ANTICIPO \$400'), findsOneWidget);
    expect(find.text('Escribir por WhatsApp'), findsOneWidget);
    expect(find.text('Gama'), findsNothing);
    expect(find.text('extracted'), findsNothing);
    expect(find.textContaining('Popular ahora'), findsNothing);
  });

  testWidgets('add to bag opens the mini-cart instead of a toast',
      (tester) async {
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

    await tester.tap(find.text('AGREGAR A LA BOLSA'));
    await tester.pumpAndSettle();

    expect(store.bagQuantity, 1);
    expect(find.text('En tu bolsa'), findsOneWidget);
    expect(find.text('VER BOLSA'), findsOneWidget);
    expect(find.text('Agregado a la bolsa'), findsNothing);
  });
}
