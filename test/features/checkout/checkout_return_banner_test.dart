import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/shopify/cart/checkout_launcher.dart';
import 'package:monetta_app/features/boutique/boutique_tokens.dart';
import 'package:monetta_app/features/checkout/checkout_return.dart';
import 'package:monetta_app/features/checkout/checkout_return_banner.dart';
import 'package:monetta_app/features/checkout/checkout_screen.dart';
import 'package:monetta_app/main.dart';

void main() {
  testWidgets('reviewing banner uses the approved title', (tester) async {
    await tester.pumpWidget(
      _bannerHost(CheckoutReturnPhase.reviewing),
    );

    expect(find.text(kCheckoutReturnReviewingTitle), findsOneWidget);
    expect(find.text(kCheckoutReturnReviewingBodyTodo), findsOneWidget);
    expect(find.text(kCheckoutReturnRetryCtaTodo), findsOneWidget);
    expect(find.text('Estamos revisando tu pago'), findsOneWidget);
    _expectNoDeclineCopy();
  });

  testWidgets('payment not completed banner uses the approved title', (
    tester,
  ) async {
    await tester.pumpWidget(
      _bannerHost(CheckoutReturnPhase.paymentNotCompleted),
    );

    expect(find.text('No se completó tu pago'), findsOneWidget);
    expect(
      find.text(kCheckoutReturnPaymentNotCompletedBodyTodo),
      findsOneWidget,
    );
    expect(find.text(kCheckoutReturnRetryCtaTodo), findsOneWidget);
    _expectNoDeclineCopy();
  });

  testWidgets('sheet failed to open banner uses the approved title', (
    tester,
  ) async {
    await tester.pumpWidget(
      _bannerHost(CheckoutReturnPhase.sheetDidNotOpen),
    );

    expect(find.text('No pudimos abrir el pago'), findsOneWidget);
    expect(find.text(kCheckoutReturnSheetDidNotOpenBodyTodo), findsOneWidget);
    expect(find.text(kCheckoutReturnRetryCtaTodo), findsOneWidget);
    _expectNoDeclineCopy();
  });

  testWidgets('reviewing banner disables retry until the lookup settles', (
    tester,
  ) async {
    final store = await _loadedStore();
    await store.addToBag(store.products.firstWhere((item) => item.isInStock));
    final gate = Completer<CheckoutOrderMatch?>();
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
        ),
      ),
    );
    await _openReview(tester);
    await tester.tap(find.byKey(const ValueKey('checkout-pay-button')));
    await tester.pump();

    expect(find.text('Estamos revisando tu pago'), findsOneWidget);
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
    expect(find.text('No se completó tu pago'), findsOneWidget);
    expect(
      tester
          .widget<BoutiqueButton>(
            find.byKey(const ValueKey('checkout-pay-button')),
          )
          .onPressed,
      isNotNull,
    );
    expect(store.bagQuantity, 1);
  });

  testWidgets('no order after the check shows the payment banner and retry', (
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
    expect(find.text('Estamos revisando tu pago'), findsNothing);
    expect(find.text('No pudimos abrir el pago'), findsNothing);
    expect(
      tester
          .widget<BoutiqueButton>(
            find.byKey(const ValueKey('checkout-pay-button')),
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
    expect(find.text('No se completó tu pago'), findsNothing);
    expect(find.text('Estamos revisando tu pago'), findsNothing);
    expect(
      tester
          .widget<BoutiqueButton>(
            find.byKey(const ValueKey('checkout-pay-button')),
          )
          .onPressed,
      isNotNull,
    );
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

Widget _bannerHost(CheckoutReturnPhase phase) {
  return MaterialApp(
    theme: buildTheme(),
    home: Scaffold(body: CheckoutReturnBanner(phase: phase)),
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
