/// Persists the shopper's wishlist. Device-scoped (empty [accountId]) until
/// sign-in, then attached to the account — see [mergeDeviceItemsIntoAccount]
/// and `docs/ACCOUNTS_AND_SYNC_PLAN.md` § 5 (merge, not replace or discard).
library;

import 'package:drift/drift.dart';

import 'database.dart';

class WishlistStore {
  WishlistStore(this._db);

  final AppDatabase _db;

  static String scopeKey(String? accountId) => accountId ?? '';

  Future<Set<String>> allProductIds({String? accountId}) async {
    final scope = scopeKey(accountId);
    final rows = await (_db.select(_db.wishlistItems)
          ..where((t) => t.accountId.equals(scope)))
        .get();
    return {for (final row in rows) row.productId};
  }

  Future<void> add(String productId, {String? accountId}) {
    return _db.into(_db.wishlistItems).insertOnConflictUpdate(
          WishlistItemsCompanion.insert(
            productId: productId,
            accountId: Value(scopeKey(accountId)),
            addedAt: DateTime.now().toUtc(),
          ),
        );
  }

  Future<void> remove(String productId, {String? accountId}) {
    final scope = scopeKey(accountId);
    return (_db.delete(_db.wishlistItems)
          ..where(
            (t) => t.productId.equals(productId) & t.accountId.equals(scope),
          ))
        .go();
  }

  Future<void> clearAllScopes() => _db.delete(_db.wishlistItems).go();

  Future<void> deleteForAccount(String accountId) {
    if (accountId.isEmpty) return Future.value();
    return (_db.delete(_db.wishlistItems)
          ..where((t) => t.accountId.equals(accountId)))
        .go();
  }

  /// On login, every wishlist row still scoped to the guest (`''`) becomes
  /// this account's. Rows already belonging to a *different* account are left
  /// untouched — that would mean two people signed into the same device, and
  /// this is not the place to resolve that.
  Future<void> mergeDeviceItemsIntoAccount(String accountId) async {
    final guestRows = await (_db.select(_db.wishlistItems)
          ..where((t) => t.accountId.equals('')))
        .get();
    await _db.transaction(() async {
      for (final row in guestRows) {
        await (_db.delete(_db.wishlistItems)
              ..where(
                (t) =>
                    t.productId.equals(row.productId) & t.accountId.equals(''),
              ))
            .go();
        await _db.into(_db.wishlistItems).insertOnConflictUpdate(
              WishlistItemsCompanion.insert(
                productId: row.productId,
                accountId: Value(accountId),
                addedAt: row.addedAt,
              ),
            );
      }
    });
  }
}
