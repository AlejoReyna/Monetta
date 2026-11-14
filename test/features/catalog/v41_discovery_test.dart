// G02–G08/G37 acceptance. Fixtures test local behavior, not provider delivery.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/media/monetta_image.dart';
import 'package:monetta_app/domain/home_content.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/catalog/brand_screen.dart';
import 'package:monetta_app/features/catalog/brands_screen.dart';
import 'package:monetta_app/features/catalog/catalog_query.dart';
import 'package:monetta_app/features/catalog/categories_screen.dart';
import 'package:monetta_app/features/catalog/category_tree.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/catalog/product_card.dart';
import 'package:monetta_app/features/catalog/search_screen.dart';
import 'package:monetta_app/main.dart';
import 'package:monetta_app/features/product/product_screen.dart';
import '../../support/product_screen_harness.dart' show mockPathProvider;
import 'v41_discovery_fixture.dart';

Future<void> tapVisible(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    final scrollable = find.byType(Scrollable).first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        300,
        scrollable: scrollable,
        maxScrolls: 60,
      );
    }
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> mountDiscovery(
  WidgetTester tester,
  Widget child,
  CatalogStore store, {
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 1000);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLightTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: StoreScope(notifier: store, child: child),
    ),
  );
  await tester.pumpAndSettle();
}

List<ProductCard> cards(WidgetTester tester) =>
    tester.widgetList<ProductCard>(find.byType(ProductCard)).toList();
