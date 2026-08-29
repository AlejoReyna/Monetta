import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/cart_controller.dart';
import 'package:monetta_app/data/shopify/cart/cart_api.dart';
import 'package:monetta_app/data/shopify/cart/cart_repository.dart';
import 'package:monetta_app/data/shopify/cart/cart_session_store.dart';
import 'package:monetta_app/data/shopify/shopify_gid.dart';
import 'package:monetta_app/domain/cart.dart';

void main() {
  const guest = CartSessionScope.guest(shopDomain: 'staging.invalid');
  final intent = [
    LocalCartIntent(variantId: shopifyVariantGid(9), quantity: 1),
  ];

  test('distinguishes applicable, non-applicable and invalid codes', () async {
    final reconciler = _DiscountReconciler();
    final controller = CartController(reconciler: reconciler);

    await controller.replaceDiscountCodes(
      scope: guest,
      localIntent: intent,
      discountCodes: const ['SAVE'],
    );
    expect(controller.discountStatus, CartDiscountUpdateStatus.applied);
    expect(controller.requestedDiscountCodes, ['SAVE']);

    await controller.replaceDiscountCodes(
      scope: guest,
      localIntent: intent,
      discountCodes: const ['NOT_APPLICABLE'],
    );
    expect(
      controller.discountStatus,
      CartDiscountUpdateStatus.notApplicable,
    );

    await controller.replaceDiscountCodes(
      scope: guest,
      localIntent: intent,
      discountCodes: const ['INVALID'],
    );
    expect(controller.discountStatus, CartDiscountUpdateStatus.invalid);
    expect(controller.discountMessage, isNot(contains(_opaque('cart'))));
  });

  test('apply/remove always sends the complete normalized set', () async {
    final reconciler = _DiscountReconciler();
    final controller = CartController(reconciler: reconciler);

    await controller.replaceDiscountCodes(
      scope: guest,
      localIntent: intent,
      discountCodes: const ['first', 'SECOND'],
    );
    await controller.removeDiscountCode(
      scope: guest,
      localIntent: intent,
      code: 'FIRST',
    );

    expect(reconciler.desiredSets, [
      ['FIRST', 'SECOND'],
      ['SECOND'],
    ]);
    expect(controller.requestedDiscountCodes, ['SECOND']);

    await controller.removeDiscountCode(
      scope: guest,
      localIntent: intent,
      code: 'SECOND',
    );
    expect(reconciler.desiredSets.last, isEmpty);
    expect(controller.discountStatus, CartDiscountUpdateStatus.removed);
  });

  test('removal is successful only when Shopify confirms an empty set',
      () async {
    final controller = CartController(
      reconciler: _RemovalReconciler(_RemovalOutcome.confirmed),
    );
    await controller.replaceDiscountCodes(
      scope: guest,
      localIntent: intent,
      discountCodes: const ['KEEP'],
    );
    await controller.replaceDiscountCodes(
      scope: guest,
      localIntent: intent,
      discountCodes: const [],
    );

    expect(controller.discountStatus, CartDiscountUpdateStatus.removed);
    expect(controller.snapshot?.cart?.discountCodes, isEmpty);
  });

  test('removal userError keeps previous cart and reports unconfirmed',
      () async {
    final controller = CartController(
      reconciler: _RemovalReconciler(_RemovalOutcome.userError),
    );
    await controller.replaceDiscountCodes(
      scope: guest,
      localIntent: intent,
      discountCodes: const ['KEEP'],
    );
    await controller.replaceDiscountCodes(
      scope: guest,
      localIntent: intent,
      discountCodes: const [],
    );

    expect(controller.discountStatus, CartDiscountUpdateStatus.error);
    expect(controller.discountMessage, isNot(contains('eliminado')));
    expect(controller.snapshot?.cart?.discountCodes.single.code, 'KEEP');
  });

  test('ambiguous removal read that retains code is not successful', () async {
    final controller = CartController(
      reconciler: _RemovalReconciler(_RemovalOutcome.recoveredWithCode),
    );
    await controller.replaceDiscountCodes(
      scope: guest,
      localIntent: intent,
      discountCodes: const ['KEEP'],
    );
    await controller.replaceDiscountCodes(
      scope: guest,
      localIntent: intent,
      discountCodes: const [],
    );

    expect(controller.discountStatus, CartDiscountUpdateStatus.error);
    expect(controller.snapshot?.cart?.discountCodes.single.code, 'KEEP');
  });

  test('ambiguous removal read that is empty confirms removal', () async {
    final controller = CartController(
      reconciler: _RemovalReconciler(_RemovalOutcome.recoveredEmpty),
    );
    await controller.replaceDiscountCodes(
      scope: guest,
      localIntent: intent,
      discountCodes: const ['KEEP'],
    );
    await controller.replaceDiscountCodes(
      scope: guest,
      localIntent: intent,
      discountCodes: const [],
    );

    expect(controller.discountStatus, CartDiscountUpdateStatus.removed);
    expect(controller.snapshot?.cart?.discountCodes, isEmpty);
  });

  test('normal reconciliation carries known intent but discovers unknown',
      () async {
    final reconciler = _DiscountReconciler();
    final controller = CartController(reconciler: reconciler);

    await controller.reconcileLocalBag(scope: guest, localIntent: intent);
    expect(reconciler.rawDesiredSets.single, isNull);
    expect(controller.discountIntentState, CartDiscountIntentState.known);

    await controller.replaceDiscountCodes(
      scope: guest,
      localIntent: intent,
      discountCodes: const ['SAVE'],
    );
    await controller.reconcileLocalBag(scope: guest, localIntent: intent);
    expect(reconciler.rawDesiredSets.last, ['SAVE']);
  });

  test('account change resets desired codes to unknown', () async {
    const accountA = CartSessionScope.authenticated(
      shopDomain: 'staging.invalid',
      localAccountId: 'a',
    );
    const accountB = CartSessionScope.authenticated(
      shopDomain: 'staging.invalid',
      localAccountId: 'b',
    );
    final reconciler = _DiscountReconciler();
    final controller = CartController(reconciler: reconciler);
    await controller.replaceDiscountCodes(
      scope: accountA,
      localIntent: intent,
      discountCodes: const ['ACCOUNT_A'],
    );

    await controller.reconcileLocalBag(scope: accountB, localIntent: intent);

    expect(reconciler.rawDesiredSets.last, isNull);
    expect(controller.requestedDiscountCodes, isEmpty);
  });

  test('late discount result cannot leak into the current account', () async {
    const accountA = CartSessionScope.authenticated(
      shopDomain: 'staging.invalid',
      localAccountId: 'a',
    );
    const accountB = CartSessionScope.authenticated(
      shopDomain: 'staging.invalid',
      localAccountId: 'b',
    );
    final reconciler = _DeferredDiscountReconciler();
    final controller = CartController(reconciler: reconciler);
    final terminalScopes = <CartSessionScope?>[];
    controller.addListener(() {
      if (controller.discountStatus != CartDiscountUpdateStatus.applying) {
        terminalScopes.add(controller.scopedSnapshot?.scope);
      }
    });

    final slow = controller.replaceDiscountCodes(
      scope: accountA,
      localIntent: intent,
      discountCodes: const ['A'],
    );
    final fast = controller.replaceDiscountCodes(
      scope: accountB,
      localIntent: intent,
      discountCodes: const ['B'],
    );
    reconciler.complete(accountB, _result(const ['B']));
    await fast;
    reconciler.complete(accountA, _result(const ['A']));
    await slow;

    expect(controller.currentScope, accountB);
    expect(controller.requestedDiscountCodes, ['B']);
    expect(controller.snapshot?.cart?.discountCodes.single.code, 'B');
    expect(terminalScopes, [accountB]);
  });
}

