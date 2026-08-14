/// Persists the shopper's wishlist. Device-scoped until sign-in, then
/// attached to the account — see [mergeDeviceItemsIntoAccount] and
/// `docs/ACCOUNTS_AND_SYNC_PLAN.md` § 5 (merge, not replace or discard).
library;

import 'package:drift/drift.dart';

import 'database.dart';

class WishlistStore {
  WishlistStore(this._db);

  final AppDatabase _db;

  Future<Set<String>> allProductIds() async {
    final rows = await _db.select(_db.wishlistItems).get();
    return {for (final row in rows) row.productId};
  }

  Future<void> add(String productId, {String? accountId}) {
    return _db.into(_db.wishlistItems).insertOnConflictUpdate(
          WishlistItemsCompanion.insert(
            productId: productId,
            accountId: Value(accountId),
            addedAt: DateTime.now().toUtc(),
          ),
        );
  }

  Future<void> remove(String productId) {
    return (_db.delete(_db.wishlistItems)
          ..where((t) => t.productId.equals(productId)))
        .go();
  }

  /// On login, every wishlist row still scoped to no account (i.e. added as
  /// a guest on this device) becomes this account's. Rows already belonging
  /// to a *different* account are left untouched — that would mean two
  /// people signed into the same device, and this is not the place to
  /// resolve that.
  Future<void> mergeDeviceItemsIntoAccount(String accountId) {
    return (_db.update(_db.wishlistItems)
          ..where((t) => t.accountId.isNull()))
        .write(WishlistItemsCompanion(accountId: Value(accountId)));
  }
}
