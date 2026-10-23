/// Recoverable Shopify-cart lifecycle and local-bag reconciliation.
library;

import '../../../domain/cart.dart';
import '../cart_attribution.dart';
import '../shopify_gid.dart';
import 'cart_api.dart';
import 'cart_session_store.dart';
import 'cart_write_coordinator.dart';

final class LocalCartIntent {
  const LocalCartIntent({required this.variantId, required this.quantity});

  final String variantId;
  final int quantity;

  @override
  String toString() => 'LocalCartIntent(<redacted>, quantity: $quantity)';
}

enum UnconfirmedCartIntentReason {
  invalidVariant,
  unavailable,
  outOfStock,
  quantityAdjusted,
}

final class UnconfirmedCartIntent {
  const UnconfirmedCartIntent({
    required this.variantId,
    required this.requestedQuantity,
    required this.confirmedQuantity,
    required this.reason,
    required this.userMessage,
  });

  final String variantId;
  final int requestedQuantity;
  final int confirmedQuantity;
  final UnconfirmedCartIntentReason reason;
  final String userMessage;

  @override
  String toString() => 'UnconfirmedCartIntent(<redacted>, '
      'requested: $requestedQuantity, confirmed: $confirmedQuantity, '
      'reason: ${reason.name})';
}

enum CartReconciliationStatus { authoritative, partiallyConfirmed, unavailable }

/// One coherent snapshot published after the complete reconciliation.
final class CartReconciliation {
  CartReconciliation({
    required this.status,
    required this.cart,
    List<UnconfirmedCartIntent> unconfirmed = const [],
    List<CartMutationIssue> issues = const [],
  })  : unconfirmed = List.unmodifiable(unconfirmed),
        issues = List.unmodifiable(issues);

  final CartReconciliationStatus status;
  final Cart? cart;
  final List<UnconfirmedCartIntent> unconfirmed;
  final List<CartMutationIssue> issues;

  bool get hasAuthoritativeCart => cart != null;

  @override
  String toString() => 'CartReconciliation(status: ${status.name}, '
      'cart: <redacted>, unconfirmed: ${unconfirmed.length})';
}

abstract interface class CartReconciler {
  Future<CartReconciliation> reconcile({
    required CartSessionScope scope,
    required Iterable<LocalCartIntent> localIntent,
    CartBuyerIdentity? buyerIdentity,
    List<String>? desiredDiscountCodes,
  });
}

final class CartRepository implements CartReconciler {
  const CartRepository({
    required CartApi api,
    required CartSessionStore sessions,
    required CartWriteCoordinator writes,
    required CartAttribution attribution,
  })  : _api = api,
        _sessions = sessions,
        _writes = writes,
        _attribution = attribution;

  final CartApi _api;
  final CartSessionStore _sessions;
  final CartWriteCoordinator _writes;
  final CartAttribution _attribution;