final class _DiscountReconciler implements CartReconciler {
  final List<List<String>> desiredSets = [];
  final List<List<String>?> rawDesiredSets = [];

  @override
  Future<CartReconciliation> reconcile({
    required CartSessionScope scope,
    required Iterable<LocalCartIntent> localIntent,
    CartBuyerIdentity? buyerIdentity,
    List<String>? desiredDiscountCodes,
  }) async {
    rawDesiredSets.add(
      desiredDiscountCodes == null ? null : List.of(desiredDiscountCodes),
    );
    final desired = List<String>.of(desiredDiscountCodes ?? const []);
    desiredSets.add(desired);
    if (desired.contains('INVALID')) {
      return CartReconciliation(
        status: CartReconciliationStatus.partiallyConfirmed,
        cart: _cart(const []),
        issues: [
          CartMutationIssue(
            kind: CartMutationIssueKind.userError,
            code: 'INVALID',
            message: 'El código no es válido.',
          ),
        ],
      );
    }
    return _result(desired);
  }
}

enum _RemovalOutcome { confirmed, userError, recoveredWithCode, recoveredEmpty }

final class _RemovalReconciler implements CartReconciler {
  _RemovalReconciler(this.outcome);

  final _RemovalOutcome outcome;

  @override
  Future<CartReconciliation> reconcile({
    required CartSessionScope scope,
    required Iterable<LocalCartIntent> localIntent,
    CartBuyerIdentity? buyerIdentity,
    List<String>? desiredDiscountCodes,
  }) async {
    final desired = desiredDiscountCodes ?? const <String>[];
    if (desired.isNotEmpty) return _result(desired);
    return switch (outcome) {
      _RemovalOutcome.confirmed ||
      _RemovalOutcome.recoveredEmpty =>
        _result(const []),
      _RemovalOutcome.recoveredWithCode => _result(const ['KEEP']),
      _RemovalOutcome.userError => CartReconciliation(
          status: CartReconciliationStatus.partiallyConfirmed,
          cart: _cart(const ['KEEP']),
          issues: [
            CartMutationIssue(
              kind: CartMutationIssueKind.userError,
              code: 'INVALID',
              message: 'No se pudo actualizar el descuento.',
            ),
          ],
        ),
    };
  }
}

