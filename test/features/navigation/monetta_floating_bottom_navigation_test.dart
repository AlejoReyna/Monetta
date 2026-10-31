import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/monetta_tokens.g.dart';
import 'package:monetta_app/app/motion.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/navigation/monetta_bottom_navigation.dart';
import 'package:monetta_app/features/navigation/monetta_floating_bottom_navigation.dart';
import 'package:monetta_app/main.dart';

import '../../support/catalog_browse_fixtures.dart';

void main() {
  testWidgets('every tab forwards its destination and updates the selection',
      (tester) async {
    final calls = <MonettaBottomDestination>[];
    var current = MonettaBottomDestination.home;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              bottomNavigationBar: MonettaFloatingBottomNavigation(
                current: current,
                bagCount: 2,
                onSelected: (destination) {
                  calls.add(destination);
                  setState(() => current = destination);
                },
              ),
            );
          },
        ),
      ),
    );
    for (final destination in MonettaBottomDestination.values) {
      final tab = find.byKey(Key('bottom-nav-${destination.name}'));
      await tester.tap(tab);
      await tester.pump();
      final semantics = tester.widget<Semantics>(
        find.ancestor(of: tab, matching: find.byType(Semantics)).first,
      );
      expect(semantics.properties.selected, isTrue);
    }
    expect(calls, MonettaBottomDestination.values);
  });

  testWidgets('large bag counts stay compact and announce the actual quantity',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          bottomNavigationBar: MonettaFloatingBottomNavigation(
            current: MonettaBottomDestination.home,
            bagCount: 100,
            onSelected: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('9+'), findsOneWidget);
    expect(find.bySemanticsLabel('Carrito, 100 artículos'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('catalog badge follows bag changes after the route is opened',
      (tester) async {
    final db = openTestDatabase();
    final store = CatalogStore(database: db);
    addTearDown(() async {
      store.dispose();
      await db.close();
    });
    await store.loadFromAsset();
    final product = store.products.firstWhere((p) => p.isInStock);
    await tester.pumpWidget(
      StoreScope(
        notifier: store,
        child: MaterialApp(
          theme: buildLightTheme(),
          home: browseScreen(bagCount: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bottom-nav-bag-badge')), findsNothing);
    await tester.runAsync(() => store.addToBag(product));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<MonettaBottomNavigation>(
            find.byType(MonettaBottomNavigation),
          )
          .bagCount,
      1,
    );
    expect(find.byKey(const Key('bottom-nav-bag-badge')), findsOneWidget);
  });

  Widget dock(ThemeData theme) {
    return MaterialApp(
      theme: theme,
      home: Scaffold(
        bottomNavigationBar: MonettaFloatingBottomNavigation(
          current: MonettaBottomDestination.home,
          bagCount: 0,
          onSelected: (_) {},
        ),
      ),
    );
  }

  testWidgets(
      'light mode paints the shipped bar and emphasizes the selected label',
      (tester) async {
    await tester.pumpWidget(dock(buildLightTheme()));

    // The floating pill is gone. The compatibility widget draws the shipped
    // full-width bar: a DecoratedBox in the bar color, selected label at
    // w600 with an underline, the others at w400.
    final surface = find.byKey(const Key('bottom-nav-surface'));
    final decoration =
        tester.widget<DecoratedBox>(surface).decoration as BoxDecoration;
    expect(decoration.color, MonettaTokens.bar);
    expect(
      tester.getSize(surface).width,
      tester.view.physicalSize.width / tester.view.devicePixelRatio,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('bottom-nav-home-label')))
          .style!
          .fontWeight,
      FontWeight.w600,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('bottom-nav-home-label')))
          .style!
          .decoration,
      TextDecoration.underline,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('bottom-nav-catalog-label')))
          .style!
          .fontWeight,
      FontWeight.w400,
    );
  });

  testWidgets('dark mode keeps the dark bar surface', (tester) async {
    await tester.pumpWidget(dock(buildDarkTheme()));

    final decoration = tester
        .widget<DecoratedBox>(find.byKey(const Key('bottom-nav-surface')))
        .decoration as BoxDecoration;
    expect(decoration.color, MonettaColors.dark.navigationSurface);
  });

  testWidgets('the dock stays put while the next page slides behind it', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    final navigator = GlobalKey<NavigatorState>();
    Widget page(String name, MonettaBottomDestination current) {
      return Scaffold(
        body: Center(child: Text(name, key: Key('$name-marker'))),
        bottomNavigationBar: MonettaFloatingBottomNavigation(
          current: current,
          bagCount: 0,
          onSelected: (_) {},
        ),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        theme: buildLightTheme().copyWith(platform: TargetPlatform.iOS),
        home: page('home', MonettaBottomDestination.home),
      ),
    );
    final bars = find.byKey(const Key('bottom-nav-surface'));
    final before = tester.getRect(bars);

    unawaited(
      navigator.currentState!.push<void>(
        monettaPageRoute<void>(
          page('catalog', MonettaBottomDestination.catalog),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    // The bar belongs to its page, so it travels with that page. Mid-push
    // both bars are mounted and the incoming page has not finished arriving.
    expect(bars, findsNWidgets(2));
    expect(
      tester.getTopLeft(find.byKey(const Key('catalog-marker'))).dx,
      greaterThan(20),
    );

    await tester.pumpAndSettle();
    expect(bars, findsOneWidget);
    final after = tester.getRect(bars);
    expect(after.left, closeTo(before.left, 1));
    expect(after.width, closeTo(before.width, 1));

    unawaited(navigator.currentState!.maybePop());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(bars, findsNWidgets(2));
    expect(
      tester.getTopLeft(find.byKey(const Key('catalog-marker'))).dx,
      greaterThan(20),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('catalog-marker'))).dx,
      greaterThan(20),
    );
    await tester.pumpAndSettle();
  });
}
