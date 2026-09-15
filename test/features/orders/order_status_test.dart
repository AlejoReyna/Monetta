import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/orders/order_status.dart';

OrderSummary _order({
  String id = 'gid://shopify/Order/1',
  String? displayNumber = '#1001',
  String? fulfillmentStatus,
  String? shopifyOrderId = 'gid://shopify/Order/1',
  String source = 'shopify_checkout',
  String? attributionCode,
  String status = 'paid',
  double total = 11480,
  String currency = 'MXN',
}) =>
    OrderSummary(
      id: id,
      accountId: 'acct-1',
      displayNumber: displayNumber,
      fulfillmentStatus: fulfillmentStatus,
      shopifyOrderId: shopifyOrderId,
      source: source,
      attributionCode: attributionCode,
      status: status,
      totalAmount: total,
      currencyCode: currency,
      placedAt: DateTime.utc(2026, 5, 12),
    );

void main() {
  group('orderLabelOf', () {
    test('prefers the real display number', () {
      expect(orderLabelOf(_order(displayNumber: '#1001')), '#1001');
    });

    test('falls back to the apartado code, never an invented number', () {
      final label = orderLabelOf(
        _order(
          displayNumber: null,
          shopifyOrderId: null,
          source: 'whatsapp_apartado',
          attributionCode: 'MN-7K3Q',
        ),
      );
      expect(label, 'MN-7K3Q');
      expect(label, isNot(contains('MON12345')));
    });
  });

  group('orderDisplayStatus: enviado no es entregado', () {
    test('fulfilled is En camino, not Entregado', () {
      final status = orderDisplayStatus(
        _order(fulfillmentStatus: 'fulfilled'),
      );
      expect(status.label, 'En camino');
      expect(status.key, isNot('delivered'));
    });

    test('only delivered evidence reads Entregado', () {
      final status = orderDisplayStatus(
        _order(fulfillmentStatus: 'delivered'),
      );
      expect(status.label, 'Entregado');
      expect(status.key, 'delivered');
    });

    test('paid without fulfillment is Confirmado, not En camino', () {
      final status = orderDisplayStatus(
        _order(fulfillmentStatus: null, status: 'paid'),
      );
      expect(status.label, 'Confirmado');
    });

    test('apartado keeps its own identity', () {
      final status = orderDisplayStatus(
        _order(
          source: 'whatsapp_apartado',
          shopifyOrderId: null,
          displayNumber: null,
          attributionCode: 'MN-7K3Q',
          status: 'pending',
        ),
      );
      expect(status.label, 'Apartado');
    });
  });

  group('filterOrders', () {
    final orders = [
      _order(id: 'gid://shopify/Order/1', fulfillmentStatus: 'fulfilled'),
      _order(id: 'gid://shopify/Order/2', fulfillmentStatus: 'delivered'),
      _order(
        id: 'apartado:9',
        fulfillmentStatus: null,
        shopifyOrderId: null,
        displayNumber: null,
        source: 'whatsapp_apartado',
        attributionCode: 'MN-1',
        status: 'pending',
      ),
      _order(
        id: 'gid://shopify/Order/3',
        fulfillmentStatus: null,
        status: 'paid',
      ),
    ];

    test('En camino requires shipment evidence', () {
      final inTransit = filterOrders(orders, OrderFilter.inTransit);
      expect(inTransit.map((o) => o.id), ['gid://shopify/Order/1']);
    });

    test('Entregados requires delivery evidence', () {
      final delivered = filterOrders(orders, OrderFilter.delivered);
      expect(delivered.map((o) => o.id), ['gid://shopify/Order/2']);
    });

    test('Apartados isolates WhatsApp orders', () {
      final apartados = filterOrders(orders, OrderFilter.apartado);
      expect(apartados.map((o) => o.id), ['apartado:9']);
    });

    test('Todos keeps every row', () {
      expect(filterOrders(orders, OrderFilter.all), hasLength(4));
    });
  });

  group('summarizeOrders', () {
    test('sums MXN only and counts other currencies separately', () {
      final summary = summarizeOrders([
        _order(total: 1000, currency: 'MXN'),
        _order(id: 'gid://shopify/Order/2', total: 50, currency: 'USD'),
      ]);
      expect(summary.count, 2);
      expect(summary.totalMxn, 1000);
      expect(summary.otherCurrencyCount, 1);
    });
  });
}
