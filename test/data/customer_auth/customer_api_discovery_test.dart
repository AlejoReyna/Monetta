import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monetta_app/data/customer_auth/customer_account_config.dart';
import 'package:monetta_app/data/customer_auth/customer_api_discovery.dart';
import 'package:monetta_app/data/customer_auth/customer_auth_error.dart';
import 'package:monetta_app/data/customer_auth/customer_identity.dart';
import 'package:monetta_app/data/customer_auth/customer_orders.dart';

const CustomerAccountConfig _config = CustomerAccountConfig(
  shopDomain: 'shop.example.com',
  shopId: '90228850722',
  clientId: 'client-id',
  redirectUri: 'shop.90228850722.oauth://callback',
  apiVersion: '2026-07',
);

const String _endpoint =
    'https://clientes.example.com/customer/api/2026-07/graphql';

http.Response _discoveryOk() =>
    http.Response(jsonEncode({'graphql_api': _endpoint}), 200);

/// Records the closing of the client it wraps.
class _TrackingClient extends http.BaseClient {
  _TrackingClient(this._inner);

  final http.Client _inner;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request);

  @override
  void close() {
    closed = true;
    _inner.close();
  }
}

/// The result of a call, captured without awaiting it.
class _Outcome {
  _Outcome(Future<Uri> call) {
    call.then<void>(
      (value) {
        done = true;
        this.value = value;
      },
      onError: (Object error, StackTrace _) {
        done = true;
        this.error = error;
      },
    );
  }

  bool done = false;
  Uri? value;
  Object? error;
}

Future<CustomerAuthException> _failureOf(
  Future<http.Response> Function() respond,
) async {
  final discovery = CustomerApiDiscoveryService(
    config: _config,
    client: MockClient((_) => respond()),
  );
  try {
    await discovery.graphQlEndpoint();
  } on CustomerAuthException catch (error) {
    return error;
  }
  fail('discovery should have failed');
}

/// A MockClient that serves discovery on GET and a valid API answer on POST,
/// counting the discovery requests.
class _SharedServer {
  int discoveryRequests = 0;

