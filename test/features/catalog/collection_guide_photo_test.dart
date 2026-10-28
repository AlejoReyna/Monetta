import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/media/monetta_image.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/boutique/guide_art.dart';
import 'package:monetta_app/features/catalog/brand_screen.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/main.dart';

import '../../support/client_guide_capture.dart';
import '../../support/guide_photo_finders.dart';

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

  Future<void> pumpCollection(
    WidgetTester tester,
    CollectionScreen screen,
  ) async {
    final catalog = await store();
    await pumpClientGuide(
      tester,
      StoreScope(notifier: catalog, child: screen),
      size: const Size(390, 844),
    );
  }

  testWidgets('a brand collection shows its photo and only its name', (
    tester,
  ) async {
    await pumpCollection(
      tester,
      const CollectionScreen(
        title: 'Coach',
        filter: CollectionFilter(brand: 'coach'),
      ),
    );
    expect(findAssetImage(kGuideCollectionCoach), findsOneWidget);
    expect(findAssetImage(kGuideStudioBanner), findsNothing);
    final banner = find.byKey(const ValueKey('catalog-guide-banner'));
    expect(
      find.descendant(of: banner, matching: find.text('COACH')),
      findsOneWidget,
    );
    expect(find.text('Ver la colección'), findsNothing);
    expect(find.byKey(const Key('catalog-banner-cta')), findsNothing);
    // Coach keeps the text on the right: the title sits in the right half.
    expect(tester.getCenter(find.text('COACH')).dx, greaterThan(390 / 2));
  });

  testWidgets('a left-text photo puts the name in the left half', (
    tester,
  ) async {
    await pumpCollection(
      tester,
      const CollectionScreen(
        title: 'Marc Jacobs',
        filter: CollectionFilter(brand: 'marc_jacobs'),
      ),
    );
    expect(findAssetImage(kGuideCollectionMarcJacobs), findsOneWidget);
    expect(find.text('MARC JACOBS'), findsOneWidget);
    expect(tester.getCenter(find.text('MARC JACOBS')).dx, lessThan(390 / 2));
  });

  testWidgets('a category collection resolves its photo from the filter', (
    tester,
  ) async {
    await pumpCollection(
      tester,
      const CollectionScreen(
        title: 'Carteras',
        filter: CollectionFilter(category: 'cartera'),
      ),
    );
    expect(findAssetImage(kGuideCollectionWallets), findsOneWidget);
    expect(find.text('CARTERAS'), findsOneWidget);
    expect(find.text('Ver la colección'), findsNothing);
  });

  testWidgets('a silhouette beats the category it belongs to', (tester) async {
    await pumpCollection(
      tester,
      const CollectionScreen(
        title: 'Totes',
        filter: CollectionFilter(category: 'bolsa', silhouette: 'tote'),
      ),
    );
    expect(findAssetImage(kGuideCollectionTotes), findsOneWidget);
    expect(findAssetImage(kGuideWholesaleBags), findsNothing);
    expect(find.text('TOTES'), findsOneWidget);
  });

  testWidgets('without a matching photo the studio banner stays', (
    tester,
  ) async {
    await pumpCollection(
      tester,
      const CollectionScreen(title: 'Catálogo'),
    );
    expect(findAssetImage(kGuideStudioBanner), findsOneWidget);
    expect(find.text('Catálogo'), findsOneWidget);
    expect(find.text('Ver la colección'), findsOneWidget);
    expect(find.byKey(const ValueKey('catalog-guide-banner')), findsNothing);
  });

  testWidgets('a caller-supplied hero wins over the guide photo', (
    tester,
  ) async {
    await pumpCollection(
      tester,
      const CollectionScreen(
        title: 'Coach',
        filter: CollectionFilter(brand: 'coach'),
        heroImageAsset: 'assets/images/campaign_olive.jpg',
      ),
    );
    expect(findAssetImage('assets/images/campaign_olive.jpg'), findsOneWidget);
    expect(findAssetImage(kGuideCollectionCoach), findsNothing);
    expect(find.text('Coach'), findsWidgets);
  });

  testWidgets('a brand page wears that brand\'s photo and no other', (
    tester,
  ) async {
    final catalog = await store();
    await pumpClientGuide(
      tester,
      StoreScope(
        notifier: catalog,
        child: const BrandScreen(brandSlug: 'michael_kors'),
      ),
      size: const Size(390, 844),
    );
    expect(findAssetImage(kGuideCollectionMichaelKors), findsOneWidget);
    expect(findAssetImage(kGuideCollectionCoach), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('brand-header')),
        matching: find.byKey(const ValueKey('catalog-guide-banner')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a brand without a photo keeps the typographic header', (
    tester,
  ) async {
    final catalog = await store();
    await pumpClientGuide(
      tester,
      StoreScope(
        notifier: catalog,
        child: const BrandScreen(brandSlug: 'guess'),
      ),
      size: const Size(390, 844),
    );
    expect(find.byKey(const ValueKey('catalog-guide-banner')), findsNothing);
    for (final asset in [
      kGuideCollectionCoach,
      kGuideCollectionMichaelKors,
      kGuideCollectionSteveMadden,
      kGuideCollectionToryBurch,
      kGuideCollectionKateSpade,
      kGuideCollectionMarcJacobs,
    ]) {
      expect(findAssetImage(asset), findsNothing, reason: asset);
    }
  });
}
