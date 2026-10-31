import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/shopify/cart/checkout_launcher.dart';
import 'package:monetta_app/data/shopify/storefront_config.dart';

void main() {
  group('StorefrontConfig', () {
    test('isUsable requires host-shaped domain and non-empty token', () {
      expect(
        const StorefrontConfig(
          shopDomain: 'monetta.mx',
          accessToken: 'public_token',
        ).isUsable,
        isTrue,
      );
      expect(
        const StorefrontConfig(shopDomain: '', accessToken: 'x').isUsable,
        isFalse,
      );
      expect(
        const StorefrontConfig(shopDomain: 'monetta.mx', accessToken: '')
            .isUsable,
        isFalse,
      );
      expect(
        const StorefrontConfig(
          shopDomain: 'https://monetta.mx',
          accessToken: 'x',
        ).isUsable,
        isFalse,
      );
      expect(
        const StorefrontConfig(
          shopDomain: 'monetta.mx/path',
          accessToken: 'x',
        ).isUsable,
        isFalse,
      );
    });

    test('endpoint pins api version and domain', () {
      const config = StorefrontConfig(
        shopDomain: 'example.myshopify.com',
        accessToken: 'tok',
        apiVersion: '2026-07',
      );
      expect(
        config.endpoint.toString(),
        'https://example.myshopify.com/api/2026-07/graphql.json',
      );
    });

    test(
        'headers carry the public token and Spanish locale, never logs token in toString',
        () {
      const config = StorefrontConfig(
        shopDomain: 'monetta.mx',
        accessToken: 'supersecrettokenvalue',
      );
      expect(
        config.headers['X-Shopify-Storefront-Access-Token'],
        'supersecrettokenvalue',
      );
      expect(config.headers['Accept-Language'], 'es-MX');
      final text = config.toString();
      expect(text, isNot(contains('supersecrettokenvalue')));
      expect(text, contains('monetta.mx'));
    });

    test('defaults market to Mexico / Spanish', () {
      const config = StorefrontConfig(
        shopDomain: 'monetta.mx',
        accessToken: 'tok',
      );
      expect(config.country, 'MX');
      expect(config.language, 'ES');
      expect(config.apiVersion, StorefrontConfig.defaultApiVersion);
    });

    test('a live alias accepts the checkout URL on any live host', () {
      // Shopify returns cart.checkoutUrl on the shop's primary domain,
      // whichever live alias the app was configured with.
      const config = StorefrontConfig(
        shopDomain: 'fakcei-n9.myshopify.com',
        accessToken: 'tok',
      );
      expect(config.checkoutHosts, StorefrontConfig.productionShopDomains);
      final policy = CheckoutUrlPolicy(allowedHosts: config.checkoutHosts);
      expect(
        () => policy.validate('https://monetta.mx/cart/c/abc?key=k'),
        returnsNormally,
      );
      expect(
        () => policy.validate('https://www.monetta.mx/cart/c/abc?key=k'),
        returnsNormally,
      );
    });

    test('a development shop accepts only its own checkout host', () {
      const config = StorefrontConfig(
        shopDomain: 'monetta-staging.myshopify.com',
        accessToken: 'tok',
      );
      expect(config.checkoutHosts, {'monetta-staging.myshopify.com'});
      final policy = CheckoutUrlPolicy(allowedHosts: config.checkoutHosts);
      expect(
        () => policy.validate('https://monetta.mx/cart/c/abc?key=k'),
        throwsA(isA<CheckoutUrlPolicyException>()),
      );
    });

    test('fromEnvironment without dart-defines is not usable', () {
      // Unit tests do not pass --dart-define values, so this is the cold default.
      final config = StorefrontConfig.fromEnvironment();
      expect(config.isUsable, isFalse);
      expect(config.toString(), isNot(contains('shpss_')));
    });
  });
}