final class _DeferredDiscountReconciler implements CartReconciler {
  final Map<CartSessionScope, Completer<CartReconciliation>> _pending = {};

  void complete(CartSessionScope scope, CartReconciliation result) =>
      _pending[scope]!.complete(result);

  @override
  Future<CartReconciliation> reconcile({
    required CartSessionScope scope,
    required Iterable<LocalCartIntent> localIntent,
    CartBuyerIdentity? buyerIdentity,
    List<String>? desiredDiscountCodes,
  }) {
    final completer = Completer<CartReconciliation>();
    _pending[scope] = completer;
    return completer.future;
  }
}

CartReconciliation _result(List<String> codes) => CartReconciliation(
      status: CartReconciliationStatus.authoritative,
      cart: _cart(codes),
    );

Cart _cart(List<String> codes) {
  const money = CartMoney(amount: '10.0000', currencyCode: 'MXN');
  final timestamp = DateTime.utc(2026, 8, 27);
  return Cart(
    id: _opaque('cart'),
    checkoutUrl: Uri(path: _opaque('checkout')).toString(),
    createdAt: timestamp,
    updatedAt: timestamp,
    lines: [
      CartLine(
        id: _opaque('line'),
        variantId: shopifyVariantGid(9),
        productId: shopifyProductGid(8),
        title: 'Bolsa',
        variantTitle: 'Única',
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
    discountCodes: [
      for (final code in codes)
        CartDiscountCode(
          code: code,
          applicable: code != 'NOT_APPLICABLE',
        ),
    ],
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
