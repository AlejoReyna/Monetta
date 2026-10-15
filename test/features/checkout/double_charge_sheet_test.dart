import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:monetta_app/app/account_controller.dart';
import 'package:monetta_app/app/cart_controller.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/accounts_orders/accounts_orders_config.dart';
import 'package:monetta_app/data/local/account_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/order_summary_store.dart';
import 'package:monetta_app/data/repositories/order_history_repository.dart';
import 'package:monetta_app/data/shopify/cart/cart_api.dart';
import 'package:monetta_app/data/shopify/cart/cart_repository.dart';
import 'package:monetta_app/data/shopify/cart/cart_session_store.dart';
import 'package:monetta_app/data/shopify/cart/checkout_launcher.dart';
import 'package:monetta_app/domain/cart.dart';
import 'package:monetta_app/features/checkout/checkout_return.dart';
import 'package:monetta_app/features/checkout/checkout_screen.dart';
import 'package:monetta_app/features/checkout/reviewing_checkout.dart';
import 'package:monetta_app/main.dart';

const _cartId = 'gid://shopify/Cart/cart-token-1?key=secret';
const _cartToken = 'cart-token-1';

void main() {
  group('ReviewingCheckoutCart', () {
    test('stores a flag and timestamp and clears when the bag is empty',
        () async {
      final memory = _MemoryWarningStore();
      final now = DateTime.utc(2026, 10, 15, 15);
      final guard = ReviewingCheckoutCart(
        store: memory,
        clock: () => now,
      );
      expect(guard.isActive, isFalse);

      guard.markActive();
      await guard.flush();
      expect(guard.isActive, isTrue);
      expect(guard.toString(), 'ReviewingCheckoutCart(active: true)');
      expect(memory.record?.markedAt, now);

      guard.noteBag(emptied: false);
      expect(guard.isActive, isTrue);

      guard.noteBag(emptied: true);
      await guard.flush();
      expect(guard.isActive, isFalse);
      expect(memory.record, isNull);
    });

    test('a restarted reader restores the flag without a cart token', () async {
      final memory = _MemoryWarningStore();
      final now = DateTime.utc(2026, 10, 15, 15);
      final first = ReviewingCheckoutCart(store: memory, clock: () => now)
        ..markActive();
      await first.flush();
      first.dispose();

      final second = ReviewingCheckoutCart(store: memory, clock: () => now);
      await second.ensureLoaded();
      expect(second.isActive, isTrue);
      expect(second.blocksCheckout(bagEmpty: false), isTrue);
      expect(second.blocksCheckout(bagEmpty: true), isFalse);
    });

    test('the warning expires 24 hours after the uncertain return', () async {
      final memory = _MemoryWarningStore();
      var now = DateTime.utc(2026, 10, 15, 15);
      final guard = ReviewingCheckoutCart(store: memory, clock: () => now)
        ..markActive();
      await guard.flush();

      now = now.add(const Duration(hours: 23, minutes: 59));
      expect(guard.isActive, isTrue);

      now = DateTime.utc(2026, 10, 15, 15).add(
        kCheckoutReviewingWarningLifetime,
      );
      guard.expireIfDue();
      await guard.flush();
      expect(guard.isActive, isFalse);
      expect(memory.record, isNull);

      final restored = ReviewingCheckoutCart(store: memory, clock: () => now);
      await restored.ensureLoaded();
      expect(restored.isActive, isFalse);
    });
  });

  testWidgets('cart checkout shows the sheet while banner 3 is active', (
    tester,
  ) async {
    final harness = await _BagHarness.create(reviewing: true);
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    await _tapCartCheckout(tester);

    expect(find.text(kCheckoutDoubleChargeTitle), findsOneWidget);
    expect(find.text(kCheckoutDoubleChargeBody), findsOneWidget);
    expect(find.text(kCheckoutReturnViewOrdersLabel), findsOneWidget);
    expect(find.text(kCheckoutDoubleChargePayAnywayLabel), findsOneWidget);
    expect(find.text('¿Cómo te contactamos?'), findsNothing);
    expect(harness.launches, 0);
  });

  testWidgets('cart checkout opens directly when banner 3 is not active', (
    tester,
  ) async {
    final harness = await _BagHarness.create();
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    await _tapCartCheckout(tester);

    expect(find.text(kCheckoutDoubleChargeTitle), findsNothing);
    expect(find.text('¿Cómo te contactamos?'), findsOneWidget);
  });

  testWidgets('a new cart token keeps the warning and still shows the sheet', (
    tester,
  ) async {
    final harness = await _BagHarness.create(reviewing: true);
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    harness.reconciler.cartId = 'gid://shopify/Cart/other-cart?key=next';
    await harness.cart.reconcileLocalBag(
      scope: const CartSessionScope.guest(shopDomain: 'staging.invalid'),
      localIntent: [
        for (final line in harness.store.bagLines)
          LocalCartIntent(variantId: line.variant.id, quantity: line.quantity),
      ],
    );
    await tester.pumpAndSettle();
    await _tapCartCheckout(tester);

    expect(find.text(kCheckoutDoubleChargeTitle), findsOneWidget);
    expect(find.text('¿Cómo te contactamos?'), findsNothing);
    expect(harness.guard.isActive, isTrue);
  });

  testWidgets('changing the bag quantity keeps the warning', (tester) async {
    final harness = await _BagHarness.create(reviewing: true);
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final variantId = harness.store.bagLines.single.variant.id;
    await harness.store.updateBagQuantity(variantId, 3);
    await tester.pumpAndSettle();

    expect(harness.store.bagQuantity, 3);
    expect(harness.guard.isActive, isTrue);
    await _tapCartCheckout(tester);
    expect(find.text(kCheckoutDoubleChargeTitle), findsOneWidget);
  });

  testWidgets('an empty bag clears the warning', (tester) async {
    final memory = _MemoryWarningStore();
    final guard = ReviewingCheckoutCart(store: memory)..markActive();
    await guard.flush();
    final harness = await _BagHarness.create(guard: guard);
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final product = harness.store.bagLines.single.product;
    await harness.store.removeFromBag(harness.store.bagLines.single.variant.id);
    await tester.pumpAndSettle();
    await guard.flush();

    expect(harness.store.bagQuantity, 0);
    expect(guard.isActive, isFalse);
    expect(memory.record, isNull);

    await harness.store.addToBag(product);
    await tester.pumpAndSettle();
    await _tapCartCheckout(tester);
    expect(find.text(kCheckoutDoubleChargeTitle), findsNothing);
    expect(find.text('¿Cómo te contactamos?'), findsOneWidget);
  });

  testWidgets('a restarted app shows the sheet while the bag is not empty', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final now = DateTime.utc(2026, 10, 15, 15);
    final preferences = await SharedPreferences.getInstance();
    final stored = SharedPreferencesReviewingWarningStore(preferences);
    final writer = ReviewingCheckoutCart(store: stored, clock: () => now)
      ..markActive();
    await writer.flush();
    writer.dispose();

    expect(
      preferences.getKeys(),
      unorderedEquals({
        kCheckoutReviewingWarningFlagKey,
        kCheckoutReviewingWarningAtKey,
      }),
    );
    expect(preferences.getBool(kCheckoutReviewingWarningFlagKey), isTrue);
    expect(
      preferences.getInt(kCheckoutReviewingWarningAtKey),
      now.millisecondsSinceEpoch,
    );
    for (final key in preferences.getKeys()) {
      expect(preferences.get(key), isNot(isA<String>()));
    }

    final harness = await _BagHarness.create();
    addTearDown(harness.dispose);
    await tester.pumpWidget(
      harness.app(
        warningStore: stored,
        clock: () => now,
        restore: true,
      ),
    );
    await tester.pumpAndSettle();
    await _tapCartCheckout(tester);

    expect(find.text(kCheckoutDoubleChargeTitle), findsOneWidget);
    expect(find.text('¿Cómo te contactamos?'), findsNothing);
  });

  testWidgets('a warning older than 24 hours opens checkout directly', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 10, 15, 15);
    final guard = ReviewingCheckoutCart(clock: () => now)..markActive();
    final harness = await _BagHarness.create(guard: guard);
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    now = now.add(kCheckoutReviewingWarningLifetime);
    await _tapCartCheckout(tester);

    expect(find.text(kCheckoutDoubleChargeTitle), findsNothing);
    expect(find.text('¿Cómo te contactamos?'), findsOneWidget);
    expect(guard.isActive, isFalse);
  });

  testWidgets('view orders opens history and does not start checkout', (
    tester,
  ) async {
    final harness = await _BagHarness.create(reviewing: true, signedIn: true);
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    await _tapCartCheckout(tester);
    await tester
        .tap(find.byKey(const ValueKey('checkout-double-charge-orders')));
    await tester.pumpAndSettle();

    expect(find.text('Mis pedidos'), findsWidgets);
    expect(find.text(kCheckoutDoubleChargeTitle), findsNothing);
    expect(find.text('¿Cómo te contactamos?'), findsNothing);
    expect(harness.guard.isActive, isTrue);
  });

  testWidgets('pay anyway continues into checkout and keeps the warning', (
    tester,
  ) async {
    final harness = await _BagHarness.create(reviewing: true);
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    await _tapCartCheckout(tester);
    await tester.tap(find.byKey(const ValueKey('checkout-double-charge-pay')));
    await tester.pumpAndSettle();

    expect(find.text('¿Cómo te contactamos?'), findsOneWidget);
    expect(find.text(kCheckoutDoubleChargeTitle), findsNothing);
    expect(harness.guard.isActive, isTrue);
  });

  testWidgets('an uncertain return stores the banner 3 warning', (
    tester,
  ) async {
    final harness = await _FlowHarness.create();
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      harness.app(
        CheckoutFlowScreen(
          launchSecureCheckout: (_) async => const CheckoutCancelled(),
          orderLookup: _ScriptedLookup((_) async => null),
          orderLookupTimeout: Duration.zero,
          attemptIdentity: const CheckoutAttemptIdentity(cartToken: _cartToken),
        ),
      ),
    );
    await _openReview(tester);
    await tester.tap(find.byKey(const ValueKey('checkout-pay-button')));
    await tester.pumpAndSettle();

    expect(find.text('Estamos revisando tu pago'), findsOneWidget);
    expect(harness.guard.isActive, isTrue);
  });

  testWidgets('a matching order clears banner 3 for the cart', (tester) async {
    final harness = await _FlowHarness.create();
    harness.guard.markActive();
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      harness.app(
        CheckoutFlowScreen(
          launchSecureCheckout: (_) async => const CheckoutCancelled(),
          orderLookup: _ScriptedLookup(
            (_) async =>
                const CheckoutOrderMatch(orderId: 'gid://shopify/Order/5'),
          ),
          attemptIdentity: const CheckoutAttemptIdentity(cartToken: _cartToken),
          onOrderFound: (context, match) async {},
        ),
      ),
    );
    await _openReview(tester);
    await tester.tap(find.byKey(const ValueKey('checkout-pay-button')));
    await tester.pumpAndSettle();

    expect(harness.guard.isActive, isFalse);
  });

  testWidgets('completing checkout clears banner 3 for the cart', (
    tester,
  ) async {
    final harness = await _FlowHarness.create();
    harness.guard.markActive();
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      harness.app(
        CheckoutFlowScreen(
          launchSecureCheckout: (_) async => const CheckoutCompleted(),
          attemptIdentity: const CheckoutAttemptIdentity(cartToken: _cartToken),
        ),
      ),
    );
    await _openReview(tester);
    await tester.tap(find.byKey(const ValueKey('checkout-pay-button')));
    await tester.pumpAndSettle();

    expect(harness.guard.isActive, isFalse);
    expect(find.text('Pago protegido'), findsNothing);
  });

  testWidgets('a capable miss does not clear the double-charge warning', (
    tester,
  ) async {
    final harness = await _FlowHarness.create();
    harness.guard.markActive();
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      harness.app(
        CheckoutFlowScreen(
          launchSecureCheckout: (_) async => const CheckoutCancelled(),
          orderLookup: _ScriptedLookup((_) async => null),
          orderLookupTimeout: Duration.zero,
          correlationAvailable: true,
          attemptIdentity: const CheckoutAttemptIdentity(cartToken: _cartToken),
        ),
      ),
    );
    await _openReview(tester);
    await tester.tap(find.byKey(const ValueKey('checkout-pay-button')));
    await tester.pumpAndSettle();

    expect(find.text('No se completó tu pago'), findsOneWidget);
    expect(harness.guard.isActive, isTrue);
  });
}

