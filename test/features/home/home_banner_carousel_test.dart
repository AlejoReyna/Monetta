import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/media/monetta_image.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/boutique/guide_art.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/home/home_boutique_sections.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/main.dart';

import '../../support/client_guide_capture.dart';
import '../../support/guide_photo_finders.dart';

Finder _dots() => find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
                'home-banner-dot-',
              ),
    );

Future<void> _swipeLeft(WidgetTester tester) async {
  await tester.drag(find.byType(PageView), const Offset(-300, 0));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('three swipeable slides with three dots, no timers', (
    tester,
  ) async {
    var catalog = 0;
    var latest = 0;
    var perfumes = 0;
    await pumpClientGuide(
      tester,
      Scaffold(
        body: HomeEditorialBanner(
          playing: true,
          onOpenNew: () => latest++,
          onOpenCatalog: () => catalog++,
          onOpenPerfumes: () => perfumes++,
        ),
      ),
    );

    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.childrenDelegate.estimatedChildCount, 3);
    expect(_dots(), findsNWidgets(3));
    expect(find.byKey(const ValueKey('home-compact-hero')), findsOneWidget);

    // Slide 1: Compra fácil desde México, text on the right, opens the catalog.
    expect(findAssetImage(kGuideHomeBannerEasy), findsOneWidget);
    expect(find.text('desde México'), findsOneWidget);
    expect(
      tester.getCenter(find.text('desde México')).dx,
      greaterThan(390 / 2),
    );
    await tester.tap(find.text('desde México'));
    expect(catalog, 1);

    // Slide 2: Nueva colección, text on the left, opens the new collection.
    await _swipeLeft(tester);
    expect(findAssetImage(kGuideHomeBannerNew), findsOneWidget);
    expect(find.text('COLECCIÓN'), findsOneWidget);
    expect(find.text('Un paraíso de marcas\npor descubrir.'), findsOneWidget);
    expect(
      tester.getCenter(find.text('COLECCIÓN')).dx,
      lessThan(390 / 2),
    );
    await tester.tap(find.byKey(const ValueKey('home-banner-action')));
    expect(latest, 1);

    // Slide 3: Perfumes, text on the right.
    await _swipeLeft(tester);
    expect(findAssetImage(kGuideHomeBannerPerfumes), findsOneWidget);
    expect(find.text('PERFUMES'), findsOneWidget);
    expect(
      find.text('Descubre nuestra selección de fragancias originales'),
      findsOneWidget,
    );
    await tester.tap(find.text('PERFUMES'));
    expect(perfumes, 1);
    expect(catalog, 1);
    expect(latest, 1);
    // pumpAndSettle returning proves the carousel schedules nothing.
    await tester.pumpAndSettle();
  });

  testWidgets('the active dot follows the page', (tester) async {
    await pumpClientGuide(
      tester,
      Scaffold(
        body: HomeEditorialBanner(playing: true, onOpenNew: () {}),
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

    testWidgets('the «Lo más nuevo» hero is gone and offers use the photo', (
      tester,
    ) async {
      final catalog = await store();
      await pumpClientGuide(
        tester,
        StoreScope(notifier: catalog, child: const HomeScreen()),
        size: const Size(390, 844),
      );
      final scroll = find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first;
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('home-section-offers')),
        400,
        scrollable: scroll,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-followup-hero')), findsNothing);
      expect(
        find.byKey(const ValueKey('home-followup-collection')),
        findsNothing,
      );
      expect(find.textContaining('TUS MODELOS'), findsNothing);
      expect(findAssetImage(kGuideHomeWholesale), findsOneWidget);
      expect(find.textContaining('PRECIOS DE'), findsOneWidget);
      expect(find.textContaining('mayoreo'), findsWidgets);
      // The guide's own line replaces the old «pendiente» note.
      expect(find.text('A partir de 3 piezas'), findsOneWidget);
      expect(find.textContaining('pendientes de confirmación'), findsNothing);
      expect(find.text('CONOCE MÁS'), findsOneWidget);
    });

    testWidgets('the perfumes slide opens the perfume collection', (
      tester,
    ) async {
      final catalog = await store();
      await pumpClientGuide(
        tester,
        StoreScope(notifier: catalog, child: const HomeScreen()),
        size: const Size(390, 844),
      );
      await _swipeLeft(tester);
      await _swipeLeft(tester);
      await tester.tap(find.text('PERFUMES'));
      await tester.pumpAndSettle();
      final screen =
          tester.widget<CollectionScreen>(find.byType(CollectionScreen));
      expect(screen.filter.category, 'perfume');
    });
  });
}
