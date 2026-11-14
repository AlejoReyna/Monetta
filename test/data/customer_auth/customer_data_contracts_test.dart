// Deterministic provider fixtures only. These tests never contact Shopify.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monetta_app/data/customer_auth/customer_account_config.dart';
import 'package:monetta_app/data/customer_auth/customer_addresses.dart';
import 'package:monetta_app/data/customer_auth/customer_auth_error.dart';
import 'package:monetta_app/data/customer_auth/customer_graphql_client.dart';
import 'package:monetta_app/data/customer_auth/customer_order_details.dart';

const config = CustomerAccountConfig(
  shopDomain: 'fixture.example',
  shopId: '1',
  clientId: 'fixture',
  redirectUri: 'shop.1.oauth://callback',
);
const addressId = 'gid://shopify/CustomerAddress/1';
const orderId = 'gid://shopify/Order/1';
Map<String, Object?> address([String id = addressId]) => {
      'id': id,
      'address1': 'Historical street',
      'city': 'Montemorelos',
      'formatted': ['Historical street', 'Montemorelos'],
    };
Map<String, Object?> connection(List<Object?> nodes, {String? next}) => {
      'nodes': nodes,
      'pageInfo': {'hasNextPage': next != null, 'endCursor': next},
    };
http.Response jsonResponse(Object? value, [int status = 200]) =>
    http.Response(jsonEncode(value), status);
CustomerGraphqlClient client(
  Future<http.Response> Function(http.Request) onPost,
) =>
    CustomerGraphqlClient(
      config: config,
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return jsonResponse({
            'graphql_api':
                'https://fixture.example/customer/api/2026-07/graphql',
          });
        }
        expect(request.headers['authorization'], 'fixture-token');
        return onPost(request);
      }),
    );
Matcher dataError(String code) =>
    isA<CustomerDataException>().having((e) => e.code, 'code', code);