  http.Client client() => MockClient((request) async {
        if (request.method == 'GET') {
          discoveryRequests += 1;
          return _discoveryOk();
        }
        final query = (jsonDecode(request.body) as Map)['query'] as String;
        if (query.contains('MonettaCustomerOrders')) {
          return http.Response(
            jsonEncode({
              'data': {
                'customer': {
                  'orders': {
                    'pageInfo': {'hasNextPage': false, 'endCursor': null},
                    'nodes': <Object>[],
                  },
                },
              },
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'data': {
              'customer': {'id': 'gid://shopify/Customer/7'},
            },
          }),
          200,
        );
      });
}

void main() {
  group('CustomerApiDiscoveryService', () {
    test('INV-08 shared discovery: caches after the first success', () async {
      var requests = 0;
      final discovery = CustomerApiDiscoveryService(
        config: _config,
        client: MockClient((request) async {
          requests += 1;
          expect(request.method, 'GET');
          expect(request.url, _config.customerApiDiscoveryEndpoint);
          expect(request.headers['Accept'], 'application/json');
          return _discoveryOk();
        }),
      );

      final first = await discovery.graphQlEndpoint();
      final second = await discovery.graphQlEndpoint();

      expect(requests, 1);
      expect(first.toString(), _endpoint);
      expect(second, first);
    });

    test('INV-08 shared discovery: concurrent callers share one request',
        () async {
      var requests = 0;
      final gate = Completer<void>();
      final discovery = CustomerApiDiscoveryService(
        config: _config,
        client: MockClient((_) async {
          requests += 1;
          await gate.future;
          return _discoveryOk();
        }),
      );

      final a = discovery.graphQlEndpoint();
      final b = discovery.graphQlEndpoint();
      gate.complete();
      final results = await Future.wait([a, b]);

      expect(requests, 1);
      expect(results[0], results[1]);
      expect(results[0].toString(), _endpoint);
    });

    test('INV-08 shared discovery: a failure is not cached', () async {
      var requests = 0;
      final discovery = CustomerApiDiscoveryService(
        config: _config,
        client: MockClient((_) async {
          requests += 1;
          return requests == 1 ? http.Response('', 503) : _discoveryOk();
        }),
      );

      await expectLater(
        discovery.graphQlEndpoint(),
        throwsA(isA<CustomerAuthException>()),
      );
      final endpoint = await discovery.graphQlEndpoint();

      expect(requests, 2);
      expect(endpoint.toString(), _endpoint);
    });

    test('INV-08 shared discovery: HTTP 5xx is a server error', () async {
      final error = await _failureOf(() async => http.Response('', 503));
      expect(error.kind, CustomerAuthErrorKind.server);
      expect(error.debugDetail, 'customer API discovery HTTP 503');
    });

    test('INV-08 shared discovery: invalid JSON is a server error', () async {
      final error = await _failureOf(() async => http.Response('nope', 200));
      expect(error.kind, CustomerAuthErrorKind.server);
      expect(error.debugDetail, 'customer API discovery returned non-JSON');
    });

    test('INV-08 shared discovery: a missing graphql_api is rejected',
        () async {
      final error = await _failureOf(
        () async => http.Response(jsonEncode({'other': 1}), 200),
      );
      expect(error.kind, CustomerAuthErrorKind.server);
      expect(
        error.debugDetail,
        'customer API discovery carried no valid graphql_api',
      );
    });

    test('INV-08 shared discovery: a non-https graphql_api is rejected',
        () async {
      final error = await _failureOf(
        () async => http.Response(
          jsonEncode({'graphql_api': 'http://clientes.example.com/graphql'}),
          200,
        ),
      );
      expect(error.kind, CustomerAuthErrorKind.server);
      expect(
        error.debugDetail,
        'customer API discovery carried no valid graphql_api',
      );
    });

    test(
        'INV-08 shared discovery: a graphql_api with a fragment is '
        'rejected', () async {
      final error = await _failureOf(
        () async => http.Response(
          jsonEncode({'graphql_api': '$_endpoint#frag'}),
          200,
        ),
      );
      expect(error.kind, CustomerAuthErrorKind.server);
      expect(
        error.debugDetail,
        'customer API discovery carried no valid graphql_api',
      );
    });

    test(
        'INV-08 shared discovery: a body over the size limit is a '
        'server error', () async {
      final error = await _failureOf(
        () async => http.Response(
          'x' * (kMaxCustomerApiResponseBytes + 1),
          200,
        ),
      );
      expect(error.kind, CustomerAuthErrorKind.server);
      expect(
        error.debugDetail,
        'customer API discovery response exceeded size limit',
      );
    });

    test('INV-08 shared discovery: a transport failure is offline', () async {
      final error = await _failureOf(
        () async => throw http.ClientException('no route'),
      );
      expect(error.kind, CustomerAuthErrorKind.offline);
      expect(
        error.debugDetail,
        'customer API discovery transport failure: ClientException',
      );
    });

    testWidgets(
        'INV-08 shared discovery: a silent server times out as '
        'offline after 15 s', (tester) async {
      final discovery = CustomerApiDiscoveryService(
        config: _config,
        client: MockClient((_) => Completer<http.Response>().future),
      );

      final outcome = _Outcome(discovery.graphQlEndpoint());
      await tester.pump(const Duration(seconds: 14));
      expect(outcome.done, isFalse);
      await tester.pump(const Duration(seconds: 2));

      expect(outcome.error, isA<CustomerAuthException>());
      final error = outcome.error! as CustomerAuthException;
      expect(error.kind, CustomerAuthErrorKind.offline);
      expect(error.debugDetail, 'customer API discovery timed out');
    });

    testWidgets(
        'INV-08 shared discovery: orders built without a '
        'discovery keep their own 20 s discovery timeout', (tester) async {
      final orders = HttpCustomerOrdersService(
        config: _config,
        client: MockClient((_) => Completer<http.Response>().future),
      );

      Object? failure;
      var done = false;
      unawaited(
        orders.fetchOrders('token').then<void>(
          (_) => done = true,
          onError: (Object error) {
            done = true;
            failure = error;
          },
        ),
      );
      await tester.pump(const Duration(seconds: 19));
      expect(done, isFalse);
      await tester.pump(const Duration(seconds: 2));

      expect(failure, isA<CustomerAuthException>());
      expect(
        (failure! as CustomerAuthException).debugDetail,
        'customer API discovery timed out',
      );
    });

    test(
        'INV-08 shared discovery: identity and orders sharing one '
        'discovery make a single discovery request', () async {
      final server = _SharedServer();
      final discovery = CustomerApiDiscoveryService(
        config: _config,
        client: server.client(),
      );
      final identity = HttpCustomerIdentityService(
        config: _config,
        client: server.client(),
        discovery: discovery,
      );
      final orders = HttpCustomerOrdersService(
        config: _config,
        client: server.client(),
        discovery: discovery,
      );

      await identity.fetch('token');
      await orders.fetchOrders('token');

      // Only the shared discovery client's GET counts: the services' own
      // clients never see a discovery request.
      expect(server.discoveryRequests, 1);
    });

    test(
        'INV-08 shared discovery: concurrent identity and orders calls '
        'make a single discovery request', () async {
      final server = _SharedServer();
      final discovery = CustomerApiDiscoveryService(
        config: _config,
        client: server.client(),
      );
      final identity = HttpCustomerIdentityService(
        config: _config,
        client: server.client(),
        discovery: discovery,
      );
      final orders = HttpCustomerOrdersService(
        config: _config,
        client: server.client(),
        discovery: discovery,
      );

      await Future.wait([identity.fetch('token'), orders.fetchOrders('token')]);

      expect(server.discoveryRequests, 1);
    });

    test(
        'INV-08 shared discovery: closing the discovery keeps an '
        'injected client open', () {
      final client = _TrackingClient(MockClient((_) async => _discoveryOk()));
      CustomerApiDiscoveryService(config: _config, client: client).close();
      expect(client.closed, isFalse);
    });

    test(
        'INV-08 shared discovery: closing a service keeps an injected '
        'discovery open', () async {
      final discoveryClient =
          _TrackingClient(MockClient((_) async => _discoveryOk()));
      final discovery = CustomerApiDiscoveryService(
        config: _config,
        client: discoveryClient,
      );
      final identityClient =
          _TrackingClient(MockClient((_) async => _discoveryOk()));
      final ordersClient =
          _TrackingClient(MockClient((_) async => _discoveryOk()));

      HttpCustomerIdentityService(
        config: _config,
        client: identityClient,
        discovery: discovery,
      ).close();
      HttpCustomerOrdersService(
        config: _config,
        client: ordersClient,
        discovery: discovery,
      ).close();

      expect(discoveryClient.closed, isFalse);
      // The services' own clients are injected too, so they stay open as well.
      expect(identityClient.closed, isFalse);
      expect(ordersClient.closed, isFalse);
      // The shared discovery still works after both services closed.
      expect((await discovery.graphQlEndpoint()).toString(), _endpoint);
    });
  });
}
