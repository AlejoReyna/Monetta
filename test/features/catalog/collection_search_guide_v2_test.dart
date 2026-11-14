import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/catalog/product_card.dart';
import 'package:monetta_app/features/catalog/search_history.dart';
import 'package:monetta_app/features/catalog/search_screen.dart';
import 'package:monetta_app/features/product/product_screen.dart';
import 'package:monetta_app/main.dart';

Future<CatalogStore> _loadedStore() async {
  final store = CatalogStore(database: openTestDatabase());
  await store.loadFromAsset();
  return store;
}

Future<void> _pumpCollection(
  WidgetTester tester,
  CatalogStore store,
  CollectionScreen screen,
) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    StoreScope(
      notifier: store,
      child: MaterialApp(theme: buildTheme(), home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('COL-GUIDE collection toolbar (slide 06)', () {
    testWidgets('v4.1 independent controls preserve immutable collection scope',
        (tester) async {
      final store = await _loadedStore();
      addTearDown(store.dispose);
      await _pumpCollection(
        tester,
        store,
        const CollectionScreen(
          title: 'Bolsas',
          filter: CollectionFilter(category: 'bolsa'),
        ),
      );
      expect(find.byKey(const Key('collection-local-search')), findsOneWidget);
      expect(find.byKey(const Key('collection-filter-button')), findsOneWidget);
      expect(find.byKey(const Key('collection-sort-button')), findsOneWidget);
      expect(find.byKey(const Key('collection-pill-cartera')), findsNothing);
      await tester.tap(find.byKey(const Key('collection-sort-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('collection-sort-oldest')), findsOneWidget);
      expect(find.byKey(const Key('collection-filter-apply')), findsNothing);
      await tester.tap(find.byKey(const Key('collection-sort-oldest')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('collection-sort-apply')));
      await tester.pumpAndSettle();
      expect(
        tester.widgetList<ProductCard>(find.byType(ProductCard)).every(
              (c) => store.facetsFor(c.product.id)?.category?.value == 'bolsa',
            ),
        isTrue,
      );
    });

    testWidgets(
        '«VER PRODUCTO» opens the ficha; the card has no "+" and keeps its heart',
        (tester) async {
      final store = await _loadedStore();
      addTearDown(store.dispose);
      await _pumpCollection(
        tester,
        store,
        const CollectionScreen(
          title: 'Bolsas',
          filter: CollectionFilter(category: 'bolsa'),
        ),
      );
      final card = tester.widgetList<ProductCard>(find.byType(ProductCard));
      expect(card, isNotEmpty);
      final first = card.first.product;
      final button = find.byKey(Key('view-product-${first.id}'));
      expect(button, findsOneWidget);
      expect(
        find.descendant(of: button, matching: find.text('VER PRODUCTO')),
        findsOneWidget,
      );
      // The card has no purchase shortcut any more; the favourite stays.
      expect(find.byKey(Key('quick-add-${first.id}')), findsNothing);
      expect(find.byTooltip('Guardar en favoritos'), findsWidgets);

      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        tester.widget<ProductScreen>(find.byType(ProductScreen)).productId,
        first.id,
      );
    });
  });

  group('SRCH-GUIDE search state (slide 05)', () {
    testWidgets(
        'typing shows recents with a clock, suggestions with icons, three '
        'small products and a bordered «Ver todo»', (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = await _loadedStore();
      addTearDown(store.dispose);
      final history = SearchHistory();
      await history.remember('Bolso coach negro');
      await history.remember('Bolso coach beige');

      await tester.pumpWidget(
        StoreScope(
          notifier: store,
          child: MaterialApp(
            theme: buildTheme(),
            home: SearchScreen(history: history),
          ),
        ),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('search-query-field')),
        'Bolso coach',
      );
      await tester.pumpAndSettle();

      expect(find.text('Búsquedas recientes'), findsOneWidget);
      expect(find.text('Bolso coach negro'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsWidgets);
      expect(find.text('Sugerencias'), findsOneWidget);
      expect(find.text('Productos'), findsOneWidget);
      // Three small columns.
      final rail = find.byKey(const ValueKey('search-product-rail'));
      expect(rail, findsOneWidget);
      final cards =
          find.descendant(of: rail, matching: find.byType(ProductCard));
      expect(cards.evaluate().length, lessThanOrEqualTo(3));
      if (cards.evaluate().length == 3) {
        final tops = [
          for (var i = 0; i < 3; i++) tester.getTopLeft(cards.at(i)).dy,
        ];
        expect(tops.toSet(), hasLength(1));
      }
      // «Ver todo»: full width, with a border and a chevron.
      final seeAll = find.byKey(const ValueKey('search-see-all'));
      expect(seeAll, findsOneWidget);
      final seeAllLabel = find.descendant(
        of: seeAll,
        matching: find.text('Ver todo'),
      );
      expect(seeAllLabel, findsOneWidget);
      expect(
        tester.getSize(seeAll).width,
        greaterThan(300),
        reason: 'a lo ancho',
      );
      expect(
        find.descendant(of: seeAll, matching: find.byIcon(Icons.chevron_right)),
        findsOneWidget,
      );
    });

    testWidgets('an empty field lists the real categories with their marks',
        (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = await _loadedStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(
        StoreScope(
          notifier: store,
          child: MaterialApp(
            theme: buildTheme(),
            home: SearchScreen(history: SearchHistory()),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Sugerencias'), findsOneWidget);
      final bags = find.byKey(const ValueKey('search-category-bolsa'));
      expect(bags, findsOneWidget);
      expect(find.byIcon(Icons.shopping_bag_outlined), findsWidgets);
    });
  });
}
