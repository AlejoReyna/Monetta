import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/cart_controller.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/shopify/cart/cart_repository.dart';
import 'package:monetta_app/data/shopify/cart/cart_api.dart';
import 'package:monetta_app/data/shopify/cart/cart_session_store.dart';
import 'package:monetta_app/data/shopify/cart/checkout_launcher.dart';
import 'package:monetta_app/features/boutique/boutique_tokens.dart';
import 'package:monetta_app/features/checkout/checkout_screen.dart';
import 'package:monetta_app/main.dart';

// Regresión S2 (Payments tester, slow 3G): Pagar se tocaba con el carrito en
// `syncing`. Pagar solo se habilita cuando Shopify confirmó el carrito.

const _shop = 'monetta-test.myshopify.com';

final class _QueuedReconciler implements CartReconciler {
  final pending = <Completer<CartReconciliation>>[];

  @override
  Future<CartReconciliation> reconcile({
    required CartSessionScope scope,
    required Iterable<LocalCartIntent> localIntent,
    CartBuyerIdentity? buyerIdentity,
    List<String>? desiredDiscountCodes,
  }) {
    final c = Completer<CartReconciliation>();
    pending.add(c);
    return c.future;
  }
}

CartReconciliation _ready() => CartReconciliation(
      status: CartReconciliationStatus.authoritative,
      cart: null,
    );

void main() {
  late CatalogStore store;
  late _QueuedReconciler reconciler;
  late CartController controller;
  late int calls;
  late Completer<CheckoutResult> sheet;

  Future<void> pumpReview(WidgetTester tester) async {
    // Creado dentro de la zona del test para que pump() drene su futuro.
    sheet = Completer<CheckoutResult>();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: CartScope(
          shopDomain: _shop,
          notifier: controller,
          child: StoreScope(
            notifier: store,
            child: CheckoutFlowScreen(
              launchSecureCheckout: (draft) {
                calls++;
                return sheet.future;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'qa@example.com');
    await tester.enterText(fields.at(1), '5550000000');
    await tester.ensureVisible(find.text('REVISAR PEDIDO'));
    await tester.tap(find.text('REVISAR PEDIDO'));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> startSync() async {
    unawaited(
      controller.reconcileLocalBag(
        scope: const CartSessionScope.guest(shopDomain: _shop),
        localIntent: const [],
      ),
    );
  }

  BoutiqueButton payButton(WidgetTester tester) =>
      tester.widget<BoutiqueButton>(
        find.byKey(const ValueKey('checkout-pay-button')),
      );

  setUp(() async {
    store = CatalogStore(database: openTestDatabase());
    await store.loadFromAsset();
    await store.addToBag(store.products.firstWhere((p) => p.isInStock));
    reconciler = _QueuedReconciler();
    controller = CartController(reconciler: reconciler);
    calls = 0;
  });

  testWidgets(
      'Pagar deshabilitado con indicador mientras sincroniza; tocar no '
      'abre checkout; se habilita al estar listo y triple toque abre uno',
      (tester) async {
    await startSync();
    await pumpReview(tester);
    final pay = find.byKey(const ValueKey('checkout-pay-button'));
    expect(pay, findsOneWidget);
    expect(payButton(tester).onPressed, isNull);
    expect(payButton(tester).busy, isTrue);
    expect(
      find.bySemanticsLabel('Confirmando tu bolsa con Shopify'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('checkout-total-unconfirmed')),
      findsOneWidget,
    );

    await tester.ensureVisible(pay);
    for (var i = 0; i < 3; i++) {
      await tester.tap(pay, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(calls, 0, reason: 'tocar Pagar durante syncing no hace nada');

    reconciler.pending.single.complete(_ready());
    await tester.pump();
    expect(controller.status, CartControllerStatus.ready);
    expect(payButton(tester).onPressed, isNotNull);
    expect(payButton(tester).busy, isFalse);
    expect(
      find.byKey(const ValueKey('checkout-total-unconfirmed')),
      findsNothing,
    );

    for (var i = 0; i < 3; i++) {
      await tester.tap(pay, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(calls, 1, reason: 'triple toque abre un solo checkout');

    sheet.complete(
      const CheckoutFailed(
        code: CheckoutFailureCode.configuration,
        userMessage: 'No fue posible abrir el checkout. Tu bolsa se conserva.',
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Abriendo checkout seguro'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'con error de sincronización Pagar sigue deshabilitado, muestra '
      'el error y REINTENTAR vuelve a sincronizar', (tester) async {
    await startSync();
    await pumpReview(tester);
    reconciler.pending.single.completeError(Exception('timeout'));
    await tester.pump();
    expect(controller.status, CartControllerStatus.error);
    expect(payButton(tester).onPressed, isNull);
    expect(payButton(tester).busy, isFalse);
    expect(
      find.text('No fue posible sincronizar tu bolsa en este momento.'),
      findsOneWidget,
    );

    final pay = find.byKey(const ValueKey('checkout-pay-button'));
    await tester.ensureVisible(pay);
    await tester.tap(pay, warnIfMissed: false);
    await tester.pump();
    expect(calls, 0);

    final retry = find.byKey(const ValueKey('checkout-cart-sync-retry'));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pump();
    expect(reconciler.pending, hasLength(2));
    expect(controller.status, CartControllerStatus.syncing);
    expect(payButton(tester).onPressed, isNull);

    reconciler.pending.last.complete(_ready());
    await tester.pump();
    expect(payButton(tester).onPressed, isNotNull);
    expect(
      find.byKey(const ValueKey('checkout-cart-sync-error')),
      findsNothing,
    );
  });
}
