/// Serialization and ambiguous-result recovery contract for cart mutations.
library;

import 'dart:async';

import 'cart_session_store.dart';

enum CartWriteOperation {
  create,
  addLines,
  updateLines,
  removeLines,
  updateBuyerIdentity,
  replaceDiscountCodes,
}

/// Signals that the request might have reached Shopify but its response was
/// not observed. It is intentionally safe to stringify.
final class AmbiguousCartWriteException implements Exception {
  const AmbiguousCartWriteException(this.operation);

  final CartWriteOperation operation;

  @override
  String toString() => 'AmbiguousCartWriteException(${operation.name})';
}

typedef CartWrite<T> = Future<T> Function();

/// Runs one mutation at a time for a cart session.
///
/// A concrete coordinator must call [recoverAfterAmbiguousFailure] after an
/// [AmbiguousCartWriteException]. Recovery reads Shopify state; it must not
/// blindly repeat [write].
abstract interface class CartWriteCoordinator {
  Future<T> run<T>({
    required CartSessionScope scope,
    required CartWrite<T> write,
    required CartWrite<T> recoverAfterAmbiguousFailure,
  });
}

/// FIFO mutex keyed by store and buyer session.
///
/// Failures never poison the queue. Different sessions are independent.
final class SerialCartWriteCoordinator implements CartWriteCoordinator {
  final Map<CartSessionScope, Future<void>> _tails = {};

  @override
  Future<T> run<T>({
    required CartSessionScope scope,
    required CartWrite<T> write,
    required CartWrite<T> recoverAfterAmbiguousFailure,
  }) async {
    final previous = _tails[scope] ?? Future<void>.value();
    final release = Completer<void>();
    final tail = previous.then<void>((_) => release.future);
    _tails[scope] = tail;

    await previous;
    try {
      try {
        return await write();
      } on AmbiguousCartWriteException {
        return await recoverAfterAmbiguousFailure();
      }
    } finally {
      release.complete();
      if (identical(_tails[scope], tail)) {
        unawaited(_tails.remove(scope));
      }
    }
  }
}
