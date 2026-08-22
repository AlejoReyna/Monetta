import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/customer_auth/customer_account_config.dart';

void main() {
  group('CustomerAccountConfig', () {
    test('isUsable is false with empty fields', () {
      const config = CustomerAccountConfig(
        shopDomain: '',
        shopId: '',
        clientId: '',
        redirectUri: '',
      );
      expect(config.isUsable, isFalse);
    });

    test('isUsable is true once every field is a real, non-placeholder value',
        () {
      const config = CustomerAccountConfig(
        shopDomain: 'shop.example.com',
        shopId: '12345',
        clientId: 'shp_abc',
        redirectUri: 'shop.12345.oauth://callback',
      );
      expect(config.isUsable, isTrue);
    });

    test('discovery endpoints use the storefront domain', () {
      const config = CustomerAccountConfig(
        shopDomain: 'clientes.example.com',
        shopId: '12345',
        clientId: 'shp_abc',
        redirectUri: 'shop.12345.oauth://callback',
      );
      expect(
        config.openIdConfigurationEndpoint.toString(),
        'https://clientes.example.com/.well-known/openid-configuration',
      );
      expect(
        config.customerApiDiscoveryEndpoint.toString(),
        'https://clientes.example.com/.well-known/customer-account-api',
      );
    });

    test(
        'an empty API version is not usable — it would build a /api//graphql URL',
        () {
      const config = CustomerAccountConfig(
        shopDomain: 'shop.example.com',
        shopId: '12345',
        clientId: 'shp_abc',
        redirectUri: 'shop.12345.oauth://callback',
        apiVersion: '',
      );
      expect(config.isUsable, isFalse);
    });

    test('the API version is pinned, never unstable', () {
      expect(
        CustomerAccountConfig.defaultApiVersion,
        isNot(contains('unstable')),
      );
      expect(
        CustomerAccountConfig.fromEnvironment().apiVersion,
        isNot(contains('unstable')),
      );
    });

    test(
      'fromEnvironment() defaults to the placeholder shop id and is not usable',
      () {
        final config = CustomerAccountConfig.fromEnvironment();
        expect(config.isUsable, isFalse);
        expect(config.shopId, 'replace_with_shop_id');
        expect(config.shopDomain, isEmpty);
      },
    );
  });
}
