/// Guide v2, part A: «Compra por estilo», «Tus marcas favoritas» and the
/// wholesale banner of the home.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/features/boutique/boutique_tokens.dart';
import 'package:monetta_app/app/monetta_tokens.g.dart';
import 'package:monetta_app/features/boutique/guide_brand_tile.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/media/monetta_image.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/domain/home_content.dart';
import 'package:monetta_app/features/boutique/guide_art.dart';
import 'package:monetta_app/features/catalog/brand_screen.dart';
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
  // The tile decodes at its display size, so the asset sits under a
  // ResizeImage.
  var provider = image.image;
  if (provider is ResizeImage) provider = provider.imageProvider;
  return (provider as AssetImage).assetName;
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
    // Changed with the web-parity pass: the five line icons are now the live
    // web's five square photo tiles, and «Hobo» replaces «Perfumes».
    testWidgets('five photo tiles in order, each with its photo and label', (
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
      const ids = ['crossbody', 'tote', 'shoulder', 'satchel', 'hobo'];
      const labels = ['Crossbody', 'Tote', 'Shoulder', 'Satchel', 'Hobo'];
      const photos = [
        kGuideStyleCrossbody,
        kGuideStyleTote,
        kGuideStyleShoulder,
        kGuideStyleSatchel,
        kGuideStyleHobo,
      ];
      var previousX = -1.0;
      for (var i = 0; i < ids.length; i++) {
        final tile = find.byKey(ValueKey('home-style-${ids[i]}'));
        expect(tile, findsOneWidget);
        expect(
          find.descendant(of: tile, matching: find.text(labels[i])),
          findsOneWidget,
        );
        expect(_assetOf(tester, tile), photos[i]);
        expect(File(photos[i]).existsSync(), isTrue, reason: photos[i]);
        final x = tester.getCenter(tile).dx;
        expect(x, greaterThan(previousX), reason: ids[i]);
        previousX = x;
        // Same row: the five tiles share one top edge.
        expect(
          tester.getTopLeft(tile).dy,
          tester.getTopLeft(find.byKey(const ValueKey('home-style-tote'))).dy,
        );
        // The whole tile is a tap target of at least 48.
        expect(tester.getSize(tile).height, greaterThanOrEqualTo(48));
        expect(tester.getSize(tile).width, greaterThanOrEqualTo(48));
      }
      // Perfumes left the strip: Hobo took its place.
      expect(find.byKey(const ValueKey('home-style-perfumes')), findsNothing);
      expect(find.text('Perfumes'), findsNothing);
      for (final id in ids) {
        await tester.tap(find.byKey(ValueKey('home-style-$id')));
      }
      expect(opened, ids);
    });

    testWidgets('tiles follow the web: cream, radius 10, square photo, gap 4', (
      tester,
    ) async {
      await pumpClientGuide(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: HomeShopByStyle(onOpen: (_) {}),
          ),
        ),
      );
      final tote = find.byKey(const ValueKey('home-style-tote'));
      final crossbody = find.byKey(const ValueKey('home-style-crossbody'));
      // Four logical pixels between neighbours.
      expect(
        tester.getTopLeft(tote).dx - tester.getTopRight(crossbody).dx,
        closeTo(4, .01),
      );
      // The photo is square and fills the tile's width.
      final photo = find.descendant(of: tote, matching: find.byType(Image));
      final photoSize = tester.getSize(photo);
      expect(photoSize.width, closeTo(photoSize.height, .01));
      expect(photoSize.width, closeTo(tester.getSize(tote).width, .01));
      expect(tester.widget<Image>(photo).fit, BoxFit.cover);
      // Tile ground follows the surfaceTile token (section pending the v4.1 Home rework).
      final decorated = tester.widget<DecoratedBox>(
        find.descendant(of: tote, matching: find.byType(DecoratedBox)).first,
      );
      final decoration = decorated.decoration as BoxDecoration;
      expect(decoration.color, MonettaTokens.surfaceTile);
      expect(decoration.borderRadius, BorderRadius.circular(18));
      // The label: editorial serif 12, centred, one line with ellipsis.
      final label = tester.widget<Text>(
        find.descendant(of: tote, matching: find.text('Tote')),
      );
      expect(label.style?.fontFamily, kBoutiqueSerifFamily);
      expect(label.style?.fontSize, 12);
      expect(label.maxLines, 1);
      expect(label.overflow, TextOverflow.ellipsis);
      expect(label.textAlign, TextAlign.center);
      // «Ver <label>» for assistive technology.
      expect(find.bySemanticsLabel('Ver Tote'), findsOneWidget);
    });
  });

  group('Tus marcas favoritas', () {
    testWidgets(
        'a horizontal rail keeps the editorial logos and its closing action', (
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
      final handles = [
        'coach',
        'guess-1',
        'michael-kors',
        'steve-madden',
        'tommy-hilfiger',
        'anne-klein',
        'christian-dior',
        'the-ordinary',
        'summer-fridays',
        'laneige',
        'rhode',
      ];
      final rail = find.descendant(
        of: find.byKey(const ValueKey('home-brands-rail')),
        matching: find.byType(Scrollable),
      );
      for (final handle in handles) {
        final brand = configured[handle]!;
        final tile = find.byKey(ValueKey('home-brand-$handle'));
        await tester.scrollUntilVisible(tile, 150, scrollable: rail);
        expect(tester.widget(tile), isA<GuideBrandTile>());
        expect(_assetOf(tester, tile),
            brandLogoAsset(brand.title.toLowerCase().replaceAll(' ', '_')));
        expect(File(brand.fallbackAsset).existsSync(), isTrue);
      }
      await tester.scrollUntilVisible(find.byTooltip('Ver marcas'), 145,
          scrollable: rail);
      expect(find.text('Ver todas'), findsOneWidget);
    });

    test('guideBrandsFor: every configured brand, the guide five first', () {
      final configured = HomeContent.fallback.brands;
      final handles = [
        for (final brand in guideBrandsFor(configured)) brand.handle,
      ];
      expect(handles, hasLength(configured.length));
      expect(handles.take(6), [
        'coach',
        'guess-1',
        'michael-kors',
        'steve-madden',
        'tommy-hilfiger',
        'anne-klein',
      ]);
      expect(handles.last, 'rhode');
    });
  });
}
