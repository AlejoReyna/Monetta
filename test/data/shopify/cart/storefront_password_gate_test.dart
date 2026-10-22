import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monetta_app/data/shopify/cart/storefront_password_gate.dart';

void main() {
  const shop = 'monetta-staging.myshopify.com';

  test('recognizes the staging storefront password redirect', () {
    expect(
      isStorefrontPasswordRedirect(
        shopHost: shop,
        statusCode: 302,
        location: 'https://monetta-staging.myshopify.com/password',
      ),
      isTrue,
    );
    expect(
      isStorefrontPasswordRedirect(
        shopHost: shop,
        statusCode: 302,
        location: '/password?return_url=%2Fcart',
      ),
      isTrue,
    );
    expect(
      isStorefrontPasswordRedirect(
        shopHost: 'Monetta-Staging.myshopify.com',
        statusCode: 301,
        location: 'https://monetta-staging.myshopify.com/password/',
      ),
      isTrue,
    );
  });

  test('does not treat the store home or another host as the password page',
      () {
    for (final location in [
      'https://monetta-staging.myshopify.com/',
      'https://monetta-staging.myshopify.com/password-reset',
      'https://attacker.example/password',
      'https://monetta-staging.myshopify.com.attacker.example/password',
      '//attacker.example/password',
      '/cart/c/opaque',
    ]) {
      expect(
        isStorefrontPasswordRedirect(
          shopHost: shop,
          statusCode: 302,
          location: location,
        ),
        isFalse,
        reason: location,
      );
    }
    expect(
      isStorefrontPasswordRedirect(
        shopHost: shop,
        statusCode: 200,
        location: 'https://monetta-staging.myshopify.com/password',
      ),
      isFalse,
    );
  });

  test('HEAD of the shop root reports a password redirect and ignores the key',
      () async {
    final seen = <Uri>[];
    final probe = HttpStorefrontPasswordProbe(
      client: MockClient((request) async {
        seen.add(request.url);
        expect(request.method, 'HEAD');
        expect(request.followRedirects, isFalse);
        return http.Response(
          '',
          302,
          headers: const {
            'location': 'https://monetta-staging.myshopify.com/password',
          },
        );
      }),
    );

    expect(
      await probe.checkHost(shop),
      StorefrontPasswordGate.passwordProtected,
    );
    expect(seen, hasLength(1));
    expect(seen.single.path, '/');
    expect(seen.single.query, isEmpty);
    expect(seen.single.host, shop);
  });

  test('a public shop root and a failed probe do not claim password protection',
      () async {
    final openProbe = HttpStorefrontPasswordProbe(
      client: MockClient(
        (_) async => http.Response('', 200),
      ),
    );
    final failedProbe = HttpStorefrontPasswordProbe(
      client: MockClient((_) async => throw Exception('offline')),
    );

    expect(await openProbe.checkHost(shop), StorefrontPasswordGate.open);
    expect(
      await failedProbe.checkHost(shop),
      StorefrontPasswordGate.unknown,
    );
    expect(
      await openProbe.checkHost('not a host'),
      StorefrontPasswordGate.unknown,
    );
  });
}