  /// Makes Shopify Cart authoritative for the supplied local intent.
  ///
  /// Invalid identities and quantities remain explicit unconfirmed intent.
  /// They are never sent to Shopify or represented as accepted remote lines.
  @override
  Future<CartReconciliation> reconcile({
    required CartSessionScope scope,
    required Iterable<LocalCartIntent> localIntent,
    CartBuyerIdentity? buyerIdentity,
    List<String>? desiredDiscountCodes,
  }) async {
    final normalized = _normalize(localIntent);
    SensitiveCartId? recoveryCartId;

    try {
      return await _writes.run<CartReconciliation>(
        scope: scope,
        write: () async {
          var cartId = await _sessions.read(scope);
          Cart? cart;
          if (cartId != null) {
            recoveryCartId = cartId;
            cart = await _api.get(cartId);
          }

          if (cart == null) {
            if (cartId != null) await _sessions.delete(scope);
            cartId = null;
            recoveryCartId = null;
            // Login reconciles the account scope, which has no cart yet.
            // Adopting the guest cart keeps its id, lines and discounts.
            // Creating a second cart here is what forced the shopper to
            // start checkout over.
            final adopted = await _adoptGuestCart(scope);
            if (adopted != null) {
              cart = adopted;
              cartId = SensitiveCartId(adopted.id);
              recoveryCartId = cartId;
            }
          }

          if (cart == null) {
            final created = await _api.create(
              lines: normalized.quantities.entries
                  .map(
                    (entry) => CartLineCreateInput(
                      merchandiseId: entry.key,
                      quantity: entry.value,
                    ),
                  )
                  .toList(growable: false),
              attributes: {
                for (final attribute in _attribution.toAttributeInputs())
                  attribute['key']!: attribute['value']!,
              },
              buyerIdentity: buyerIdentity,
            );
            cart = created.cart;
            if (cart == null) {
              return _snapshot(
                cart: null,
                desired: normalized.quantities,
                initialUnconfirmed: normalized.invalid,
                issues: created.issues,
              );
            }
            cartId = SensitiveCartId(cart.id);
            recoveryCartId = cartId;
            await _sessions.write(scope, cartId);
            final issues = <CartMutationIssue>[...created.issues];
            if (desiredDiscountCodes != null &&
                !_sameCodes(cart.discountCodes, desiredDiscountCodes)) {
              final discounted = await _api.replaceDiscountCodes(
                cartId,
                desiredDiscountCodes,
              );
              issues.addAll(discounted.issues);
              if (discounted.cart == null) {
                if (!_hasUserError(discounted.issues)) {
                  issues.add(_unconfirmedDiscountIssue());
                }
              } else {
                cart = discounted.cart;
              }
            }
            return _snapshot(
              cart: cart,
              desired: normalized.quantities,
              initialUnconfirmed: normalized.invalid,
              issues: issues,
            );
          }

          final issues = <CartMutationIssue>[];
          if (buyerIdentity != null) {
            final updated = await _api.updateBuyerIdentity(
              cartId!,
              buyerIdentity,
            );
            issues.addAll(updated.issues);
            cart = updated.cart ?? cart;
          }

          final remoteByVariant = <String, List<CartLine>>{};
          for (final line in cart.lines) {
            remoteByVariant.putIfAbsent(line.variantId, () => []).add(line);
          }

          final removals = <String>[];
          for (final entry in remoteByVariant.entries) {
            if (!normalized.quantities.containsKey(entry.key)) {
              removals.addAll(entry.value.map((line) => line.id));
            } else if (entry.value.length > 1) {
              removals.addAll(entry.value.skip(1).map((line) => line.id));
            }
          }
          if (removals.isNotEmpty) {
            final removed = await _api.removeLines(cartId!, removals);
            issues.addAll(removed.issues);
            cart = removed.cart ?? cart;
          }

          final updates = <CartLineUpdateInput>[];
          for (final entry in normalized.quantities.entries) {
            final existing = remoteByVariant[entry.key];
            if (existing != null &&
                existing.isNotEmpty &&
                existing.first.quantity != entry.value) {
              updates.add(
                CartLineUpdateInput(
                  lineId: existing.first.id,
                  quantity: entry.value,
                ),
              );
            }
          }
          if (updates.isNotEmpty) {
            final updated = await _api.updateLines(cartId!, updates);
            issues.addAll(updated.issues);
            cart = updated.cart ?? cart;
          }

          final additions = normalized.quantities.entries
              .where((entry) => !remoteByVariant.containsKey(entry.key))
              .map(
                (entry) => CartLineCreateInput(
                  merchandiseId: entry.key,
                  quantity: entry.value,
                ),
              )
              .toList(growable: false);
          if (additions.isNotEmpty) {
            final added = await _api.addLines(cartId!, additions);
            issues.addAll(added.issues);
            cart = added.cart ?? cart;
          }

          if (desiredDiscountCodes != null &&
              !_sameCodes(cart.discountCodes, desiredDiscountCodes)) {
            final discounted = await _api.replaceDiscountCodes(
              cartId!,
              desiredDiscountCodes,
            );
            issues.addAll(discounted.issues);
            if (discounted.cart == null) {
              if (!_hasUserError(discounted.issues)) {
                issues.add(_unconfirmedDiscountIssue());
              }
            } else {
              cart = discounted.cart;
            }
          }

          final freshId = SensitiveCartId(cart!.id);
          recoveryCartId = freshId;
          await _sessions.write(scope, freshId);
          return _snapshot(
            cart: cart,
            desired: normalized.quantities,
            initialUnconfirmed: normalized.invalid,
            issues: issues,
          );
        },
        recoverAfterAmbiguousFailure: () async {
          final cartId = recoveryCartId;
          if (cartId == null) {
            return _unavailable(normalized);
          }
          final recovered = await _api.get(cartId);
          if (recovered == null) {
            await _sessions.delete(scope);
            return _unavailable(normalized);
          }
          await _sessions.write(scope, SensitiveCartId(recovered.id));
          return _snapshot(
            cart: recovered,
            desired: normalized.quantities,
            initialUnconfirmed: normalized.invalid,
          );
        },
      );
    } on CartApiException {
      return _unavailable(normalized);
    }
  }

  /// Moves this shop's guest cart onto [scope] when the account has none.
  ///
  /// Returns null when there is nothing to adopt. The caller then creates a
  /// cart. A failed read leaves the guest session in place.
  Future<Cart?> _adoptGuestCart(CartSessionScope scope) async {
    if (!scope.isAuthenticated) return null;
    final guestScope = CartSessionScope.guest(shopDomain: scope.shopDomain);
    final guestId = await _sessions.read(guestScope);
    if (guestId == null) return null;
    final guestCart = await _api.get(guestId);
    if (guestCart == null) {
      await _sessions.delete(guestScope);
      return null;
    }
    final adoptedId = SensitiveCartId(guestCart.id);
    await _sessions.write(scope, adoptedId);
    await _sessions.delete(guestScope);
    return guestCart;
  }

