/// Bag survival across the payment-demo steps.
///
/// Each test names the production step it reproduces and whether the bag
/// stays. Checkout completion still subtracts only inside the receipt
/// transaction (`BagStore.applyPurchase`).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/cart_controller.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/shopify_checkout_coordinator.dart';
import 'package:monetta_app/data/local/bag_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/shopify/cart/cart_api.dart';
import 'package:monetta_app/data/shopify/cart/cart_repository.dart';
import 'package:monetta_app/data/shopify/cart/cart_session_store.dart';
import 'package:monetta_app/data/shopify/cart/checkout_launcher.dart';
import 'package:monetta_app/data/shopify/cart/storefront_password_gate.dart';
import 'package:monetta_app/data/shopify/shopify_gid.dart';
import 'package:monetta_app/domain/cart.dart';

import '../support/shopify_cart_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const shop = 'monetta-staging.myshopify.com';
  final variant = shopifyVariantGid(1);
  final localIntent = [LocalCartIntent(variantId: variant, quantity: 1)];
  const scope = CartSessionScope.guest(shopDomain: shop);

  test(
      'login keeps the guest bag; logout hides it until the same account returns',
      () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final store = CatalogStore(database: db, shopDomain: shop);
    await store.loadFromAsset();
    final product = store.products.firstWhere((item) => item.isInStock);
    final variantId = product.variants.firstWhere((item) => item.available).id;
    await store.addToBag(product, variantId: variantId);
    final quantity = store.bagQuantity;

    // CustomerSessionRepository._persistLogin merges before
    // AccountController.login publishes the scope.
    await BagStore(db).mergeDeviceItemsIntoAccount('acct-a');
    await store.setAccountScope('acct-a');

    expect(store.bagQuantity, quantity);
    expect(
      (await BagStore(db).all(accountId: 'acct-a')).single.variantId,
      variantId,
    );
    expect(await BagStore(db).all(), isEmpty);

    // Logout publishes a null scope. The account rows stay isolated.
    await store.setAccountScope(null);
    expect(store.bagQuantity, 0);
    expect(
      (await BagStore(db).all(accountId: 'acct-a')).single.quantity,
      quantity,
    );

    await store.setAccountScope('acct-a');
    expect(store.bagQuantity, quantity);
  });

  test('restart keeps the bag for the same shop, including a signed-in scope',
      () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final first = CatalogStore(database: db, shopDomain: shop);
    await first.loadFromAsset();
    final product = first.products.firstWhere((item) => item.isInStock);
    final variantId = product.variants.firstWhere((item) => item.available).id;
    await first.addToBag(product, variantId: variantId);
    await first.setAccountScope('acct-a');
    await first.addToBag(product, variantId: variantId);
    final guestQuantity = (await BagStore(db).all()).single.quantity;
    final accountQuantity =
        (await BagStore(db).all(accountId: 'acct-a')).single.quantity;

    final restarted = CatalogStore(database: db, shopDomain: shop);
    await restarted.loadFromAsset();
    expect(restarted.bagQuantity, guestQuantity);

    // AccountController.restore publishes the scope after the catalog loads.
    await restarted.setAccountScope('acct-a');
    expect(restarted.bagQuantity, accountQuantity);
  });

  test('password warning, cancel and failure keep the bag and the cart session',
      () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final bags = BagStore(db);
    await bags.upsert(
      productId: shopifyProductGid(1),
      variantId: variant,
      quantity: 2,
    );
    final sessions = InMemoryCartSessionStore();
    final cartId = SensitiveCartId(_opaque('cart-session'));
    await sessions.write(scope, cartId);

    Future<void> present(CheckoutResult terminal, {bool password = false}) =>
        _present(
          sessions: sessions,
          localIntent: localIntent,
          scope: scope,
          terminal: terminal,
          password: password,
          onCompleted: (_) async => fail('bag must stay'),
        );

    await present(const CheckoutCancelled(), password: true);
    await present(const CheckoutCancelled());
    await present(
      const CheckoutFailed(
        code: CheckoutFailureCode.unavailable,
        userMessage: 'Fallo seguro.',
      ),
    );

    expect((await bags.all()).single.quantity, 2);
    expect(await db.select(db.checkoutReceipts).get(), isEmpty);
    expect(await sessions.read(scope), cartId);
  });

  test('completed checkout subtracts with the receipt and leaves other units',
      () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final bags = BagStore(db);
    await bags.upsert(
      productId: shopifyProductGid(1),
      variantId: variant,
      quantity: 2,
    );
    final sessions = InMemoryCartSessionStore();
    await sessions.write(scope, SensitiveCartId(_opaque('cart-session')));

    final result = await _present(
      sessions: sessions,
      localIntent: localIntent,
      scope: scope,
      terminal: const CheckoutCompleted(),
      onCompleted: (purchase) => bags.applyPurchase(
        operationId: purchase.operationId,
        shopDomain: purchase.scope.shopDomain,
        accountId: purchase.scope.buyerKey,
        quantities: purchase.quantities,
      ),
    );

    expect(result, isA<CheckoutCompleted>());
    expect((await bags.all()).single.quantity, 1);
    expect(
      (await db.select(db.checkoutReceipts).get()).single.operationId,
      isNotEmpty,
    );
    expect(await sessions.read(scope), isNull);

    // The receipt makes a second completion a no-op for the same cart.
    await bags.applyPurchase(
      operationId:
          (await db.select(db.checkoutReceipts).get()).single.operationId,
      shopDomain: shop,
      accountId: null,
      quantities: {variant: 1},
    );
    expect((await bags.all()).single.quantity, 1);
  });
}

