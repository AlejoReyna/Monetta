import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/catalog/catalog_browse_screen.dart';
import 'package:monetta_app/features/catalog/product_card.dart';
import 'package:monetta_app/features/favorites/favorites_screen.dart';
import 'package:monetta_app/main.dart';
import 'package:monetta_app/reco/events.dart';

Widget _host(CatalogStore store) => MaterialApp(
      theme: buildTheme(),
      home: StoreScope(
        notifier: store,
        child: const FavoritesScreen(),
      ),
    );

Future<CatalogStore> _loadedStore() async {
  final db = openTestDatabase();
  final store = CatalogStore(database: db);
  addTearDown(() async {
    store.dispose();
    await db.close();
  });
  await store.loadFromAsset();
  return store;
}

Finder _recoCards() => find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> && key.value.startsWith('favorite-reco-');
    });

void main() {
  group('FavoritesScreen', () {
    testWidgets('empty state explains and offers the catalog', (
      tester,
    ) async {
      final db = openTestDatabase();
      final store = CatalogStore(database: db);
      addTearDown(() async {
        store.dispose();
        await db.close();
      });
      await store.loadFromAsset();

      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      expect(find.text('Favoritos'), findsWidgets);
      expect(find.text('Aún no tienes favoritos'), findsOneWidget);
      expect(
        find.text('Explorar el catálogo'),
        findsOneWidget,
      );
      expect(find.text('Basado en tus gustos'), findsOneWidget);
      expect(find.text('Selección editorial'), findsOneWidget);
      expect(find.text('Ver'), findsOneWidget);
      expect(find.textContaining('Porque te gusta'), findsNothing);
      expect(find.textContaining('personaliz'), findsNothing);
    });

    testWidgets('lists saved pieces with the shared card', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final db = openTestDatabase();
      final store = CatalogStore(database: db);
      addTearDown(() async {
        store.dispose();
        await db.close();
      });
      await store.loadFromAsset();
      final ids = store.products.take(2).map((p) => p.id).toList();
      for (final id in ids) {
        await store.toggleWishlist(id);
      }

      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      expect(find.text('2 piezas guardadas en esta cuenta.'), findsOneWidget);
      for (final id in ids) {
        expect(find.byKey(ValueKey('favorite-card-$id')), findsOneWidget);
        expect(find.byKey(ValueKey('favorite-reco-$id')), findsNothing);
      }
      // Guardar ya es historial: el carrusel sigue al feed, no al orden editorial.
      expect(find.text('Basado en tus gustos'), findsOneWidget);
      expect(find.text('Selección editorial'), findsNothing);
      expect(find.textContaining('Porque te gusta'), findsNothing);
    });

    testWidgets('unhearting from the grid removes the piece', (tester) async {
      final db = openTestDatabase();
      final store = CatalogStore(database: db);
      addTearDown(() async {
        store.dispose();
        await db.close();
      });
      await store.loadFromAsset();
      final product = store.products.first;
      await store.toggleWishlist(product.id);

      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();
      expect(
          find.byKey(ValueKey('favorite-card-${product.id}')), findsOneWidget);

      await tester.ensureVisible(find.byIcon(Icons.favorite));
      await tester.tap(find.byTooltip('Quitar de favoritos'));
      await tester.pumpAndSettle();

      expect(store.wishlist, isNot(contains(product.id)));
      expect(find.text('Aún no tienes favoritos'), findsOneWidget);
    });

    testWidgets('saved ids missing from the catalog are honest and removable',
        (tester) async {
      final db = openTestDatabase();
      final store = CatalogStore(database: db);
      addTearDown(() async {
        store.dispose();
        await db.close();
      });
      await store.loadFromAsset();
      final product = store.products.first;
      await store.toggleWishlist(product.id);
      await store.toggleWishlist('gid://shopify/Product/999999');

      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      expect(
        find.byKey(ValueKey('favorite-card-${product.id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('favorite-reco-${product.id}')),
        findsNothing,
      );
      expect(
        find.text(
          '1 pieza guardada ya no está disponible en el catálogo.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Quitar no disponibles'));
      await tester.pumpAndSettle();

      expect(
        store.wishlist,
        isNot(contains('gid://shopify/Product/999999')),
      );
      expect(store.wishlist, contains(product.id));
      expect(
        find.byKey(ValueKey('favorite-card-${product.id}')),
        findsOneWidget,
      );
    });

    testWidgets('scopes isolate two accounts on the same device',
        (tester) async {
      final db = openTestDatabase();
      final store = CatalogStore(database: db);
      addTearDown(() async {
        store.dispose();
        await db.close();
      });
      await store.loadFromAsset();
      final first = store.products.first.id;
      final second = store.products.skip(1).first.id;

      await store.setAccountScope('acct-A');
      await store.toggleWishlist(first);
      await store.setAccountScope('acct-B');
      expect(store.wishlist, isEmpty);
      await store.toggleWishlist(second);

      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('favorite-card-$second')), findsOneWidget);
      expect(find.byKey(ValueKey('favorite-card-$first')), findsNothing);

      await store.setAccountScope('acct-A');
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('favorite-card-$first')), findsOneWidget);
      expect(find.byKey(ValueKey('favorite-card-$second')), findsNothing);
      // La pieza guardada visible es la de A, no la de B.
      expect(store.wishlist, contains(first));
      expect(store.wishlist, isNot(contains(second)));
    });
  });

  group('favoritesRailProducts', () {
    test('caps at the loaded catalog and does not duplicate to reach 60',
        () async {
      final store = await _loadedStore();
      expect(store.products.length, greaterThan(kFavoritesRailCap));

      final selection = favoritesRailProducts(
        loaded: [...store.products, ...store.products],
        favoriteIds: {store.products.first.id},
        ranked: store.products.reversed.toList(),
        hasHistory: false,
      );

      expect(selection.editorial, isTrue);
      expect(selection.products, hasLength(kFavoritesRailCap));
      expect(
        selection.products.map((product) => product.id).toSet(),
        hasLength(kFavoritesRailCap),
      );
      expect(selection.products.first.id, store.products[1].id);
      expect(
        selection.products.map((product) => product.id),
        isNot(contains(store.products.first.id)),
      );
      expect(
        selection.products.map((product) => product.id).toList(),
        [
          for (final product in store.products.skip(1)) product.id,
        ].take(kFavoritesRailCap).toList(),
      );
    });

    test('shows every real product when the catalog has fewer than 60',
        () async {
      final store = await _loadedStore();
      final few = store.products.take(3).toList();
      final selection = favoritesRailProducts(
        loaded: [...few, ...few, few.first],
        favoriteIds: const {},
        hasHistory: false,
      );

      expect(selection.products.map((product) => product.id).toList(), [
        few[0].id,
        few[1].id,
        few[2].id,
      ]);
    });

    test('with history follows ranked order and still drops favorites',
        () async {
      final store = await _loadedStore();
      final loaded = store.products.take(8).toList();
      final ranked = loaded.reversed.toList();
      final favorite = loaded.first.id;
      final selection = favoritesRailProducts(
        loaded: loaded,
        favoriteIds: {favorite},
        ranked: ranked,
        hasHistory: true,
      );

      expect(selection.source, FavoritesRailSource.history);
      expect(
        selection.products.map((product) => product.id).toList(),
        [
          for (final product in ranked)
            if (product.id != favorite) product.id,
        ],
      );
    });

    test('an empty ranked feed falls back to editorial order', () async {
      final store = await _loadedStore();
      final loaded = store.products.take(4).toList();
      final selection = favoritesRailProducts(
        loaded: loaded,
        favoriteIds: {loaded.last.id},
        ranked: const <Product>[],
        hasHistory: true,
      );

      expect(selection.editorial, isTrue);
      expect(selection.products.map((product) => product.id).toList(), [
        loaded[0].id,
        loaded[1].id,
        loaded[2].id,
      ]);
    });
  });

  group('Favorites recommendations rail', () {
    testWidgets('lays the loaded catalog in two scrolling rows',
        (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final store = await _loadedStore();
      final selection = favoritesRailProducts(
        loaded: store.products,
        favoriteIds: store.wishlist,
        hasHistory: !store.profile.isEmpty,
      );
      expect(selection.editorial, isTrue);
      expect(selection.products, hasLength(kFavoritesRailCap));

      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      final rail = tester.widget<ListView>(
        find.byKey(const ValueKey('favorites-reco-rail')),
      );
      expect(rail.scrollDirection, Axis.horizontal);
      final delegate = rail.childrenDelegate as SliverChildBuilderDelegate;
      expect(delegate.childCount, kFavoritesRailCap ~/ 2);

      final top = find.byKey(
        ValueKey('favorite-reco-${selection.products[0].id}'),
      );
      final bottom = find.byKey(
        ValueKey('favorite-reco-${selection.products[1].id}'),
      );
      final next = find.byKey(
        ValueKey('favorite-reco-${selection.products[2].id}'),
      );
      expect(top, findsOneWidget);
      expect(bottom, findsOneWidget);
      expect(next, findsOneWidget);

      final topRect = tester.getRect(top);
      final bottomRect = tester.getRect(bottom);
      final nextRect = tester.getRect(next);
      expect(bottomRect.top, greaterThan(topRect.bottom - 1));
      expect(bottomRect.left, closeTo(topRect.left, 1));
      expect(nextRect.left, greaterThan(topRect.right - 1));

      expect(_recoCards().evaluate().length, lessThan(kFavoritesRailCap));
    });

    testWidgets('Ver opens that same set in the catalog', (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final store = await _loadedStore();
      final selection = favoritesRailProducts(
        loaded: store.products,
        favoriteIds: store.wishlist,
        hasHistory: false,
      );

      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Ver'));
      await tester.tap(find.text('Ver'));
      await tester.pumpAndSettle();

      final screen = tester.widget<CatalogBrowseScreen>(
        find.byType(CatalogBrowseScreen),
      );
      expect(
        screen.items.map((item) => item.shopifyProductId).toList(),
        selection.products.map((product) => product.id).toList(),
      );
    });

    testWidgets('the shared card still saves and opens the quick view',
        (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final store = await _loadedStore();
      final product = store.products.first;
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      final card = find.byKey(ValueKey('favorite-reco-${product.id}'));
      await tester.ensureVisible(card);
      // Heart first. Opening the preview records a view and the rail follows
      // that history, so this card would no longer be the one on screen.
      await tester.tap(
        find.descendant(
          of: card,
          matching: find.byIcon(Icons.favorite_border),
        ),
      );
      await tester.pumpAndSettle();

      expect(store.wishlist, contains(product.id));
      expect(
        find.byKey(ValueKey('favorite-card-${product.id}')),
        findsOneWidget,
      );
      expect(card, findsNothing);

      final preview = _recoCards().first;
      await tester.ensureVisible(preview);
      await tester.tap(preview);
      await tester.pumpAndSettle();
      expect(find.text('AGREGAR A BOLSA'), findsOneWidget);
    });

    testWidgets('with history the visible order is the existing feed',
        (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final store = await _loadedStore();
      for (final product in store.products.skip(40).take(8)) {
        store.record(EventType.productView, productId: product.id);
      }
      expect(store.profile.isEmpty, isFalse);
      final ranked = [
        for (final item in store.feed(limit: store.products.length))
          item.product,
      ];
      final selection = favoritesRailProducts(
        loaded: store.products,
        favoriteIds: store.wishlist,
        ranked: ranked,
        hasHistory: true,
      );
      expect(selection.editorial, isFalse);

      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      expect(find.text('Selección editorial'), findsNothing);
      expect(find.textContaining('Porque te gusta'), findsNothing);
      final first = find.byKey(
        ValueKey('favorite-reco-${selection.products.first.id}'),
      );
      expect(first, findsOneWidget);
      final firstDx = tester.getTopLeft(first).dx;
      for (final element in _recoCards().evaluate()) {
        final dx = tester.getTopLeft(find.byWidget(element.widget)).dx;
        expect(dx, greaterThanOrEqualTo(firstDx - 0.5));
      }
    });

    testWidgets('hides the section when the catalog is empty', (tester) async {
      final store = await _loadedStore();
      store.products = const [];

      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      expect(find.text('Aún no tienes favoritos'), findsOneWidget);
      expect(find.text('Basado en tus gustos'), findsNothing);
      expect(find.text('Ver'), findsNothing);
      expect(find.byType(ProductCard), findsNothing);
    });

    testWidgets('hides the section when every loaded product is saved',
        (tester) async {
      final store = await _loadedStore();
      final kept = store.products.take(2).toList();
      store.products = kept;
      for (final product in kept) {
        await store.toggleWishlist(product.id);
      }

      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      expect(find.text('Basado en tus gustos'), findsNothing);
      expect(find.text('Selección editorial'), findsNothing);
      expect(
        find.byKey(ValueKey('favorite-card-${kept[0].id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('favorite-card-${kept[1].id}')),
        findsOneWidget,
      );
    });
  });
}
