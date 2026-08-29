/// Application state for one coherent remote-cart reconciliation snapshot.
library;

import 'package:flutter/foundation.dart';

import '../data/shopify/cart/cart_api.dart';
import '../data/shopify/cart/cart_repository.dart';
import '../data/shopify/cart/cart_session_store.dart';
import '../domain/cart.dart';

enum CartControllerStatus { idle, syncing, ready, stale, error }

enum CartDiscountUpdateStatus {
  idle,
  applying,
  applied,
  notApplicable,
  invalid,
  removed,
  error,
}

enum CartDiscountIntentState { unknown, known }

final class ScopedCartSnapshot {
  const ScopedCartSnapshot({
    required this.scope,
    required this.reconciliation,
  });

  final CartSessionScope scope;
  final CartReconciliation reconciliation;
}

final class CartController extends ChangeNotifier {
  CartController({required CartReconciler reconciler})
      : _reconciler = reconciler;

  final CartReconciler _reconciler;

  CartControllerStatus _status = CartControllerStatus.idle;
  CartSessionScope? _currentScope;
  ScopedCartSnapshot? _scopedSnapshot;
  String? _errorMessage;
  List<String> _requestedDiscountCodes = const [];
  CartDiscountIntentState _discountIntentState =
      CartDiscountIntentState.unknown;
  CartDiscountUpdateStatus _discountStatus = CartDiscountUpdateStatus.idle;
  String? _discountMessage;
  int _requestGeneration = 0;
  bool _disposed = false;

  CartControllerStatus get status => _status;
  CartSessionScope? get currentScope => _currentScope;
  ScopedCartSnapshot? get scopedSnapshot => _scopedSnapshot;
  CartReconciliation? get snapshot => _scopedSnapshot?.reconciliation;
  String? get errorMessage => _errorMessage;
  List<String> get requestedDiscountCodes => _requestedDiscountCodes;
  CartDiscountIntentState get discountIntentState => _discountIntentState;
  CartDiscountUpdateStatus get discountStatus => _discountStatus;
  String? get discountMessage => _discountMessage;

  Future<CartReconciliation?> reconcileLocalBag({
    required CartSessionScope scope,
    required Iterable<LocalCartIntent> localIntent,
    CartBuyerIdentity? buyerIdentity,
  }) async {
    final generation = ++_requestGeneration;
    final scopeChanged = _currentScope != scope;
    _currentScope = scope;
    if (scopeChanged) {
      _scopedSnapshot = null;
      _requestedDiscountCodes = const [];
      _discountIntentState = CartDiscountIntentState.unknown;
      _discountStatus = CartDiscountUpdateStatus.idle;
      _discountMessage = null;
    }
    _status = CartControllerStatus.syncing;
    _errorMessage = null;
    notifyListeners();
    try {
      final next = await _reconciler.reconcile(
        scope: scope,
        localIntent: localIntent,
        buyerIdentity: buyerIdentity,
        desiredDiscountCodes:
            _discountIntentState == CartDiscountIntentState.known
                ? _requestedDiscountCodes
                : null,
      );
      if (!_isCurrent(generation, scope)) return null;
      _scopedSnapshot = ScopedCartSnapshot(
        scope: scope,
        reconciliation: next,
      );
      if (next.cart case final cart?) {
        _requestedDiscountCodes = List.unmodifiable(
          cart.discountCodes.map((item) => item.code),
        );
        _discountIntentState = CartDiscountIntentState.known;
        _discountStatus = _statusForReturnedCodes(cart.discountCodes);
      }
      _status = switch (next.status) {
        CartReconciliationStatus.authoritative => CartControllerStatus.ready,
        CartReconciliationStatus.partiallyConfirmed =>
          CartControllerStatus.stale,
        CartReconciliationStatus.unavailable => CartControllerStatus.error,
      };
      if (_status == CartControllerStatus.error) {
        _errorMessage = 'Tu bolsa local se conserva hasta recuperar Shopify.';
      }
      notifyListeners();
      return next;
    } on Exception {
      if (!_isCurrent(generation, scope)) return null;
      _scopedSnapshot = null;
      _status = CartControllerStatus.error;
      _errorMessage = 'No fue posible sincronizar tu bolsa en este momento.';
      notifyListeners();
      return null;
    }
  }

  Future<void> applyDiscountCode({
    required CartSessionScope scope,
    required Iterable<LocalCartIntent> localIntent,
    required String code,
    CartBuyerIdentity? buyerIdentity,
  }) {
    return replaceDiscountCodes(
      scope: scope,
      localIntent: localIntent,
      discountCodes: [..._requestedDiscountCodes, code],
      buyerIdentity: buyerIdentity,
    );
  }

  Future<void> removeDiscountCode({
    required CartSessionScope scope,
    required Iterable<LocalCartIntent> localIntent,
    required String code,
    CartBuyerIdentity? buyerIdentity,
  }) {
    final target = code.trim().toUpperCase();
    return replaceDiscountCodes(
      scope: scope,
      localIntent: localIntent,
      discountCodes:
          _requestedDiscountCodes.where((item) => item.toUpperCase() != target),
      buyerIdentity: buyerIdentity,
    );
  }

