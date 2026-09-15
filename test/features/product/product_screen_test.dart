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
  testWidgets('product hero covers the complete detail viewport',
      (tester) async {
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
    expect(find.text('APARTAR'), findsOneWidget);
    expect(
      find.text(
        'Escríbenos por WhatsApp para solicitar apartado (\$400 MXN · 20 días). Abrir el chat no reserva stock ni confirma el anticipo.',
      ),
      findsOneWidget,
    );
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
