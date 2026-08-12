import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/features/checkout/checkout_screen.dart';
import 'package:monetta_app/main.dart';

Future<CatalogStore> _loadedStore() async {
  final store = CatalogStore();
  await store.loadFromAsset();
  return store;
}

Widget _app(CatalogStore store, Widget child) {
  return MaterialApp(
    theme: buildTheme(),
    home: StoreScope(notifier: store, child: child),
  );
}

void main() {
  testWidgets('an empty bag offers a clear route back to shopping',
      (tester) async {
    final store = await _loadedStore();
    await tester.pumpWidget(_app(store, const BagScreen()));

    expect(find.text('Tu bolsa está vacía'), findsOneWidget);
    expect(find.text('SEGUIR DESCUBRIENDO'), findsOneWidget);
  });

  testWidgets('bag quantities stay editable and update the order total',
      (tester) async {
    final store = await _loadedStore();
    final product = store.products.firstWhere((item) => item.isInStock);
    store.addToBag(product);

    await tester.pumpWidget(_app(store, const BagScreen()));
    await tester.pump();

    expect(find.text('Tu bolsa'), findsOneWidget);
    expect(find.text(product.title), findsOneWidget);
    expect(find.text('CONTINUAR A ENTREGA'), findsOneWidget);
    expect(store.bagQuantity, 1);

    await tester.tap(find.byTooltip('Agregar uno'));
    await tester.pump();

    expect(store.bagQuantity, 2);
    expect(find.text('2'), findsWidgets);
  });

  testWidgets('guest delivery leads to review and the secure Shopify handoff',
      (tester) async {
    final store = await _loadedStore();
    store.addToBag(store.products.firstWhere((item) => item.isInStock));

    await tester.pumpWidget(_app(store, const CheckoutFlowScreen()));
    await tester.pump();

    expect(find.text('¿Dónde lo enviamos?'), findsOneWidget);
    expect(
      find.text(
        'Compra como invitado. Solo pedimos lo necesario para entregar tu pedido.',
      ),
      findsOneWidget,
    );

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(8));
    await tester.enterText(fields.at(0), 'ana@example.com');
    await tester.enterText(fields.at(1), '8112345678');
    await tester.enterText(fields.at(2), 'Ana García');
    await tester.enterText(fields.at(3), 'Río Pánuco 123');
    await tester.enterText(fields.at(4), 'Del Valle');
    await tester.enterText(fields.at(5), '66220');
    await tester.enterText(fields.at(6), 'San Pedro Garza García');
    await tester.enterText(fields.at(7), 'Nuevo León');

    await tester.ensureVisible(find.text('REVISAR PEDIDO'));
    await tester.tap(find.text('REVISAR PEDIDO'));
    await tester.pumpAndSettle();

    expect(find.text('Todo listo'), findsOneWidget);
    expect(find.text('CONTINUAR AL PAGO SEGURO'), findsOneWidget);
    expect(find.textContaining('Shopify procesa el pago'), findsOneWidget);

    await tester.ensureVisible(find.text('CONTINUAR AL PAGO SEGURO'));
    await tester.tap(find.text('CONTINUAR AL PAGO SEGURO'));
    await tester.pumpAndSettle();

    expect(find.text('Pago protegido'), findsOneWidget);
    expect(find.textContaining('Este prototipo termina'), findsOneWidget);
  });
}
