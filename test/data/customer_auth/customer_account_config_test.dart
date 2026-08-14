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

    test('fromEnvironment() defaults to the placeholder shop id and is not usable', () {
      final config = CustomerAccountConfig.fromEnvironment();
      expect(config.isUsable, isFalse);
      expect(config.shopId, 'replace_with_shop_id');
    });
  });
}
