/// Persists the shopper's pre-checkout bag, so it survives an app restart —
/// replacing `CatalogStore`'s previous in-memory-only `_bagQuantities` map.
/// Device-scoped until sign-in, same merge contract as [WishlistStore].
library;

import 'package:drift/drift.dart';

import 'database.dart';

class BagStore {
  BagStore(this._db);

  final AppDatabase _db;

  /// productId -> (variantId, quantity).
  Future<Map<String, (String, int)>> all() async {
    final rows = await _db.select(_db.bagLines).get();
    return {
      for (final row in rows) row.productId: (row.variantId, row.quantity),
    };
  }

  Future<void> upsert({
    required String productId,
    required String variantId,
    required int quantity,
    String? accountId,
  }) {
    return _db.into(_db.bagLines).insertOnConflictUpdate(
          BagLinesCompanion.insert(
            productId: productId,
            variantId: variantId,
            quantity: quantity,
            accountId: Value(accountId),
          ),
        );
  }

  Future<void> remove(String productId) {
    return (_db.delete(_db.bagLines)..where((t) => t.productId.equals(productId)))
        .go();
  }

  Future<void> clear() => _db.delete(_db.bagLines).go();

  /// See `WishlistStore.mergeDeviceItemsIntoAccount` — same contract.
  Future<void> mergeDeviceItemsIntoAccount(String accountId) {
    return (_db.update(_db.bagLines)..where((t) => t.accountId.isNull()))
        .write(BagLinesCompanion(accountId: Value(accountId)));
  }
}
