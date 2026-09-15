import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/startup_reveal.dart';
import 'package:monetta_app/app/motion.dart';
import 'package:monetta_app/app/theme.dart';

void main() {
  Widget app({required bool ready, bool reduceMotion = false}) => MaterialApp(
        theme: buildLightTheme(),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: StartupReveal(
            ready: ready,
            child: ready
                ? const Scaffold(body: Reveal(child: Text('Catalog ready')))
                : const SizedBox.expand(),
          ),
        ),
      );

  testWidgets('covers the ready catalog until the wordmark reveal finishes',
      (tester) async {
    await tester.pumpWidget(app(ready: false));
    expect(find.byType(MonettaWordmark), findsOneWidget);
    final initialWidth = tester.getSize(find.byType(ClipRect).last).width;
    expect(initialWidth, closeTo(30 / 38 * 48, 0.1));
    expect(find.text('Catalog ready'), findsNothing);

    await tester.pumpWidget(app(ready: true));
    expect(find.text('Catalog ready'), findsOneWidget);
    expect(find.byType(MonettaWordmark), findsOneWidget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 650));
    expect(
      tester.getSize(find.byType(ClipRect).last).width,
      closeTo(132 / 38 * 48, 0.1),
    );
    expect(find.byType(AbsorbPointer), findsWidgets);
    final homeFade = tester.widget<FadeTransition>(
      find.descendant(
        of: find.byType(Reveal),
        matching: find.byType(FadeTransition),
      ),
    );
    expect(
      homeFade.opacity.value,
      1,
      reason: 'Home must finish its entrance before the splash fades away',
    );
    await tester.pumpAndSettle();
    expect(find.byType(MonettaWordmark), findsNothing);
    expect(find.text('Catalog ready'), findsOneWidget);
  });

  testWidgets('reduced motion reveals the catalog after its first frame',
      (tester) async {
    await tester.pumpWidget(app(ready: false, reduceMotion: true));
    await tester.pumpWidget(app(ready: true, reduceMotion: true));
    await tester.pump();
    expect(find.byType(MonettaWordmark), findsNothing);
    expect(find.text('Catalog ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