  /// Sends the complete desired set. It never models this as an append.
  Future<void> replaceDiscountCodes({
    required CartSessionScope scope,
    required Iterable<LocalCartIntent> localIntent,
    required Iterable<String> discountCodes,
    CartBuyerIdentity? buyerIdentity,
  }) async {
    List<String> desired;
    try {
      desired = _normalizeCodes(discountCodes);
    } on FormatException {
      _discountStatus = CartDiscountUpdateStatus.invalid;
      _discountMessage = 'Escribe un código de descuento válido.';
      notifyListeners();
      return;
    }

    final generation = ++_requestGeneration;
    final scopeChanged = _currentScope != scope;
    final previousForScope = !scopeChanged && _scopedSnapshot?.scope == scope
        ? _scopedSnapshot
        : null;
    _currentScope = scope;
    if (scopeChanged) {
      _scopedSnapshot = null;
      _requestedDiscountCodes = const [];
      _discountIntentState = CartDiscountIntentState.unknown;
    }
    _requestedDiscountCodes = List.unmodifiable(desired);
    _discountIntentState = CartDiscountIntentState.known;
    _discountStatus = CartDiscountUpdateStatus.applying;
    _discountMessage = 'Aplicando descuento…';
    notifyListeners();
    try {
      final next = await _reconciler.reconcile(
        scope: scope,
        localIntent: localIntent,
        buyerIdentity: buyerIdentity,
        desiredDiscountCodes: desired,
      );
      if (!_isCurrent(generation, scope)) return;
      _scopedSnapshot = next.cart == null
          ? previousForScope
          : ScopedCartSnapshot(scope: scope, reconciliation: next);
      _status = switch (next.status) {
        CartReconciliationStatus.authoritative => CartControllerStatus.ready,
        CartReconciliationStatus.partiallyConfirmed =>
          CartControllerStatus.stale,
        CartReconciliationStatus.unavailable => CartControllerStatus.error,
      };
      _applyDiscountResult(next, desired);
    } on Exception {
      if (!_isCurrent(generation, scope)) return;
      _scopedSnapshot = previousForScope;
      _status = CartControllerStatus.error;
      _discountStatus = CartDiscountUpdateStatus.error;
      _discountMessage =
          'No se pudo confirmar el descuento. Tu bolsa local se conserva.';
    }
    notifyListeners();
  }

  void _applyDiscountResult(CartReconciliation result, List<String> desired) {
    final cart = result.cart;
    if (cart == null) {
      _discountStatus = CartDiscountUpdateStatus.error;
      _discountMessage =
          'No se pudo confirmar el descuento. Inténtalo de nuevo.';
      return;
    }
    final hasUserError = result.issues.any(
      (issue) => issue.kind == CartMutationIssueKind.userError,
    );
    if (desired.isEmpty) {
      if (hasUserError || cart.discountCodes.isNotEmpty) {
        _discountStatus = CartDiscountUpdateStatus.error;
        _discountMessage = 'No se pudo confirmar la eliminación del código.';
      } else {
        _discountStatus = CartDiscountUpdateStatus.removed;
        _discountMessage = 'Código eliminado.';
      }
      return;
    }
    final returned = {
      for (final item in cart.discountCodes) item.code.toUpperCase(): item,
    };
    final missing = desired.any((code) => !returned.containsKey(code));
    if (missing || hasUserError) {
      _discountStatus = CartDiscountUpdateStatus.invalid;
      _discountMessage = 'Shopify no reconoció uno de los códigos.';
    } else if (desired.any((code) => returned[code]!.applicable == false)) {
      _discountStatus = CartDiscountUpdateStatus.notApplicable;
      _discountMessage = 'El código es válido, pero no aplica a esta bolsa.';
    } else {
      _discountStatus = CartDiscountUpdateStatus.applied;
      _discountMessage = 'Descuento aplicado.';
    }
  }

  static List<String> _normalizeCodes(Iterable<String> values) {
    final normalized = <String>[];
    final seen = <String>{};
    for (final raw in values) {
      final code = raw.trim().toUpperCase();
      if (code.isEmpty ||
          code.length > 255 ||
          code.contains(RegExp(r'[\r\n]'))) {
        throw const FormatException('Invalid discount code');
      }
      if (seen.add(code)) normalized.add(code);
    }
    if (normalized.length > 250) {
      throw const FormatException('Too many discount codes');
    }
    return List.unmodifiable(normalized);
  }

  static CartDiscountUpdateStatus _statusForReturnedCodes(
    List<CartDiscountCode>? codes,
  ) {
    if (codes == null || codes.isEmpty) return CartDiscountUpdateStatus.idle;
    return codes.every((item) => item.applicable)
        ? CartDiscountUpdateStatus.applied
        : CartDiscountUpdateStatus.notApplicable;
  }

  bool _isCurrent(int generation, CartSessionScope scope) =>
      !_disposed && generation == _requestGeneration && _currentScope == scope;

  @override
  void dispose() {
    _disposed = true;
    _requestGeneration += 1;
    _scopedSnapshot = null;
    super.dispose();
  }
}
