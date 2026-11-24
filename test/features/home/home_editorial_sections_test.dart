import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/cart_controller.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/shopify_checkout_coordinator.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/shopify/cart/cart_api.dart';
import 'package:monetta_app/data/shopify/cart/cart_repository.dart';
import 'package:monetta_app/data/shopify/cart/checkout_launcher.dart';
import 'package:monetta_app/data/shopify/cart_attribution.dart';
import 'package:monetta_app/domain/cart.dart';
import 'package:monetta_app/domain/home_content.dart';
import 'package:monetta_app/features/checkout/checkout_screen.dart';
import 'package:monetta_app/features/home/home_for_you_section.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/main.dart';

import '../../support/product_screen_harness.dart';
import '../../support/scripted_catalog_store.dart';
import '../../support/shopify_cart_fakes.dart';

class _HomeCheckoutCartApi implements CartApi {
  final FakeCartApi _delegate = FakeCartApi();

  @override
  Future<CartMutationResult> create({
    required List<CartLineCreateInput> lines,
    required Map<String, String> attributes,
    CartBuyerIdentity? buyerIdentity,
  }) async {
    const money = CartMoney(amount: '10.00', currencyCode: 'MXN');
    final timestamp = DateTime.utc(2026, 8, 27);
    final totalQty = lines.fold<int>(0, (sum, line) => sum + line.quantity);
    return CartMutationResult(
      cart: Cart(
        id: 'gid://shopify/Cart/home-for-you?key=secret',
        checkoutUrl: 'https://monetta.example/checkouts/cn/c1',
        createdAt: timestamp,
        updatedAt: timestamp,
        lines: [
          for (var i = 0; i < lines.length; i++)
            CartLine(
              id: 'gid://shopify/CartLine/${i + 1}',
              variantId: lines[i].merchandiseId,
              productId: 'gid://shopify/Product/1',
              title: 'Producto',
              variantTitle: 'Variante',
              quantity: lines[i].quantity,
              cost: const CartLineCost(
                amountPerQuantity: money,
                subtotal: money,
                total: money,
              ),
            ),
        ],
        totalQuantity: totalQty,
        buyerIdentity: const CartBuyerSummary(
          countryCode: 'MX',
          isAuthenticated: false,
        ),
        cost: const CartCost(subtotal: money, total: money),
      ),
    );
  }

  @override
  Future<Cart?> get(SensitiveCartId cartId) => _delegate.get(cartId);

  @override
  Future<CartMutationResult> addLines(
    SensitiveCartId cartId,
    List<CartLineCreateInput> lines,
  ) =>
      _delegate.addLines(cartId, lines);

  @override
  Future<CartMutationResult> updateLines(
    SensitiveCartId cartId,
    List<CartLineUpdateInput> lines,
  ) =>
      _delegate.updateLines(cartId, lines);

  @override
  Future<CartMutationResult> removeLines(
    SensitiveCartId cartId,
    List<String> lineIds,
  ) =>
      _delegate.removeLines(cartId, lineIds);

  @override
  Future<CartMutationResult> updateBuyerIdentity(
    SensitiveCartId cartId,
    CartBuyerIdentity identity,
  ) =>
      _delegate.updateBuyerIdentity(cartId, identity);

  @override
  Future<CartMutationResult> replaceDiscountCodes(
    SensitiveCartId cartId,
    List<String> discountCodes,
  ) =>
      _delegate.replaceDiscountCodes(cartId, discountCodes);
}

void main() {
  testWidgets('the brands rail shows configured brands with their logo artwork',
      (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = CatalogStore(database: openTestDatabase());
    addTearDown(store.dispose);
    await store.loadFromAsset();

    await tester.pumpWidget(
      MaterialApp(
        home: StoreScope(
          notifier: store,
          child: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();

    final brandsSection = find.byKey(
      const ValueKey('home-section-brands'),
    );
    final homeScroll = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .first;
    await tester.scrollUntilVisible(
      brandsSection,
      700,
      scrollable: homeScroll,
    );
    await tester.pump();

    final rail = find.descendant(
      of: find.byKey(const ValueKey('home-brands-rail')),
      matching: find.byType(Scrollable),
    );
    await tester.ensureVisible(rail);
    await tester.pump();
    expect(tester.widget<Scrollable>(rail).axis, Axis.horizontal);
    for (final brand in guideBrandsFor(HomeContent.fallback.brands)) {
      final tile = find.byKey(ValueKey('home-brand-${brand.handle}'));
      await tester.scrollUntilVisible(tile, 150, scrollable: rail);
      expect(
        find.descendant(of: tile, matching: find.byType(Image)),
        findsOneWidget,
      );
    }
  });

  testWidgets('Para ti pide una opción y continúa con la bolsa existente',
      (tester) async {
    setPhoneView(tester);
    final store = await loadStore(
      ScriptedCatalogStore(database: openTestDatabase()),
    );
    addTearDown(store.dispose);
    final product = syntheticProduct(
      variants: [
        syntheticVariant(
          id: 'gid://shopify/ProductVariant/101',
          title: 'Talla chica',
          price: 1000,
        ),
        syntheticVariant(
          id: 'gid://shopify/ProductVariant/102',
          title: 'Talla mediana',
          price: 1100,
        ),
        syntheticVariant(
          id: 'gid://shopify/ProductVariant/103',
          title: 'Talla grande',
          price: 1200,
        ),
      ],
    );
    store.products = [product];
    await store.addToBag(
      product,
      variantId: 'gid://shopify/ProductVariant/101',
    );

    final launcher = FakeCheckoutLauncher([const CheckoutCancelled()]);
    final sessions = InMemoryCartSessionStore();
    final controller = CartController(
      reconciler: CartRepository(
        api: _HomeCheckoutCartApi(),
        sessions: sessions,
        writes: RecoveringCartWriteCoordinator(),
        attribution: const CartAttribution(
          platform: 'test',
          deviceId: 'fixture',
          appVersion: '0',
        ),
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      CartScope(
        shopDomain: 'monetta.example',
        notifier: controller,
        checkoutCoordinator: ShopifyCheckoutCoordinator(
          launcher: launcher,
          urlPolicy: CheckoutUrlPolicy.forShopDomain('monetta.example'),
          sessions: sessions,
        ),
        child: fichaApp(
          store,
          const Scaffold(body: HomeForYouSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final options = find.byKey(ValueKey('for-you-options-${product.id}'));
    await tester.tap(options);
    await tester.pumpAndSettle();
    final buy = find.text('Comprar ahora', findRichText: true);
    expect(buy, findsOneWidget);
    await tester.ensureVisible(buy);
    await tester.tap(buy);
    await tester.pumpAndSettle();
    expect(store.bagQuantity, 1);

    final option = optionChip('Talla mediana');
    await tester.ensureVisible(option);
    await tester.tap(option);
    await tester.pumpAndSettle();
    store.failWith = StateError('QA');
    await tester.ensureVisible(buy);
    await tester.tap(buy);
    await tester.pumpAndSettle();
    expect(find.byType(CheckoutFlowScreen), findsNothing);
    expect(launcher.presentCalls, 0);
    expect(store.bagQuantity, 1);

    store.failWith = null;
    await tester.tap(buy);
    await tester.pumpAndSettle();
    expect(find.byType(CheckoutFlowScreen), findsNothing);
    expect(launcher.presentCalls, 1);
    expect(
      store.bagLines.map((line) => line.variant.id),
      unorderedEquals([
        'gid://shopify/ProductVariant/101',
        'gid://shopify/ProductVariant/102',
      ]),
    );
  });
}
