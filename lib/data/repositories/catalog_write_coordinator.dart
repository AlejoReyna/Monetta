/// Serializes catalog writers and makes their authority policy explicit.
library;

import 'dart:async';

enum CatalogAuthority {
  localOnly,
  awaitingFirestore,
  firestoreLive,
  firestoreUnavailable,
}

class CatalogWriteCoordinator {
  CatalogWriteCoordinator({required bool expectsFirestore})
      : _authority = expectsFirestore
            ? CatalogAuthority.awaitingFirestore
            : CatalogAuthority.localOnly;

  CatalogAuthority _authority;
  Future<void> _tail = Future<void>.value();

  CatalogAuthority get authority => _authority;

  bool get allowsDelta =>
      _authority == CatalogAuthority.localOnly ||
      _authority == CatalogAuthority.firestoreUnavailable;

  void markFirestoreUnavailable() {
    if (_authority != CatalogAuthority.localOnly) {
      _authority = CatalogAuthority.firestoreUnavailable;
    }
  }

  /// Runs a Firestore cache mutation exclusively, then marks it authoritative.
  Future<T> runFirestoreWrite<T>(Future<T> Function() write) {
    return _exclusive(() async {
      final result = await write();
      _authority = CatalogAuthority.firestoreLive;
      return result;
    });
  }

  /// Runs delta only in an eligible fallback state. Authority is checked after
  /// all earlier writers finish, so a queued delta cannot overwrite Firestore.
  Future<T> runDeltaWrite<T>({
    required Future<T> Function() write,
    required T Function() blocked,
  }) {
    return _exclusive(() => allowsDelta ? write() : Future<T>.value(blocked()));
  }

  Future<T> _exclusive<T>(Future<T> Function() action) async {
    final previous = _tail;
    final release = Completer<void>();
    _tail = release.future;
    try {
      await previous;
      return await action();
    } finally {
      release.complete();
    }
  }
}
