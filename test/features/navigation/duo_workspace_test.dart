import 'dart:async';

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/shopify/cart/checkout_launcher.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/boutique/boutique_tokens.dart';
import 'package:monetta_app/features/catalog/browse_detail_layout.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/catalog/product_card.dart';
import 'package:monetta_app/features/checkout/checkout_screen.dart';
import 'package:monetta_app/features/navigation/adaptive_storefront_scaffold.dart';
import 'package:monetta_app/features/navigation/duo_workspace.dart';
import 'package:monetta_app/features/navigation/monetta_bottom_navigation.dart';
import 'package:monetta_app/features/product/product_screen.dart';
import 'package:monetta_app/main.dart';
import 'package:monetta_app/platform/system_layout_context.dart';

import '../../support/product_screen_harness.dart';

// The inner display measured on the Duo simulator
// (artifacts/iphone-duo/resume-runtime-summary.json): 951×669 points, the
// system bar's 84-point inset on the right, 34 at the bottom and a 40-point
// division at x = 455.5, inactive when flat and active half folded.
const Size kInner = Size(951, 669);
const Size kOuter = Size(466, 678);
const Rect kCrease = Rect.fromLTWH(455.5, 0, 40, 669);
const Rect kLeftSide = Rect.fromLTRB(0, 0, 455.5, 669);
const Rect kRightSide = Rect.fromLTRB(495.5, 0, 867, 669);

SystemLayoutContext inner({bool folded = false, int sequence = 1}) =>
    SystemLayoutContext(
      supported: true,
      sequence: sequence,
      viewSize: kInner,
      safeInsets: const EdgeInsets.fromLTRB(0, 0, 84, 34),
      barEdge: SystemBarEdge.right,
      divisions: [ReservedRegion(bounds: kCrease, active: folded)],
    );

const SystemLayoutContext outer = SystemLayoutContext(
  supported: true,
  sequence: 9,
  viewSize: kOuter,
  safeInsets: EdgeInsets.fromLTRB(0, 0, 84, 34),
  barEdge: SystemBarEdge.right,
);

Matcher inside(Rect side) => predicate<Rect>(
      (rect) =>
          rect.left >= side.left - .5 &&
          rect.right <= side.right + .5 &&
          rect.top >= side.top - .5 &&
          rect.bottom <= side.bottom + .5,
      'inside $side',
    );

