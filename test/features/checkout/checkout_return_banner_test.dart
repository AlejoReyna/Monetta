import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/shopper_copy.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/shopify/cart/checkout_launcher.dart';
import 'package:monetta_app/features/boutique/boutique_tokens.dart';
import 'package:monetta_app/features/checkout/checkout_return.dart';
import 'package:monetta_app/features/checkout/checkout_return_banner.dart';
import 'package:monetta_app/features/checkout/checkout_screen.dart';
import 'package:monetta_app/main.dart';

void main() {
  testWidgets('confirming state shows the loading line and no retry', (
    tester,
  ) async {
    await tester.pumpWidget(_bannerHost(CheckoutReturnPhase.confirming));

    expect(find.text('Confirmando tu pago…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Intentar de nuevo'), findsNothing);
    expect(find.text(kCheckoutReturnViewOrdersLabel), findsNothing);
    _expectNoDeclineCopy();
  });

  testWidgets('banner 3 explains the uncertain payment and has no retry', (
    tester,
  ) async {
    var orders = 0;
    Uri? whatsApp;
    await tester.pumpWidget(
      _bannerHost(
        CheckoutReturnPhase.reviewing,
        onViewOrders: () => orders += 1,
        onWhatsApp: () => whatsApp = conciergeWhatsAppUri(),
      ),
    );

    expect(find.text('Estamos revisando tu pago'), findsOneWidget);
    expect(find.text(kCheckoutReturnReviewingBody), findsOneWidget);
    expect(find.text('Intentar de nuevo'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    _expectNoDeclineCopy();

    await tester.tap(find.text('Ver mis pedidos'));
    await tester.tap(find.text('Escríbenos por WhatsApp'));
    expect(orders, 1);
    expect(whatsApp?.host, 'wa.me');
    expect(whatsApp?.path, '/528261066868');
    expect(whatsApp.toString(), startsWith('https://wa.me/528261066868'));
  });

  testWidgets('banner 1 offers retry only after a capable miss', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      _bannerHost(
        CheckoutReturnPhase.paymentNotCompleted,
        onRetry: () => retries += 1,
      ),
    );

    expect(find.text('No se completó tu pago'), findsOneWidget);
    expect(find.text(kCheckoutReturnPaymentNotCompletedBody), findsOneWidget);
    expect(find.text('Intentar de nuevo'), findsOneWidget);
    expect(find.text(kCheckoutReturnViewOrdersLabel), findsNothing);
    _expectNoDeclineCopy();

    await tester.tap(find.text('Intentar de nuevo'));
    expect(retries, 1);
  });

  testWidgets('banner 2 offers retry when the sheet never opened', (
    tester,
  ) async {
    await tester.pumpWidget(
      _bannerHost(
        CheckoutReturnPhase.sheetDidNotOpen,
        onRetry: () {},
      ),
    );

    expect(find.text('No pudimos abrir el pago'), findsOneWidget);
    expect(find.text(kCheckoutReturnSheetDidNotOpenBody), findsOneWidget);
    expect(find.text('Intentar de nuevo'), findsOneWidget);
    expect(find.text('Estamos revisando tu pago'), findsNothing);
    _expectNoDeclineCopy();
  });

  testWidgets('timeout without correlation shows banner 3 and no retry', (
    tester,
  ) async {
    final store = await _loadedStore();
    await store.addToBag(store.products.firstWhere((item) => item.isInStock));
    final gate = Completer<CheckoutOrderMatch?>();
    Uri? openedWhatsApp;
    addTearDown(() {
      if (!gate.isCompleted) gate.complete(null);
    });

    await tester.pumpWidget(
      _flow(
        store,
        CheckoutFlowScreen(
          launchSecureCheckout: (_) async => const CheckoutCancelled(),
          orderLookup: _ScriptedLookup((_) => gate.future),
          orderLookupTimeout: Duration.zero,
          attemptIdentity: const CheckoutAttemptIdentity(cartToken: 'cart-1'),
          openUri: (uri) async {
            openedWhatsApp = uri;
            return true;
          },
        ),
      ),
    );
    await _openReview(tester);
    await tester.tap(find.byKey(const ValueKey('checkout-pay-button')));
    await tester.pump();

    expect(find.text('Confirmando tu pago…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('Intentar de nuevo'), findsNothing);
    expect(
      tester
          .widget<BoutiqueButton>(
            find.byKey(const ValueKey('checkout-pay-button')),
          )
          .onPressed,
      isNull,
    );

    gate.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('Estamos revisando tu pago'), findsOneWidget);
    expect(find.text('Intentar de nuevo'), findsNothing);
    expect(find.text('Ver mis pedidos'), findsOneWidget);
    expect(find.text('Escríbenos por WhatsApp'), findsOneWidget);
    expect(find.byKey(const ValueKey('checkout-pay-button')), findsNothing);
    expect(store.bagQuantity, 1);

    await tester.ensureVisible(find.text('Escríbenos por WhatsApp'));
    await tester.tap(find.text('Escríbenos por WhatsApp'));
    await tester.pump();
    expect(openedWhatsApp, conciergeWhatsAppUri());
    expect(
      openedWhatsApp.toString(),
      startsWith('https://wa.me/528261066868'),
    );
  });

  testWidgets('capable lookup with no match shows banner 1 and retry', (
    tester,
  ) async {
    final store = await _loadedStore();
    await store.addToBag(store.products.firstWhere((item) => item.isInStock));
    var calls = 0;

    await tester.pumpWidget(
      _flow(
        store,
        CheckoutFlowScreen(
          launchSecureCheckout: (_) async => const CheckoutFailed(
            code: CheckoutFailureCode.unknown,
            userMessage: 'ignored',
          ),
          orderLookup: _ScriptedLookup((attempt) async {
            calls += 1;
            expect(attempt.checkoutToken, 'chk-1');
            return null;
          }),
          orderLookupTimeout: Duration.zero,
          correlationAvailable: true,
          attemptIdentity:
              const CheckoutAttemptIdentity(checkoutToken: 'chk-1'),
        ),
      ),
    );
    await _openReview(tester);
    await tester.tap(find.byKey(const ValueKey('checkout-pay-button')));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('No se completó tu pago'), findsOneWidget);
    expect(
      find.text('No se hizo ningún cargo. Tus productos siguen en el carrito.'),
      findsOneWidget,
    );
    expect(find.text('Estamos revisando tu pago'), findsNothing);
    expect(find.text('No pudimos abrir el pago'), findsNothing);
    expect(find.text('Intentar de nuevo'), findsOneWidget);
    expect(
      tester
          .widget<BoutiqueButton>(
            find.byKey(const ValueKey('checkout-retry-button')),
          )
          .onPressed,
      isNotNull,
    );
    expect(store.bagQuantity, 1);
  });

  testWidgets('sheet failed to open shows its banner and does not poll', (
    tester,
  ) async {
    final store = await _loadedStore();
    await store.addToBag(store.products.firstWhere((item) => item.isInStock));
    var calls = 0;

    await tester.pumpWidget(
      _flow(
        store,
        CheckoutFlowScreen(
          launchSecureCheckout: (_) async => const CheckoutFailed(
            code: CheckoutFailureCode.configuration,
            userMessage: 'ignored',
          ),
          orderLookup: _ScriptedLookup((_) async {
            calls += 1;
            return const CheckoutOrderMatch(orderId: 'should-not-run');
          }),
        ),
      ),
    );
    await _openReview(tester);
    await tester.tap(find.byKey(const ValueKey('checkout-pay-button')));
    await tester.pumpAndSettle();

    expect(calls, 0);
    expect(find.text('No pudimos abrir el pago'), findsOneWidget);
    expect(
      find.text(
        'Revisa tu conexión e inténtalo otra vez. Tus productos siguen en el carrito.',
      ),
      findsOneWidget,
    );
    expect(find.text('No se completó tu pago'), findsNothing);
    expect(find.text('Estamos revisando tu pago'), findsNothing);
    expect(find.text('Intentar de nuevo'), findsOneWidget);
    expect(find.byKey(const ValueKey('checkout-pay-button')), findsNothing);
    expect(store.bagQuantity, 1);
  });

  testWidgets('a found order opens detail and does not show retry', (
    tester,
  ) async {
    final store = await _loadedStore();
    await store.addToBag(store.products.firstWhere((item) => item.isInStock));
    CheckoutOrderMatch? found;

    await tester.pumpWidget(
      _flow(
        store,
        CheckoutFlowScreen(
          launchSecureCheckout: (_) async => const CheckoutCancelled(),
          orderLookup: _ScriptedLookup(
            (_) async => const CheckoutOrderMatch(
              orderId: 'gid://shopify/Order/5',
              displayNumber: '#1005',
            ),
          ),
          attemptIdentity: const CheckoutAttemptIdentity(cartToken: 'cart-1'),
          onOrderFound: (context, match) async {
            found = match;
          },
        ),
      ),
    );
    await _openReview(tester);
    await tester.tap(find.byKey(const ValueKey('checkout-pay-button')));
    await tester.pumpAndSettle();

    expect(found?.orderId, 'gid://shopify/Order/5');
    expect(find.byKey(const ValueKey('checkout-pay-button')), findsNothing);
    expect(find.text('Intentar de nuevo'), findsNothing);
    expect(find.text('No se completó tu pago'), findsNothing);
    expect(find.text('Estamos revisando tu pago'), findsNothing);
    expect(find.text('No pudimos abrir el pago'), findsNothing);
    expect(store.bagQuantity, 1);
  });
}