Future<void> _tapCartCheckout(WidgetTester tester) async {
  final cta = find.text('Continuar al checkout');
  await tester.ensureVisible(cta);
  await tester.pumpAndSettle();
  await tester.tap(cta);
  await tester.pumpAndSettle();
}

Future<void> _openReview(WidgetTester tester) async {
  await tester.pump();
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'buyer@example.invalid');
  await tester.enterText(fields.at(1), '8112345678');
  await tester.ensureVisible(find.text('REVISAR PEDIDO'));
  await tester.tap(find.text('REVISAR PEDIDO'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const ValueKey('checkout-pay-button')));
}

final class _BagHarness {
  _BagHarness({
    required this.store,
    required this.guard,
    required this.reconciler,
    required this.cart,
    required this.account,
    required this.database,
  });

  final CatalogStore store;
  final ReviewingCheckoutCart guard;
  final _FixedCartReconciler reconciler;
  final CartController cart;
  final AccountController account;
  final AppDatabase database;
  var launches = 0;

  static Future<_BagHarness> create({
    bool reviewing = false,
    bool signedIn = false,
    ReviewingCheckoutCart? guard,
  }) async {
    final database = openTestDatabase();
    final store = CatalogStore(database: database);
    await store.loadFromAsset();
    await store.addToBag(store.products.firstWhere((item) => item.isInStock));
    final account = AccountController(
      accountStore: AccountStore(database),
      deviceStore: DeviceStore(database),
      orderHistoryRepository: OrderHistoryRepository(
        store: OrderSummaryStore(database),
        config: AccountsOrdersConfig.disabled,
      ),
      deviceId: 'device-local',
    );
    if (signedIn) {
      account.account = Account(
        localAccountId: 'account-current',
        authProvider: 'monetta',
        createdAt: DateTime.utc(2026, 8, 27),
        lastSeenAt: DateTime.utc(2026, 8, 27),
      );
    }
    final resolvedGuard = guard ?? ReviewingCheckoutCart();
    if (reviewing) resolvedGuard.markActive();
    final reconciler = _FixedCartReconciler(_cartId);
    return _BagHarness(
      store: store,
      guard: resolvedGuard,
      reconciler: reconciler,
      cart: CartController(reconciler: reconciler),
      account: account,
      database: database,
    );
  }