  static _NormalizedIntent _normalize(Iterable<LocalCartIntent> values) {
    final quantities = <String, int>{};
    final invalid = <UnconfirmedCartIntent>[];
    for (final value in values) {
      try {
        final raw = value.variantId.trim();
        final canonical = shopifyVariantGid(raw);
        if (raw != canonical || value.quantity <= 0) {
          throw const FormatException('Non-canonical cart intent');
        }
        quantities.update(
          canonical,
          (quantity) => quantity + value.quantity,
          ifAbsent: () => value.quantity,
        );
      } on FormatException {
        invalid.add(
          UnconfirmedCartIntent(
            variantId: value.variantId,
            requestedQuantity: value.quantity,
            confirmedQuantity: 0,
            reason: UnconfirmedCartIntentReason.invalidVariant,
            userMessage: 'Una variante de tu bolsa ya no es válida.',
          ),
        );
      }
    }
    return _NormalizedIntent(quantities: quantities, invalid: invalid);
  }

  static bool _sameCodes(
    Iterable<CartDiscountCode> actual,
    Iterable<String> desired,
  ) {
    final actualSet = actual.map((item) => item.code.toUpperCase()).toSet();
    final desiredSet = desired.map((item) => item.toUpperCase()).toSet();
    return actualSet.length == desiredSet.length &&
        actualSet.containsAll(desiredSet);
  }

  static CartMutationIssue _unconfirmedDiscountIssue() => CartMutationIssue(
        kind: CartMutationIssueKind.userError,
        code: 'DISCOUNT_UPDATE_UNCONFIRMED',
        message: 'No se pudo confirmar el cambio de descuento.',
      );

  static bool _hasUserError(Iterable<CartMutationIssue> issues) => issues.any(
        (issue) => issue.kind == CartMutationIssueKind.userError,
      );

  static CartReconciliation _snapshot({
    required Cart? cart,
    required Map<String, int> desired,
    required List<UnconfirmedCartIntent> initialUnconfirmed,
    List<CartMutationIssue> issues = const [],
  }) {
    if (cart == null) {
      return CartReconciliation(
        status: CartReconciliationStatus.unavailable,
        cart: null,
        unconfirmed: [
          ...initialUnconfirmed,
          ...desired.entries.map(
            (entry) => _unavailableIntent(entry.key, entry.value),
          ),
        ],
        issues: issues,
      );
    }

    final confirmed = <String, int>{};
    for (final line in cart.lines) {
      confirmed.update(
        line.variantId,
        (quantity) => quantity + line.quantity,
        ifAbsent: () => line.quantity,
      );
    }
    final outOfStock = issues.any(
      (issue) => issue.code == 'MERCHANDISE_OUT_OF_STOCK',
    );
    final unconfirmed = <UnconfirmedCartIntent>[...initialUnconfirmed];
    for (final entry in desired.entries) {
      final accepted = confirmed[entry.key] ?? 0;
      if (accepted == entry.value) continue;
      final reason = accepted == 0 && outOfStock
          ? UnconfirmedCartIntentReason.outOfStock
          : UnconfirmedCartIntentReason.quantityAdjusted;
      unconfirmed.add(
        UnconfirmedCartIntent(
          variantId: entry.key,
          requestedQuantity: entry.value,
          confirmedQuantity: accepted,
          reason: reason,
          userMessage: reason == UnconfirmedCartIntentReason.outOfStock
              ? 'Una variante de tu bolsa está agotada.'
              : 'Shopify ajustó una cantidad al inventario disponible.',
        ),
      );
    }
    final remoteDiffers = confirmed.length != desired.length ||
        desired.entries.any((entry) => confirmed[entry.key] != entry.value);
    final hasFeedback = issues.isNotEmpty;
    return CartReconciliation(
      status: unconfirmed.isEmpty && !remoteDiffers && !hasFeedback
          ? CartReconciliationStatus.authoritative
          : CartReconciliationStatus.partiallyConfirmed,
      cart: cart,
      unconfirmed: unconfirmed,
      issues: issues,
    );
  }

  static CartReconciliation _unavailable(_NormalizedIntent normalized) =>
      CartReconciliation(
        status: CartReconciliationStatus.unavailable,
        cart: null,
        unconfirmed: [
          ...normalized.invalid,
          ...normalized.quantities.entries.map(
            (entry) => _unavailableIntent(entry.key, entry.value),
          ),
        ],
      );

  static UnconfirmedCartIntent _unavailableIntent(
    String variantId,
    int quantity,
  ) =>
      UnconfirmedCartIntent(
        variantId: variantId,
        requestedQuantity: quantity,
        confirmedQuantity: 0,
        reason: UnconfirmedCartIntentReason.unavailable,
        userMessage: 'Tu bolsa local se conserva hasta recuperar Shopify.',
      );
}

final class _NormalizedIntent {
  const _NormalizedIntent({required this.quantities, required this.invalid});

  final Map<String, int> quantities;
  final List<UnconfirmedCartIntent> invalid;
}
