/// Guide v2, part A: «Compra por estilo», «Tus marcas favoritas» and the
/// wholesale banner of the home.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/features/boutique/guide_brand_tile.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/media/monetta_image.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/domain/home_content.dart';
import 'package:monetta_app/features/boutique/guide_art.dart';
import 'package:monetta_app/features/catalog/brand_screen.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/home/home_boutique_sections.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/main.dart';

import '../../support/client_guide_capture.dart';

Finder _homeScroll() => find
    .byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    )
    .first;

String _assetOf(WidgetTester tester, Finder within) {
  final image = tester.widget<Image>(
    find.descendant(of: within, matching: find.byType(Image)),
  );
  return (image.image as AssetImage).assetName;
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => '/tmp',
    );
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

  group('Compra por estilo', () {
    testWidgets('five entries in order, each with its icon and label', (
      tester,
    ) async {
      final opened = <String>[];
      await pumpClientGuide(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: HomeShopByStyle(onOpen: (entry) => opened.add(entry.id)),
          ),
        ),
      );
      const ids = ['crossbody', 'tote', 'shoulder', 'satchel', 'perfumes'];
      const labels = ['Crossbody', 'Tote', 'Shoulder', 'Satchel', 'Perfumes'];
      const icons = [
        kGuideIconStyleCrossbody,
        kGuideIconStyleTote,
        kGuideIconStyleShoulder,
        kGuideIconStyleSatchel,
        kGuideIconStylePerfumes,
      ];
      var previousX = -1.0;
      for (var i = 0; i < ids.length; i++) {
        final tile = find.byKey(ValueKey('home-style-${ids[i]}'));
        expect(tile, findsOneWidget);
        expect(
          find.descendant(of: tile, matching: find.text(labels[i])),
          findsOneWidget,
        );
        expect(_assetOf(tester, tile), icons[i]);
        final x = tester.getCenter(tile).dx;
        expect(x, greaterThan(previousX), reason: ids[i]);
        previousX = x;
        // Same row: the five tiles share one top edge.
        expect(
          tester.getTopLeft(tile).dy,
          tester.getTopLeft(find.byKey(const ValueKey('home-style-tote'))).dy,
        );
      }
      for (final id in ids) {
        await tester.tap(find.byKey(ValueKey('home-style-$id')));
      }
      expect(opened, ids);
    });

    testWidgets('each entry opens its silhouette, perfumes its category', (
      tester,
    ) async {
      final catalog = await store();
      await pumpClientGuide(
        tester,
        StoreScope(notifier: catalog, child: const HomeScreen()),
      );
      const expected = {
        'crossbody': ('bolsa', 'crossbody'),
        'tote': ('bolsa', 'tote'),
        'shoulder': ('bolsa', 'shoulder'),
        'satchel': ('bolsa', 'satchel'),
        'perfumes': ('perfume', null),
      };
      for (final entry in expected.entries) {
        final tile = find.byKey(ValueKey('home-style-${entry.key}'));
        await tester.scrollUntilVisible(
          tile,
          -200,
          scrollable: _homeScroll(),
        );
        await tester.ensureVisible(tile);
        await tester.pumpAndSettle();
        await tester.tap(tile);
        await tester.pumpAndSettle();
        final screen = tester.widget<CollectionScreen>(
          find.byType(CollectionScreen),
        );
        expect(screen.filter.category, entry.value.$1, reason: entry.key);
        expect(screen.filter.silhouette, entry.value.$2, reason: entry.key);
        Navigator.of(tester.element(find.byType(CollectionScreen))).pop();
        await tester.pumpAndSettle();
      }
    });
  });

  group('Tus marcas favoritas', () {
    testWidgets('a 4-column grid of every configured brand with its logo', (
      tester,
    ) async {
      final catalog = await store();
      await pumpClientGuide(
        tester,
        StoreScope(notifier: catalog, child: const HomeScreen()),
        size: const Size(390, 844),
      );
      final section = find.byKey(const ValueKey('home-section-brands'));
      await tester.scrollUntilVisible(
        section,
        300,
        scrollable: _homeScroll(),
      );
      await tester.pumpAndSettle();

      final configured = {
        for (final brand in HomeContent.fallback.brands) brand.handle: brand,
      };
      final tiles = [
        for (final element in find
            .descendant(
              of: section,
              matching: find.byWidgetPredicate(
                (w) =>
                    w.key is ValueKey<String> &&
                    (w.key! as ValueKey<String>).value.startsWith(
                          'home-brand-entrance-',
                        ),
              ),
            )
            .evaluate())
          (element.widget.key! as ValueKey<String>).value.substring(
                'home-brand-entrance-'.length,
              ),
      ];
      // All twelve configured brands: the guide's five first, then the rest
      // in the configured order. None invented.
      expect(tiles, [
        'coach',
        'guess-1',
        'michael-kors',
        'steve-madden',
        'tommy-hilfiger',
        'anne-klein',
        'olalplex',
        'christian-dior',
        'the-ordinary',
        'summer-fridays',
        'laneige',
        'rhode',
      ]);
      for (final handle in tiles) {
        final brand = configured[handle]!;
        final tile = find.byKey(ValueKey('home-brand-$handle'));
        // The shared guide tile (tinted rectangle, large wordmark).
        expect(tester.widget(tile), isA<GuideBrandTile>());
        // Real bundled wordmark, named like `brandLogoAsset` (by the tile's
        // title: «Christian Dior» is shown, and filed, as «Dior»).
        expect(
          _assetOf(tester, tile),
          brandLogoAsset(brand.title.toLowerCase().replaceAll(' ', '_')),
        );
        expect(File(brand.fallbackAsset).existsSync(), isTrue);
      }
      // Four across, three rows: the fifth wraps under the first.
      final tops = [
        for (final handle in tiles)
          tester.getTopLeft(find.byKey(ValueKey('home-brand-$handle'))),
      ];
      expect(tops[0].dy, tops[1].dy);
      expect(tops[1].dy, tops[2].dy);
      expect(tops[2].dy, tops[3].dy);
      expect(tops[4].dy, greaterThan(tops[0].dy));
      expect(tops[4].dx, tops[0].dx);
      // Three rows of four: the ninth starts the last row.
      expect(tops[7].dy, tops[4].dy);
      expect(tops[8].dy, greaterThan(tops[4].dy));
      expect(tops[8].dx, tops[0].dx);
      expect(tops[11].dy, tops[8].dy);
      // «Ver todas» is kept.
      expect(find.text('Ver todas'), findsOneWidget);
    });

    test('guideBrandsFor: every brand, the guide order first, none dropped',
        () {
      final configured = HomeContent.fallback.brands;
      final ordered = guideBrandsFor(configured);
      final handles = [for (final brand in ordered) brand.handle];
      expect(handles, hasLength(12));
      // The guide's five lead, in the guide's own order.
      expect(handles.take(5), [
        'coach',
        'guess-1',
        'michael-kors',
        'steve-madden',
        'tommy-hilfiger',
      ]);
      // The rest keep their configured order (stable tie-break).
      expect(handles.skip(5), [
        'anne-klein',
        'olalplex',
        'christian-dior',
        'the-ordinary',
        'summer-fridays',
        'laneige',
        'rhode',
      ]);
      expect(handles.toSet(), {
        for (final brand in configured) brand.handle,
      });
    });
  });

  testWidgets('the wholesale banner uses the pill and the guide subtitle', (
    tester,
  ) async {
    final catalog = await store();
    await pumpClientGuide(
      tester,
      StoreScope(notifier: catalog, child: const HomeScreen()),
    );
    final pill = find.byKey(const ValueKey('home-wholesale-button'));
    await tester.scrollUntilVisible(pill, 400, scrollable: _homeScroll());
    await tester.pumpAndSettle();
    expect(tester.widget(pill), isA<GuidePillButton>());
    expect(find.text('CONOCE MÁS'), findsOneWidget);
    expect(find.text('A partir de 3 piezas'), findsOneWidget);
  });
}
