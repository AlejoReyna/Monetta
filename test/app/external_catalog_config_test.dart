import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/external_catalog_config.dart';
import 'package:monetta_app/app/external_catalog_controller.dart';

void main() {
  group('ExternalCatalogConfig.fromEnvironment', () {
    test('is disabled by default (no --dart-define passed in this test run)',
        () {
      final config = ExternalCatalogConfig.fromEnvironment();
      expect(config.enabled, isFalse);
    });

    test('ExternalCatalogConfig.disabled is the safe default value', () {
      expect(ExternalCatalogConfig.disabled.enabled, isFalse);
      expect(ExternalCatalogConfig.disabled.baseUrl, isNull);
    });

    test('a flag with no base URL is treated as disabled, not half-on', () {
      const config = ExternalCatalogConfig(enabled: true, baseUrl: null);
      // Constructing directly with enabled:true + no URL is possible, but the
      // controller must still refuse to build a repository — see below.
      final controller = ExternalCatalogController(config: config);
      expect(controller.enabled, isFalse);
    });
  });

  group('ExternalCatalogController — disabled by default', () {
    test('items is empty and loadAndRefresh is a no-op', () async {
      final controller =
          ExternalCatalogController(config: ExternalCatalogConfig.disabled);
      await controller.loadAndRefresh();
      expect(controller.items, isEmpty);
      expect(controller.enabled, isFalse);
    });
  });
}
