import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/tooling/dart_defines_validation.dart';

void main() {
  test('rejects ENABLE_EXTERNAL_CATALOG in every environment', () {
    final errors = validateDartDefines(
      values: {
        'APP_ENV': 'local',
        'ALLOW_OFFLINE_CATALOG': 'true',
        'ENABLE_EXTERNAL_CATALOG': 'true',
      },
      expectedEnvironment: 'local',
    );
    expect(errors.join(' '), contains('ENABLE_EXTERNAL_CATALOG'));
  });

  test('staging Storefront-only is valid without Firestore', () {
    final errors = validateDartDefines(
      values: {
        'APP_ENV': 'staging',
        'ALLOW_OFFLINE_CATALOG': 'false',
        'FIRESTORE_CATALOG_ENABLED': 'false',
        'SHOPIFY_STORE_DOMAIN': 'monetta-staging.myshopify.com',
        'SHOPIFY_STOREFRONT_ACCESS_TOKEN': 'shpat_staging_token_value',
        'ENABLE_EXTERNAL_CATALOG': 'false',
      },
      expectedEnvironment: 'staging',
    );
    expect(errors, isEmpty);
  });

  test('production rejects external catalog flag', () {
    final errors = validateDartDefines(
      values: {
        'APP_ENV': 'production',
        'ALLOW_OFFLINE_CATALOG': 'false',
        'SHOPIFY_STORE_DOMAIN': 'monetta.mx',
        'SHOPIFY_STOREFRONT_ACCESS_TOKEN': 'shpat_live_token_value',
        'CUSTOMER_ACCOUNT_SHOP_ID': '123',
        'CUSTOMER_ACCOUNT_CLIENT_ID': 'abc',
        'ACCOUNTS_ORDERS_BASE_URL': 'https://api.monetta.mx',
        'ENABLE_EXTERNAL_CATALOG': 'true',
      },
      expectedEnvironment: 'production',
    );
    expect(errors.join(' '), contains('ENABLE_EXTERNAL_CATALOG'));
  });
}
