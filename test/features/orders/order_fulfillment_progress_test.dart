import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/orders/order_fulfillment_progress.dart';

OrderSummary _order({
  String? fulfillmentStatus,
  String status = 'paid',
  String source = 'shopify_checkout',
}) =>
    OrderSummary(
      id: 'gid://shopify/Order/1',
      accountId: 'acct',
      fulfillmentStatus: fulfillmentStatus,
      status: status,
      totalAmount: 100,
      currencyCode: 'MXN',
      placedAt: DateTime.utc(2026, 1, 1),
      source: source,
    );

void main() {
  group('orderFulfillmentPhase (mocked)', () {
    test('preparing when paid without fulfillment', () {
      expect(
        orderFulfillmentPhase(_order(fulfillmentStatus: null)),
        OrderFulfillmentPhase.preparing,
      );
    });

    test('in transit when shipped regardless of pending payment', () {
      expect(
        orderFulfillmentPhase(
          _order(fulfillmentStatus: 'shipped', status: 'pending'),
        ),
        OrderFulfillmentPhase.inTransit,
      );
    });

    test('unavailable when refunded even if delivered token present', () {
      expect(
        orderFulfillmentPhase(
          _order(fulfillmentStatus: 'delivered', status: 'refunded'),
        ),
        OrderFulfillmentPhase.unavailable,
      );
    });

    test('partial maps to partial phase', () {
      expect(
        orderFulfillmentPhase(_order(fulfillmentStatus: 'partial')),
        OrderFulfillmentPhase.partial,
      );
    });
  });
}
