/// Reconciles Shopify immediately before checkout and owns terminal effects.
library;

import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../data/shopify/cart/cart_api.dart';
import '../data/shopify/cart/cart_repository.dart';
import '../data/shopify/cart/cart_session_store.dart';
import '../data/shopify/cart/checkout_launcher.dart';
import 'cart_controller.dart';

typedef CheckoutCompletion = Future<void> Function(
  CheckoutPurchase purchase,
);

final class CheckoutPurchase {
  CheckoutPurchase({
    required this.scope,
    required this.operationId,
    required Map<String, int> quantities,
  }) : quantities = Map.unmodifiable(quantities);
  final CartSessionScope scope;
  final String operationId;
  final Map<String, int> quantities;
}

final class ShopifyCheckoutCoordinator {
  ShopifyCheckoutCoordinator({
    required CheckoutLauncher launcher,
    required CheckoutUrlPolicy urlPolicy,
    required CartSessionStore sessions,
    ExternalCheckoutOpener? externalOpener,
  })  : _launcher = launcher,
        _urlPolicy = urlPolicy,
        _sessions = sessions,
        _externalOpener = externalOpener;

  final CheckoutLauncher _launcher;
  final CheckoutUrlPolicy _urlPolicy;
  final CartSessionStore _sessions;
  final ExternalCheckoutOpener? _externalOpener;

  Future<void> Function()? _pendingCompletion;
  CartSessionScope? _pendingScope;

  bool _presenting = false;
  bool _openingFallback = false;
  ValidatedCheckoutUrl? _latestUrl;

  bool get isPresenting => _presenting;
  bool get canOpenExternalFallback =>
      !_presenting &&
      !_openingFallback &&
      _externalOpener != null &&
      _latestUrl != null;

  Future<void> preload(CartReconciliation reconciliation) async {
    if (_presenting) return;
    _latestUrl = null;
    final cart = reconciliation.cart;
    if (cart == null ||
        reconciliation.status != CartReconciliationStatus.authoritative) {
      return;
    }
    try {
      final validated = _urlPolicy.validate(cart.checkoutUrl);
      _latestUrl = validated;
      await _launcher.preload(validated);
    } on Exception {
      // Preload is an optional optimization. Presentation always refreshes and
      // validates again, so failure here never exposes details or blocks retry.
    }
  }

  Future<CheckoutResult> present({
    required CartController controller,
    required CartSessionScope scope,
    required Iterable<LocalCartIntent> localIntent,
    required CheckoutCompletion onCompleted,
    CartBuyerIdentity? buyerIdentity,
  }) async {
    if (_presenting || _openingFallback) {
      return _unavailable('Ya hay un checkout abierto.');
    }
    _presenting = true;
    _latestUrl = null;
    try {
      final pending = _pendingCompletion;
      if (pending != null) {
        final completedScope = _pendingScope;
        await pending();
        _pendingCompletion = null;
        _pendingScope = null;
        if (completedScope != scope) {
          return _unavailable(
            'Se actualizó una compra de otra cuenta. Revisa tu bolsa e intenta de nuevo.',
          );
        }
        return const CheckoutCompleted();
      }
      final refreshed = await controller.reconcileLocalBag(
        scope: scope,
        localIntent: List<LocalCartIntent>.unmodifiable(localIntent),
        buyerIdentity: buyerIdentity,
      );
      if (refreshed == null ||
          refreshed.status != CartReconciliationStatus.authoritative ||
          refreshed.cart == null) {
        return _unavailable(
          'Shopify debe confirmar tu bolsa antes de abrir el checkout.',
        );
      }
      final cart = refreshed.cart!;

      final validated = _urlPolicy.validate(cart.checkoutUrl);
      _latestUrl = validated;
      // Keep the SDK's preloaded document aligned with the just-reconciled
      // cart. This is an optimization; present() remains the only operation
      // that can produce a terminal checkout result.
      try {
        await _launcher.preload(validated);
      } on Exception {
        // The native SDK can still present the authoritative URL directly.
      }
      final result = await _launcher.present(validated);
      if (result is CheckoutCompleted) {
        _latestUrl = null;
        final quantities = <String, int>{};
        for (final line in cart.lines) {
          quantities.update(
            line.variantId,
            (value) => value + line.quantity,
            ifAbsent: () => line.quantity,
          );
        }
        final purchase = CheckoutPurchase(
          scope: scope,
          operationId: sha256
              .convert(utf8.encode('${scope.shopDomain}:${cart.id}'))
              .toString(),
          quantities: quantities,
        );
        // Keep the captured completion retryable without opening another
        // checkout. The local receipt makes retry after session-delete failure
        // safe as well as retry after a failed bag transaction.
        _pendingScope = scope;
        _pendingCompletion = () async {
          await onCompleted(purchase);
          await _sessions.delete(scope);
        };
        await _pendingCompletion!();
        _pendingCompletion = null;
        _pendingScope = null;
        try {
          await _launcher.invalidate();
        } on Exception {
          // Invalidation is cache-only and must not turn a trusted completion
          // into a second, misleading terminal outcome.
        }
      }
      return result;
    } on CheckoutUrlPolicyException {
      return const CheckoutFailed(
        code: CheckoutFailureCode.configuration,
        userMessage: 'Shopify devolvió un checkout que no es seguro abrir.',
      );
    } on Exception {
      return _unavailable(
        _pendingCompletion != null
            ? 'Shopify confirmó tu compra. Reintenta para actualizar tu bolsa sin volver a pagar.'
            : 'No fue posible abrir el checkout. Tu bolsa se conserva.',
      );
    } finally {
      _presenting = false;
    }
  }

  Future<bool> openExternalFallback() async {
    final opener = _externalOpener;
    final checkoutUrl = _latestUrl;
    if (_presenting ||
        _openingFallback ||
        opener == null ||
        checkoutUrl == null) {
      return false;
    }
    _openingFallback = true;
    try {
      return await opener.open(checkoutUrl);
    } on Exception {
      return false;
    } finally {
      _openingFallback = false;
    }
  }

  Future<void> invalidate() async {
    _latestUrl = null;
    try {
      await _launcher.invalidate();
    } on Exception {
      // Cache invalidation has no user data side effect and can safely fail.
    }
  }

  static CheckoutFailed _unavailable(String message) => CheckoutFailed(
        code: CheckoutFailureCode.unavailable,
        userMessage: message,
      );
}
