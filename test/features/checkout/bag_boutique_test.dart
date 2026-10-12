import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/media/monetta_image.dart';
import 'package:monetta_app/app/motion.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/shopify/cart/checkout_launcher.dart';
import 'package:monetta_app/features/checkout/checkout_screen.dart';
import 'package:monetta_app/features/checkout/mini_cart.dart';
import 'package:monetta_app/main.dart';

Future<CatalogStore> _loadedStore() async {
  final store = CatalogStore(database: openTestDatabase());
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
  test('free-shipping incentive covers empty, partial and complete', () {
    expect(remainingForFreeShipping(0), kFreeShippingThreshold);
    expect(
      remainingForFreeShipping(kFreeShippingThreshold - 1),
      1,
    );
    expect(remainingForFreeShipping(kFreeShippingThreshold), 0);
    expect(remainingForFreeShipping(kFreeShippingThreshold + 500), 0);
    expect(shippingFor(0), kStandardShippingFee);
    expect(shippingFor(kFreeShippingThreshold), 0);
  });

  testWidgets('bag shows incentive, remove action and recommendations',
      (tester) async {
    final store = await _loadedStore();
    final product = store.products.firstWhere((item) => item.isInStock);
    await store.addToBag(product);

    await tester.pumpWidget(_app(store, const BagScreen()));
    await tester.pump();

    // Header title plus the in-body heading share the label.
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Mi bolsa'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('free-shipping-incentive')),
      findsOneWidget,
    );
    // Incentivo real: o faltante o gratis, nunca cifra inventada.
    expect(
      find.textContaining(
        RegExp(r'(Te faltan|Tienes envío gratis)'),
      ),
      findsWidgets,
    );
    // Solo Eliminar: sin Guardar para después.
    expect(find.text('Guardar para después'), findsNothing);
    expect(find.text('Eliminar'), findsOneWidget);
    // Recomendaciones con ProductCard de lectura.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('bag-recommendations')),
      400,
    );
    expect(
      find.byKey(const ValueKey('bag-recommendations')),
      findsOneWidget,
    );
  });

  testWidgets('bag remove action empties the line', (tester) async {
    final store = await _loadedStore();
    final product = store.products.firstWhere((item) => item.isInStock);
    await store.addToBag(product);

    await tester.pumpWidget(_app(store, const BagScreen()));
    await tester.pump();

    await tester.tap(find.text('Eliminar'));
    await tester.pump();
    expect(store.bagLines, isEmpty);
    expect(find.text('Tu bolsa está vacía'), findsOneWidget);
  });

  testWidgets('quantity zero removes the line; large values clamp to 10',
      (tester) async {
    final store = await _loadedStore();
    final product = store.products.firstWhere((item) => item.isInStock);
    await store.addToBag(product);
    final variantId = store.bagLines.single.variant.id;

    await store.updateBagQuantity(variantId, 99);
    expect(store.bagLines.single.quantity, 10);

    await tester.pumpWidget(_app(store, const BagScreen()));
    await tester.pump();
    // Al tope, el stepper deshabilita agregar.
    final add = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Agregar uno',
    );
    expect(add, findsOneWidget);
    expect(tester.widget<IconButton>(add).onPressed, isNull);

    await store.updateBagQuantity(variantId, 0);
    expect(store.bagLines, isEmpty);
  });

  testWidgets('missing image never breaks the bag row', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MonettaImage(url: null)),
      ),
    );
    await tester.pump();
    // El fallback honesto se dibuja en vez de un hueco o una excepción.
    expect(find.byType(MonettaImage), findsOneWidget);
  });

  testWidgets('review lists no invented payment methods', (tester) async {
    final store = await _loadedStore();
    await store.addToBag(store.products.firstWhere((item) => item.isInStock));

    await tester.pumpWidget(
      _app(
        store,
        CheckoutFlowScreen(
          launchSecureCheckout: (_) async => const CheckoutCancelled(),
        ),
      ),
    );
    await tester.pump();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'buyer@example.invalid');
    await tester.enterText(fields.at(1), '8112345678');
    await tester.ensureVisible(find.text('REVISAR PEDIDO'));
    await tester.tap(find.text('REVISAR PEDIDO'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('payment-hosted-notice')), findsOneWidget);
    expect(find.textContaining('Tarjeta de crédito'), findsNothing);
    expect(find.textContaining('PayPal'), findsNothing);
    expect(find.textContaining('Mercado Pago'), findsNothing);
    expect(find.textContaining('Oxxo'), findsNothing);
    expect(find.textContaining('Meses'), findsNothing);
  });

  testWidgets('failed launch preserves the bag and explains the browser',
      (tester) async {
    final store = await _loadedStore();
    await store.addToBag(store.products.firstWhere((item) => item.isInStock));

    await tester.pumpWidget(
      _app(
        store,
        CheckoutFlowScreen(
          launchSecureCheckout: (_) async => const CheckoutFailed(
            code: CheckoutFailureCode.unavailable,
            userMessage: 'No fue posible abrir el checkout.',
          ),
          openExternalCheckout: () async => true,
        ),
      ),
    );
    await tester.pump();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'buyer@example.invalid');
    await tester.enterText(fields.at(1), '8112345678');
    await tester.ensureVisible(find.text('REVISAR PEDIDO'));
    await tester.tap(find.text('REVISAR PEDIDO'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('CONTINUAR AL PAGO SEGURO'));
    await tester.tap(find.text('CONTINUAR AL PAGO SEGURO'));
    await tester.pumpAndSettle();

    expect(store.bagQuantity, 1);
    expect(
      find.textContaining('no confirma el pago'),
      findsOneWidget,
    );
    // Volver del navegador jamás confirma: seguimos en revisión, sin éxito.
    expect(find.text('¡Listo!'), findsNothing);
  });

  testWidgets('mini cart shows the added line and both exits', (tester) async {
    final store = await _loadedStore();
    final product = store.products.firstWhere((item) => item.isInStock);
    await store.addToBag(product);

    await tester.pumpWidget(_app(store, const MiniCartSheet()));
    await tester.pump();

    expect(find.text('En tu bolsa'), findsOneWidget);
    expect(find.text(product.title), findsOneWidget);
    expect(find.text('VER BOLSA'), findsOneWidget);
    expect(find.text('Seguir viendo'), findsOneWidget);
  });

  testWidgets('bag survives small/large surfaces, big text and dark',
      (tester) async {
    final store = await _loadedStore();
    await store.addToBag(store.products.firstWhere((item) => item.isInStock));

    for (final size in const [Size(360, 640), Size(430, 932)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData().copyWith(
            textScaler: const TextScaler.linear(1.3),
            platformBrightness: Brightness.dark,
          ),
          child: MaterialApp(
            theme: buildTheme(brightness: Brightness.dark),
            home: StoreScope(notifier: store, child: const BagScreen()),
          ),
        ),
      );
      await tester.pump();
      // Header title plus the in-body heading share the label.
      expect(find.text('Mi bolsa'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });
}
