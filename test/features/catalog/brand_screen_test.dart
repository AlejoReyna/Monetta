import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/catalog/brand_screen.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/catalog/product_card.dart';
import 'package:monetta_app/main.dart';

Future<CatalogStore> _loadedStore() async {
  final store = CatalogStore(database: openTestDatabase());
  await store.loadFromAsset();
  return store;
}

/// The brand with the most pieces in the bundled catalog — the screen must
/// work for whichever brand that is, not for one hard-coded name.
String _busiestBrand(CatalogStore store) => store.availableBrands.first;

Future<void> _pump(
  WidgetTester tester,
  CatalogStore store,
  String slug, {
  String? story,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: StoreScope(
        notifier: store,
        child: BrandScreen(brandSlug: slug, story: story),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows only this brand, for whichever brand is asked for',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    addTearDown(store.dispose);
    final slug = _busiestBrand(store);

    await _pump(tester, store, slug);

    final visible = tester
        .widgetList<ProductCard>(find.byType(ProductCard))
        .map((card) => card.product.id);
    expect(visible, isNotEmpty);
    for (final id in visible) {
      expect(store.facetsFor(id)?.brand?.value, slug);
    }
  });

  testWidgets('category tabs keep the brand scope', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    addTearDown(store.dispose);
    final slug = _busiestBrand(store);
    final categories = <String>{
      for (final product in store.products)
        if (store.facetsFor(product.id)?.brand?.value == slug)
          if (store.facetsFor(product.id)?.category?.value case final value?)
            value,
    };

    await _pump(tester, store, slug);

    if (categories.length < 2) {
      // Tabs are only offered when there is more than one real category.
      expect(find.byKey(const Key('brand-tab-all')), findsNothing);
      return;
    }

    final category = categories.first;
    expect(find.byKey(Key('brand-tab-$category')), findsOneWidget);
    await tester.tap(find.byKey(Key('brand-tab-$category')));
    await tester.pumpAndSettle();

    final visible = tester
        .widgetList<ProductCard>(find.byType(ProductCard))
        .map((card) => card.product.id);
    expect(visible, isNotEmpty);
    for (final id in visible) {
      expect(store.facetsFor(id)?.brand?.value, slug);
      expect(store.facetsFor(id)?.category?.value, category);
    }
  });

  testWidgets('a tab is never offered for a category with no pieces',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    addTearDown(store.dispose);
    final slug = _busiestBrand(store);
    final categories = <String>{
      for (final product in store.products)
        if (store.facetsFor(product.id)?.brand?.value == slug)
          if (store.facetsFor(product.id)?.category?.value case final value?)
            value,
    };

    await _pump(tester, store, slug);

    for (final missing in const ['perfume', 'reloj', 'cosmetiquera']) {
      if (categories.contains(missing)) continue;
      expect(find.byKey(Key('brand-tab-$missing')), findsNothing);
    }
  });

  testWidgets('the editorial block only exists when there is text',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    addTearDown(store.dispose);
    final slug = _busiestBrand(store);

    await _pump(tester, store, slug);
    expect(find.byKey(const ValueKey('brand-story')), findsNothing);
    expect(find.text('Sobre la marca'), findsNothing);
    // Nothing claims a ranking the app cannot compute.
    expect(find.text('Más vendidas'), findsNothing);

    await _pump(tester, store, slug, story: 'Texto de la dueña.');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('brand-story')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Sobre la marca'), findsOneWidget);
  });

  testWidgets('continuing keeps the brand in the destination', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    addTearDown(store.dispose);
    final slug = _busiestBrand(store);

    await _pump(tester, store, slug);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('brand-see-all')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('brand-see-all')));
    await tester.pumpAndSettle();

    final collection = tester.widget<CollectionScreen>(
      find.byType(CollectionScreen),
    );
    expect(collection.filter.brand, slug);
  });
}
