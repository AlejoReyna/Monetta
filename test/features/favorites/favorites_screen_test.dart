import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/catalog/product_card.dart';
import 'package:monetta_app/features/favorites/favorites_screen.dart';
import 'package:monetta_app/main.dart';

Widget _host(CatalogStore store) => MaterialApp(
      theme: buildTheme(),
      home: StoreScope(
        notifier: store,
        child: const FavoritesScreen(),
      ),
    );

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
      expect(find.byType(ProductCard), findsNothing);
    });

    testWidgets('lists saved pieces with the shared card', (tester) async {
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
      expect(find.byType(ProductCard), findsNWidgets(2));
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
      expect(find.byType(ProductCard), findsOneWidget);

      await tester.tap(find.byIcon(Icons.favorite));
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

      expect(find.byType(ProductCard), findsOneWidget);
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
      expect(find.byType(ProductCard), findsOneWidget);
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
      expect(find.byType(ProductCard), findsOneWidget);

      await store.setAccountScope('acct-A');
      await tester.pumpAndSettle();
      expect(find.byType(ProductCard), findsOneWidget);
      // La pieza visible es la de A, no la de B.
      expect(store.wishlist, contains(first));
      expect(store.wishlist, isNot(contains(second)));
    });
  });
}