Future<CheckoutResult> _present({
  required CartSessionStore sessions,
  required List<LocalCartIntent> localIntent,
  required CartSessionScope scope,
  required CheckoutResult terminal,
  required CheckoutCompletion onCompleted,
  bool password = false,
}) async {
  final launcher = _RecordingLauncher(terminal);
  final coordinator = ShopifyCheckoutCoordinator(
    launcher: launcher,
    urlPolicy: CheckoutUrlPolicy.forShopDomain(scope.shopDomain),
    sessions: sessions,
    passwordProbe: password
        ? _FixedPasswordProbe(StorefrontPasswordGate.passwordProtected)
        : null,
  );
  final result = await coordinator.present(
    controller: CartController(
      reconciler: _FixedReconciler(_authoritativeCart(scope.shopDomain)),
    ),
    scope: scope,
    localIntent: localIntent,
    onCompleted: onCompleted,
  );
  expect(launcher.presentCalls, password ? 0 : 1);
  return result;
}

CartReconciliation _authoritativeCart(String shop) {
  final timestamp = DateTime.utc(2026, 8, 27);
  const money = CartMoney(amount: '10.00', currencyCode: 'MXN');
  return CartReconciliation(
    status: CartReconciliationStatus.authoritative,
    cart: Cart(
      id: _opaque('cart'),
      checkoutUrl: Uri(
        scheme: 'https',
        host: shop,
        path: '/cart/c/opaque',
        queryParameters: const {'key': 'redacted-fixture'},
      ).toString(),
      createdAt: timestamp,
      updatedAt: timestamp,
      lines: [
        CartLine(
          id: _opaque('line'),
          variantId: shopifyVariantGid(1),
          productId: shopifyProductGid(1),
          title: 'Producto',
          variantTitle: 'Variante',
          quantity: 1,
          cost: const CartLineCost(
            amountPerQuantity: money,
            subtotal: money,
            total: money,
          ),
        ),
      ],
      totalQuantity: 1,
      buyerIdentity: const CartBuyerSummary(
        countryCode: 'MX',
        isAuthenticated: false,
      ),
      cost: const CartCost(subtotal: money, total: money),
    ),
  );
}

String _opaque(String suffix) => String.fromCharCodes([
      111,
      112,
      97,
      113,
      117,
      101,
      ...suffix.codeUnits,
    ]);

final class _FixedReconciler implements CartReconciler {
  _FixedReconciler(this._response);

  final CartReconciliation _response;

  @override
  Future<CartReconciliation> reconcile({
    required CartSessionScope scope,
    required Iterable<LocalCartIntent> localIntent,
    CartBuyerIdentity? buyerIdentity,
    List<String>? desiredDiscountCodes,
  }) async =>
      _response;
}

final class _RecordingLauncher implements CheckoutLauncher {
  _RecordingLauncher(this.result);

  final CheckoutResult result;
  int presentCalls = 0;

  @override
  Future<void> preload(ValidatedCheckoutUrl checkoutUrl) async {}

  @override
  Future<CheckoutResult> present(ValidatedCheckoutUrl checkoutUrl) async {
    presentCalls += 1;
    return result;
  }

  @override
  Future<void> invalidate() async {}
}

final class _FixedPasswordProbe implements StorefrontPasswordProbe {
  _FixedPasswordProbe(this.gate);

  final StorefrontPasswordGate gate;

  @override
  Future<StorefrontPasswordGate> checkHost(String host) async => gate;
}
