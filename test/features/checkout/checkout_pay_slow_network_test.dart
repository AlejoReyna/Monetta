import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/shopify/cart/checkout_launcher.dart';
import 'package:monetta_app/features/checkout/checkout_screen.dart';
import 'package:monetta_app/main.dart';

// Regresión del ticket "Pagar no aparece en 3G": el botón de pago vive en el
// paso de revisión (después del contacto) y, con una red lenta, el lanzador
// se invoca una sola vez y siempre termina en un estado accionable.
void main() {
  testWidgets(
    'Pagar aparece tras REVISAR PEDIDO, abre un solo checkout y no se queda '
    'esperando para siempre cuando Shopify responde tarde con error',
    (tester) async {
      final store = CatalogStore(database: openTestDatabase());
      await store.loadFromAsset();
      await store.addToBag(store.products.firstWhere((p) => p.isInStock));

      var calls = 0;
      final pending = Completer<CheckoutResult>();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: StoreScope(
            notifier: store,
            child: CheckoutFlowScreen(
              launchSecureCheckout: (draft) {
                calls++;
                return pending.future;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      final pay = find.byKey(const ValueKey('checkout-pay-button'));
      expect(pay, findsNothing, reason: 'Pagar requiere el paso de contacto');

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'qa@example.com');
      await tester.enterText(fields.at(1), '5550000000');
      await tester.ensureVisible(find.text('REVISAR PEDIDO'));
      await tester.tap(find.text('REVISAR PEDIDO'));
      await tester.pumpAndSettle();
      expect(pay, findsOneWidget);

      await tester.ensureVisible(pay);
      for (var i = 0; i < 3; i++) {
        await tester.tap(pay, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 40));
      }
      expect(calls, 1, reason: 'triple toque abre un solo checkout');
      expect(find.textContaining('Abriendo checkout seguro'), findsOneWidget);

      pending.complete(
        const CheckoutFailed(
          code: CheckoutFailureCode.configuration,
          userMessage: 'No fue posible abrir el checkout. Tu bolsa se conserva.',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Abriendo checkout seguro'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
