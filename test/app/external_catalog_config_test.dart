import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/external_catalog_config.dart';
import 'package:monetta_app/app/external_catalog_controller.dart';

void main() {
  group('ExternalCatalogConfig — retired (WP-02 / F03)', () {
    test('fromEnvironment is always disabled', () {
      final config = ExternalCatalogConfig.fromEnvironment();
      expect(config.enabled, isFalse);
      expect(config.baseUrl, isNull);
    });

    test('disabled constant remains the safe default', () {
      expect(ExternalCatalogConfig.disabled.enabled, isFalse);
      expect(ExternalCatalogConfig.disabled.baseUrl, isNull);
    });

    test('controller stays inert even if constructed enabled without URL',
        () async {
      const config = ExternalCatalogConfig(enabled: true, baseUrl: null);
      final controller = ExternalCatalogController(config: config);
      await controller.loadAndRefresh();
      expect(controller.enabled, isFalse);
      expect(controller.items, isEmpty);
    });
  });
}
