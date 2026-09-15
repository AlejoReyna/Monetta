import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/catalog/catalog_controls.dart';
import 'package:monetta_app/features/catalog/product_card.dart';
import 'package:monetta_app/main.dart';

Future<CatalogStore> _loadedStore() async {
  final store = CatalogStore(database: openTestDatabase());
  await store.loadFromAsset();
  return store;
}

void main() {
  testWidgets('collection hides count metadata and filters reduce the grid',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: StoreScope(
          notifier: store,
          child: const CollectionScreen(
            title: 'Bolsas',
            filter: CollectionFilter(category: 'bolsa'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Bolsas'), findsOneWidget);
    expect(find.textContaining('piezas ordenadas por'), findsNothing);
    expect(find.text('Más nuevas'), findsNothing);
    expect(find.text('extracted'), findsNothing);
    expect(find.text('También en marcas de Estados Unidos'), findsNothing);

    List<String> visibleIds() => tester
        .widgetList<ProductCard>(find.byType(ProductCard))
        .map((card) => card.product.id)
        .toList();

    final silhouettePills = find.byWidgetPredicate(
      (widget) =>
          widget is MonettaCapsuleChip &&
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>)
              .value
              .startsWith('collection-silhouette-'),
    );
    expect(silhouettePills, findsWidgets);

    final unfiltered = visibleIds();
    expect(unfiltered, isNotEmpty);

    // A silhouette chip must change the products on screen, not just its own
    // appearance: the grid has to become exactly that silhouette's bags.
    final firstPill = silhouettePills.first;
    final slug =
        (tester.widget<MonettaCapsuleChip>(firstPill).key! as ValueKey<String>)
            .value
            .replaceFirst('collection-silhouette-', '');
    final expected = store.products
        .where(
          (product) =>
              store.facetsFor(product.id)?.category?.value == 'bolsa' &&
              store.facetsFor(product.id)?.silhouette?.value == slug,
        )
        .map((product) => product.id)
        .toSet();
    expect(expected, isNotEmpty);

    expect(tester.widget<MonettaCapsuleChip>(firstPill).selected, isFalse);
    await tester.tap(firstPill);
    await tester.pumpAndSettle();
    expect(tester.widget<MonettaCapsuleChip>(firstPill).selected, isTrue);
    // The grid is lazy, so assert containment rather than a full set match.
    expect(visibleIds(), isNotEmpty);
    expect(visibleIds().every(expected.contains), isTrue);
    expect(
      unfiltered.where((id) => !expected.contains(id)),
      isNotEmpty,
      reason: 'the chip must actually remove pieces, not only highlight',
    );

    // Tapping it again returns to the collection, not to the whole catalog.
    await tester.tap(firstPill);
    await tester.pumpAndSettle();
    expect(visibleIds().toSet(), unfiltered.toSet());
    expect(
      visibleIds().any((id) => !expected.contains(id)),
      isTrue,
      reason: 'clearing returns to the collection, not to the filtered view',
    );

    await tester.tap(find.byKey(const Key('collection-filter-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('collection-filter-sort')), findsOneWidget);
    expect(
      find.byKey(const Key('collection-filter-availability')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('collection-filter-availability')));
    await tester.pump();
    expect(find.text('En existencia'), findsOneWidget);

    await tester.tap(find.byKey(const Key('collection-filter-stock')));
    await tester.pump();
    expect(find.text('En stock  ×'), findsNothing);
  });

  testWidgets(
      'collection filters are Spanish, stay pending until applied, and filter the grid',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    addTearDown(store.dispose);
    final inStockBags = store.products.where((product) {
      return store.facetsFor(product.id)?.category?.value == 'bolsa' &&
          product.isInStock;
    });
    expect(inStockBags, isNotEmpty);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: StoreScope(
          notifier: store,
          child: const CollectionScreen(
            title: 'Bolsas',
            filter: CollectionFilter(category: 'bolsa'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    List<String> visibleProductIds() => tester
        .widgetList<ProductCard>(find.byType(ProductCard))
        .map((card) => card.product.id)
        .toList();

    final initialIds = visibleProductIds();
    expect(initialIds, isNotEmpty);

    await tester.tap(find.byKey(const Key('collection-filter-button')));
    await tester.pumpAndSettle();
    expect(find.text('Filtrar y ordenar'), findsOneWidget);
    expect(find.text('Ordenar por'), findsOneWidget);
    expect(find.text('Disponibilidad'), findsOneWidget);
    expect(find.byKey(const Key('collection-filter-sort')), findsOneWidget);
    expect(
      find.byKey(const Key('collection-filter-availability')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('collection-filter-availability')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('collection-filter-stock')));
    await tester.pump();
    expect(find.byKey(const Key('collection-filter-count')), findsNothing);
    expect(visibleProductIds(), initialIds);

    await tester.tap(find.byKey(const Key('collection-filter-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('collection-filter-count')), findsNothing);

    await tester.tap(find.byKey(const Key('collection-filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('collection-filter-availability')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('collection-filter-stock')));
    await tester.tap(find.byKey(const Key('collection-filter-apply')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('collection-filter-count')), findsOneWidget);
    expect(
      tester
          .widgetList<ProductCard>(find.byType(ProductCard))
          .every((card) => card.product.isInStock),
      isTrue,
    );

    await tester.tap(find.byKey(const Key('collection-filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('collection-filter-clear')));
    await tester.tap(find.byKey(const Key('collection-filter-apply')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('collection-filter-count')), findsNothing);
  });

  testWidgets('every collection view exposes its filter action',
      (tester) async {
    final store = await _loadedStore();
    addTearDown(store.dispose);

    for (final view in const [
      ('Bolsas', 'bolsa'),
      ('Relojes', 'reloj'),
      ('Perfumes', 'perfume'),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: StoreScope(
            notifier: store,
            child: CollectionScreen(
              title: view.$1,
              filter: CollectionFilter(category: view.$2),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('collection-filter-button')), findsOneWidget);
      expect(find.byTooltip('Filtrar y ordenar'), findsOneWidget);
    }
  });
}
