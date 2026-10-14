import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/main.dart';

// The home body extends behind the navigation. The closing band keeps the
// copyright a full bar-height plus 24 above the bottom edge, so the line is
// not hidden under the bar.

Future<CatalogStore> _loadedStore() async {
  final store = CatalogStore(database: openTestDatabase());
  await store.loadFromAsset();
  return store;
}

Widget _app(CatalogStore store) {
  return MaterialApp(
    theme: buildLightTheme(),
    home: StoreScope(
      notifier: store,
      child: const HomeScreen(),
    ),
  );
}

Finder _homeScroll() => find
    .byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    )
    .first;

void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  tester.view.padding = const FakeViewPadding(bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(bottom: 34);
  addTearDown(tester.view.reset);
}

Future<void> _scrollToBleed(WidgetTester tester, Finder bleed) async {
  await tester.scrollUntilVisible(bleed, 800, scrollable: _homeScroll());
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  final clearance = find.byKey(const ValueKey('home-closing-nav-clearance'));
  final surface = find.byKey(const Key('bottom-nav-surface'));

  testWidgets('home footer clearance is the navigation bar plus 24', (
    tester,
  ) async {
    _phone(tester);
    final store = await _loadedStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(_app(store));
    await tester.pump();

    await _scrollToBleed(tester, clearance);

    expect(surface, findsOneWidget);
    final bar = tester.getSize(surface).height;
    expect(tester.getSize(clearance).height, bar + 24);
    expect(bar, 90, reason: '56 + 34 of safe area');
  });
}
