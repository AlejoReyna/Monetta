import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monetta_app/data/shopify/http_storefront_transport.dart';
import 'package:monetta_app/data/shopify/storefront_client.dart';

void main() {
  final endpoint =
      Uri.https('example.myshopify.com', '/api/2026-07/graphql.json');
  const headers = <String, String>{
    'Content-Type': 'application/json',
    'X-Shopify-Storefront-Access-Token': 'tok',
  };
  const body = '{"query":"{ shop { name } }"}';

  test('returns decoded JSON on HTTP 200', () async {
    final transport = HttpStorefrontTransport(
      client: MockClient((request) async {
        expect(request.url, endpoint);
        expect(request.headers['X-Shopify-Storefront-Access-Token'], 'tok');
        return http.Response(
          jsonEncode({
            'data': {
              'shop': {'name': 'M'},
            },
          }),
          200,
        );
      }),
      maxAttempts: 1,
    );

    final json = await transport.send(endpoint, headers, body);
    expect(json['data'], isA<Map<String, dynamic>>());
    transport.close();
  });

  test('retries retryable HTTP statuses then succeeds', () async {
    var calls = 0;
    final transport = HttpStorefrontTransport(
      client: MockClient((request) async {
        calls++;
        if (calls < 3) {
          return http.Response('nope', 503);
        }
        return http.Response(jsonEncode({'data': <String, Object?>{}}), 200);
      }),
      maxAttempts: 3,
      baseBackoff: Duration.zero,
    );

    final json = await transport.send(endpoint, headers, body);
    expect(json, contains('data'));
    expect(calls, 3);
    transport.close();
  });

  test('non-retryable 4xx fails immediately', () async {
    var calls = 0;
    final transport = HttpStorefrontTransport(
      client: MockClient((request) async {
        calls++;
        return http.Response('nope', 401);
      }),
      maxAttempts: 3,
      baseBackoff: Duration.zero,
    );

    await expectLater(
      transport.send(endpoint, headers, body),
      throwsA(
        isA<StorefrontException>()
            .having((e) => e.isRetryable, 'retryable', isFalse),
      ),
    );
    expect(calls, 1);
    transport.close();
  });

  test('invalid JSON fails closed', () async {
    final transport = HttpStorefrontTransport(
      client: MockClient((request) async => http.Response('not-json', 200)),
      maxAttempts: 1,
    );

    await expectLater(
      transport.send(endpoint, headers, body),
      throwsA(isA<StorefrontException>()),
    );
    transport.close();
  });

  test('timeout is retryable', () async {
    final transport = HttpStorefrontTransport(
      client: MockClient((request) async {
        throw TimeoutException('slow');
      }),
      maxAttempts: 1,
      timeout: const Duration(milliseconds: 10),
    );

    await expectLater(
      transport.send(endpoint, headers, body),
      throwsA(
        isA<StorefrontException>()
            .having((e) => e.isRetryable, 'retryable', isTrue),
      ),
    );
    transport.close();
  });

  test('sendOnce never retries an ambiguous mutation response', () async {
    var calls = 0;
    final transport = HttpStorefrontTransport(
      client: MockClient((request) async {
        calls += 1;
        return http.Response('unavailable', 503);
      }),
      maxAttempts: 3,
      baseBackoff: Duration.zero,
    );

    await expectLater(
      transport.sendOnce(endpoint, headers, body),
      throwsA(
        isA<StorefrontException>()
            .having((error) => error.isAmbiguous, 'ambiguous', isTrue),
      ),
    );
    expect(calls, 1);
    transport.close();
  });
}
