import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/shopify/shopify_gid.dart';

void main() {
  group('shopifyProductGidFromKey', () {
    test('reads the canonical GID key the backend sends', () {
      expect(
        shopifyProductGidFromKey('shopify:gid://shopify/Product/123'),
        'gid://shopify/Product/123',
      );
    });

    test('maps a numeric REST id key to the product GID', () {
      // Pushes sent before the backend canonicalized keys carry REST ids.
      expect(
        shopifyProductGidFromKey('shopify:123'),
        'gid://shopify/Product/123',
      );
    });

    test('returns null for keys that name no Shopify product', () {
      expect(shopifyProductGidFromKey('shopify:bolsa-coach'), isNull);
      expect(shopifyProductGidFromKey('external:coach_us:CU068'), isNull);
      expect(
        shopifyProductGidFromKey('shopify:gid://shopify/ProductVariant/9'),
        isNull,
      );
    });
  });
}
