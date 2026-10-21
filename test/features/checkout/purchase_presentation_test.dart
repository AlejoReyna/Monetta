import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/main.dart';
import 'package:monetta_app/features/checkout/order_confirmation_screen.dart';
import 'package:monetta_app/features/checkout/purchase_notices.dart';

import '../../support/client_guide_capture.dart';

void main() {
  for (final (size, scale, brightness) in [
    (const Size(390, 844), 1.0, Brightness.light),
    (const Size(320, 568), 2.0, Brightness.light),
    (const Size(834, 1194), 1.0, Brightness.light),
    (const Size(390, 844), 1.0, Brightness.dark),
  ]) {
    testWidgets('purchase confirmation actions at $size / $scale / $brightness',
        (tester) async {
      var viewed = false;
      final db = openTestDatabase();
      final store = CatalogStore(database: db);
      addTearDown(() async {
        store.dispose();
        await db.close();
      });
      await pumpClientGuide(
        tester,
        StoreScope(
          notifier: store,
          child: OrderConfirmationScreen(
            orderLabel: '#DEMO-1',
            onViewOrder: () => viewed = true,
          ),
        ),
        size: size,
        textScale: scale,
        brightness: brightness,
      );
      expect(find.text('¡Gracias por tu compra!'), findsOneWidget);
      expect(find.text('#DEMO-1'), findsOneWidget);
      expect(
        find.textContaining('contenido pendiente de aprobación'),
        findsOneWidget,
      );
      expect(find.textContaining('3 a 5'), findsNothing);
      expect(tester.takeException(), isNull);
      if (scale == 1) {
        await captureClientGuide(
          tester,
          'purchase-${size.width.toInt()}-${brightness.name}',
        );
      }
      final action = find.text('Ver detalles del pedido');
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      expect(viewed, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('without active method config names only hosted provider',
      (tester) async {
    await pumpClientGuide(tester, const Scaffold(body: SecurePaymentLine()));
    expect(find.text('Pagos seguros con Shopify.'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.textContaining('PayPal'), findsNothing);
  });

  testWidgets('payment trust line lists only supplied active methods',
      (tester) async {
    await pumpClientGuide(
      tester,
      const Scaffold(
        body: SecurePaymentLine(methods: ['Transferencia bancaria']),
      ),
    );
    expect(
      find.text('Pagos seguros con Shopify · Transferencia bancaria'),
      findsOneWidget,
    );
    expect(find.textContaining('Visa'), findsNothing);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('home action dismisses confirmation to the existing root',
      (tester) async {
    await pumpClientGuide(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const OrderConfirmationScreen(),
              ),
            ),
            child: const Text('Open fixture'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open fixture'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Volver al inicio'));
    await tester.tap(find.text('Volver al inicio'));
    await tester.pumpAndSettle();
    expect(find.byType(OrderConfirmationScreen), findsNothing);
    expect(find.text('Open fixture'), findsOneWidget);
  });
}
