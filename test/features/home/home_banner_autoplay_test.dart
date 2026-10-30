/// Web-parity pass: the opening banner advances by itself every 5 s, loops
/// after the last slide and waits whenever autoplay would be rude.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/features/home/home_boutique_sections.dart';

import '../../support/client_guide_capture.dart';

const Duration _delay = Duration(seconds: 5);
const Duration _slide = Duration(milliseconds: 450);

PageView _hero(WidgetTester tester) => tester.widget<PageView>(
      find
          .descendant(
            of: find.byType(HomeEditorialBanner),
            matching: find.byType(PageView),
          )
          .first,
    );

/// The slide the hero rests on (settled pages are whole numbers).
int _page(WidgetTester tester) => _hero(tester).controller!.page!.round();

/// Waits [duration] and then long enough for a slide that the wait let start
/// to finish: a timer that fires inside one long `pump` only starts its
/// animation on that pump's last frame.
Future<void> _idle(WidgetTester tester, Duration duration) async {
  await tester.pump(duration);
  await tester.pump(_slide + const Duration(milliseconds: 50));
}

/// Lets a pending autoplay timer fire and its 450 ms slide finish.
Future<void> _autoplayStep(WidgetTester tester) async {
  await tester.pump(_delay);
  await tester.pump(_slide + const Duration(milliseconds: 50));
}

Future<void> _pumpBanner(
  WidgetTester tester, {
  bool playing = true,
  bool disableAnimations = false,
}) async {
  await pumpClientGuide(
    tester,
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: disableAnimations,
        ),
        child: Scaffold(
          body: HomeEditorialBanner(playing: playing, onOpenNew: () {}),
        ),
      ),
    ),
  );
}

Future<void> _swipeLeft(WidgetTester tester) async {
  await tester.drag(find.byType(PageView).first, const Offset(-300, 0));
  // Only the swipe's own settling, never a full autoplay delay.
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('advances after 5 s and loops from the last slide to the first', (
    tester,
  ) async {
    await _pumpBanner(tester);
    expect(_page(tester), 0);

    await tester.pump(const Duration(milliseconds: 4900));
    expect(_page(tester), 0, reason: 'not before the 5 s are up');

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(_slide + const Duration(milliseconds: 50));
    expect(_page(tester), 1);

    await _autoplayStep(tester);
    expect(_page(tester), 2);

    // After the last slide it goes back to the first.
    await _autoplayStep(tester);
    expect(_page(tester), 0);

    // And keeps going.
    await _autoplayStep(tester);
    expect(_page(tester), 1);
  });

  testWidgets('the slide takes 450 ms, not a jump', (tester) async {
    await _pumpBanner(tester);

    await tester.pump(_delay);
    // First frame of the animation, then roughly halfway through it.
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 200));
    final midway = _hero(tester).controller!.page!;
    expect(midway, greaterThan(0));
    expect(midway, lessThan(1));

    await tester.pump(const Duration(milliseconds: 300));
    expect(_hero(tester).controller!.page, 1);
  });

  testWidgets('does not advance with animations disabled', (tester) async {
    await _pumpBanner(tester, disableAnimations: true);

    await _idle(tester, const Duration(seconds: 30));

    expect(_page(tester), 0);
  });

  testWidgets('does not advance while playing is false, and resumes after', (
    tester,
  ) async {
    await _pumpBanner(tester, playing: false);
    await _idle(tester, const Duration(seconds: 30));
    expect(_page(tester), 0);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeEditorialBanner(playing: true, onOpenNew: () {}),
        ),
      ),
    );
    await _autoplayStep(tester);
    expect(_page(tester), 1);
  });

  testWidgets('waits while the route is covered and resumes when it returns', (
    tester,
  ) async {
    Widget app({required bool covered}) => MaterialApp(
          home: TickerMode(
            enabled: !covered,
            child: Scaffold(
              body: HomeEditorialBanner(playing: true, onOpenNew: () {}),
            ),
          ),
        );
    await tester.pumpWidget(app(covered: true));
    await _idle(tester, const Duration(seconds: 30));
    expect(_page(tester), 0);

    // Back on screen: a muted animation must not complete at once, and the
    // 5 s count starts only now.
    await tester.pumpWidget(app(covered: false));
    await tester.pump(_slide + const Duration(milliseconds: 50));
    await tester.pump(_slide + const Duration(milliseconds: 50));
    expect(_page(tester), 0);
    await _autoplayStep(tester);
    expect(_page(tester), 1);
  });

  testWidgets('does not advance while a pointer is held down', (tester) async {
    await _pumpBanner(tester);

    final hold = await tester.startGesture(
      tester.getCenter(find.byType(PageView).first),
    );
    await _idle(tester, const Duration(seconds: 12));
    expect(_page(tester), 0);

    await hold.up();
    await tester.pump(const Duration(milliseconds: 4900));
    expect(_page(tester), 0, reason: 'the count starts again on release');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(_slide + const Duration(milliseconds: 50));
    expect(_page(tester), 1);
  });

  testWidgets('a swipe restarts the 5 s count', (tester) async {
    await _pumpBanner(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(_page(tester), 0);

    await _swipeLeft(tester);
    expect(_page(tester), 1);

    // 3 s + the swipe put the first timer past 5 s long ago; a restarted
    // count has not run out yet.
    await tester.pump(const Duration(milliseconds: 4300));
    expect(_page(tester), 1);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(_slide + const Duration(milliseconds: 50));
    expect(_page(tester), 2);
  });

  testWidgets('leaves no timer behind once the banner is gone', (tester) async {
    await _pumpBanner(tester);
    await tester.pump(const Duration(seconds: 2));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 30));

    expect(tester.takeException(), isNull);
    expect(tester.binding.hasScheduledFrame, isFalse);
    // The framework itself fails the test when a Timer is still pending after
    // the tree was disposed.
  });
}
