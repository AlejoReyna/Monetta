import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:monetta_app/main.dart' as app;

/// Real application launch using CI defines and isolated test-device storage.
/// This is an offline app smoke, not Shopify authentication/payment evidence.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('launch application, browse and open account navigation',
      (tester) async {
    await app.main();
    for (var i = 0; i < 60 && find.text('Home').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.byType(MaterialApp), findsOneWidget);

    // A fresh install opens on the first-visit welcome. Dismiss it the way a
    // shopper who does not want to personalise would, then carry on with the
    // store itself. A device that has already made the choice skips this.
    final startButton = find.byKey(const ValueKey('welcome-start-button'));
    if (startButton.evaluate().isNotEmpty) {
      await tester.tap(startButton);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
      await tester.pump(const Duration(seconds: 1));
      expect(startButton, findsNothing);
    }

    // The actual app uses a custom bottom bar; verify its public labels.
    expect(find.text('Home'), findsWidgets);
    await tester.tap(find.byKey(const Key('bottom-nav-catalog')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('catalog-filter-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('catalog-filter-button')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('catalog-filter-apply')), findsOneWidget);
    await tester.tap(find.byKey(const Key('catalog-filter-clear')));
    await tester.tap(find.byKey(const Key('catalog-filter-apply')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('catalog-filter-apply')), findsNothing);
    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 500));
    final account = find.text('Cuenta');
    expect(account, findsWidgets);
    await tester.tap(account.last);
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('sesión'), findsWidgets);
  });
}
