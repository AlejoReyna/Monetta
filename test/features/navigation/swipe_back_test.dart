import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/motion.dart';
import 'package:monetta_app/app/theme.dart';

const _previousKey = Key('previous-page');
const _currentKey = Key('current-page');

Widget _page(Key key, {Widget? body}) => Scaffold(
      key: key,
      body: body ?? const Center(child: Text('Page')),
    );

Future<GlobalKey<NavigatorState>> _mount(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.iOS,
  Widget? home,
  bool disableAnimations = false,
  bool accessibleNavigation = false,
}) async {
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      theme: buildTheme().copyWith(platform: platform),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: disableAnimations,
          accessibleNavigation: accessibleNavigation,
        ),
        child: child!,
      ),
      home: home ?? _page(_previousKey),
    ),
  );
  return navigator;
}

Future<void> _push(
  WidgetTester tester,
  GlobalKey<NavigatorState> navigator, {
  Widget? page,
  bool material = false,
}) async {
  final child = page ?? _page(_currentKey);
  // Existing MaterialPageRoute callers and the shopper helper must interoperate.
  unawaited(
    navigator.currentState!.push<void>(
      material
          ? MaterialPageRoute<void>(builder: (_) => child)
          : monettaPageRoute<void>(child),
    ),
  );
  await tester.pumpAndSettle();
}

Future<TestGesture> _swipe(WidgetTester tester, double distance) async {
  final gesture = await tester.startGesture(const Offset(5, 300));
  await gesture.moveBy(const Offset(30, 0));
  await tester.pump();
  await gesture.moveBy(Offset(distance, 0));
  await tester.pump();
  return gesture;
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform swipe follows finger and restores previous scroll',
        (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final navigator = await _mount(
        tester,
        platform: platform,
        home: _page(
          _previousKey,
          body: ListView.builder(
            controller: scroll,
            itemExtent: 80,
            itemCount: 40,
            itemBuilder: (_, index) => Text('Item $index'),
          ),
        ),
      );
      scroll.jumpTo(640);
      await tester.pump();
      await _push(tester, navigator);

      final gesture = await _swipe(tester, 200);
      expect(navigator.currentState!.userGestureInProgress, isTrue);
      expect(tester.getTopLeft(find.byKey(_currentKey)).dx, closeTo(230, 1));
      final previousX = tester.getTopLeft(find.byKey(_previousKey)).dx;
      expect(previousX, lessThan(0));
      expect(previousX, greaterThan(-tester.view.physicalSize.width / 3));

      // Hold before release to measure distance-based completion, not a fling.
      await gesture.moveBy(const Offset(300, 0));
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byKey(_currentKey), findsNothing);
      expect(find.byKey(_previousKey), findsOneWidget);
      expect(scroll.offset, 640);
      expect(navigator.currentState!.canPop(), isFalse);
      expect(navigator.currentState!.userGestureInProgress, isFalse);
    });

    testWidgets('$platform short swipe returns to current page',
        (tester) async {
      final navigator = await _mount(tester, platform: platform);
      await _push(tester, navigator, material: true);
      final gesture = await _swipe(tester, 100);
      expect(tester.getTopLeft(find.byKey(_currentKey)).dx, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byKey(_currentKey), findsOneWidget);
      expect(tester.getTopLeft(find.byKey(_currentKey)).dx, 0);
      expect(navigator.currentState!.canPop(), isTrue);
      expect(navigator.currentState!.userGestureInProgress, isFalse);
    });
  }

  testWidgets('nested swipe returns exactly one page', (tester) async {
    final navigator = await _mount(tester);
    await _push(tester, navigator);
    const thirdKey = Key('third-page');
    await _push(tester, navigator, page: _page(thirdKey), material: true);
    final gesture = await _swipe(tester, 500);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(thirdKey), findsNothing);
    expect(find.byKey(_currentKey), findsOneWidget);
    expect(navigator.currentState!.canPop(), isTrue);
  });

  testWidgets('root and blocked routes ignore back swipes', (tester) async {
    final navigator = await _mount(tester);
    var gesture = await _swipe(tester, 500);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(_previousKey), findsOneWidget);
    expect(navigator.currentState!.userGestureInProgress, isFalse);

    await _push(
      tester,
      navigator,
      page: PopScope(canPop: false, child: _page(_currentKey)),
    );
    gesture = await _swipe(tester, 500);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(_currentKey), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(_currentKey)).dx, 0);
  });

  testWidgets('content swipes change gallery without navigating back',
      (tester) async {
    final navigator = await _mount(tester);
    final gallery = PageController(initialPage: 1);
    addTearDown(gallery.dispose);
    await _push(
      tester,
      navigator,
      page: _page(
        _currentKey,
        body: PageView(
          controller: gallery,
          children: const [Text('Photo 1'), Text('Photo 2')],
        ),
      ),
    );
    await tester.dragFrom(const Offset(200, 300), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(gallery.page, 0);
    expect(find.byKey(_currentKey), findsOneWidget);
    expect(navigator.currentState!.canPop(), isTrue);
  });

  testWidgets('vertical drag at the edge scrolls without navigating back',
      (tester) async {
    final navigator = await _mount(tester);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await _push(
      tester,
      navigator,
      page: _page(
        _currentKey,
        body: ListView(
          controller: scroll,
          children: const [SizedBox(height: 2000)],
        ),
      ),
    );
    await tester.dragFrom(const Offset(5, 450), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
    expect(find.byKey(_currentKey), findsOneWidget);
    expect(navigator.currentState!.userGestureInProgress, isFalse);
  });

  for (final accessibleNavigation in [false, true]) {
    testWidgets('reduced motion ($accessibleNavigation) keeps swipe navigation',
        (tester) async {
      final navigator = await _mount(
        tester,
        disableAnimations: !accessibleNavigation,
        accessibleNavigation: accessibleNavigation,
      );
      await _push(tester, navigator);
      final gesture = await _swipe(tester, 500);
      expect(tester.getTopLeft(find.byKey(_currentKey)).dx, 0);
      expect(tester.getTopLeft(find.byKey(_previousKey)).dx, 0);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byKey(_currentKey), findsNothing);
      expect(find.byKey(_previousKey), findsOneWidget);
    });
  }
}
