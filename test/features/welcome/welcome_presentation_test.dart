import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/features/welcome/welcome_screen.dart';

import '../../support/client_guide_capture.dart';

void main() {
  for (final (size, scale) in [
    (const Size(390, 844), 1.0),
    (const Size(320, 568), 2.0),
    (const Size(834, 1194), 1.0),
    (const Size(844, 390), 1.0),
  ]) {
    testWidgets('welcome copy and action at $size / $scale', (tester) async {
      var started = false;
      await pumpClientGuide(
        tester,
        WelcomeScreen(onStart: () => started = true),
        size: size,
        textScale: scale,
      );
      expect(find.text('Un paraíso de marcas\npor descubrir'), findsOneWidget);
      expect(
        find.text('BOUTIQUE ONLINE DE\nPRODUCTOS ORIGINALES'),
        findsOneWidget,
      );
      final action = find.byKey(const ValueKey('welcome-start-button'));
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (scale == 1) {
        await captureClientGuide(tester, 'welcome-${size.width.toInt()}');
      }
      await tester.tap(action);
      expect(started, isTrue);
    });
  }
}
