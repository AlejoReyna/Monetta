import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/cart_controller.dart';
import 'package:monetta_app/data/shopify/cart/cart_api.dart';
import 'package:monetta_app/data/shopify/cart/cart_repository.dart';
import 'package:monetta_app/data/shopify/cart/cart_session_store.dart';
import 'package:monetta_app/data/shopify/shopify_gid.dart';
import 'package:monetta_app/domain/cart.dart';

void main() {
  const accountA = CartSessionScope.authenticated(
    shopDomain: 'staging.invalid',
    localAccountId: 'account-a',
  );
  const accountB = CartSessionScope.authenticated(
    shopDomain: 'staging.invalid',
    localAccountId: 'account-b',
  );

  test('publishes one final coherent snapshot for its scope', () async {
    final expected = _result('guest');
    final controller =
        CartController(reconciler: _ImmediateReconciler(expected));
    final states = <CartControllerStatus>[];
    final snapshots = <CartReconciliation?>[];
    controller.addListener(() {
      states.add(controller.status);
      snapshots.add(controller.snapshot);
    });
    const guest = CartSessionScope.guest(shopDomain: 'staging.invalid');

    await controller.reconcileLocalBag(scope: guest, localIntent: const []);

    expect(states, [CartControllerStatus.syncing, CartControllerStatus.ready]);
    expect(snapshots, [null, expected]);
    expect(controller.currentScope, guest);
    expect(controller.scopedSnapshot?.scope, guest);
  });

  test('slow account A cannot replace faster account B', () async {
    final reconciler = _DeferredReconciler();
    final controller = CartController(reconciler: reconciler);

    final slowA = controller.reconcileLocalBag(
      scope: accountA,
      localIntent: const [],
    );
    final fastB = controller.reconcileLocalBag(
      scope: accountB,
      localIntent: const [],
    );
    reconciler.complete(accountB, _result('b'));
    await fastB;

    expect(controller.currentScope, accountB);
    expect(controller.scopedSnapshot?.scope, accountB);
    expect(controller.snapshot?.cart?.id, _opaque('cart-b'));

    reconciler.complete(accountA, _result('a'));
    await slowA;

    expect(controller.currentScope, accountB);
    expect(controller.scopedSnapshot?.scope, accountB);
    expect(controller.snapshot?.cart?.id, _opaque('cart-b'));
  });

  test('failed account B cannot retain successful account A cart', () async {
    final reconciler = _DeferredReconciler();
    final controller = CartController(reconciler: reconciler);

    final first = controller.reconcileLocalBag(
      scope: accountA,
      localIntent: const [],
    );
    reconciler.complete(accountA, _result('a'));
    await first;
    expect(controller.snapshot?.cart?.id, _opaque('cart-a'));

    final failed = controller.reconcileLocalBag(
      scope: accountB,
      localIntent: const [],
    );
    expect(controller.currentScope, accountB);
    expect(controller.snapshot, isNull, reason: 'scope change clears A now');
    reconciler.fail(accountB);
    await failed;

    expect(controller.status, CartControllerStatus.error);
    expect(controller.currentScope, accountB);
    expect(controller.scopedSnapshot, isNull);
    expect(controller.snapshot, isNull);
  });

  test('terminal notifications belong only to the current request', () async {
    final reconciler = _DeferredReconciler();
    final controller = CartController(reconciler: reconciler);
    final terminalScopes = <CartSessionScope?>[];
    controller.addListener(() {
      if (controller.status != CartControllerStatus.syncing) {
        terminalScopes.add(controller.scopedSnapshot?.scope);
      }
    });

    final slowA = controller.reconcileLocalBag(
      scope: accountA,
      localIntent: const [],
    );
    final fastB = controller.reconcileLocalBag(
      scope: accountB,
      localIntent: const [],
    );
    reconciler.complete(accountB, _result('b'));
    await fastB;
    reconciler.complete(accountA, _result('a'));
    await slowA;

    expect(terminalScopes, [accountB]);
  });
}

final class _ImmediateReconciler implements CartReconciler {
  const _ImmediateReconciler(this.result);

  final CartReconciliation result;

  @override
  Future<CartReconciliation> reconcile({
    required CartSessionScope scope,
    required Iterable<LocalCartIntent> localIntent,
    CartBuyerIdentity? buyerIdentity,
    List<String>? desiredDiscountCodes,
  }) async =>
      result;
}

final class _DeferredReconciler implements CartReconciler {
  final Map<CartSessionScope, Completer<CartReconciliation>> _requests = {};

  void complete(CartSessionScope scope, CartReconciliation result) =>
      _requests[scope]!.complete(result);

  void fail(CartSessionScope scope) =>
      _requests[scope]!.completeError(Exception('synthetic failure'));

  @override
  Future<CartReconciliation> reconcile({
    required CartSessionScope scope,
    required Iterable<LocalCartIntent> localIntent,
    CartBuyerIdentity? buyerIdentity,
    List<String>? desiredDiscountCodes,
  }) {
    final request = Completer<CartReconciliation>();
    _requests[scope] = request;
    return request.future;
  }
}

CartReconciliation _result(String suffix) => CartReconciliation(
      status: CartReconciliationStatus.authoritative,
      cart: _cart(suffix),
    );

Cart _cart(String suffix) {
  const money = CartMoney(amount: '0.00', currencyCode: 'MXN');
  final timestamp = DateTime.utc(2026, 8, 27);
  return Cart(
    id: _opaque('cart-$suffix'),
    checkoutUrl: Uri(path: _opaque('checkout-$suffix')).toString(),
    createdAt: timestamp,
    updatedAt: timestamp,
    lines: [
      CartLine(
        id: _opaque('line-$suffix'),
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
