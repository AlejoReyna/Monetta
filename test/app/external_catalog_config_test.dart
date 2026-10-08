import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/external_catalog_config.dart';

void main() {
  group('ExternalCatalogConfig — retired (WP-02 / F03)', () {
    test('the flag is not requested in the test environment', () {
      expect(ExternalCatalogConfig.flagRequestedInEnvironment, isFalse);
    });
  });
}
