import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/card_lift.dart';
import 'package:monetta_app/app/motion.dart';

void main() {
  Widget card({VoidCallback? onTap}) => MaterialApp(
        home: Center(
          child: MonettaCardLift(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: const SizedBox(width: 180, height: 240),
            ),
          ),
        ),
      );

  double shadowOpacity(WidgetTester tester) {
    final surface = tester.widget<DecoratedBox>(find.descendant(
      of: find.byType(MonettaCardLift),
      matching: find.byType(DecoratedBox),
    ));
    return (surface.decoration as BoxDecoration).boxShadow!.first.color.a;
  }

  testWidgets('quick taps remain visible without delaying the child action',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(card(onTap: () => taps++));
    // Down and up can both arrive before the next frame.
    await tester.tap(find.byType(MonettaCardLift));
    await tester.pump();
    expect(taps, 1);
    expect(shadowOpacity(tester), greaterThan(0));
    await tester.pump(kSnap);
    expect(shadowOpacity(tester), 0);
  });

  testWidgets('dragging and cancelled touches release the card immediately',
      (tester) async {
    await tester.pumpWidget(card());
    final center = tester.getCenter(find.byType(MonettaCardLift));
    final drag = await tester.startGesture(center);
    await tester.pump();
    expect(shadowOpacity(tester), greaterThan(0));
    await drag.moveBy(const Offset(0, 60));
    await tester.pump();
    expect(shadowOpacity(tester), 0);
    await drag.up();

    final touch = await tester.startGesture(center);
    await tester.pump();
    await touch.cancel();
    await tester.pump();
    expect(shadowOpacity(tester), 0);
  });
}