void main() {
  test('provider order edit rejects a mixed paginated snapshot', () async {
    var calls = 0;
    final service = ShopifyCustomerOrderDetailsService(
      client((_) async {
        calls++;
        return jsonResponse({
          'data': {
            'order': {
              'id': orderId,
              'name': '#1',
              'updatedAt': 'revision-$calls',
              'lineItems':
                  connection(<Object?>[], next: calls == 1 ? 'next' : null),
              'fulfillments': connection(<Object?>[]),
            },
          },
        });
      }),
    );
    await expectLater(
      service.fetchOrderDetails('fixture-token', orderId),
      throwsA(dataError('order_changed_during_read')),
    );
  });
  test('successful but unreadable address write remains uncertain', () async {
    final service = ShopifyCustomerAddressService(
      client(
        (_) async => jsonResponse({
          'data': {
            'customerAddressCreate': {
              'customerAddress': null,
              'userErrors': <Object?>[],
            },
          },
        }),
      ),
    );
    await expectLater(
      service.create(
        'fixture-token',
        CustomerAddressInput({'city': 'Fixture'}),
      ),
      throwsA(
        isA<CustomerDataException>()
            .having((e) => e.mutationMayHaveSucceeded, 'uncertain', true),
      ),
    );
  });

  test('addresses paginate, deduplicate, and retain provider default ID',
      () async {
    var calls = 0;
    final service = ShopifyCustomerAddressService(
      client((request) async {
        final body = jsonDecode(request.body) as Map;
        expect((body['variables'] as Map)['after'], calls == 0 ? null : 'next');
        calls++;
        return jsonResponse({
          'data': {
            'customer': {
              'defaultAddress': {'id': addressId},
              'addresses': connection(
                [address(), if (calls == 2) address('$addressId-2')],
                next: calls == 1 ? 'next' : null,
              ),
            },
          },
        });
      }),
    );
    final book = await service.fetchAddresses('fixture-token');
    expect(book.addresses, hasLength(2));
    expect(book.defaultAddressId, addressId);
    expect(calls, 2);
  });
  test('missing customer is unavailable rather than empty address success',
      () async {
    final service = ShopifyCustomerAddressService(
      client(
        (_) async => jsonResponse({
          'data': {'customer': null},
        }),
      ),
    );
    await expectLater(
      service.fetchAddresses('fixture-token'),
      throwsA(dataError('customer_unavailable')),
    );
  });
  test('broken pagination fails rather than publishing truncated address book',
      () async {
    final service = ShopifyCustomerAddressService(
      client(
        (_) async => jsonResponse({
          'data': {
            'customer': {
              'addresses': connection([address()], next: 'repeated'),
            },
          },
        }),
      ),
    );
    await expectLater(
      service.fetchAddresses('fixture-token'),
      throwsA(dataError('incomplete_pagination')),
    );
  });
  test(
      'create/update/delete send provider variables once and confirm actual result',
      () async {
    var calls = 0;
    final service = ShopifyCustomerAddressService(
      client((request) async {
        calls++;
        final body = jsonDecode(request.body) as Map;
        final query = body['query'] as String;
        final vars = body['variables'] as Map;
        if (query.contains('MonettaAddressDelete')) {
          expect(vars['addressId'], addressId);
          return jsonResponse({
            'data': {
              'customerAddressDelete': {
                'deletedAddressId': addressId,
                'userErrors': <Object?>[],
              },
            },
          });
        }
        expect(
          vars['address'],
          {'address1': 'New street', 'territoryCode': 'MX'},
        );
        expect(vars, isNot(contains('customerId')));
        final key = query.contains('MonettaAddressCreate')
            ? 'customerAddressCreate'
            : 'customerAddressUpdate';
        return jsonResponse({
          'data': {
            key: {'customerAddress': address(), 'userErrors': <Object?>[]},
          },
        });
      }),
    );
    final input =
        CustomerAddressInput({'address1': 'New street', 'territoryCode': 'MX'});
    expect(
      (await service.create('fixture-token', input, defaultAddress: true)).id,
      addressId,
    );
    expect(
      (await service.update('fixture-token', addressId, input)).id,
      addressId,
    );
    await service.delete('fixture-token', addressId);
    expect(calls, 3);
  });
  test(
      'provider denies unauthorized address without leaking message or reporting success',
      () async {
    final service = ShopifyCustomerAddressService(
      client(
        (_) async => jsonResponse({
          'data': {
            'customerAddressDelete': {
              'deletedAddressId': null,
              'userErrors': [
                {'code': 'NOT_FOUND', 'message': 'private fixture input'},
              ],
            },
          },
        }),
      ),
    );
    await expectLater(
      service.delete('fixture-token', addressId),
      throwsA(dataError('address_rejected')),
    );
  });
  for (final status in [401, 403]) {
    test('provider $status is an auth error, no private body echoed', () async {
      final service = ShopifyCustomerAddressService(
        client((_) async => http.Response('private fixture input', status)),
      );
      await expectLater(
        service.fetchAddresses('fixture-token'),
        throwsA(isA<CustomerAuthException>()),
      );
    });
  }
  test('ambiguous mutation failure is single attempt, requires reconciliation',
      () async {
    var calls = 0;
    final service = ShopifyCustomerAddressService(
      client((_) async {
        calls++;
        throw StateError('private fixture input');
      }),
    );
    await expectLater(
      service.delete('fixture-token', addressId),
      throwsA(
        isA<CustomerDataException>()
            .having((e) => e.mutationMayHaveSucceeded, 'uncertain', true)
            .having(
              (e) => e.toString(),
              'safe detail',
              isNot(contains('private')),
            ),
      ),
    );
    expect(calls, 1);
  });
  test(
      'malformed mutation response is uncertain rather than retryable confirmed failure',
      () async {
    final service = ShopifyCustomerAddressService(
      client((_) async => http.Response('not json', 200)),
    );
    await expectLater(
      service.delete('fixture-token', addressId),
      throwsA(
        isA<CustomerDataException>()
            .having((e) => e.mutationMayHaveSucceeded, 'uncertain', true),
      ),
    );
  });
  test('GraphQL denied errors are sanitized, never downgraded to data',
      () async {
    final c = client(
      (_) async => jsonResponse({
        'errors': [
          {
            'message': 'private fixture input',
            'extensions': {'code': 'ACCESS_DENIED'},
          }
        ],
      }),
    );
    await expectLater(
      c.execute('fixture-token', '{ customer { id } }'),
      throwsA(isA<CustomerAuthException>()),
    );
  });
  test('order detail paginates lines and shipments independently of payment',
      () async {
    var calls = 0;
    final service = ShopifyCustomerOrderDetailsService(
      client((request) async {
        calls++;
        final vars = (jsonDecode(request.body) as Map)['variables'] as Map;
        expect(vars['id'], orderId);
        expect(vars['linesAfter'], calls == 1 ? null : 'next');
        return jsonResponse({
          'data': {
            'order': {
              'id': orderId,
              'name': '#1',
              'financialStatus': 'PENDING',
              'fulfillmentStatus': 'PARTIALLY_FULFILLED',
              'shippingAddress': address(),
              'lineItems': connection(
                [
                  {
                    'id': 'line-$calls',
                    'name': 'Historical item',
                    'quantity': 1,
                    'variantTitle': 'Dorado',
                    'variantId': 'variant-$calls',
                  }
                ],
                next: calls == 1 ? 'next' : null,
              ),
              'fulfillments': connection([
                {
                  'id': 'shipment',
                  'status': 'SUCCESS',
                  'latestShipmentStatus': 'IN_TRANSIT',
                  'trackingInformation': [
                    {
                      'company': 'Fixture carrier',
                      'number': '123',
                      'url': 'https://tracking.example/123',
                    }
                  ],
                }
              ]),
            },
          },
        });
      }),
    );
    final detail = (await service.fetchOrderDetails('fixture-token', orderId))!;
    expect(detail.lines, hasLength(2));
    expect(detail.shipments, hasLength(1));
    expect(detail.financialStatus, 'PENDING');
    expect(detail.shipments.single.latestShipmentStatus, 'IN_TRANSIT');
    expect(detail.shippingAddress!.fields['address1'], 'Historical street');
  });
  test(
      'old summary DTOs need not carry detail; provider null order remains null',
      () async {
    final service = ShopifyCustomerOrderDetailsService(
      client(
        (_) async => jsonResponse({
          'data': {'order': null},
        }),
      ),
    );
    expect(await service.fetchOrderDetails('fixture-token', orderId), isNull);
  });
  test('wrong authorized resource ID fails closed', () async {
    final service = ShopifyCustomerOrderDetailsService(
      client(
        (_) async => jsonResponse({
          'data': {
            'order': {'id': 'other-order', 'name': '#2'},
          },
        }),
      ),
    );
    await expectLater(
      service.fetchOrderDetails('fixture-token', orderId),
      throwsA(dataError('order_unavailable')),
    );
  });
  test(
      'unsafe provider tracking URL is omitted without manufacturing a replacement',
      () {
    expect(customerHttpsUri('javascript:alert(1)'), isNull);
    expect(customerHttpsUri('https://user:password@fixture.example'), isNull);
  });
  test('account changes, logout and A-B-A discard stale in-flight results',
      () async {
    final scope = AccountReadScope<String>()..bindAccount('a');
    final pending = Completer<String>();
    final result = scope.read(() => pending.future);
    scope.bindAccount('b');
    scope.bindAccount('a');
    pending.complete('private a');
    await expectLater(result, throwsA(dataError('stale_session')));
    expect(scope.value, isNull);
    expect(await scope.read(() async => 'fresh a'), 'fresh a');
    scope.bindAccount(null);
    expect(scope.value, isNull);
    await expectLater(
      scope.read(() async => 'unreachable'),
      throwsA(dataError('unauthenticated')),
    );
  });
  test('older same-account read cannot replace a newer confirmed read',
      () async {
    final scope = AccountReadScope<String>()..bindAccount('a');
    final pending = Completer<String>();
    final old = scope.read(() => pending.future);
    await scope.read(() async => 'new');
    pending.complete('old');
    await expectLater(old, throwsA(dataError('stale_session')));
    expect(scope.value, 'new');
  });
}
