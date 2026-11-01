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

Color? _pillColor(WidgetTester tester, String value) {
  final material = find.descendant(
    of: find.byKey(Key('collection-pill-$value')),
    matching: find.byType(Material),
  );
  return tester.widget<Material>(material.first).color;
}

void main() {
  group('COL-GUIDE collection toolbar (slide 06)', () {
    testWidgets('pills, count, «Ordenar por» and no brand link',
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

      for (final label in [
        'Bolsas',
        'Carteras',
        'Accesorios',
        'Relojes',
        'Más',
      ]) {
        expect(
          find.descendant(
            of: find.byWidgetPredicate(
              (w) =>
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>)
                      .value
                      .startsWith('collection-pill-'),
            ),
            matching: find.text(label),
          ),
          findsOneWidget,
          reason: label,
        );
      }
      // The destination's own category is the active (brown) pill.
      expect(_pillColor(tester, 'bolsa'), isNot(_pillColor(tester, 'cartera')));

      // «N productos» is the real number of pieces in the destination.
      final expected = store.products
          .where((p) => store.facetsFor(p.id)?.category?.value == 'bolsa')
          .length;
      expect(
        tester.widget<Text>(find.byKey(const Key('collection-count'))).data,
        '$expected productos',
      );
      expect(find.text('Ordenar por'), findsOneWidget);
      expect(find.byKey(const Key('collection-open-brand')), findsNothing);
      expect(find.textContaining('Ver Coach'), findsNothing);
      // The round filter button is part of the same row.
      expect(find.byKey(const Key('collection-filter-button')), findsOneWidget);
    });

    testWidgets('a pill changes the category; the sort link opens the sheet',
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
      await tester.tap(find.byKey(const Key('collection-pill-cartera')));
      await tester.pumpAndSettle();
      final wallets = store.products
          .where((p) => store.facetsFor(p.id)?.category?.value == 'cartera')
          .length;
      expect(
        tester.widget<Text>(find.byKey(const Key('collection-count'))).data,
        '$wallets ${wallets == 1 ? 'producto' : 'productos'}',
      );
      expect(
        tester.widgetList<ProductCard>(find.byType(ProductCard)).every(
              (c) =>
                  store.facetsFor(c.product.id)?.category?.value == 'cartera',
            ),
        isTrue,
      );
      // It is a filter like any other: it counts and can be cleared.
      expect(find.byKey(const Key('collection-filter-count')), findsOneWidget);
      await tester.tap(find.byKey(const Key('collection-clear-inline')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('collection-filter-count')), findsNothing);

      await tester.tap(find.byKey(const Key('collection-sort-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('collection-filter-sort')), findsOneWidget);
    });

    testWidgets('«VER PRODUCTO» opens the ficha; the "+" and heart stay',
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
      // The purchase shortcut and the favourite are untouched.
      expect(
        find.byKey(Key('quick-add-${first.id}')),
        first.isInStock ? findsOneWidget : findsNothing,
      );
      expect(find.byTooltip('Guardar'), findsWidgets);

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