  Widget app({
    ReviewingWarningStore? warningStore,
    DateTime Function()? clock,
    bool restore = false,
  }) {
    return MaterialApp(
      theme: buildTheme(),
      builder: (context, navigator) => AppRouteScopes(
        accountController: account,
        cartController: cart,
        catalogStore: store,
        reviewingCheckout: restore ? null : guard,
        reviewingWarningStore: warningStore,
        reviewingClock: clock,
        shopDomain: 'staging.invalid',
        child: navigator!,
      ),
      home: StoreScope(
        notifier: store,
        child: BagScreen(
          launchSecureCheckout: (_) async {
            launches += 1;
            return const CheckoutCancelled();
          },
        ),
      ),
    );
  }

  Future<void> dispose() async {
    cart.dispose();
    account.dispose();
    guard.dispose();
    await database.close();
  }
}

final class _FlowHarness {
  _FlowHarness({
    required this.store,
    required this.guard,
    required this.database,
  });

  final CatalogStore store;
  final ReviewingCheckoutCart guard;
  final AppDatabase database;

  static Future<_FlowHarness> create() async {
    final database = openTestDatabase();
    final store = CatalogStore(database: database);
    await store.loadFromAsset();
    await store.addToBag(store.products.firstWhere((item) => item.isInStock));
    return _FlowHarness(
      store: store,
      guard: ReviewingCheckoutCart(),
      database: database,
    );
  }

