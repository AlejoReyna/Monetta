import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Minimal integration_test entry so CI format/analyze paths resolve (F30).
/// Device push / Checkout Kit journeys remain owner-gated and are not faked here.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('integration_test harness is wired', (tester) async {
    expect(true, isTrue);
  });
}
