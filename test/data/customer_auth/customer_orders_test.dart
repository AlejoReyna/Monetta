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
  for (final count in [0, 26, 60]) {
    test('R6 loads all $count orders with unique IDs', () async {
      var calls = 0;
      final service = HttpCustomerOrdersService(
        config: _config,
        client: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'graphql_api':
                    'https://shop.example.com/customer/api/2026-07/graphql',
              }),
              200,
            );
          }
          final vars = (jsonDecode(request.body) as Map)['variables'] as Map;
          final offset = int.parse(vars['after'] as String? ?? '0');
          expect(offset, calls * 25);
          calls++;
          final end = (offset + 25).clamp(0, count);
          return http.Response(
            jsonEncode({
              'data': {
                'customer': {
                  'orders': {
                    'pageInfo': {
                      'hasNextPage': end < count,
                      'endCursor': '$end',
                    },
                    'nodes': [
                      for (var i = offset; i < end; i++)
                        {
                          'id': 'gid://shopify/Order/$i',
                          'name': '#${1000 + i}',
                          'number': 1000 + i,
                          'processedAt': '2026-09-01T00:00:00Z',
                          'financialStatus': 'PAID',
                          'totalPrice': {
                            'amount': '100',
                            'currencyCode': 'MXN',
                          },
                        },
                    ],
                  },
                },
              },
            }),
            200,
          );
        }),
      );
      final orders = await service.fetchOrders('test');
      expect(orders, hasLength(count));
      expect(orders.map((o) => o.id).toSet(), hasLength(count));
      expect(calls, count == 0 ? 1 : (count / 25).ceil());
    });
  }

  test(
      'R6 second-page failure rejects partial history and retry starts from first page',
      () async {
    var fail = true;
    final offsets = <Object?>[];
    final service = HttpCustomerOrdersService(
      config: _config,
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'graphql_api':
                  'https://shop.example.com/customer/api/2026-07/graphql',
            }),
            200,
          );
        }
        final after =
            ((jsonDecode(request.body) as Map)['variables'] as Map)['after'];
        offsets.add(after);
        if (after != null && fail) return http.Response('{}', 503);
        return http.Response(
          jsonEncode({
            'data': {
              'customer': {
                'orders': {
                  'pageInfo': {
                    'hasNextPage': after == null,
                    'endCursor': after == null ? 'next' : null,
                  },
                  'nodes': <dynamic>[],
                },
              },
            },
          }),
          200,
        );
      }),
    );
    await expectLater(
      service.fetchOrders('test'),
      throwsA(isA<CustomerAuthException>()),
    );
    fail = false;
    expect(await service.fetchOrders('test'), isEmpty);
    expect(offsets, [null, 'next', null, 'next']);
  });

  group('HttpCustomerOrdersService.parseOrders', () {
    test('parses nodes into CustomerAccountOrder rows', () {
      final body = utf8.encode(
        jsonEncode({
          'data': {
            'customer': {
              'orders': {
                'pageInfo': {'hasNextPage': false, 'endCursor': null},
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
                'orders': {
                  'pageInfo': {'hasNextPage': false, 'endCursor': null},
                  'nodes': <Map<String, dynamic>>[],
                },
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
