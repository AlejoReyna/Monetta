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
  String? paymentMethod,
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
      paymentMethod: paymentMethod,
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
      expect(status.key, 'confirmed');
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

  group('orderDisplayStatus: financial_status estricto', () {
    final labels = <String, String>{
      'paid': 'Confirmado',
      'PAID': 'Confirmado',
      'partially_refunded': 'Reembolso en proceso',
      'PARTIALLY_REFUNDED': 'Reembolso en proceso',
      'partially refunded': 'Reembolso en proceso',
      'pending_refund': 'Reembolso en proceso',
      'refund_pending': 'Reembolso en proceso',
      'refunded': 'Reembolsado',
      'voided': 'Cancelado',
      'cancelled': 'Cancelado',
      'canceled': 'Cancelado',
      'pending': 'Pago en proceso',
      'PENDING': 'Pago en proceso',
      'authorized': 'Pago en proceso',
      'partially_paid': 'Pago en proceso',
      'expired': 'Pago en proceso',
      'unknown': 'Pago en proceso',
      'UNKNOWN': 'Pago en proceso',
      '': 'Pago en proceso',
      'null': 'Pago en proceso',
      'unfulfilled': 'Pago en proceso',
      'not_a_real_status': 'Pago en proceso',
    };

    for (final entry in labels.entries) {
      final raw = entry.key.isEmpty ? '(vacío)' : entry.key;
      test('$raw → ${entry.value}', () {
        final status = orderDisplayStatus(
          _order(fulfillmentStatus: null, status: entry.key),
        );
        expect(status.label, entry.value);
        expect(status.label, isNot('Con ajuste'));
        expect(status.detail, isNot(contains('Te avisaremos')));
        if (entry.value != 'Confirmado') {
          expect(status.label, isNot('Confirmado'));
          expect(status.key, isNot('confirmed'));
          expect(status.success, isFalse);
        } else {
          expect(status.key, 'confirmed');
          expect(status.detail, 'Aquí verás cuando tu pedido salga.');
        }
      });
    }

    test('null financial_status is Pago en proceso, never Confirmado', () {
      final status = orderPaymentStatus(
        _order(fulfillmentStatus: null, status: 'unknown'),
      );
      expect(status.label, 'Pago en proceso');
      expect(status.key, 'payment_in_progress');
      expect(status.detail, 'Lo verás aquí cuando se confirme.');
      expect(status.detail, isNot(contains('Te avisaremos')));
    });

    test('pending bank transfer uses the transaction type', () {
      for (final method in [
        'bank_deposit',
        'MANUAL',
        'Transferencia bancaria'
      ]) {
        final status = orderDisplayStatus(
          _order(
            fulfillmentStatus: null,
            status: 'pending',
            paymentMethod: method,
          ),
        );
        expect(status.label, 'Esperando tu transferencia');
        expect(status.detail, contains('Lo verás aquí cuando se confirme.'));
        expect(orderPaymentMethodIsBankTransfer(method), isTrue);
      }
    });

    test('pending card or unknown method is Pago en proceso', () {
      for (final method in [null, '', 'card', 'shopify_payments', 'custom']) {
        final status = orderDisplayStatus(
          _order(
            fulfillmentStatus: null,
            status: 'pending',
            paymentMethod: method,
          ),
        );
        expect(status.label, 'Pago en proceso');
        expect(status.detail, 'Lo verás aquí cuando se confirme.');
        expect(status.label, isNot('Esperando tu transferencia'));
      }
    });

    test('refund in progress explains itself without a notification', () {
      final status = orderDisplayStatus(
        _order(fulfillmentStatus: null, status: 'partially_refunded'),
      );
      expect(status.label, 'Reembolso en proceso');
      expect(status.detail, 'Lo verás aquí cuando se complete.');
      expect(status.success, isFalse);
    });

    test('refunded names the amount, action and neutral tone', () {
      final status = orderDisplayStatus(
        _order(
          fulfillmentStatus: 'shipped',
          status: 'refunded',
          total: 11480,
          currency: 'MXN',
        ),
      );
      expect(status.label, 'Reembolsado');
      expect(status.detail, contains('Te devolvimos'));
      expect(status.detail, contains('a tu método de pago.'));
      expect(status.detail, contains('11,480'));
      expect(status.detail, contains('MXN'));
      expect(status.actionLabel, 'Ver pedido');
      expect(status.success, isFalse);
      expect(status.label, isNot('En camino'));
    });

    test('refunded without an amount uses the fallback body', () {
      final status = orderDisplayStatus(
        _order(status: 'refunded', total: 0),
      );
      expect(status.detail, 'Te devolvimos tu pago.');
      expect(status.actionLabel, 'Ver pedido');
    });
  });

  group('orderDisplayStatus: el pago gana al envío', () {
    test('shipped and refunded is never En camino', () {
      final status = orderDisplayStatus(
        _order(fulfillmentStatus: 'shipped', status: 'refunded'),
      );
      expect(status.label, 'Reembolsado');
      expect(status.key, isNot('in_transit'));
      expect(status.key, isNot('delivered'));
    });

    test('shipped and cancelled is never En camino', () {
      final status = orderDisplayStatus(
        _order(fulfillmentStatus: 'shipped', status: 'cancelled'),
      );
      expect(status.label, 'Cancelado');
      expect(status.label, isNot('En camino'));
    });

    test('fulfilled and voided is never En camino', () {
      final status = orderDisplayStatus(
        _order(fulfillmentStatus: 'fulfilled', status: 'voided'),
      );
      expect(status.label, 'Cancelado');
    });

    test('delivered and partially refunded is not Entregado', () {
      final status = orderDisplayStatus(
        _order(fulfillmentStatus: 'delivered', status: 'partially_refunded'),
      );
      expect(status.label, 'Reembolso en proceso');
      expect(status.key, isNot('delivered'));
    });

    test('shipped and unpaid is not En camino', () {
      final status = orderDisplayStatus(
        _order(fulfillmentStatus: 'shipped', status: 'pending'),
      );
      expect(status.label, 'Pago en proceso');
      expect(status.label, isNot('En camino'));
    });

    test('paid and shipped is still En camino', () {
      final status = orderDisplayStatus(
        _order(fulfillmentStatus: 'shipped', status: 'paid'),
      );
      expect(status.label, 'En camino');
    });

    test('paid and delivered is still Entregado', () {
      final status = orderDisplayStatus(
        _order(fulfillmentStatus: 'delivered', status: 'paid'),
      );
      expect(status.label, 'Entregado');
      expect(status.key, 'delivered');
    });

    test('En camino filter ignores unpaid shipments', () {
      final orders = [
        _order(id: 'paid-shipped', fulfillmentStatus: 'shipped'),
        _order(
          id: 'refunded-shipped',
          fulfillmentStatus: 'shipped',
          status: 'refunded',
        ),
        _order(
          id: 'cancelled-shipped',
          fulfillmentStatus: 'fulfilled',
          status: 'cancelled',
        ),
      ];
      expect(
        filterOrders(orders, OrderFilter.inTransit).map((o) => o.id),
        ['paid-shipped'],
      );
      expect(filterOrders(orders, OrderFilter.delivered), isEmpty);
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
