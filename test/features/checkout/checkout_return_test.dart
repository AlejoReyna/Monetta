import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/accounts_orders/order_history_client.dart';
import 'package:monetta_app/data/customer_auth/customer_orders.dart';
import 'package:monetta_app/data/repositories/order_history_repository.dart';
import 'package:monetta_app/data/shopify/cart/checkout_launcher.dart';
import 'package:monetta_app/features/checkout/checkout_order_lookup.dart';
import 'package:monetta_app/features/checkout/checkout_return.dart';

void main() {
  group('MON-UX-03-DUP timing', () {
    test('interval and timeout are the proposed constants', () {
      expect(kCheckoutOrderLookupInterval, const Duration(seconds: 3));
      expect(kCheckoutOrderLookupTimeout, const Duration(seconds: 30));
    });

    test('token correlation stays off until sources return tokens', () {
      expect(kCheckoutTokenCorrelationAvailable, isFalse);
    });
  });

  group('decideCheckoutReturn', () {
    test('found order stops polling and does not end as a retry', () async {
      final clock = _Clock(DateTime.utc(2026, 10, 15));
      var calls = 0;
      final decision = await decideCheckoutReturn(
        result: const CheckoutCancelled(),
        attempt: const CheckoutAttemptIdentity(cartToken: 'cart-token'),
        lookup: _ScriptedLookup((attempt) async {
          calls += 1;
          expect(attempt.cartToken, 'cart-token');
          expect(attempt.toString(), 'CheckoutAttemptIdentity(<redacted>)');
          if (calls < 2) return null;
          return const CheckoutOrderMatch(orderId: 'gid://shopify/Order/9');
        }),
        clock: clock.now,
        delay: (duration) async => clock.advance(duration),
      );

      expect(decision, isA<CheckoutOrderFound>());
      expect(
        (decision as CheckoutOrderFound).match.orderId,
        'gid://shopify/Order/9',
      );
      expect(calls, 2);
      expect(clock.elapsed, kCheckoutOrderLookupInterval);
    });

    test('timeout without correlation is uncertain, not a missed charge',
        () async {
      final clock = _Clock(DateTime.utc(2026, 10, 15));
      final seenAt = <Duration>[];
      final decision = await decideCheckoutReturn(
        result: const CheckoutFailed(
          code: CheckoutFailureCode.unknown,
          userMessage: 'ignored',
        ),
        attempt: const CheckoutAttemptIdentity(checkoutToken: 'chk-1'),
        lookup: _ScriptedLookup((_) async {
          seenAt.add(clock.elapsed);
          return null;
        }),
        clock: clock.now,
        delay: (duration) async => clock.advance(duration),
      );

      expect(kCheckoutTokenCorrelationAvailable, isFalse);
      expect(decision, isA<CheckoutReturnUncertain>());
      expect(decision, isNot(isA<CheckoutOrderNotFound>()));
      expect(clock.elapsed, kCheckoutOrderLookupTimeout);
      expect(
        seenAt,
        [
          for (var seconds = 0; seconds <= 30; seconds += 3)
            Duration(seconds: seconds),
        ],
      );
    });

    test('capable lookup with no match is banner 1', () async {
      final clock = _Clock(DateTime.utc(2026, 10, 15));
      final decision = await decideCheckoutReturn(
        result: const CheckoutCancelled(),
        attempt: const CheckoutAttemptIdentity(cartToken: 'cart-token'),
        correlationAvailable: true,
        lookup: _ScriptedLookup((_) async => null),
        timeout: Duration.zero,
        clock: clock.now,
        delay: (duration) async => clock.advance(duration),
      );

      expect(decision, isA<CheckoutOrderNotFound>());
    });

    test('a lookup error stays uncertain even when correlation is on',
        () async {
      final clock = _Clock(DateTime.utc(2026, 10, 15));
      final decision = await resolvePaymentReturn(
        attempt: const CheckoutAttemptIdentity(cartToken: 'cart-token'),
        correlationAvailable: true,
        lookup: _ScriptedLookup((_) async => throw StateError('source down')),
        timeout: Duration.zero,
        clock: clock.now,
        delay: (duration) async => clock.advance(duration),
      );

      expect(decision, isA<CheckoutReturnUncertain>());
      expect(decision, isNot(isA<CheckoutOrderNotFound>()));
    });

    test('a lookup error is not treated as not-found before timeout', () async {
      final clock = _Clock(DateTime.utc(2026, 10, 15));
      var calls = 0;
      final decision = await resolvePaymentReturn(
        attempt: const CheckoutAttemptIdentity(cartToken: 'cart-token'),
        lookup: _ScriptedLookup((_) async {
          calls += 1;
          if (calls == 1) throw StateError('source down');
          return const CheckoutOrderMatch(orderId: 'gid://shopify/Order/3');
        }),
        timeout: const Duration(seconds: 3),
        interval: const Duration(seconds: 3),
        clock: clock.now,
        delay: (duration) async => clock.advance(duration),
      );

      expect(decision, isA<CheckoutOrderFound>());
      expect(calls, 2);
    });

    test('sheet failed to open does not look for an order', () async {
      var calls = 0;
      for (final code in const [
        CheckoutFailureCode.configuration,
        CheckoutFailureCode.unavailable,
      ]) {
        final decision = await decideCheckoutReturn(
          result: CheckoutFailed(code: code, userMessage: 'ignored'),
          attempt: const CheckoutAttemptIdentity(cartToken: 'cart-token'),
          lookup: _ScriptedLookup((_) async {
            calls += 1;
            return const CheckoutOrderMatch(orderId: 'should-not-run');
          }),
        );
        expect(decision, isA<CheckoutReturnSheetDidNotOpen>());
      }
      expect(calls, 0);
    });

    test('cart completed still reconciles because an order may exist',
        () async {
      final decision = await decideCheckoutReturn(
        result: const CheckoutFailed(
          code: CheckoutFailureCode.cartCompleted,
          userMessage: 'ignored',
        ),
        attempt: const CheckoutAttemptIdentity(checkoutToken: 'chk'),
        lookup: _ScriptedLookup(
          (_) async =>
              const CheckoutOrderMatch(orderId: 'gid://shopify/Order/8'),
        ),
        timeout: Duration.zero,
      );
      expect(
        (decision as CheckoutOrderFound).match.orderId,
        'gid://shopify/Order/8',
      );
    });
  });

  group('matchCheckoutOrder', () {
    const attempt = CheckoutAttemptIdentity(
      cartToken: 'cart-token',
      checkoutToken: 'checkout-token',
    );

    test('matches any order that shares the cart or checkout token', () {
      final match = matchCheckoutOrder(attempt, const [
        CheckoutSourcedOrder(id: 'other', cartToken: 'nope'),
        CheckoutSourcedOrder(
          id: 'unpaid',
          displayNumber: '#1002',
          checkoutToken: 'cart-token',
        ),
      ]);
      expect(match?.orderId, 'unpaid');
      expect(match?.displayNumber, '#1002');
    });

    test('does not match a different token or a missing token', () {
      expect(
        matchCheckoutOrder(
          attempt,
          const [CheckoutSourcedOrder(id: '1', cartToken: 'other')],
        ),
        isNull,
      );
      expect(
        matchCheckoutOrder(
          const CheckoutAttemptIdentity(),
          const [CheckoutSourcedOrder(id: '1', cartToken: 'cart-token')],
        ),
        isNull,
      );
    });

    test('reads the cart token and the checkout path token, not the key', () {
      final identity = checkoutAttemptFromCart(
        cartId: 'gid://shopify/Cart/cart-token?key=secret',
        checkoutUrl: 'https://shop.example/cart/c/checkout-token?key=secret',
      );
      expect(identity.cartToken, 'cart-token');
      expect(identity.checkoutToken, 'checkout-token');
      expect(identity.toString(), contains('<redacted>'));
      expect(identity.toString(), isNot(contains('secret')));
      expect(identity.toString(), isNot(contains('cart-token')));
    });
  });

  group('existing order sources', () {
    test('do not carry a checkout or cart token, so they cannot match', () {
      final snapshot = OrderCorrelationSnapshot(
        customerOrders: [
          CustomerAccountOrder(
            id: 'gid://shopify/Order/1',
            name: '#1001',
            number: 1001,
            processedAt: DateTime.utc(2026, 10, 15),
            financialStatus: 'PAID',
            fulfillmentStatus: null,
            totalAmount: 10,
            currencyCode: 'MXN',
          ),
        ],
        mirroredOrders: [
          MirroredOrder(
            id: 2,
            shopifyOrderId: 'gid://shopify/Order/2',
            source: 'shopify_checkout',
            attributionCode: null,
            financialStatus: 'pending',
            fulfillmentStatus: null,
            totalAmount: 10,
            currencyCode: 'MXN',
            placedAt: null,
          ),
        ],
      );

      final sourced = checkoutSourcedOrdersFrom(snapshot);
      expect(sourced, hasLength(2));
      expect(sourced.every((order) => order.cartToken == null), isTrue);
      expect(sourced.every((order) => order.checkoutToken == null), isTrue);
      expect(
        matchCheckoutOrder(
          const CheckoutAttemptIdentity(
            cartToken: 'cart-token',
            checkoutToken: 'checkout-token',
          ),
          sourced,
        ),
        isNull,
      );
    });
  });
}

final class _Clock {
  _Clock(this._now);

  DateTime _now;
  final DateTime _started = DateTime.utc(2026, 10, 15);

  DateTime now() => _now;

  Duration get elapsed => _now.difference(_started);

  void advance(Duration duration) {
    _now = _now.add(duration);
  }
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