  Widget app(Widget child) {
    return MaterialApp(
      theme: buildTheme(),
      builder: (context, navigator) => ReviewingCheckoutHost(
        reviewing: guard,
        child: navigator!,
      ),
      home: StoreScope(notifier: store, child: child),
    );
  }

  Future<void> dispose() async {
    guard.dispose();
    await database.close();
  }
}

final class _MemoryWarningStore implements ReviewingWarningStore {
  ReviewingWarningRecord? record;

  @override
  Future<ReviewingWarningRecord?> read() async => record;

  @override
  Future<void> write(ReviewingWarningRecord? record) async {
    this.record = record;
  }
}

final class _FixedCartReconciler implements CartReconciler {
  _FixedCartReconciler(this.cartId);

  String cartId;

  @override
  Future<CartReconciliation> reconcile({
    required CartSessionScope scope,
    required Iterable<LocalCartIntent> localIntent,
    CartBuyerIdentity? buyerIdentity,
    List<String>? desiredDiscountCodes,
  }) async {
    const money = CartMoney(amount: '10.00', currencyCode: 'MXN');
    final timestamp = DateTime.utc(2026, 10, 15);
    final local = localIntent.first;
    return CartReconciliation(
      status: CartReconciliationStatus.authoritative,
      cart: Cart(
        id: cartId,
        checkoutUrl: 'https://checkout.example/c/$_cartToken',
        createdAt: timestamp,
        updatedAt: timestamp,
        lines: [
          CartLine(
            id: 'line-1',
            variantId: local.variantId,
            productId: 'gid://shopify/Product/1',
            title: 'Producto',
            variantTitle: 'Variante',
            quantity: local.quantity,
            cost: const CartLineCost(
              amountPerQuantity: money,
              subtotal: money,
              total: money,
            ),
          ),
        ],
        totalQuantity: local.quantity,
        buyerIdentity: const CartBuyerSummary(
          countryCode: 'MX',
          isAuthenticated: false,
        ),
        cost: const CartCost(subtotal: money, total: money),
      ),
    );
  }
}

final class _ScriptedLookup implements CheckoutOrderLookup {
  _ScriptedLookup(this._handle);

  final Future<CheckoutOrderMatch?> Function(CheckoutAttemptIdentity attempt)
      _handle;

  @override
  Future<CheckoutOrderMatch?> findOrder(CheckoutAttemptIdentity attempt) {
    return _handle(attempt);
  }
}
