import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/media/monetta_image.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/catalog/brand_screen.dart';
import 'package:monetta_app/features/catalog/catalog_browse_screen.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/catalog/product_card.dart';
import 'package:monetta_app/features/catalog/search_history.dart';
import 'package:monetta_app/features/catalog/search_screen.dart';
import 'package:monetta_app/features/favorites/favorites_screen.dart';
import 'package:monetta_app/main.dart';

void main() {
  for (final screen in [
    'catalog',
    'category',
    'brand',
    'favorites',
    'search',
  ]) {
    testWidgets('$screen uses the shared product card geometry',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = FakeViewPadding.zero;
      tester.view.viewPadding = FakeViewPadding.zero;
      addTearDown(tester.view.reset);
      final store = CatalogStore(database: openTestDatabase());
      addTearDown(store.dispose);
      await store.loadFromAsset();
      for (final product in store.products.take(2)) {
        await store.toggleWishlist(product.id);
      }
      final page = switch (screen) {
        'catalog' => CatalogBrowseScreen(
            products: store.products,
            facetsById: store.facetsById,
          ),
        'category' => const CollectionScreen(
            title: 'Bolsas',
            filter: CollectionFilter(category: 'bolsa'),
          ),
        'brand' => BrandScreen(brandSlug: store.availableBrands.first),
        'favorites' => const FavoritesScreen(),
        _ => SearchScreen(initialQuery: 'bolso', history: SearchHistory()),
      };
      await tester.pumpWidget(
        StoreScope(
          notifier: store,
          child: MaterialApp(theme: buildLightTheme(), home: page),
        ),
      );
      await tester.pump();
      final tiles = find.byType(MonettaProductTile);
      expect(tiles, findsAtLeastNWidgets(2));
      final first = tiles.at(0);
      final photo = tester.getRect(
        find.descendant(of: first, matching: find.byType(AspectRatio)).first,
      );
      final image = tester.getRect(
        find.descendant(of: first, matching: find.byType(MonettaImage)).first,
      );
      final second = tester.getRect(
        find
            .descendant(of: tiles.at(1), matching: find.byType(AspectRatio))
            .first,
      );
      expect(photo.left, 0);
      expect(photo.width, 189);
      expect(photo.height, closeTo(236.25, .01));
      expect(
        image,
        photo.deflate(8),
        reason: 'the photo has a slight card inset',
      );
      expect(second.left - photo.right, 12);
      expect(second.top, photo.top);
      final data = tester.widget<MonettaProductTile>(first).data;
      final brand = tester.getRect(
        find.descendant(of: first, matching: find.text(data.brand!)),
      );
      expect(brand.left, photo.left + 12);
      expect(brand.top, closeTo(photo.bottom + 10, .01));
      expect(tester.takeException(), isNull);
    });
  }
}
