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
        'catalog' => CatalogBrowseScreen(items: store.catalogItems),
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
      // The shipped grids do not share one absolute origin or width. What
      // they share is a repeated card: the next photo matches the first in
      // size and sits on the same row.
      expect(second.width, closeTo(photo.width, 0.5));
      expect(second.height, closeTo(photo.height, 0.5));
      expect(second.top, closeTo(photo.top, 0.5));
      expect(second.left, greaterThan(photo.right));
      expect(
        image.left,
        greaterThanOrEqualTo(photo.left - 0.5),
      );
      expect(image.width, lessThanOrEqualTo(photo.width + 0.5));
      final brandLabel = tester.widget<MonettaProductTile>(first).data.brand;
      if (brandLabel != null && brandLabel.isNotEmpty) {
        final brand = tester.getRect(
          find.descendant(of: first, matching: find.text(brandLabel)),
        );
        expect(brand.top, greaterThan(photo.top));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
