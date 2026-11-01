import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/normalize/normalizer.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/boutique/guide_brand_tile.dart';
import 'package:monetta_app/features/catalog/brand_screen.dart';
import 'package:monetta_app/features/catalog/categories_screen.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/catalog/catalog_browse_screen.dart';
import 'package:monetta_app/main.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import '../../support/client_guide_capture.dart';

Future<void> _pop(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator)).pop();
  await tester.pumpAndSettle();
}

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
      // Guide v2: seven collections, in the guide's order. Relojes is not in
      // the grid (it lives in the menu), and Accesorios carries the watch.
      expect(
        [for (final category in guideDirectoryCategories) category.title],
        [
          'Crossbody',
          'Tote',
          'Shoulder',
          'Handbags',
          'Carteras',
          'Perfumes',
          'Accesorios',
        ],
      );
      expect(
        find.byKey(const ValueKey('categories-category-watches')),
        findsNothing,
      );
      for (final category in guideDirectoryCategories) {
        final tile = find.byKey(ValueKey('categories-category-${category.id}'));
        // Every tile carries its gold line icon.
        expect(
          find.descendant(
            of: tile,
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Image &&
                  (w.image as AssetImage).assetName ==
                      kGuideCategoryIcons[category.id],
            ),
          ),
          findsOneWidget,
          reason: category.id,
        );
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
        await _pop(tester);
        expect(tester.takeException(), isNull);
      }
      // Three columns: tiles 1-3 share a row, the 4th starts the next one.
      if (size.width < 800 && scale == 1) {
        Offset at(String id) => tester.getTopLeft(
              find.byKey(ValueKey('categories-category-$id')),
            );
        expect(at('crossbody').dy, at('tote').dy);
        expect(at('tote').dy, at('shoulder').dy);
        expect(at('handbags').dy, greaterThan(at('crossbody').dy));
        expect(at('handbags').dx, at('crossbody').dx);
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
      expect(tester.widget(brand), isA<GuideBrandTile>());
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
    await _pop(tester);
    // Guide v2: the menu no longer links Categorías or Contacto (Contacto is
    // reached from Cuenta). Mayoreo is listed, as in the theme's menu.
    await tester.tap(find.byKey(const Key('home-menu-button')));
    await tester.pumpAndSettle();
    final menu = find.byKey(const Key('monetta-side-menu'));
    expect(
      find.descendant(of: menu, matching: find.text('Mayoreo')),
      findsOneWidget,
    );
    for (final label in ['Categorías', 'Contacto']) {
      expect(
        find.descendant(of: menu, matching: find.text(label)),
        findsNothing,
        reason: label,
      );
    }
    expect(
      find.descendant(of: menu, matching: find.text('Todas las marcas')),
      findsOneWidget,
    );
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
    await tester.tap(find.byKey(const Key('bottom-nav-catalog')));
    await tester.pumpAndSettle();
    await _pop(tester);
    expect(find.byType(CatalogBrowseScreen), findsOneWidget);
    // The guide's menu on this screen has no Mayoreo or Contacto links.
    await tester.tap(find.byKey(const Key('bottom-nav-catalog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-menu-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('guide-menu-contact')), findsNothing);
    expect(find.byKey(const ValueKey('guide-menu-wholesale')), findsNothing);
    expect(find.text('Bolsas'), findsWidgets);
  });
}
