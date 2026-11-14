import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/catalog/browse_detail_layout.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/catalog/product_card.dart';
import 'package:monetta_app/features/product/product_screen.dart';
import 'package:monetta_app/features/product/product_selection.dart';
import 'package:monetta_app/main.dart';
import 'package:monetta_app/platform/system_layout_context.dart';

import '../../support/product_screen_harness.dart';

class _PendingStore extends CatalogStore {
  _PendingStore() : super(database: openTestDatabase());
  final release = Completer<void>();
  final List<String?> mutations = [];
  @override
  Future<void> addToBag(Product product, {String? variantId}) async {
    mutations.add(variantId);
    await release.future;
    await super.addToBag(product, variantId: variantId);
  }
}

void main() {
  setUpAll(mockPathProvider);

  Future<void> resize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  void view(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> mount(
    WidgetTester tester,
    CatalogStore store,
    Widget page, {
    ValueNotifier<SystemLayoutContext>? geometry,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: StoreScope(
          notifier: store,
          child: geometry == null
              ? page
              : ValueListenableBuilder(
                  valueListenable: geometry,
                  builder: (_, value, child) =>
                      SystemLayoutScope(geometry: value, child: child!),
                  child: page,
                ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
      'synthetic fold, camera, asymmetric insets and keyboard keep actions usable',
      (tester) async {
    view(tester);
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.padding =
        const FakeViewPadding(left: 13, top: 23, right: 45, bottom: 34);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewInsets);
    const fold = Rect.fromLTWH(0, 360, 1000, 32);
    const camera = Rect.fromLTWH(430, 440, 140, 50);
    final geometry = ValueNotifier(
      const SystemLayoutContext(
        supported: true,
        sequence: 1,
        viewSize: Size(1000, 800),
        barEdge: SystemBarEdge.left,
        divisions: [ReservedRegion(bounds: fold, active: true)],
        occlusions: [ReservedRegion(bounds: camera, active: true)],
      ),
    );
    addTearDown(geometry.dispose);
    final store = await loadedStore();
    final product =
        syntheticProduct(title: kLongProductName, variants: chipVariants());
    addProducts(store, [product]);
    await mount(
      tester,
      store,
      ProductScreen(productId: product.id),
      geometry: geometry,
      textScale: 2,
    );
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(ProductScreen));
    await tester.ensureVisible(find.byKey(kDockPrimaryKey));
    await tester.pumpAndSettle();
    final action = tester.getRect(find.byKey(kDockPrimaryKey));
    expect(action.overlaps(fold), isFalse);
    expect(action.overlaps(camera), isFalse);
    expect(action.left, greaterThanOrEqualTo(13));
    expect(action.right, lessThanOrEqualTo(955));
    expect(action.bottom, lessThanOrEqualTo(766));
    geometry.value = const SystemLayoutContext();
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    await resize(tester, const Size(390, 560));
    await tester.ensureVisible(find.byKey(kDockPrimaryKey));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(ProductScreen)), same(state));
    expect(
      MediaQuery.textScalerOf(tester.element(find.byType(ProductScreen)))
          .scale(16),
      32,
    );
    final compactAction = tester.getRect(find.byKey(kDockPrimaryKey));
    expect(compactAction.left, greaterThanOrEqualTo(13));
    expect(compactAction.right, lessThanOrEqualTo(345));
    expect(compactAction.top, greaterThanOrEqualTo(0));
    expect(
      compactAction.bottom,
      lessThanOrEqualTo(380),
      reason: 'above the keyboard',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('same product/variant/gallery/sections survive repeated reflow',
      (tester) async {
    view(tester);
    final store = await loadedStore();
    final product = store.products.firstWhere(
      (p) => p.images.length > 1 && selectableVariants(p).length > 1,
    );
    await mount(tester, store, ProductScreen(productId: product.id));
    final state = tester.state(find.byType(ProductScreen));
    // The gallery shows the active variant's photos: arrows only when it has
    // more than one.
    final next = find.byKey(const Key('product-gallery-next'));
    final expectedPage = next.evaluate().isNotEmpty ? 1 : 0;
    if (expectedPage == 1) {
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    await scrollTo(tester, find.byType(ProductOptionSelector));
    tester
        .widget<ProductOptionSelector>(find.byType(ProductOptionSelector))
        .onSelect(1);
    await tester.pump();
    final variantId = selectableVariants(product)[1].id;
    await scrollTo(tester, find.text('Descripción'));
    await tester.tap(find.text('Descripción'));
    await tester.pumpAndSettle();
    for (final size in [
      const Size(1024, 768),
      const Size(768, 1024),
      const Size(390, 844),
      const Size(920, 600),
    ]) {
      await resize(tester, size);
      expect(tester.state(find.byType(ProductScreen)), same(state));
      final selector = tester
          .widget<ProductOptionSelector>(find.byType(ProductOptionSelector));
      expect(
        selectedVariant(selector.product, selector.selectedIndex!)?.id,
        variantId,
      );
      final gallery = tester.widget<PageView>(find.byType(PageView).first);
      expect(gallery.controller?.page?.round() ?? 0, expectedPage);
      final accordion = find
          .ancestor(
            of: find.text('Descripción'),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics && widget.properties.expanded != null,
            ),
          )
          .first;
      expect(tester.widget<Semantics>(accordion).properties.expanded, isTrue);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'an unselected collection preserves its visible result ID across column changes',
      (tester) async {
    view(tester);
    tester.view.physicalSize = const Size(1024, 768);
    final store = await loadedStore();
    await mount(
      tester,
      store,
      const BrowseDetailLayout(child: CollectionScreen(title: 'Colección')),
    );
    await tester.pumpAndSettle();
    final scroll = find
        .descendant(
          of: find.byType(CustomScrollView).first,
          matching: find.byType(Scrollable),
        )
        .first;
    tester.state<ScrollableState>(scroll).position.jumpTo(1800);
    await tester.pumpAndSettle();
    final visible = find.byType(ProductCard).evaluate().where((element) {
      final render = element.findRenderObject()! as RenderBox;
      final rect = render.localToGlobal(Offset.zero) & render.size;
      return rect.bottom > 80 && rect.top < 650;
    }).toList();
    expect(visible, isNotEmpty);
    final id = (visible.first.widget as ProductCard).product.id;
    await resize(tester, const Size(390, 844));
    await tester.pumpAndSettle();
    final anchor = find.byWidgetPredicate(
      (widget) => widget is ProductCard && widget.product.id == id,
    );
    expect(anchor, findsOneWidget);
    expect(
      tester.getRect(anchor).overlaps(const Rect.fromLTWH(0, 56, 390, 700)),
      isTrue,
    );
    expect(find.byType(ProductScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'resizing an in-flight add issues exactly one exact-variant mutation',
      (tester) async {
    view(tester);
    final store = await loadStore(_PendingStore());
    final product = syntheticProduct(variants: chipVariants());
    addProducts(store, [product]);
    await mount(
      tester,
      store,
      ProductScreen(productId: product.id, initialVariantIndex: 1),
    );
    await scrollTo(tester, find.byKey(kDockPrimaryKey));
    await tester.tap(find.byKey(kDockPrimaryKey));
    await tester.pump();
    await resize(tester, const Size(1024, 768));
    await resize(tester, const Size(390, 844));
    expect(store.mutations, [product.variants[1].id]);
    store.release.complete();
    await tester.pumpAndSettle();
    expect(store.bagQuantity, 1);
    expect(store.bagLines.single.variant.id, product.variants[1].id);
    expect(store.mutations, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'browse expands, collapses and Back restores the source selection',
      (tester) async {
    view(tester);
    final store = await loadedStore();
    final product = syntheticProduct(variants: chipVariants());
    addProducts(store, [product]);
    final query = TextEditingController(text: 'bolsa café');
    addTearDown(query.dispose);
    await mount(
      tester,
      store,
      BrowseDetailLayout(
        child: Scaffold(
          body: Builder(
            builder: (context) => ListView(
              children: [
                TextField(controller: query),
                const SizedBox(height: 320),
                ProductCard(
                  product: product,
                  onTap: () => openProduct(context, product),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await scrollTo(tester, find.byType(ProductCard));
    await tester.tap(find.byType(ProductCard));
    await tester.pumpAndSettle();
    final selectedState = tester.state(find.byType(ProductScreen));
    await resize(tester, const Size(1024, 768));
    expect(find.byType(ProductCard), findsWidgets);
    expect(tester.state(find.byType(ProductScreen)), same(selectedState));
    await resize(tester, const Size(390, 844));
    expect(query.text, 'bolsa café');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ProductScreen), findsNothing);
    expect(find.byType(ProductCard), findsOneWidget);
    expect(
      tester
          .getRect(find.byType(ProductCard))
          .overlaps(const Rect.fromLTWH(0, 0, 390, 844)),
      isTrue,
    );
    expect(query.text, 'bolsa café');
    expect(tester.takeException(), isNull);
  });
  testWidgets('direct product opened over browsing keeps independent history',
      (tester) async {
    view(tester);
    tester.view.physicalSize = const Size(1024, 768);
    final store = await loadedStore();
    final product = syntheticProduct(variants: chipVariants());
    addProducts(store, [product]);
    await mount(
      tester,
      store,
      BrowseDetailLayout(
        child: Scaffold(
          body: ListView(children: [ProductCard(product: product)]),
        ),
      ),
    );
    await tester.tap(find.byType(ProductCard));
    await tester.pumpAndSettle();
    final original = tester.state(find.byType(ProductScreen));
    final context = tester.element(find.byType(ProductScreen));
    expect(BrowseDetailScope.maybeOf(context), isNull);
    openProduct(context, product, initialVariantIndex: 1);
    await tester.pumpAndSettle();
    final direct = tester.widget<ProductScreen>(find.byType(ProductScreen));
    expect(direct.onClose, isNull);
    expect(direct.initialVariantIndex, 1);
    expect(tester.state(find.byType(ProductScreen)), isNot(same(original)));
    await resize(tester, const Size(390, 844));
    expect(
      tester.widget<ProductScreen>(find.byType(ProductScreen)).onClose,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(ProductScreen)), same(original));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'real collection keeps filter/sort drafts and applied results through reflow',
      (tester) async {
    view(tester);
    final store = await loadedStore();
    await mount(
      tester,
      store,
      const BrowseDetailLayout(
        child: CollectionScreen(
          title: 'Bolsas',
          filter: CollectionFilter(query: 'bolsa'),
        ),
      ),
    );
    await tester
        .ensureVisible(find.byKey(const Key('collection-filter-button')));
    await tester.tap(find.byKey(const Key('collection-filter-button')));
    await tester.pumpAndSettle();
    // Sorting has its own control since UI v4.1; the panel keeps filters.
    // Availability is a direct toggle in the v4.1 panel.
    await tester
        .ensureVisible(find.byKey(const Key('collection-filter-stock')));
    await tester.tap(find.byKey(const Key('collection-filter-stock')));
    await tester.pump();
    bool? stockSelected() => tester
        .widget<CheckboxListTile>(
          find.byKey(const Key('collection-filter-stock')),
        )
        .value;
    expect(stockSelected(), isTrue);
    await resize(tester, const Size(1024, 768));
    expect(stockSelected(), isTrue);
    final resultLabel = tester
        .widget<Text>(
          find
              .descendant(
                of: find.byKey(const Key('collection-filter-apply')),
                matching: find.byType(Text),
              )
              .first,
        )
        .data;
    await tester.tap(find.byKey(const Key('collection-filter-apply')));
    await tester.pumpAndSettle();
    for (var i = 0;
        i < 12 && find.byType(ProductCard).evaluate().isEmpty;
        i++) {
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -200),
      );
      await tester.pump();
    }
    final card = find.byType(ProductCard).first;
    await tester.ensureVisible(card);
    final product = tester.widget<ProductCard>(card).product;
    expect(product.isInStock, isTrue);
    await tester.tap(card);
    await tester.pumpAndSettle();
    await resize(tester, const Size(390, 844));
    await resize(tester, const Size(1024, 768));
    expect(
      tester.widget<ProductScreen>(find.byType(ProductScreen)).productId,
      product.id,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('collection-filter-count')), findsOneWidget);
    final filter = find.byKey(const Key('collection-filter-button'));
    await tester.scrollUntilVisible(
      filter,
      -200,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await Scrollable.ensureVisible(tester.element(filter), alignment: .3);
    await tester.pump();
    await tester.tap(filter);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(
            find
                .descendant(
                  of: find.byKey(const Key('collection-filter-apply')),
                  matching: find.byType(Text),
                )
                .first,
          )
          .data,
      resultLabel,
    );
    expect(stockSelected(), isTrue);
    expect(tester.takeException(), isNull);
  });
}
