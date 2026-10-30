import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/features/navigation/monetta_bottom_navigation.dart';

// NAV-08 text contrast. It lives apart from monetta_bottom_navigation_test.dart
// because that file loads the bundled fonts: the guideline samples rendered
// pixels, and the anti-aliased edges of thin real glyphs come out lighter on
// the Linux CI rasterizer than on macOS. FlutterTest's solid glyphs keep the
// sample equal to the label colour on every platform.

void main() {
  testWidgets('NAV-08 labels meet the text contrast guideline', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(bottom: 34);
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: MonettaBottomNavigation(
              current: MonettaBottomDestination.catalog,
              bagCount: 2,
              onSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(textContrastGuideline));
    } finally {
      handle.dispose();
    }
  });
}
