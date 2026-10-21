import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/monetta_tokens.g.dart';
import 'package:monetta_app/app/motion.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
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
          home: browseScreen(const [], bagCount: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bottom-nav-bag-badge')), findsNothing);
    await tester.runAsync(() => store.addToBag(product));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<MonettaFloatingBottomNavigation>(
            find.byType(MonettaFloatingBottomNavigation),
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
      'light mode paints the flat bar in the shared bar color; the selection is '
      'accent color, weight and a rule', (
    tester,
  ) async {
    await tester.pumpWidget(dock(buildLightTheme()));

    final surface = find.byKey(const Key('bottom-nav-surface'));
    expect(tester.widget<Material>(surface).color, MonettaTokens.bar);
    // Full width and flat: it spans the screen and has no rounded corners.
    expect(
      tester.getSize(surface).width,
      tester.view.physicalSize.width / tester.view.devicePixelRatio,
    );
    expect(tester.widget<Material>(surface).shape, isNot(isA<StadiumBorder>()));

    final rule = tester.widget<Container>(
      find.byKey(const Key('bottom-nav-home-rule')),
    );
    expect(
      (rule.decoration! as BoxDecoration).color,
      MonettaTokens.navigationActive,
    );
    expect(
      tester.getSize(find.byKey(const Key('bottom-nav-home-rule'))),
      const Size(28, 2),
    );
    expect(find.byKey(const Key('bottom-nav-catalog-rule')), findsNothing);
    expect(
      tester.widget<Icon>(find.byKey(const Key('bottom-nav-home-icon'))).color,
      MonettaTokens.navigationActive,
    );
    expect(
      tester
          .widget<Icon>(find.byKey(const Key('bottom-nav-catalog-icon')))
          .color,
      MonettaTokens.navigationInactive,
    );
    final label =
        tester.widget<Text>(find.byKey(const Key('bottom-nav-home-label')));
    expect(label.style!.fontWeight, FontWeight.w600);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('bottom-nav-catalog-label')))
          .style!
          .fontWeight,
      FontWeight.w500,
    );
  });

  testWidgets('dark mode keeps the dark bar and selects with the gold accent', (
    tester,
  ) async {
    await tester.pumpWidget(dock(buildDarkTheme()));

    expect(
      tester
          .widget<Material>(find.byKey(const Key('bottom-nav-surface')))
          .color,
      const Color(0xFF191A18),
    );
    expect(
      tester.widget<Icon>(find.byKey(const Key('bottom-nav-home-icon'))).color,
      MonettaColors.dark.accent,
    );
    expect(
      tester
          .widget<Icon>(find.byKey(const Key('bottom-nav-catalog-icon')))
          .color,
      const Color(0xFFC2C3BB),
    );
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
    final before = tester.getRect(find.byKey(const Key('bottom-nav-surface')));

    unawaited(
      navigator.currentState!.push<void>(
        monettaPageRoute<void>(
          page('catalog', MonettaBottomDestination.catalog),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final during = tester.getRect(find.byKey(const Key('bottom-nav-surface')));
    expect(during.left, closeTo(before.left, 1));
    expect(during.top, closeTo(before.top, 1));
    expect(during.width, closeTo(before.width, 1));
    expect(
      tester.getTopLeft(find.byKey(const Key('catalog-marker'))).dx,
      greaterThan(20),
    );

    await tester.pumpAndSettle();
    final after = tester.getRect(find.byKey(const Key('bottom-nav-surface')));
    expect(after.left, closeTo(before.left, 1));
    expect(after.top, closeTo(before.top, 1));

    unawaited(navigator.currentState!.maybePop());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final popping = tester.getRect(find.byKey(const Key('bottom-nav-surface')));
    expect(popping.left, closeTo(before.left, 1));
    expect(popping.top, closeTo(before.top, 1));
    expect(
      tester.getTopLeft(find.byKey(const Key('catalog-marker'))).dx,
      greaterThan(20),
    );
    await tester.pumpAndSettle();
  });
}