/// A browsing page with a grid and the shared bar, like the catalog screens.
class _Browse extends StatelessWidget {
  const _Browse({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) => AdaptiveStorefrontScaffold(
        avoidReservedRegions: true,
        appBar: AppBar(title: const Text('Catálogo de prueba')),
        body: ProductCardGrid(
          products: products,
          padding: const EdgeInsets.all(BoutiqueSpace.lg),
        ),
        bottomNavigationBar: MonettaBottomNavigation(
          current: MonettaBottomDestination.catalog,
          bagCount: StoreScope.of(context).bagQuantity,
          onSelected: (destination) {
            switch (destination) {
              case MonettaBottomDestination.bag:
                unawaited(openBag(context));
              case MonettaBottomDestination.account:
                // The real account needs a signed-in controller; the
                // workspace only sees a page of the account kind.
                DuoWorkspace.showPane(
                  context,
                  DuoPanePage(
                    kind: DuoPaneKind.account,
                    builder: (_) => const Scaffold(
                      key: Key('account-stub'),
                      body: Center(child: Text('Mi cuenta')),
                    ),
                  ),
                );
              case MonettaBottomDestination.home:
              case MonettaBottomDestination.catalog:
                break;
            }
          },
        ),
      );
}

void main() {
  setUpAll(mockPathProvider);

  late ValueNotifier<SystemLayoutContext> geometry;

  Future<void> settle(WidgetTester tester) async {
    // Layout, then the origins measured after it, then animations.
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> mount(
    WidgetTester tester,
    CatalogStore store,
    Widget home, {
    SystemLayoutContext? start,
    double textScale = 1,
    SecureCheckoutLauncher? launcher,
  }) async {
    tester.view.devicePixelRatio = 1;
    final layout = start ?? inner();
    tester.view.physicalSize = layout.viewSize;
    tester.view.padding = const FakeViewPadding(right: 84, bottom: 34);
    addTearDown(tester.view.reset);
    geometry = ValueNotifier(layout);
    addTearDown(geometry.dispose);
    final navigatorKey = GlobalKey<NavigatorState>();
    final routes = DuoRouteObserver();
    addTearDown(routes.dispose);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [routes],
        theme: buildLightTheme(),
        builder: (context, navigator) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: ValueListenableBuilder<SystemLayoutContext>(
            valueListenable: geometry,
            builder: (context, value, child) =>
                SystemLayoutScope(geometry: value, child: child!),
            child: StoreScope(
              notifier: store,
              child: DuoWorkspace(
                navigatorKey: navigatorKey,
                routes: routes,
                paneRoot: (_) =>
                    BagScreen(embedded: true, launchSecureCheckout: launcher),
                child: navigator!,
              ),
            ),
          ),
        ),
        home: home,
      ),
    );
    await settle(tester);
  }

  Future<void> reshape(
    WidgetTester tester,
    SystemLayoutContext layout,
  ) async {
    tester.view.physicalSize = layout.viewSize;
    geometry.value = layout;
    await settle(tester);
  }

  Finder cardFor(Product product) =>
      find.byKey(ValueKey('product-card-${product.id}'));

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  bool? marked(WidgetTester tester, Finder control) => tester
      .widget<Semantics>(
        find.ancestor(of: control, matching: find.byType(Semantics)).first,
      )
      .properties
      .selected;

  Future<({CatalogStore store, Product single, Product several})> catalog() =>
      loadedStore().then((store) {
        final single = singleVariantAssetProduct(store);
        final several = syntheticProduct(
          id: 'gid://shopify/Product/9101',
          title: 'Bolsa de tallas',
          variants: chipVariants(),
        );
        addProducts(store, [several]);
        return (store: store, single: single, several: several);
      });

  testWidgets('opens with only the empty bag on the right side',
      (tester) async {
    final shop = await catalog();
    await mount(
      tester,
      shop.store,
      _Browse(products: [shop.single, shop.several]),
    );

    expect(tester.getRect(find.byType(_Browse)), kLeftSide);
    final emptyBag = find.byKey(const Key('duo-empty-bag'));
    expect(emptyBag, findsOneWidget);
    expect(tester.getRect(emptyBag), inside(kRightSide));
    expect(find.text('Tu bolsa está vacía'), findsOneWidget);
    expect(find.text('Recomendaciones'), findsNothing);
    expect(find.text('VOLVER A LA TIENDA'), findsNothing);
    expect(
      tester.getRect(find.byKey(const Key('duo-rail'))).left,
      greaterThanOrEqualTo(867),
    );
    expect(find.byKey(const Key('duo-crease')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('half folded, neither side is left empty', (tester) async {
    final shop = await catalog();
    await mount(
      tester,
      shop.store,
      _Browse(products: [shop.single, shop.several]),
      start: inner(folded: true),
    );

    // Before, every surface took only the larger usable region and left the
    // right of the crease blank.
    expect(tester.getRect(find.byType(_Browse)), kLeftSide);
    expect(
      tester.getRect(find.byType(ProductCardGrid)).width,
      closeTo(455.5, .5),
    );
    expect(
      tester.getRect(find.byKey(const Key('duo-empty-bag'))),
      inside(kRightSide),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a card previews on the right, the catalog stays and «Ver producto» '
      'replaces the preview', (tester) async {
    final shop = await catalog();
    await mount(
      tester,
      shop.store,
      _Browse(products: [shop.single, shop.several]),
    );

    await tester.tap(cardFor(shop.single));
    await settle(tester);
    final preview = find.byKey(const Key('duo-preview'));
    expect(preview, findsOneWidget);
    expect(tester.getRect(preview), inside(kRightSide));
    expect(tester.getRect(cardFor(shop.single)), inside(kLeftSide));
    // The piece shown on the right is marked in the catalog.
    final anchor = find.descendant(
      of: cardFor(shop.single),
      matching: find.byType(ProductResultAnchor),
    );
    expect(
      tester
          .widget<Semantics>(
            find.descendant(of: anchor, matching: find.byType(Semantics)).first,
          )
          .properties
          .selected,
      isTrue,
    );

    // Touching another piece replaces the preview; nothing stacks up.
    await tester.tap(cardFor(shop.several));
    await settle(tester);
    expect(preview, findsOneWidget);
    expect(find.text('Bolsa de tallas'), findsWidgets);

    await reveal(tester, find.byKey(const Key('quick-view-view-product')));
    await tester.tap(find.byKey(const Key('quick-view-view-product')));
    await settle(tester);
    expect(preview, findsNothing);
    final product = find.byType(ProductScreen);
    expect(product, findsOneWidget);
    expect(tester.widget<ProductScreen>(product).productId, shop.several.id);
    expect(tester.getRect(product), inside(kRightSide));
    expect(tester.getRect(find.byType(_Browse)), kLeftSide);

    // Back on the right side returns to the bag.
    await tester.tap(find.byTooltip('Volver').last);
    await settle(tester);
    expect(product, findsNothing);
    expect(find.byKey(const Key('duo-empty-bag')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adding from the preview keeps it and confirms on the right',
      (tester) async {
    final shop = await catalog();
    await mount(tester, shop.store, _Browse(products: [shop.single]));

    await tester.tap(cardFor(shop.single));
    await settle(tester);
    await reveal(tester, find.byKey(const Key('quick-view-primary')));
    await tester.tap(find.byKey(const Key('quick-view-primary')));
    await settle(tester);

    expect(shop.store.bagQuantity, 1);
    expect(find.byKey(const Key('duo-preview')), findsOneWidget);
    // The mini-cart sheet is not needed: the bag lives on this side.
    expect(find.text('VER BOLSA'), findsOneWidget);
    expect(find.byKey(const Key('duo-added-to-bag')), findsOneWidget);
    await tester.tap(find.text('VER BOLSA'));
    await settle(tester);
    expect(find.byKey(const Key('duo-preview')), findsNothing);
    expect(find.byType(BagScreen), findsOneWidget);
    expect(find.text('Recomendaciones'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging a card onto the right side adds it to the bag',
      (tester) async {
    final shop = await catalog();
    await mount(
      tester,
      shop.store,
      _Browse(products: [shop.single, shop.several]),
    );

    final gesture =
        await tester.startGesture(tester.getCenter(cardFor(shop.single)));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(120, 0));
    await tester.pump();
    expect(find.byKey(const Key('duo-drag-feedback')), findsOneWidget);
    expect(find.byKey(const Key('duo-bag-drop-zone')), findsOneWidget);
    await gesture.moveTo(kRightSide.center);
    await tester.pump();
    expect(find.text('Suelta para agregarla'), findsOneWidget);
    await gesture.up();
    await settle(tester);

    expect(shop.store.bagQuantity, 1);
    expect(shop.store.bagLines.single.product.id, shop.single.id);
    expect(find.byKey(const Key('duo-drag-feedback')), findsNothing);
    expect(find.byKey(const Key('duo-empty-bag')), findsNothing);
    expect(find.byKey(const Key('duo-added-to-bag')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a piece with several options dropped on the bag asks for one first',
      (tester) async {
    final shop = await catalog();
    await mount(
      tester,
      shop.store,
      _Browse(products: [shop.single, shop.several]),
    );

    final gesture =
        await tester.startGesture(tester.getCenter(cardFor(shop.several)));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveTo(kRightSide.center);
    await tester.pump();
    await gesture.up();
    await settle(tester);

    expect(shop.store.bagQuantity, 0);
    expect(find.byKey(const Key('duo-preview')), findsOneWidget);
    expect(find.byKey(const Key('quick-view-choose-hint')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a drop released over the catalog adds nothing', (tester) async {
    final shop = await catalog();
    await mount(tester, shop.store, _Browse(products: [shop.single]));

    final gesture =
        await tester.startGesture(tester.getCenter(cardFor(shop.single)));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(40, 40));
    await tester.pump();
    await gesture.up();
    await settle(tester);

    expect(shop.store.bagQuantity, 0);
    expect(find.byKey(const Key('duo-drag-feedback')), findsNothing);
    expect(find.byKey(const Key('duo-empty-bag')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the account opens on the right and the rail marks both sides',
      (tester) async {
    final shop = await catalog();
    await mount(tester, shop.store, _Browse(products: [shop.single]));

    bool selected(MonettaBottomDestination destination) =>
        marked(tester, find.byKey(Key('bottom-nav-${destination.name}'))) ==
        true;
    expect(selected(MonettaBottomDestination.catalog), isTrue);
    expect(selected(MonettaBottomDestination.bag), isTrue);

    await tester.tap(find.byKey(const Key('bottom-nav-account')));
    await settle(tester);
    expect(
      tester.getRect(find.byKey(const Key('account-stub'))),
      inside(kRightSide),
    );
    expect(tester.getRect(find.byType(_Browse)), kLeftSide);
    expect(selected(MonettaBottomDestination.account), isTrue);
    expect(selected(MonettaBottomDestination.bag), isFalse);

    // «Carrito» brings the bag back to the right side.
    await tester.tap(find.byKey(const Key('bottom-nav-bag')));
    await settle(tester);
    expect(find.byKey(const Key('account-stub')), findsNothing);
    expect(find.byKey(const Key('duo-empty-bag')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filters open on the right and apply live on the left',
      (tester) async {
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
    String count() =>
        tester.widget<Text>(find.byKey(const Key('collection-count'))).data!;
    final before = count();

    await reveal(tester, find.byKey(const Key('collection-filter-button')));
    await tester.tap(find.byKey(const Key('collection-filter-button')));
    await settle(tester);
    final apply = find.byKey(const Key('collection-filter-apply'));
    expect(tester.getRect(apply), inside(kRightSide));
    // No sheet covers the pieces on the left.
    expect(
      tester.getRect(find.byKey(const Key('collection-count'))),
      inside(kLeftSide),
    );

    await reveal(tester, find.byKey(const Key('collection-filter-brand')));
    await tester.tap(find.byKey(const Key('collection-filter-brand')));
    await settle(tester);
    final brand = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>)
              .value
              .startsWith('collection-filter-brand-'),
    );
    await reveal(tester, brand.first);
    await tester.tap(brand.first);
    await settle(tester);
    final after = count();
    expect(after, isNot(before), reason: 'applied without pressing «Ver»');

    // «Ver» only closes; the filters stand.
    await tester.tap(apply);
    await settle(tester);
    expect(apply, findsNothing);
    expect(count(), after);
    expect(find.byKey(const Key('duo-empty-bag')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('checkout spans both sides: order left, the way to pay right',
      (tester) async {
    final shop = await catalog();
    await shop.store.addToBag(shop.single);
    final launch = Completer<CheckoutResult>();
    await mount(
      tester,
      shop.store,
      _Browse(products: [shop.single]),
      launcher: (_) => launch.future,
    );

    final proceed = find.byWidgetPredicate(
      (widget) =>
          widget is BoutiqueButton && widget.label == 'Continuar al checkout',
    );
    await reveal(tester, proceed);
    await tester.tap(proceed);
    await settle(tester);

    expect(find.byType(CheckoutFlowScreen), findsOneWidget);
    final summary = find.byKey(const Key('checkout-duo-summary'));
    expect(tester.getRect(summary), inside(kLeftSide));
    expect(
      find.descendant(of: summary, matching: find.text('Tu pedido')),
      findsOneWidget,
    );
    final pay = find.byKey(const Key('checkout-duo-pay'));
    expect(tester.getRect(pay), inside(kRightSide));
    expect(
      tester.getRect(find.byKey(const ValueKey('checkout-pay-button'))),
      inside(kRightSide),
    );

    await tester.tap(find.byTooltip('Volver'));
    await settle(tester);
    expect(find.byType(CheckoutFlowScreen), findsNothing);
    expect(tester.getRect(find.byType(BagScreen)), inside(kRightSide));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'closing the phone keeps the right side page and opening returns it',
      (tester) async {
    final shop = await catalog();
    await mount(
      tester,
      shop.store,
      _Browse(products: [shop.single, shop.several]),
    );
    await reveal(tester, find.byKey(Key('view-product-${shop.several.id}')));
    await tester.tap(find.byKey(Key('view-product-${shop.several.id}')));
    await settle(tester);
    final product = find.byType(ProductScreen);
    final state = tester.state(product);
    expect(tester.getRect(product), inside(kRightSide));

    await reshape(tester, outer);
    expect(find.byKey(const Key('duo-rail')), findsNothing);
    expect(tester.state(product), same(state));
    // Drawn over the catalog with its own chrome, as a pushed page was.
    expect(tester.getRect(product).width, kOuter.width);
    expect(tester.getRect(product).left, 0);

    await reshape(tester, inner(sequence: 10));
    expect(tester.state(product), same(state));
    expect(tester.getRect(product), inside(kRightSide));
    expect(tester.getRect(find.byType(_Browse)), kLeftSide);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a piece chosen on the outer display moves right on opening, '
      'with its state', (tester) async {
    final shop = await catalog();
    await mount(
      tester,
      shop.store,
      BrowseDetailLayout(
        child: _Browse(products: [shop.single, shop.several]),
      ),
      start: outer,
    );
    await reveal(tester, find.byKey(Key('view-product-${shop.several.id}')));
    await tester.tap(find.byKey(Key('view-product-${shop.several.id}')));
    await settle(tester);
    final product = find.byType(ProductScreen);
    final state = tester.state(product);
    expect(tester.widget<ProductScreen>(product).onClose, isNotNull);

    await reshape(tester, inner(sequence: 10));
    expect(tester.state(product), same(state));
    expect(tester.getRect(product), inside(kRightSide));
    // The results are back on the left, the piece marked among them.
    expect(tester.getRect(find.byType(_Browse)), kLeftSide);
    expect(cardFor(shop.several).hitTestable(), findsOneWidget);
    expect(tester.widget<ProductScreen>(product).onClose, isNull);

    // Back on the right side returns to the bag; the results stay.
    await tester.tap(find.byTooltip('Volver').last);
    await settle(tester);
    expect(product, findsNothing);
    expect(find.byKey(const Key('duo-empty-bag')), findsOneWidget);
    expect(cardFor(shop.several).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a product page opened on the outer display moves right too',
      (tester) async {
    final shop = await catalog();
    await mount(
      tester,
      shop.store,
      _Browse(products: [shop.single, shop.several]),
      start: outer,
    );
    await reveal(tester, find.byKey(Key('view-product-${shop.several.id}')));
    await tester.tap(find.byKey(Key('view-product-${shop.several.id}')));
    await settle(tester);
    final product = find.byType(ProductScreen);
    final state = tester.state(product);

    await reshape(tester, inner(sequence: 10));
    expect(tester.state(product), same(state));
    expect(tester.getRect(product), inside(kRightSide));
    expect(tester.getRect(find.byType(_Browse)), kLeftSide);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a bag opened on the outer display moves right on opening',
      (tester) async {
    final shop = await catalog();
    await mount(
      tester,
      shop.store,
      _Browse(products: [shop.single]),
      start: outer,
    );
    expect(find.byKey(const Key('duo-rail')), findsNothing);

    await tester.tap(find.byKey(const Key('bottom-nav-bag')));
    await settle(tester);
    expect(
      tester.widget<BagScreen>(find.byType(BagScreen)).embedded,
      isFalse,
    );

    await reshape(tester, inner(sequence: 10));
    final bag = find.byType(BagScreen);
    expect(bag, findsOneWidget);
    expect(tester.widget<BagScreen>(bag).embedded, isTrue);
    expect(tester.getRect(bag), inside(kRightSide));
    expect(tester.getRect(find.byType(_Browse)), kLeftSide);
    expect(tester.takeException(), isNull);
  });

  testWidgets('enlarged text keeps one side and the ordinary preview',
      (tester) async {
    final shop = await catalog();
    await mount(
      tester,
      shop.store,
      _Browse(products: [shop.single]),
      textScale: 2,
    );

    expect(find.byKey(const Key('duo-rail')), findsNothing);
    expect(find.byType(BagScreen), findsNothing);
    expect(tester.getRect(find.byType(_Browse)).width, kInner.width);
    await tester.tap(cardFor(shop.single));
    await settle(tester);
    expect(find.byKey(const Key('duo-preview')), findsNothing);
    expect(find.byKey(const Key('quick-view-card')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a page that needs the whole window keeps one side meanwhile',
      (tester) async {
    final shop = await catalog();
    await mount(tester, shop.store, _Browse(products: [shop.single]));
    final workspace = DuoWorkspace.stateOf(
      tester.element(find.byType(_Browse)),
    )!;
    const holder = Object();

    workspace.holdOneSide(holder, hold: true);
    await settle(tester);
    expect(find.byKey(const Key('duo-rail')), findsNothing);
    expect(tester.getRect(find.byType(_Browse)).width, kInner.width);

    workspace.holdOneSide(holder, hold: false);
    await settle(tester);
    expect(find.byKey(const Key('duo-rail')), findsOneWidget);
    expect(tester.getRect(find.byType(_Browse)), kLeftSide);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a window without a division never builds the right side',
      (tester) async {
    final shop = await catalog();
    await mount(
      tester,
      shop.store,
      _Browse(products: [shop.single]),
      start: const SystemLayoutContext(),
    );

    expect(find.byKey(const Key('duo-rail')), findsNothing);
    expect(find.byType(BagScreen), findsNothing);
    expect(find.byType(Navigator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('sides split at the crease and need room for both', () {
    final sides = DuoSides.resolve(
      size: kInner,
      padding: const EdgeInsets.fromLTRB(0, 0, 84, 34),
      geometry: inner(),
      textScaler: TextScaler.noScaling,
    )!;
    expect(sides.left, kLeftSide);
    expect(sides.gutter, kCrease);
    expect(sides.right, kRightSide);
    expect(sides.rail, const Rect.fromLTWH(867, 0, 84, 669));
    expect(sides.content, const Rect.fromLTRB(0, 0, 867, 669));

    // A horizontal division (inner portrait) or no division keeps one side.
    expect(
      DuoSides.resolve(
        size: const Size(669, 951),
        padding: const EdgeInsets.only(top: 82, bottom: 34),
        geometry: const SystemLayoutContext(
          supported: true,
          viewSize: Size(669, 951),
          divisions: [
            ReservedRegion(
              bounds: Rect.fromLTWH(0, 455.5, 669, 40),
              active: false,
            ),
          ],
        ),
        textScaler: TextScaler.noScaling,
      ),
      isNull,
    );
    expect(
      DuoSides.resolve(
        size: kOuter,
        padding: const EdgeInsets.fromLTRB(0, 0, 84, 34),
        geometry: outer,
        textScaler: TextScaler.noScaling,
      ),
      isNull,
    );
  });
}
