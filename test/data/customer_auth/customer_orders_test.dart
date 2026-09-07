import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monetta_app/data/customer_auth/customer_account_config.dart';
import 'package:monetta_app/data/customer_auth/customer_auth_error.dart';
import 'package:monetta_app/data/customer_auth/customer_orders.dart';

const _config = CustomerAccountConfig(
  shopDomain: 'shop.example.com',
  shopId: '1',
  clientId: 'client',
  redirectUri: 'shop.1.oauth://callback',
);

void main() {
  group('HttpCustomerOrdersService.parseOrders', () {
    test('parses nodes into CustomerAccountOrder rows', () {
      final body = utf8.encode(
        jsonEncode({
          'data': {
            'customer': {
              'orders': {
                'nodes': [
                  {
                    'id': 'gid://shopify/Order/11',
                    'name': '#1001',
                    'number': 1001,
                    'processedAt': '2026-08-01T12:00:00Z',
                    'financialStatus': 'PAID',
                    'fulfillmentStatus': 'FULFILLED',
                    'totalPrice': {
                      'amount': '1749.0',
                      'currencyCode': 'MXN',
                    },
                  },
                ],
              },
            },
          },
        }),
      );

      final orders = HttpCustomerOrdersService.parseOrders(body);
      expect(orders, hasLength(1));
      expect(orders.single.id, 'gid://shopify/Order/11');
      expect(orders.single.number, 1001);
      expect(orders.single.totalAmount, 1749);
      expect(orders.single.currencyCode, 'MXN');
      expect(orders.single.financialStatus, 'PAID');
    });

    test('GraphQL UNAUTHENTICATED becomes sessionExpired', () {
      final body = utf8.encode(
        jsonEncode({
          'errors': [
            {
              'message': 'UNAUTHENTICATED',
              'extensions': {'code': 'UNAUTHENTICATED'},
            },
          ],
        }),
      );

      expect(
        () => HttpCustomerOrdersService.parseOrders(body),
        throwsA(
          isA<CustomerAuthException>().having(
            (e) => e.kind,
            'kind',
            CustomerAuthErrorKind.sessionExpired,
          ),
        ),
      );
    });
  });

  test('fetchOrders discovers GraphQL endpoint and sends raw Authorization',
      () async {
    late http.Request captured;
    final client = HttpCustomerOrdersService(
      config: _config,
      client: MockClient((request) async {
        if (request.url.path.endsWith('customer-account-api')) {
          return http.Response(
            jsonEncode({
              'graphql_api':
                  'https://shop.example.com/customer/api/2026-07/graphql',
            }),
            200,
            headers: {'Content-Type': 'application/json'},
          );
        }
        captured = request;
        return http.Response(
          jsonEncode({
            'data': {
              'customer': {
                'orders': {'nodes': <Map<String, dynamic>>[]},
              },
            },
          }),
          200,
          headers: {'Content-Type': 'application/json'},
        );
      }),
    );

    final orders = await client.fetchOrders('raw-access-token');
    expect(orders, isEmpty);
    expect(captured.headers['Authorization'], 'raw-access-token');
    expect(captured.headers['Authorization'], isNot(startsWith('Bearer ')));
  });
}