void _expectNoDeclineCopy() {
  expect(find.textContaining('tarjeta'), findsNothing);
  expect(find.textContaining('rechaz'), findsNothing);
  expect(find.textContaining('declin'), findsNothing);
}

Widget _bannerHost(
  CheckoutReturnPhase phase, {
  VoidCallback? onRetry,
  VoidCallback? onViewOrders,
  VoidCallback? onWhatsApp,
}) {
  return MaterialApp(
    theme: buildTheme(),
    home: Scaffold(
      body: CheckoutReturnBanner(
        phase: phase,
        onRetry: onRetry,
        onViewOrders: onViewOrders,
        onWhatsApp: onWhatsApp,
      ),
    ),
  );
}

Widget _flow(CatalogStore store, Widget child) {
  return MaterialApp(
    theme: buildTheme(),
    home: StoreScope(notifier: store, child: child),
  );
}

Future<CatalogStore> _loadedStore() async {
  final store = CatalogStore(database: openTestDatabase());
  await store.loadFromAsset();
  return store;
}

Future<void> _openReview(WidgetTester tester) async {
  await tester.pump();
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'buyer@example.invalid');
  await tester.enterText(fields.at(1), '8112345678');
  await tester.ensureVisible(find.text('REVISAR PEDIDO'));
  await tester.tap(find.text('REVISAR PEDIDO'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const ValueKey('checkout-pay-button')));
}

final class _ScriptedLookup implements CheckoutOrderLookup {
  _ScriptedLookup(this._handle);

  final Future<CheckoutOrderMatch?> Function(CheckoutAttemptIdentity attempt)
      _handle;

  @override
  Future<CheckoutOrderMatch?> findOrder(CheckoutAttemptIdentity attempt) {
    return _handle(attempt);
  }
}
