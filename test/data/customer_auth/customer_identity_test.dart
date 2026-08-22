import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monetta_app/data/customer_auth/customer_account_config.dart';
import 'package:monetta_app/data/customer_auth/customer_auth_error.dart';
import 'package:monetta_app/data/customer_auth/customer_identity.dart';

const CustomerAccountConfig _config = CustomerAccountConfig(
  shopDomain: 'shop.example.com',
  shopId: '90228850722',
  clientId: 'client-id',
  redirectUri: 'shop.90228850722.oauth://callback',
  apiVersion: '2026-07',
);

HttpCustomerIdentityService _serviceReturning(
  Future<http.Response> Function(http.Request request) handler,
) {
  return HttpCustomerIdentityService(
    config: _config,
    client: MockClient((request) {
      if (request.method == 'GET' &&
          request.url == _config.customerApiDiscoveryEndpoint) {
        return Future.value(
          http.Response(
            jsonEncode({
              'graphql_api':
                  'https://clientes.example.com/customer/api/2026-07/graphql',
            }),
            200,
          ),
        );
      }
      return handler(request);
    }),
  );
}

void main() {
  group('HttpCustomerIdentityService', () {
    test('sends the access token raw, with no Bearer prefix', () async {
      String? authorization;
      Uri? endpoint;
      final service = _serviceReturning((request) async {
        authorization = request.headers['Authorization'];
        endpoint = request.url;
        return http.Response(
          jsonEncode({
            'data': {
              'customer': {
                'id': 'gid://shopify/Customer/7',
                'displayName': 'Ana Ruiz',
                'emailAddress': {'emailAddress': 'ana@example.com'},
              },
            },
          }),
          200,
        );
      });

      final identity = await service.fetch('shcat_abc123');

      // Shopify rejects `Bearer shcat_...` with a flat 401, which is the
      // single easiest way to break this whole flow.
      expect(authorization, 'shcat_abc123');
      expect(
        endpoint.toString(),
        'https://clientes.example.com/customer/api/2026-07/graphql',
      );
      expect(identity.shopifyCustomerId, 'gid://shopify/Customer/7');
      expect(identity.email, 'ana@example.com');
      expect(identity.displayName, 'Ana Ruiz');
    });

    test('discovers the branded GraphQL endpoint once and caches it', () async {
      var discoveryRequests = 0;
      var apiRequests = 0;
      final service = HttpCustomerIdentityService(
        config: _config,
        client: MockClient((request) async {
          if (request.method == 'GET') {
            discoveryRequests += 1;
            expect(request.url, _config.customerApiDiscoveryEndpoint);
            return http.Response(
              jsonEncode({
                'graphql_api':
                    'https://clientes.example.com/customer/api/2026-07/graphql',
              }),
              200,
            );
          }
          apiRequests += 1;
          expect(
            request.url.toString(),
            'https://clientes.example.com/customer/api/2026-07/graphql',
          );
          return http.Response(
            jsonEncode({
              'data': {
                'customer': {'id': 'gid://shopify/Customer/7'},
              },
            }),
            200,
          );
        }),
      );

      await service.fetch('first-token');
      await service.fetch('second-token');

      expect(discoveryRequests, 1);
      expect(apiRequests, 2);
    });

    test('a customer with no name or email still yields an identity', () async {
      final service = _serviceReturning(
        (_) async => http.Response(
          jsonEncode({
            'data': {
              'customer': {
                'id': 'gid://shopify/Customer/7',
                'displayName': '',
                'emailAddress': null,
              },
            },
          }),
          200,
        ),
      );

      final identity = await service.fetch('token');
      expect(identity.shopifyCustomerId, 'gid://shopify/Customer/7');
      expect(identity.email, isNull);
      expect(identity.displayName, isNull);
    });

    test('401 is a rejected token, not a server error', () async {
      final service = _serviceReturning(
        (_) async => http.Response('unauthorized', 401),
      );

      await expectLater(
        service.fetch('token'),
        throwsA(
          isA<CustomerAuthException>().having(
            (e) => e.kind,
            'kind',
            CustomerAuthErrorKind.sessionExpired,
          ),
        ),
      );
    });

    test('an UNAUTHENTICATED GraphQL error inside a 200 is a rejected token',
        () async {
      // Shopify answers GraphQL-level problems with HTTP 200; trusting the
      // status code alone would read this as a successful login.
      final service = _serviceReturning(
        (_) async => http.Response(
          jsonEncode({
            'errors': [
              {
                'message': 'Unauthenticated',
                'extensions': {'code': 'UNAUTHENTICATED'},
              },
            ],
          }),
          200,
        ),
      );

      await expectLater(
        service.fetch('token'),
        throwsA(
          isA<CustomerAuthException>().having(
            (e) => e.kind,
            'kind',
            CustomerAuthErrorKind.sessionExpired,
          ),
        ),
      );
    });

    test('a 500 is a server error', () async {
      final service = _serviceReturning(
        (_) async => http.Response('nope', 503),
      );

      await expectLater(
        service.fetch('token'),
        throwsA(
          isA<CustomerAuthException>().having(
            (e) => e.kind,
            'kind',
            CustomerAuthErrorKind.server,
          ),
        ),
      );
    });

    test('a transport failure is offline, not a crash', () async {
      final service = _serviceReturning(
        (_) async => throw http.ClientException('no route to host'),
      );

      await expectLater(
        service.fetch('token'),
        throwsA(
          isA<CustomerAuthException>().having(
            (e) => e.kind,
            'kind',
            CustomerAuthErrorKind.offline,
          ),
        ),
      );
    });

    test('a 200 with no customer object is a server error, never a null id',
        () async {
      final service = _serviceReturning(
        (_) async =>
            http.Response(jsonEncode({'data': <String, Object?>{}}), 200),
      );

      await expectLater(
        service.fetch('token'),
        throwsA(
          isA<CustomerAuthException>().having(
            (e) => e.kind,
            'kind',
            CustomerAuthErrorKind.server,
          ),
        ),
      );
    });

    test('a non-JSON body is a server error', () {
      expect(
        () => HttpCustomerIdentityService.parseIdentity(
          utf8.encode('<html>maintenance</html>'),
        ),
        throwsA(isA<CustomerAuthException>()),
      );
    });

    test('debug details never carry the access token', () async {
      final service = _serviceReturning(
        (_) async => http.Response('unauthorized', 401),
      );

      try {
        await service.fetch('shcat_supersecret');
        fail('expected a CustomerAuthException');
      } on CustomerAuthException catch (error) {
        expect(error.toString(), isNot(contains('shcat_supersecret')));
        expect(error.debugDetail ?? '', isNot(contains('shcat_supersecret')));
      }
    });
  });
}
