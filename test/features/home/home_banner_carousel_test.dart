import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/media/monetta_image.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/home/home_boutique_sections.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/main.dart';

import '../../support/client_guide_capture.dart';

Finder _dots() => find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
                'home-banner-dot-',
              ),
    );

Future<void> _swipeLeft(WidgetTester tester) async {
  // The hero's pages; «Colecciones» further down is a PageView too.
  await tester.drag(
    find
        .descendant(
          of: find.byType(HomeEditorialBanner),
          matching: find.byType(PageView),
        )
        .first,
    const Offset(-300, 0),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('B01–B03: three slides, three dots, each opens its destination',
      (tester) async {
    var products = 0;
    var brands = 0;
    var categories = 0;
    await pumpClientGuide(
      tester,
      Scaffold(
        body: HomeEditorialBanner(
          playing: false,
          onOpenProducts: () => products++,
          onOpenBrands: () => brands++,
          onOpenCategories: () => categories++,
        ),
      ),
    );

    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.childrenDelegate.estimatedChildCount, 3);
    expect(_dots(), findsNWidgets(3));
    expect(find.byKey(const ValueKey('home-compact-hero')), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('home-banner-slide-products')),
      warnIfMissed: false,
    );
    expect(products, 1);

    await _swipeLeft(tester);
    await tester.tap(
      find.byKey(const ValueKey('home-banner-slide-brands')),
      warnIfMissed: false,
    );
    expect(brands, 1);

    await _swipeLeft(tester);
    await tester.tap(
      find.byKey(const ValueKey('home-banner-slide-categories')),
      warnIfMissed: false,
    );
    expect(categories, 1);
    expect(products, 1);
    expect(brands, 1);
  });

  testWidgets('the active dot follows the page', (tester) async {
    await pumpClientGuide(
      tester,
      Scaffold(
        body: HomeEditorialBanner(
          playing: false,
          onOpenProducts: () {},
          onOpenBrands: () {},
          onOpenCategories: () {},
        ),
      ),
    );
    double widthOf(int i) =>
        tester.getSize(find.byKey(ValueKey('home-banner-dot-$i'))).width;
    expect(widthOf(0), greaterThan(widthOf(1)));
    await _swipeLeft(tester);
    expect(widthOf(1), greaterThan(widthOf(0)));
    expect(widthOf(1), greaterThan(widthOf(2)));
  });

  group('inside the home', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => '/tmp',
      );
      // Product photographs never reach the network in a widget test.
      debugMonettaFixtureImage = MemoryImage(
        File('test/support/fixture_product.jpg').readAsBytesSync(),
      );
    });
    tearDown(() => debugMonettaFixtureImage = null);

    Future<CatalogStore> store() async {
      final db = openTestDatabase();
      final catalog = CatalogStore(database: db);
      await catalog.loadFromAsset();
      addTearDown(() async {
        catalog.dispose();
        await db.close();
      });
      return catalog;
    }

    testWidgets('the home opens on B01 and swipes to B02', (
      tester,
    ) async {
      final catalog = await store();
      await pumpClientGuide(
        tester,
        StoreScope(notifier: catalog, child: const HomeScreen()),
        size: const Size(390, 844),
      );
      expect(find.byKey(const ValueKey('home-banner-slide-products')),
          findsOneWidget);
      await _swipeLeft(tester);
      expect(find.byKey(const ValueKey('home-banner-slide-brands')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
