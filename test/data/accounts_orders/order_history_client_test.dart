import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monetta_app/data/accounts_orders/order_history_client.dart';

void main() {
  test('requests the authenticated customer route with a bearer token',
      () async {
    late http.Request captured;
    final client = HttpOrderHistoryClient(
      baseUrl: 'https://accounts.example.com',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          '''{"orders":[{"id":1,"shopifyOrderId":"100","source":"shopify_checkout","attributionCode":null,"financialStatus":"paid","fulfillmentStatus":null,"totalAmount":1749,"currencyCode":"MXN","placedAt":"2026-08-25T00:00:00Z"}]}''',
          200,
          headers: {'Content-Type': 'application/json'},
        );
      }),
    );

    final orders = await client.fetchOrders('customer-access-token');

    expect(
      captured.url.toString(),
      'https://accounts.example.com/customers/me/orders',
    );
    expect(captured.headers['Authorization'], 'Bearer customer-access-token');
    expect(orders.single.shopifyOrderId, '100');
    expect(orders.single.paymentMethod, isNull);
    expect(orders.single.checkoutToken, isNull);
    expect(orders.single.cartToken, isNull);
  });

  test('parses nullable checkoutToken and cartToken', () {
    final present = MirroredOrder.fromJson(const {
      'id': 1,
      'shopifyOrderId': 'gid://shopify/Order/9',
      'source': 'shopify_checkout',
      'attributionCode': null,
      'financialStatus': 'paid',
      'fulfillmentStatus': null,
      'totalAmount': 10,
      'currencyCode': 'MXN',
      'placedAt': null,
      'checkoutToken': 'checkout-token',
      'cartToken': 'cart-token',
    });
    expect(present.checkoutToken, 'checkout-token');
    expect(present.cartToken, 'cart-token');

    final absent = MirroredOrder.fromJson(const {
      'id': 2,
      'shopifyOrderId': null,
      'source': 'whatsapp_apartado',
      'attributionCode': 'MN-1001',
      'financialStatus': null,
      'fulfillmentStatus': null,
      'totalAmount': null,
      'currencyCode': null,
      'placedAt': null,
      'checkoutToken': null,
      'cartToken': null,
    });
    expect(absent.checkoutToken, isNull);
    expect(absent.cartToken, isNull);
  });

  test('reads a normalized payment method and ignores a blank one', () async {
    final client = HttpOrderHistoryClient(
      baseUrl: 'https://accounts.example.com',
      httpClient: MockClient((_) async {
        return http.Response(
          '''{"orders":[{"id":2,"shopifyOrderId":"200","source":"shopify_checkout","attributionCode":null,"financialStatus":"pending","paymentMethod":"bank_deposit","fulfillmentStatus":null,"totalAmount":500,"currencyCode":"MXN","placedAt":"2026-08-25T00:00:00Z"},{"id":3,"shopifyOrderId":"201","source":"shopify_checkout","attributionCode":null,"financialStatus":"pending","paymentMethod":"  ","fulfillmentStatus":null,"totalAmount":10,"currencyCode":"MXN","placedAt":null}]}''',
          200,
          headers: {'Content-Type': 'application/json'},
        );
      }),
    );

    final orders = await client.fetchOrders('token');
    expect(orders.first.paymentMethod, 'bank_deposit');
    expect(orders.last.paymentMethod, isNull);
  });

  test('does not include the bearer value in an HTTP error', () async {
    final client = HttpOrderHistoryClient(
      baseUrl: 'https://accounts.example.com',
      httpClient: MockClient((_) async => http.Response('{}', 401)),
    );

    await expectLater(
      client.fetchOrders('do-not-log-me'),
      throwsA(
        isA<OrderHistoryException>().having(
          (error) => error.toString(),
          'message',
          isNot(contains('do-not-log-me')),
        ),
      ),
    );
  });
}
