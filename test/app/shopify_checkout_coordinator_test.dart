import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/cart_controller.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/bag_store.dart';
import 'package:monetta_app/app/shopify_checkout_coordinator.dart';
import 'package:monetta_app/data/shopify/cart/cart_api.dart';
import 'package:monetta_app/data/shopify/cart/cart_repository.dart';
import 'package:monetta_app/data/shopify/cart/cart_session_store.dart';
import 'package:monetta_app/data/shopify/cart/checkout_launcher.dart';
import 'package:monetta_app/data/shopify/cart/storefront_password_gate.dart';
import 'package:monetta_app/data/shopify/shopify_gid.dart';
import 'package:monetta_app/domain/cart.dart';

import '../support/shopify_cart_fakes.dart';

void main() {
  const scope = CartSessionScope.guest(shopDomain: 'checkout.invalid');
  final localIntent = [
    LocalCartIntent(variantId: shopifyVariantGid(1), quantity: 1),
  ];

  test(
      'R5 delayed native completion retains A scope and retries failed persistence without reopening',
      () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final bags = BagStore(db);
    final variant = shopifyVariantGid(1);
    await bags.upsert(
      productId: shopifyProductGid(1),
      variantId: variant,
      quantity: 2,
      accountId: 'A',
    );
    await bags.upsert(
      productId: shopifyProductGid(1),
      variantId: variant,
      quantity: 3,
      accountId: 'B',
    );
    final launcher = _DelayedLauncher();
    final coordinator = _coordinator(launcher, InMemoryCartSessionStore());
    final controller =
        CartController(reconciler: _CheckoutReconciler(_authoritativeCart()));
    const a = CartSessionScope.authenticated(
      shopDomain: 'checkout.invalid',
      localAccountId: 'A',
    );
    var activeAccount = 'A';
    var failPersistence = true;
    final first = coordinator.present(
      controller: controller,
      scope: a,
      localIntent: localIntent,
      onCompleted: (purchase) async {
        expect(activeAccount, 'B');
        expect(purchase.scope, a);
        if (failPersistence) throw Exception('storage temporarily unavailable');
        await bags.applyPurchase(
          operationId: purchase.operationId,
          shopDomain: purchase.scope.shopDomain,
          accountId: purchase.scope.buyerKey,
          quantities: purchase.quantities,
        );
      },
    );
    await launcher.entered.future;
    activeAccount = 'B';
    launcher.result.complete(const CheckoutCompleted());
    expect(await first, isA<CheckoutFailed>());
    expect((await bags.all(accountId: 'A')).single.quantity, 2);
    failPersistence = false;
    final retry = await coordinator.present(
      controller: controller,
      scope: const CartSessionScope.authenticated(
        shopDomain: 'checkout.invalid',
        localAccountId: 'B',
      ),
      localIntent: localIntent,
      onCompleted: (_) async => fail('Must use original captured callback'),
    );
    expect(retry, isA<CheckoutFailed>());
    expect((retry as CheckoutFailed).userMessage, contains('otra cuenta'));
    expect(launcher.presentCalls, 1);
    expect((await bags.all(accountId: 'A')).single.quantity, 1);
    expect((await bags.all(accountId: 'B')).single.quantity, 3);
  });

  test('refreshes immediately before present and completes cleanup once',
      () async {
    final reconciler = _CheckoutReconciler(_authoritativeCart());
    final controller = CartController(reconciler: reconciler);
    final launcher = _RecordingLauncher(const CheckoutCompleted());
    final sessions = InMemoryCartSessionStore();
    await sessions.write(scope, SensitiveCartId(_opaque('cart-session')));
    var cleanupCalls = 0;
    Set<String>? purchasedIds;
    final coordinator = _coordinator(launcher, sessions);

    final result = await coordinator.present(
      controller: controller,
      scope: scope,
      localIntent: localIntent,
      onCompleted: (ids) async {
        cleanupCalls += 1;
        purchasedIds = ids.quantities.keys.toSet();
      },
    );

    expect(result, isA<CheckoutCompleted>());
    expect(reconciler.calls, 1);
    expect(launcher.presentCalls, 1);
    expect(launcher.invalidateCalls, 1);
    expect(cleanupCalls, 1);
    expect(purchasedIds, {shopifyVariantGid(1)});
    expect(await sessions.read(scope), isNull);
  });

  test('cancel and failure preserve bag callback and cart session', () async {
    for (final terminal in <CheckoutResult>[
      const CheckoutCancelled(),
      const CheckoutFailed(
        code: CheckoutFailureCode.unavailable,
        userMessage: 'Fallo seguro.',
      ),
    ]) {
      final controller = CartController(
        reconciler: _CheckoutReconciler(_authoritativeCart()),
      );
      final sessions = InMemoryCartSessionStore();
      await sessions.write(scope, SensitiveCartId(_opaque('cart-session')));
      var cleanupCalls = 0;

      final result = await _coordinator(
        _RecordingLauncher(terminal),
        sessions,
      ).present(
        controller: controller,
        scope: scope,
        localIntent: localIntent,
        onCompleted: (_) async => cleanupCalls += 1,
      );

      expect(result.runtimeType, terminal.runtimeType);
      expect(cleanupCalls, 0);
      expect(await sessions.read(scope), isNotNull);
    }
  });

  test('double tap allows one reconciliation, presentation and terminal effect',
      () async {
    final reconciliation = Completer<CartReconciliation>();
    final reconciler = _CheckoutReconciler.delayed(reconciliation.future);
    final controller = CartController(reconciler: reconciler);
    final launcher = _RecordingLauncher(const CheckoutCompleted());
    final sessions = InMemoryCartSessionStore();
    var cleanupCalls = 0;
    final coordinator = _coordinator(launcher, sessions);

    final first = coordinator.present(
      controller: controller,
      scope: scope,
      localIntent: localIntent,
      onCompleted: (_) async => cleanupCalls += 1,
    );
    final duplicate = await coordinator.present(
      controller: controller,
      scope: scope,
      localIntent: localIntent,
      onCompleted: (_) async => cleanupCalls += 1,
    ) as CheckoutFailed;
    reconciliation.complete(_authoritativeCart());

    expect(await first, isA<CheckoutCompleted>());
    expect(duplicate.code, CheckoutFailureCode.unavailable);
    expect(reconciler.calls, 1);
    expect(launcher.presentCalls, 1);
    expect(cleanupCalls, 1);
  });

  test('password-protected storefront never opens checkout or the browser',
      () async {
    final launcher = _RecordingLauncher(const CheckoutCancelled());
    final opener = _RecordingExternalOpener();
    final probe = _FixedPasswordProbe(StorefrontPasswordGate.passwordProtected);
    final coordinator = ShopifyCheckoutCoordinator(
      launcher: launcher,
      urlPolicy: CheckoutUrlPolicy.forShopDomain('checkout.invalid'),
      sessions: InMemoryCartSessionStore(),
      externalOpener: opener,
      passwordProbe: probe,
    );

    await coordinator.preload(_authoritativeCart());
    final result = await coordinator.present(
      controller: CartController(
        reconciler: _CheckoutReconciler(_authoritativeCart()),
      ),
      scope: scope,
      localIntent: localIntent,
      onCompleted: (_) async => fail('Checkout was not opened'),
    ) as CheckoutFailed;

    expect(result.code, CheckoutFailureCode.configuration);
    expect(result.userMessage, kStorefrontPasswordCheckoutMessage);
    expect(result.allowExternalBrowser, isFalse);
    expect(probe.hosts, ['checkout.invalid', 'checkout.invalid']);
    expect(probe.hosts.every((host) => !host.contains('/')), isTrue);
    expect(launcher.presentCalls, 0);
    expect(launcher.preloadCalls, 0);
    expect(launcher.invalidateCalls, 2);
    expect(coordinator.canOpenExternalFallback, isFalse);
    expect(await coordinator.openExternalFallback(), isFalse);
    expect(opener.calls, 0);
  });

  test('an inconclusive password probe still presents checkout', () async {
    final launcher = _RecordingLauncher(const CheckoutCancelled());
    final coordinator = ShopifyCheckoutCoordinator(
      launcher: launcher,
      urlPolicy: CheckoutUrlPolicy.forShopDomain('checkout.invalid'),
      sessions: InMemoryCartSessionStore(),
      passwordProbe: _FixedPasswordProbe(StorefrontPasswordGate.unknown),
    );

    final result = await coordinator.present(
      controller: CartController(
        reconciler: _CheckoutReconciler(_authoritativeCart()),
      ),
      scope: scope,
      localIntent: localIntent,
      onCompleted: (_) async {},
    );

    expect(result, isA<CheckoutCancelled>());
    expect(launcher.presentCalls, 1);
  });

  test('an empty authoritative cart never opens its checkout URL', () async {
    final launcher = _RecordingLauncher(const CheckoutCancelled());
    final opener = _RecordingExternalOpener();
    final probe = _FixedPasswordProbe(StorefrontPasswordGate.open);
    final coordinator = ShopifyCheckoutCoordinator(
      launcher: launcher,
      urlPolicy: CheckoutUrlPolicy.forShopDomain('checkout.invalid'),
      sessions: InMemoryCartSessionStore(),
      externalOpener: opener,
      passwordProbe: probe,
    );

    final result = await coordinator.present(
      controller: CartController(
        reconciler: _CheckoutReconciler(_authoritativeCart(empty: true)),
      ),
      scope: scope,
      localIntent: localIntent,
      onCompleted: (_) async => fail('Checkout was not opened'),
    ) as CheckoutFailed;

    expect(result.code, CheckoutFailureCode.configuration);
    expect(result.userMessage, kEmptyCartCheckoutMessage);
    expect(result.allowExternalBrowser, isFalse);
    expect(probe.hosts, isEmpty);
    expect(launcher.presentCalls, 0);
    expect(coordinator.canOpenExternalFallback, isFalse);
  });

  test('invalid or non-authoritative checkout never reaches native', () async {
    final invalid = _authoritativeCart(checkoutUrl: 'not-a-checkout');
    final launcher = _RecordingLauncher(const CheckoutCancelled());
    final result = await _coordinator(
      launcher,
      InMemoryCartSessionStore(),
    ).present(
      controller: CartController(reconciler: _CheckoutReconciler(invalid)),
      scope: scope,
      localIntent: localIntent,
      onCompleted: (_) async {},
    );

    expect(result, isA<CheckoutFailed>());
    expect(launcher.presentCalls, 0);
  });

  test('external fallback is explicit and never marks completion', () async {
    final launcher = _RecordingLauncher(
      const CheckoutFailed(
        code: CheckoutFailureCode.unavailable,
        userMessage: 'Fallo seguro.',
      ),
    );
    final opener = _RecordingExternalOpener();
    final coordinator = ShopifyCheckoutCoordinator(
      launcher: launcher,
      urlPolicy: CheckoutUrlPolicy.forShopDomain('checkout.invalid'),
      sessions: InMemoryCartSessionStore(),
      externalOpener: opener,
    );
    final controller = CartController(
      reconciler: _CheckoutReconciler(_authoritativeCart()),
    );
    var cleanupCalls = 0;

    await coordinator.present(
      controller: controller,
      scope: scope,
      localIntent: localIntent,
      onCompleted: (_) async => cleanupCalls += 1,
    );

    expect(opener.calls, 0);
    expect(await coordinator.openExternalFallback(), isTrue);
    expect(opener.calls, 1);
    expect(cleanupCalls, 0);
  });

  test('preload validates an authoritative URL without presenting', () async {
    final launcher = _RecordingLauncher(const CheckoutCancelled());
    final coordinator = _coordinator(launcher, InMemoryCartSessionStore());

    await coordinator.preload(_authoritativeCart());

    expect(launcher.preloadCalls, 1);
    expect(launcher.presentCalls, 0);
    expect(coordinator.canOpenExternalFallback, isFalse);
  });

  test('present preloads only the freshly reconciled checkout URL', () async {
    final launcher = _RecordingLauncher(const CheckoutCancelled());
    final coordinator = _coordinator(launcher, InMemoryCartSessionStore());

    final result = await coordinator.present(
      controller: CartController(
        reconciler: _CheckoutReconciler(_authoritativeCart()),
      ),
      scope: scope,
      localIntent: localIntent,
      onCompleted: (_) async {},
    );

    expect(result, isA<CheckoutCancelled>());
    expect(launcher.preloadCalls, 1);
    expect(launcher.presentCalls, 1);
    expect(launcher.events, ['preload', 'present']);
  });

  test('a non-authoritative refresh clears any stale fallback URL', () async {
    final opener = _RecordingExternalOpener();
    final launcher = _RecordingLauncher(const CheckoutCancelled());
    final coordinator = ShopifyCheckoutCoordinator(
      launcher: launcher,
      urlPolicy: CheckoutUrlPolicy.forShopDomain('checkout.invalid'),
      sessions: InMemoryCartSessionStore(),
      externalOpener: opener,
    );
    await coordinator.preload(_authoritativeCart());

    final partial = CartReconciliation(
      status: CartReconciliationStatus.partiallyConfirmed,
      cart: _authoritativeCart().cart,
    );
    final result = await coordinator.present(
      controller: CartController(reconciler: _CheckoutReconciler(partial)),
      scope: scope,
      localIntent: localIntent,
      onCompleted: (_) async {},
    );

    expect(result, isA<CheckoutFailed>());
    expect(launcher.presentCalls, 0);
    expect(coordinator.canOpenExternalFallback, isFalse);
    expect(await coordinator.openExternalFallback(), isFalse);
    expect(opener.calls, 0);
  });

  test('external fallback rejects concurrent opens', () async {
    final opener = _BlockingExternalOpener();
    final coordinator = ShopifyCheckoutCoordinator(
      launcher: _RecordingLauncher(const CheckoutCancelled()),
      urlPolicy: CheckoutUrlPolicy.forShopDomain('checkout.invalid'),
      sessions: InMemoryCartSessionStore(),
      externalOpener: opener,
    );
    await coordinator.preload(_authoritativeCart());

    final first = coordinator.openExternalFallback();
    await Future<void>.delayed(Duration.zero);
    expect(await coordinator.openExternalFallback(), isFalse);
    opener.release();

    expect(await first, isTrue);
    expect(opener.calls, 1);
  });

  test('native present rejects while external fallback is opening', () async {
    final opener = _BlockingExternalOpener();
    final launcher = _RecordingLauncher(const CheckoutCancelled());
    final coordinator = ShopifyCheckoutCoordinator(
      launcher: launcher,
      urlPolicy: CheckoutUrlPolicy.forShopDomain('checkout.invalid'),
      sessions: InMemoryCartSessionStore(),
      externalOpener: opener,
    );
    await coordinator.preload(_authoritativeCart());

    final fallback = coordinator.openExternalFallback();
    await Future<void>.delayed(Duration.zero);
    final result = await coordinator.present(
      controller: CartController(
        reconciler: _CheckoutReconciler(_authoritativeCart()),
      ),
      scope: scope,
      localIntent: localIntent,
      onCompleted: (_) async {},
    ) as CheckoutFailed;

    expect(result.code, CheckoutFailureCode.unavailable);
    expect(launcher.presentCalls, 0);
    opener.release();
    expect(await fallback, isTrue);
  });
}

