import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/product_telemetry.dart';

void main() {
  test('telemetry keeps only bounded, non-identifying fields', () {
    expect(
      sanitizeTelemetryParameters({
        'source': 'shopify',
        'result_count': 4,
        'success': true,
        'email': 'shopper@example.com',
        'customer_id': 'gid://shopify/Customer/1',
        'query': 'bolsa secreta',
        'brand': 'x' * 81,
      }),
      {
        'source': 'shopify',
        'result_count': 4,
        'success': true,
      },
    );
  });

  test('disabled telemetry is a safe no-op', () async {
    const telemetry = DisabledProductTelemetry();
    await telemetry.log(ProductEvent.appOpen);
    await telemetry.recordError(StateError('test'), StackTrace.current);
    expect(telemetry.enabled, isFalse);
  });
}
