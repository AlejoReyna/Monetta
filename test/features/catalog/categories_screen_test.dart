import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/normalize/normalizer.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/catalog/brand_screen.dart';
import 'package:monetta_app/features/catalog/categories_screen.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/catalog/catalog_browse_screen.dart';
import 'package:monetta_app/features/contact/contact_screen.dart';
import 'package:monetta_app/features/wholesale/wholesale_screen.dart';
import 'package:monetta_app/main.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import '../../support/client_guide_capture.dart';

void main() {
  for (final (size, scale, brightness) in [
    (const Size(390, 1100), 1.0, Brightness.light),
    (const Size(320, 568), 2.0, Brightness.light),
    (const Size(834, 1194), 1.0, Brightness.light),
    (const Size(390, 1100), 1.0, Brightness.dark),
  ]) {
    testWidgets('category directory routes at $size / $scale / $brightness',
        (tester) async {
      final db = openTestDatabase();
      final store = CatalogStore(database: db);
      addTearDown(() async {
        store.dispose();
        await db.close();
      });
      await pumpClientGuide(
        tester,
        StoreScope(notifier: store, child: const CategoriesScreen()),
        size: size,
        textScale: scale,
        brightness: brightness,
      );
      if (scale == 1) {
        await captureClientGuide(
          tester,
          'categories-${size.width.toInt()}-${brightness.name}',
        );
      }
      expect(find.text('Colecciones'), findsOneWidget);
      for (final category in clientGuideCategories) {
        final tile = find.byKey(ValueKey('categories-category-${category.id}'));
        await tester.scrollUntilVisible(
          tile,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(tile);
        await tester.pumpAndSettle();
        await tester.tap(tile);
        await tester.pumpAndSettle();
        final screen =
            tester.widget<CollectionScreen>(find.byType(CollectionScreen));
        expect(screen.title, category.title);
        expect(screen.filter, same(category.filter));
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      final all = find.byKey(const ValueKey('categories-all-brands'));
      await tester.scrollUntilVisible(
        all,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(all);
      await tester.pumpAndSettle();
      await tester.tap(all);
      await tester.pumpAndSettle();
      expect(find.text('Ver menos'), findsOneWidget);
      final brand = find.byKey(const ValueKey('categories-brand-rhode'));
      await tester.scrollUntilVisible(
        brand,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(brand);
      await tester.pumpAndSettle();
      await tester.tap(brand);
      await tester.pumpAndSettle();
      expect(
        tester.widget<BrandScreen>(find.byType(BrandScreen)).brandSlug,
        'rhode',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('home menu and bottom categories open dedicated destinations',
      (tester) async {
    final db = openTestDatabase();
    final store = CatalogStore(database: db);
    await store.loadFromAsset();
    store.products = [
      Product(
        id: 'demo',
        handle: 'demo',
        title: 'Bolsa DEMO',
        vendor: 'Demo',
        productType: 'bolsa',
        tags: const [],
        variants: const [
          ProductVariant(
            id: 'demo-v',
            title: 'Default Title',
            price: 100,
            available: true,
          ),
        ],
        images: const [],
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    ];
    store.facetsById = {
      for (final p in store.products)
        p.id: Normalizer(store.rules).normalize(p, now: DateTime.utc(2026)),
    };
    addTearDown(() async {
      store.dispose();
      await db.close();
    });
    await pumpClientGuide(
      tester,
      StoreScope(notifier: store, child: const HomeScreen()),
      size: const Size(390, 1100),
    );
    await tester.tap(find.byKey(const Key('bottom-nav-catalog')));
    await tester.pumpAndSettle();
    expect(find.byType(CategoriesScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    for (final (label, screen) in [
      ('Categorías', CategoriesScreen),
      ('Mayoreo', WholesaleScreen),
      ('Contacto', ContactScreen),
    ]) {
      await tester.tap(find.byKey(const Key('home-menu-button')));
      await tester.pumpAndSettle();
      final link = find.descendant(
        of: find.byKey(const Key('monetta-side-menu')),
        matching: find.text(label),
      );
      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(find.byType(screen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    }
  });

  testWidgets('directory, full catalog and service menu preserve return routes',
      (tester) async {
    final db = openTestDatabase();
    final store = CatalogStore(database: db);
    addTearDown(() async {
      store.dispose();
      await db.close();
    });
    await pumpClientGuide(
      tester,
      StoreScope(
        notifier: store,
        child: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Catalog route'),
              onPressed: () => openCatalogBrowse(context, items: const []),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Catalog route'));
    await tester.pumpAndSettle();
    expect(find.byType(CatalogBrowseScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('bottom-nav-catalog')));
    await tester.pumpAndSettle();
    expect(find.byType(CategoriesScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('guide-nav-categories')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(CatalogBrowseScreen), findsOneWidget);
    // Open again and follow both service menu destinations, keeping the back stack.
    await tester.tap(find.byKey(const Key('bottom-nav-catalog')));
    await tester.pumpAndSettle();
    for (final service in ['contact', 'wholesale']) {
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('guide-menu-$service')));
      await tester.pumpAndSettle();
      expect(
        find.byType(service == 'contact' ? ContactScreen : WholesaleScreen),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(CategoriesScreen), findsOneWidget);
    }
  });
}
