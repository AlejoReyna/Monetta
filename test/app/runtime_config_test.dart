import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/runtime_config.dart';
import 'package:monetta_app/data/firestore/firestore_catalog_config.dart';

void main() {
  const enabled = FirestoreCatalogConfig(enabled: true);
  const disabled = FirestoreCatalogConfig(enabled: false);

  test('an unspecified environment cannot silently use the bundled catalog',
      () {
    const config = RuntimeConfig(
      environment: null,
      allowOfflineCatalog: false,
    );

    expect(
      config.catalogConfigurationError(
        firestore: disabled,
        hasFirebaseOptions: false,
        hasShopify: false,
      ),
      contains('APP_ENV'),
    );
  });

  test('staging requires Firestore and complete Firebase options', () {
    const config = RuntimeConfig(
      environment: AppEnvironment.staging,
      allowOfflineCatalog: false,
    );

    expect(
      config.catalogConfigurationError(
        firestore: disabled,
        hasFirebaseOptions: true,
        hasShopify: false,
      ),
      contains('FIRESTORE_CATALOG_ENABLED'),
    );
    expect(
      config.catalogConfigurationError(
        firestore: enabled,
        hasFirebaseOptions: false,
        hasShopify: false,
      ),
      contains('Firebase'),
    );
    expect(
      config.catalogConfigurationError(
        firestore: enabled,
        hasFirebaseOptions: true,
        hasShopify: false,
      ),
      isNull,
    );
  });

  test('offline catalog use must be explicit and local', () {
    const config = RuntimeConfig(
      environment: AppEnvironment.local,
      allowOfflineCatalog: true,
    );

    expect(
      config.catalogConfigurationError(
        firestore: disabled,
        hasFirebaseOptions: false,
        hasShopify: false,
      ),
      isNull,
    );
  });

  test('a bare Debug launch safely defaults to the local catalog', () {
    final config = RuntimeConfig.fromEnvironment(debugMode: true);

    expect(config.environment, AppEnvironment.local);
    expect(config.allowOfflineCatalog, isTrue);
  });

  test('a bare release launch remains blocked', () {
    final config = RuntimeConfig.fromEnvironment(debugMode: false);

    expect(config.environment, isNull);
    expect(config.allowOfflineCatalog, isFalse);
  });
}
