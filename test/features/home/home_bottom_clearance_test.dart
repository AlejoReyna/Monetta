import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/main.dart';

// NAV-10: Home extends its body behind the persistent navigation, so the
// trailing clearance has to be exactly as tall as the bar or the last content
// ends up hidden under it (or leaves a gap above it).

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
  final bleed =
      find.byKey(const ValueKey('home-account-invitation-bottom-bleed'));
  final surface = find.byKey(const Key('bottom-nav-surface'));

  testWidgets(
      'NAV-10 the home bottom clearance is as tall as the navigation bar',
      (tester) async {
    _phone(tester);
    final store = await _loadedStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(_app(store));
    await tester.pump();

    await _scrollToBleed(tester, bleed);

    expect(surface, findsOneWidget);
    final bar = tester.getSize(surface).height;
    expect(tester.getSize(bleed).height, bar);
    expect(bar, 106, reason: '72 + 34 of safe area');
  });
}
