import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/cart_controller.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/shopify_checkout_coordinator.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/shopify/cart/cart_repository.dart';
import 'package:monetta_app/data/shopify/cart/checkout_launcher.dart';
import 'package:monetta_app/data/shopify/cart_attribution.dart';
import 'package:monetta_app/domain/home_content.dart';
import 'package:monetta_app/features/checkout/checkout_screen.dart';
import 'package:monetta_app/features/home/home_for_you_section.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/main.dart';

import '../../support/product_screen_harness.dart';
import '../../support/scripted_catalog_store.dart';
import '../../support/shopify_cart_fakes.dart';

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
      expect(find.descendant(of: tile, matching: find.byType(Image)),
          findsOneWidget);
    }
  });

  testWidgets('Para ti pide una opción y continúa con la bolsa existente',
      (tester) async {
    setPhoneView(tester);
    final store = await loadStore(
      ScriptedCatalogStore(database: openTestDatabase()),
    );
    addTearDown(store.dispose);
    final product = syntheticProduct(variants: chipVariants());
    store.products = [product];
    await store.addToBag(product, variantId: 'v-chica');

    final sessions = InMemoryCartSessionStore();
    final controller = CartController(
      reconciler: CartRepository(
        api: FakeCartApi(),
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
          launcher: FakeCheckoutLauncher(const []),
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
    expect(store.bagQuantity, 1);

    store.failWith = null;
    await tester.tap(buy);
    await tester.pumpAndSettle();
    expect(find.byType(CheckoutFlowScreen), findsOneWidget);
    expect(
      store.bagLines.map((line) => line.variant.id),
      unorderedEquals(['v-chica', 'v-mediana']),
    );
  });
}