void main() {
  setUpAll(mockPathProvider);
  test(
      'same actual variant must satisfy color, discount, price and availability',
      () async {
    final store = await discoveryStore();
    final p = discoveryProduct(
      99,
      variants: const [
        ProductVariant(
          id: 'black',
          title: 'Gold hardware',
          price: 2000,
          available: true,
          selectedOptions: {'Color': 'Black'},
        ),
        ProductVariant(
          id: 'red',
          title: 'Rojo',
          price: 800,
          compareAtPrice: 1000,
          available: false,
          selectedOptions: {'Color': 'Red'},
        ),
      ],
    );
    expect(
      matchingCatalogVariants(store, p, color: 'negro').single.id,
      'black',
    );
    expect(matchingCatalogVariants(store, p, color: 'dorado'), isEmpty);
    expect(
      selectCatalogProducts(store, [p], color: 'negro', offersOnly: true),
      isEmpty,
    );
    expect(
      selectCatalogProducts(
        store,
        [p],
        color: 'rojo',
        offersOnly: true,
        availableOnly: true,
      ),
      isEmpty,
    );
    expect(
      selectCatalogProducts(
        store,
        [p],
        color: 'rojo',
        offersOnly: true,
        priceBand: 'accesible',
      ).single.id,
      p.id,
    );
  });
  test('newness requires explicit authority and ANDs with offers', () async {
    final store = await discoveryStore();
    final products = [
      discoveryProduct(1),
      discoveryProduct(2),
      discoveryProduct(4),
    ];
    expect(selectCatalogProducts(store, products, newOnly: true), isEmpty);
    expect(
      selectCatalogProducts(
        store,
        products,
        newOnly: true,
        offersOnly: true,
        approvedNewArrival: (p) => p.id == products[1].id,
      ).map((p) => p.id),
      [products[1].id],
    );
  });
  test('stable order and full-scope unique matches agree with global search',
      () async {
    final store = await discoveryStore(count: 85);
    final unique = selectCatalogProducts(
      store,
      [...store.products, ...store.products],
      query: 'guess',
      order: CatalogOrder.oldest,
    );
    expect(unique.length, searchProducts(store, 'guess').length);
    expect(unique.map((p) => p.id).toSet().length, unique.length);
    expect(unique.first.createdAt.isBefore(unique.last.createdAt), isTrue);
  });
  test(
      'exact owner tree and configured bindings never manufacture gender destinations',
      () async {
    final store = await discoveryStore();
    expect(
      categoryTree.map((n) => n.label),
      ['Bolsos', 'Carteras', 'Perfumes', 'Calzado', 'Accesorios'],
    );
    final bindings = configuredCategoryBindings(HomeContent.fallback, store);
    expect(bindings['bags']?.category, 'bolsa');
    expect(bindings.containsKey('wallets-men'), isFalse);
    expect(bindings.containsKey('bags-women'), isFalse);
    expect(
      guideBrandSlug(
        const HomeBrandCard(
          title: 'Unknown',
          brand: 'Not configured',
          handle: 'irrelevant',
          fallbackAsset: '',
        ),
        store,
      ),
      isEmpty,
    );
  });
  testWidgets(
      'filter query and offer draft cancel via Escape and system back; apply retains brand',
      (tester) async {
    final store = await discoveryStore();
    await mountDiscovery(tester, const BrandScreen(brandSlug: 'guess'), store);
    final before = cards(tester).map((c) => c.product.id).toList();
    await tapVisible(tester, find.byKey(const Key('collection-filter-button')));
    expect(find.byKey(const Key('collection-filter-new')), findsNothing);
    await tester.enterText(
      find.byKey(const Key('collection-filter-query')),
      'no such product',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(cards(tester).map((c) => c.product.id), before);
    await tapVisible(tester, find.byKey(const Key('collection-filter-button')));
    await tapVisible(tester, find.byKey(const Key('collection-filter-offers')));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(cards(tester).map((c) => c.product.id), before);
    await tapVisible(tester, find.byKey(const Key('collection-filter-button')));
    await tapVisible(tester, find.byKey(const Key('collection-filter-offers')));
    await tapVisible(tester, find.byKey(const Key('collection-filter-apply')));
    expect(cards(tester), isNotEmpty);
    for (final card in cards(tester)) {
      expect(store.facetsFor(card.product.id)?.brand?.value, 'guess');
      expect(
        card.product.variants
            .firstWhere((v) => v.id == card.initialVariantId)
            .compareAtPrice,
        isNotNull,
      );
    }
    final chip = find.widgetWithText(InputChip, 'Ofertas');
    tester.widget<InputChip>(chip).onDeleted!();
    await tester.pumpAndSettle();
    expect(cards(tester).map((c) => c.product.id), before);
  });
  testWidgets(
      'local search plus oldest retains scope and later query wins synchronously',
      (tester) async {
    final store = await discoveryStore();
    await mountDiscovery(
      tester,
      const CollectionScreen(
        title: 'Configured',
        filter: CollectionFilter(collectionHandle: 'configured-bags'),
      ),
      store,
    );
    await tester.enterText(
      find.byKey(const Key('collection-local-search')),
      'impossible',
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('collection-local-search')),
      'coach',
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('collection-sort-button')));
    expect(find.text('Filtros'), findsNothing);
    final previousOrder = cards(tester).map((c) => c.product.id).toList();
    await tapVisible(tester, find.byKey(const Key('collection-sort-oldest')));
    expect(cards(tester).map((c) => c.product.id), previousOrder);
    await tapVisible(tester, find.byKey(const Key('collection-sort-cancel')));
    expect(cards(tester).map((c) => c.product.id), previousOrder);
    await tapVisible(tester, find.byKey(const Key('collection-sort-button')));
    await tapVisible(tester, find.byKey(const Key('collection-sort-oldest')));
    await tapVisible(tester, find.byKey(const Key('collection-sort-apply')));
    expect(cards(tester), isNotEmpty);
    expect(
      cards(tester).every(
        (c) => store.facetsFor(c.product.id)?.brand?.value == 'coach',
      ),
      isTrue,
    );
    final dates = cards(tester).map((c) => c.product.createdAt).toList();
    expect(dates, [...dates]..sort());
  });
  testWidgets('unknown collection membership is not a broader product fallback',
      (tester) async {
    final store = await discoveryStore();
    await mountDiscovery(
      tester,
      const CollectionScreen(
        title: 'Missing',
        filter: CollectionFilter(collectionHandle: 'not-configured'),
      ),
      store,
    );
    expect(find.text('Sin resultados'), findsOneWidget);
    expect(cards(tester), isEmpty);
  });
  testWidgets(
      'all brands routes to the actual canonical set and returns to directory',
      (tester) async {
    final store = await discoveryStore();
    await mountDiscovery(tester, const BrandsScreen(), store);
    await tapVisible(tester, find.byKey(const Key('directory-brand-coach')));
    expect(find.byType(BrandScreen), findsOneWidget);
    expect(
      cards(tester).every(
        (c) => store.facetsFor(c.product.id)?.brand?.value == 'coach',
      ),
      isTrue,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(BrandsScreen), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('directory-brand-rhode')));
    expect(
      tester.widget<BrandScreen>(find.byType(BrandScreen)).brandSlug,
      'rhode',
    );
    expect(
      cards(tester),
      isEmpty,
      reason:
          'last configured brand never falls back to Guess or Coach inventory',
    );
  });
  testWidgets(
      'color plus offer selects an actual variant through quick view, PDP and return',
      (tester) async {
    final store = await discoveryStore();
    final target = discoveryProduct(
      20,
      variants: const [
        ProductVariant(
          id: 'target-red',
          title: 'Rojo',
          price: 500,
          available: true,
          selectedOptions: {'Color': 'Red'},
        ),
        ProductVariant(
          id: 'target-black',
          title: 'Negro',
          price: 1200,
          compareAtPrice: 1500,
          available: true,
          selectedOptions: {'Color': 'Black'},
        ),
      ],
    );
    final decoy = discoveryProduct(
      21,
      variants: const [
        ProductVariant(
          id: 'decoy-black',
          title: 'Negro',
          price: 900,
          available: true,
          selectedOptions: {'Color': 'Black'},
        ),
        ProductVariant(
          id: 'decoy-red',
          title: 'Rojo',
          price: 1000,
          compareAtPrice: 1500,
          available: true,
          selectedOptions: {'Color': 'Red'},
        ),
      ],
    );
    setDiscoveryProducts(store, [target, decoy]);
    await mountDiscovery(tester, const BrandScreen(brandSlug: 'guess'), store);
    await tapVisible(tester, find.byKey(const Key('collection-filter-button')));
    await tapVisible(
      tester,
      find.byKey(const Key('collection-filter-color-negro')),
    );
    await tapVisible(tester, find.byKey(const Key('collection-filter-offers')));
    await tapVisible(tester, find.byKey(const Key('collection-filter-apply')));
    expect(cards(tester).single.initialVariantId, 'target-black');
    await tapVisible(
      tester,
      find
          .descendant(
            of: find.byType(ProductCard),
            matching: find.byType(MonettaImage),
          )
          .first,
    );
    expect(find.byKey(const Key('quick-view-card')), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('quick-view-view-product')));
    final pdp = tester.widget<ProductScreen>(find.byType(ProductScreen));
    expect(pdp.productId, target.id);
    expect(pdp.initialVariantId, 'target-black');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(cards(tester).single.initialVariantId, 'target-black');
    expect(find.widgetWithText(InputChip, 'Ofertas'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Negro'), findsOneWidget);
  });
  testWidgets(
      'error retains query and pieces; unavailable retry does not report success',
      (tester) async {
    final store = await discoveryStore();
    store.realtimeStatus = CatalogRealtimeStatus.invalid;
    await mountDiscovery(
      tester,
      const CollectionScreen(title: 'Catálogo'),
      store,
    );
    await tester.enterText(
      find.byKey(const Key('collection-local-search')),
      'coach',
    );
    await tester.pumpAndSettle();
    final before = cards(tester).map((c) => c.product.id).toList();
    expect(find.text('Sin resultados'), findsNothing);
    await tapVisible(tester, find.text('Reintentar'));
    expect(
      find.text('La actualización del catálogo no está disponible.'),
      findsOneWidget,
    );
    expect(cards(tester).map((c) => c.product.id), before);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('collection-local-search')))
          .controller!
          .text,
      'coach',
    );
  });
  testWidgets(
      'progressive pages expose unique IDs and counts use the complete scope',
      (tester) async {
    final store = await discoveryStore(count: 85);
    await mountDiscovery(
      tester,
      const CollectionScreen(title: 'Catálogo'),
      store,
    );
    int loaded() => (tester.widget<SliverGrid>(find.byType(SliverGrid)).delegate
            as SliverChildBuilderDelegate)
        .childCount!;
    expect(loaded(), 40);
    expect(
      tester.widget<Text>(find.byKey(const Key('collection-count'))).data,
      '85 resultados',
    );
    await tapVisible(tester, find.byKey(const Key('collection-load-more')));
    expect(loaded(), 80);
    await tapVisible(tester, find.byKey(const Key('collection-load-more')));
    expect(loaded(), 85);
    expect(
      cards(tester).map((c) => c.product.id).toSet().length,
      cards(tester).length,
    );
  });
  testWidgets(
      '320/200% draft footer stays above the keyboard and cancellation retains query',
      (tester) async {
    final store = await discoveryStore();
    await mountDiscovery(
      tester,
      const CollectionScreen(title: 'Bolsos'),
      store,
      scale: 2,
    );
    tester.view.physicalSize = const Size(320, 900);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('collection-filter-button')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const Key('collection-filter-apply'))).bottom,
      lessThanOrEqualTo(600),
    );
    await tester.enterText(
      find.byKey(const Key('collection-filter-query')),
      'discard me',
    );
    await tapVisible(tester, find.byKey(const Key('collection-filter-cancel')));
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('collection-local-search')))
          .controller!
          .text,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('global search filter entry preserves query and count scope',
      (tester) async {
    final store = await discoveryStore();
    await mountDiscovery(
      tester,
      const SearchScreen(initialQuery: 'guess'),
      store,
    );
    await tapVisible(tester, find.byKey(const Key('search-filters')));
    expect(find.byKey(const Key('collection-filter-apply')), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('collection-filter-cancel')));
    expect(
      tester.widget<Text>(find.byKey(const Key('collection-count'))).data,
      '${searchProducts(store, 'guess').length} resultados',
    );
  });
}
