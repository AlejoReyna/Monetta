import 'package:monetta_app/data/shopify/cart/cart_api.dart';
import 'package:monetta_app/data/shopify/cart/cart_session_store.dart';
import 'package:monetta_app/data/shopify/cart/cart_write_coordinator.dart';
import 'package:monetta_app/data/shopify/cart/checkout_launcher.dart';
import 'package:monetta_app/domain/cart.dart';

final class FakeCartApi implements CartApi {
  CartBuyerIdentity? lastBuyerIdentity;

  CartMutationResult get emptyResult => CartMutationResult(cart: null);

  @override
  Future<CartMutationResult> create({
    required List<CartLineCreateInput> lines,
    required Map<String, String> attributes,
    CartBuyerIdentity? buyerIdentity,
  }) async {
    lastBuyerIdentity = buyerIdentity;
    return emptyResult;
  }

  @override
  Future<Cart?> get(SensitiveCartId cartId) async => null;

  @override
  Future<CartMutationResult> addLines(
    SensitiveCartId cartId,
    List<CartLineCreateInput> lines,
  ) async =>
      emptyResult;

  @override
  Future<CartMutationResult> updateLines(
    SensitiveCartId cartId,
    List<CartLineUpdateInput> lines,
  ) async =>
      emptyResult;

  @override
  Future<CartMutationResult> removeLines(
    SensitiveCartId cartId,
    List<String> lineIds,
  ) async =>
      emptyResult;

  @override
  Future<CartMutationResult> updateBuyerIdentity(
    SensitiveCartId cartId,
    CartBuyerIdentity identity,
  ) async {
    lastBuyerIdentity = identity;
    return emptyResult;
  }

  @override
  Future<CartMutationResult> replaceDiscountCodes(
    SensitiveCartId cartId,
    List<String> discountCodes,
  ) async =>
      emptyResult;
}

final class InMemoryCartSessionStore implements CartSessionStore {
  final Map<CartSessionScope, SensitiveCartId> _sessions = {};

  @override
  Future<SensitiveCartId?> read(CartSessionScope scope) async =>
      _sessions[scope];

  @override
  Future<void> write(
    CartSessionScope scope,
    SensitiveCartId cartId,
  ) async {
    _sessions[scope] = cartId;
  }

  @override
  Future<void> delete(CartSessionScope scope) async {
    _sessions.remove(scope);
  }
}

final class RecoveringCartWriteCoordinator implements CartWriteCoordinator {
  @override
  Future<T> run<T>({
    required CartSessionScope scope,
    required CartWrite<T> write,
    required CartWrite<T> recoverAfterAmbiguousFailure,
  }) async {
    try {
      return await write();
    } on AmbiguousCartWriteException {
      return recoverAfterAmbiguousFailure();
    }
  }
}

final class FakeCheckoutLauncher implements CheckoutLauncher {
  FakeCheckoutLauncher(Iterable<CheckoutResult> results)
      : _results = List.of(results);

  final List<CheckoutResult> _results;
  int preloadCalls = 0;
  int presentCalls = 0;
  int invalidateCalls = 0;

  @override
  Future<void> preload(ValidatedCheckoutUrl checkoutUrl) async {
    preloadCalls += 1;
  }

  @override
  Future<CheckoutResult> present(ValidatedCheckoutUrl checkoutUrl) async {
    presentCalls += 1;
    return _results.removeAt(0);
  }

  @override
  Future<void> invalidate() async {
    invalidateCalls += 1;
  }
}