ShopifyCheckoutCoordinator _coordinator(
  CheckoutLauncher launcher,
  CartSessionStore sessions,
) =>
    ShopifyCheckoutCoordinator(
      launcher: launcher,
      urlPolicy: CheckoutUrlPolicy.forShopDomain('checkout.invalid'),
      sessions: sessions,
    );

CartReconciliation _authoritativeCart({
  String? checkoutUrl,
  bool empty = false,
}) {
  final timestamp = DateTime.utc(2026, 8, 27);
  const money = CartMoney(amount: '10.00', currencyCode: 'MXN');
  return CartReconciliation(
    status: CartReconciliationStatus.authoritative,
    cart: Cart(
      id: _opaque('cart'),
      checkoutUrl: checkoutUrl ??
          Uri(
            scheme: 'https',
            host: 'checkout.invalid',
            path: '/opaque',
            queryParameters: const {'key': 'redacted-fixture'},
          ).toString(),
      createdAt: timestamp,
      updatedAt: timestamp,
      lines: empty
          ? const <CartLine>[]
          : [
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
      totalQuantity: empty ? 0 : 1,
      buyerIdentity: const CartBuyerSummary(
        countryCode: 'MX',
        isAuthenticated: false,
      ),
      cost: const CartCost(subtotal: money, total: money),
    ),
  );
}

final class _CheckoutReconciler implements CartReconciler {
  _CheckoutReconciler(CartReconciliation response)
      : _response = Future.value(response);

  _CheckoutReconciler.delayed(this._response);

  final Future<CartReconciliation> _response;
  int calls = 0;

  @override
  Future<CartReconciliation> reconcile({
    required CartSessionScope scope,
    required Iterable<LocalCartIntent> localIntent,
    CartBuyerIdentity? buyerIdentity,
    List<String>? desiredDiscountCodes,
  }) {
    calls += 1;
    return _response;
  }
}

final class _RecordingLauncher implements CheckoutLauncher {
  _RecordingLauncher(this.result);

  final CheckoutResult result;
  final List<String> events = [];
  int preloadCalls = 0;
  int presentCalls = 0;
  int invalidateCalls = 0;

  @override
  Future<void> preload(ValidatedCheckoutUrl checkoutUrl) async {
    events.add('preload');
    preloadCalls += 1;
  }

  @override
  Future<CheckoutResult> present(ValidatedCheckoutUrl checkoutUrl) async {
    events.add('present');
    presentCalls += 1;
    return result;
  }

  @override
  Future<void> invalidate() async {
    invalidateCalls += 1;
  }
}

final class _FixedPasswordProbe implements StorefrontPasswordProbe {
  _FixedPasswordProbe(this.gate);

  final StorefrontPasswordGate gate;
  final List<String> hosts = [];

  @override
  Future<StorefrontPasswordGate> checkHost(String host) async {
    hosts.add(host);
    return gate;
  }
}

final class _RecordingExternalOpener implements ExternalCheckoutOpener {
  int calls = 0;

  @override
  Future<bool> open(ValidatedCheckoutUrl checkoutUrl) async {
    calls += 1;
    return true;
  }
}

final class _BlockingExternalOpener implements ExternalCheckoutOpener {
  final Completer<void> _release = Completer<void>();
  int calls = 0;

  @override
  Future<bool> open(ValidatedCheckoutUrl checkoutUrl) async {
    calls += 1;
    await _release.future;
    return true;
  }

  void release() => _release.complete();
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

final class _DelayedLauncher implements CheckoutLauncher {
  final entered = Completer<void>();
  final result = Completer<CheckoutResult>();
  int presentCalls = 0;
  @override
  Future<void> preload(ValidatedCheckoutUrl url) async {}
  @override
  Future<void> invalidate() async {}
  @override
  Future<CheckoutResult> present(ValidatedCheckoutUrl url) {
    presentCalls++;
    entered.complete();
    return result.future;
  }
}
