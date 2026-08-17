import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/customer_auth/customer_account_config.dart';

void main() {
  group('CustomerAccountConfig', () {
    test('isUsable is false with empty fields', () {
      const config = CustomerAccountConfig(shopId: '', clientId: '', redirectUri: '');
      expect(config.isUsable, isFalse);
    });

    test('isUsable is true once every field is a real, non-placeholder value', () {
      const config = CustomerAccountConfig(
        shopId: '12345',
        clientId: 'shp_abc',
        redirectUri: 'shop.12345.oauth://callback',
      );
      expect(config.isUsable, isTrue);
    });

    test('endpoints are built from the shop id', () {
      const config = CustomerAccountConfig(
        shopId: '12345',
        clientId: 'shp_abc',
        redirectUri: 'shop.12345.oauth://callback',
      );
      expect(config.authorizationEndpoint, 'https://shopify.com/authentication/12345/oauth/authorize');
      expect(config.tokenEndpoint, 'https://shopify.com/authentication/12345/oauth/token');
    });

    test('the GraphQL endpoint is the Customer Account API, not the Storefront one', () {
      const config = CustomerAccountConfig(
        shopId: '12345',
        clientId: 'shp_abc',
        redirectUri: 'shop.12345.oauth://callback',
        apiVersion: '2026-07',
      );
      expect(
        config.graphQlEndpoint.toString(),
        'https://shopify.com/12345/account/customer/api/2026-07/graphql',
      );
    });

    test('an empty API version is not usable — it would build a /api//graphql URL', () {
      const config = CustomerAccountConfig(
        shopId: '12345',
        clientId: 'shp_abc',
        redirectUri: 'shop.12345.oauth://callback',
        apiVersion: '',
      );
      expect(config.isUsable, isFalse);
    });

    test('the API version is pinned, never unstable', () {
      expect(CustomerAccountConfig.defaultApiVersion, isNot(contains('unstable')));
      expect(CustomerAccountConfig.fromEnvironment().apiVersion, isNot(contains('unstable')));
    });

    test('fromEnvironment() defaults to the placeholder shop id and is not usable', () {
      final config = CustomerAccountConfig.fromEnvironment();
      expect(config.isUsable, isFalse);
      expect(config.shopId, 'replace_with_shop_id');
    });
  });
}
