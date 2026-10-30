/// Web-parity pass: the app-bar wordmark grew from 24 to 28.5 while the
/// toolbars keep their height (60 on the home, 56 on the guide screens).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/features/navigation/guide_chrome.dart';
import 'package:monetta_app/main.dart';

import '../../support/bundled_fonts.dart';

Future<CatalogStore> _store() async {
  final store = CatalogStore(database: openTestDatabase());
  await store.loadFromAsset();
  return store;
}

Widget _app(Widget home, {double textScale = 1}) => MaterialApp(
      theme: buildLightTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: home,
    );

Widget _guideScreen() => Builder(
      builder: (context) => Scaffold(
        appBar: guideAppBar(context, onSearch: () {}),
        body: const SizedBox.expand(),
      ),
    );

void _view(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder _wordmarkIn(Finder bar) =>
    find.descendant(of: bar, matching: find.byType(MonettaWordmark));

void main() {
  setUpAll(loadBundledFonts);

  test('the app-bar wordmark token is 28.5, up from 24', () {
    expect(kAppBarWordmarkHeight, 28.5);
    expect(const MonettaWordmark.appBar().height, 28.5);
  });

  testWidgets('home: bigger wordmark, toolbar still 60', (tester) async {
    _view(tester, const Size(390, 844));
    final store = await _store();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      _app(StoreScope(notifier: store, child: const HomeScreen())),
    );
    await tester.pump();

    final bar = find.byType(AppBar);
    expect(tester.widget<AppBar>(bar).toolbarHeight, 60);
    // 60 plus the bar's hairline.
    expect(
      tester.getSize(bar).height,
      tester.widget<AppBar>(bar).preferredSize.height,
    );
    expect(tester.widget<AppBar>(bar).preferredSize.height, closeTo(60, 1));
    final mark = _wordmarkIn(bar);
    expect(tester.getSize(mark).height, 28.5);
    expect(tester.widget<MonettaWordmark>(mark).height, 28.5);
    // Centred between the menu and search buttons.
    expect(tester.getCenter(mark).dx, closeTo(390 / 2, 1));
  });

  testWidgets('guide screen: bigger wordmark, toolbar still 56', (
    tester,
  ) async {
    _view(tester, const Size(390, 844));
    await tester.pumpWidget(_app(_guideScreen()));
    await tester.pump();

    final bar = find.byType(AppBar);
    expect(tester.getSize(bar).height, kToolbarHeight);
    expect(kToolbarHeight, 56);
    expect(tester.getSize(_wordmarkIn(bar)).height, 28.5);
    expect(tester.getSize(_wordmarkIn(bar)).height, lessThan(56));
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('home does not overflow at 320 px and text scale $scale', (
      tester,
    ) async {
      _view(tester, const Size(320, 700));
      final store = await _store();
      addTearDown(store.dispose);
      await tester.pumpWidget(
        _app(
          StoreScope(notifier: store, child: const HomeScreen()),
          textScale: scale,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 60);
      expect(tester.getSize(find.byType(AppBar)).height, closeTo(60, 1));
      final mark = _wordmarkIn(find.byType(AppBar));
      expect(tester.getSize(mark).height, 28.5);
      // The wordmark keeps clear of the two 56 px bar buttons.
      expect(tester.getTopLeft(mark).dx, greaterThanOrEqualTo(56));
      expect(tester.getTopRight(mark).dx, lessThanOrEqualTo(320 - 56));
    });

    testWidgets(
        'guide screen does not overflow at 320 px and text scale $scale', (
      tester,
    ) async {
      _view(tester, const Size(320, 700));
      await tester.pumpWidget(_app(_guideScreen(), textScale: scale));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(AppBar)).height, kToolbarHeight);
      final mark = _wordmarkIn(find.byType(AppBar));
      expect(tester.getSize(mark).height, 28.5);
      expect(tester.getTopLeft(mark).dx, greaterThanOrEqualTo(56));
      expect(tester.getTopRight(mark).dx, lessThanOrEqualTo(320 - 56));
    });
  }
}
