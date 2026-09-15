/// Persists the shopper's pre-checkout bag, so it survives an app restart —
/// replacing `CatalogStore`'s previous in-memory-only bag map.
/// Device-scoped (empty [accountId]) until sign-in, same merge contract as
/// [WishlistStore]. Lines are keyed by variant so two variants of one product
/// can coexist.
library;

import 'package:drift/drift.dart';

import 'database.dart';

class BagLineRow {
  const BagLineRow({
    required this.productId,
    required this.variantId,
    required this.quantity,
  });

  final String productId;
  final String variantId;
  final int quantity;
}

class BagStore {
  BagStore(this._db);

  final AppDatabase _db;

  static String scopeKey(String? accountId) => accountId ?? '';

  /// Lines for one effective account scope (guest = empty string).
  Future<List<BagLineRow>> all({String? accountId}) async {
    final scope = scopeKey(accountId);
    final rows = await (_db.select(_db.bagLines)
          ..where((t) => t.accountId.equals(scope)))
        .get();
    return [
      for (final row in rows)
        BagLineRow(
          productId: row.productId,
          variantId: row.variantId,
          quantity: row.quantity,
        ),
    ];
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
            accountId: Value(scopeKey(accountId)),
          ),
        );
  }

  Future<void> remove(String variantId, {String? accountId}) {
    final scope = scopeKey(accountId);
    return (_db.delete(_db.bagLines)
          ..where(
            (t) => t.variantId.equals(variantId) & t.accountId.equals(scope),
          ))
        .go();
  }

  Future<void> clear({String? accountId}) {
    final scope = scopeKey(accountId);
    return (_db.delete(_db.bagLines)..where((t) => t.accountId.equals(scope)))
        .go();
  }

  /// Clears every bag line regardless of account — used on shop switch.
  Future<void> clearAllScopes() => _db.delete(_db.bagLines).go();

  Future<void> applyPurchase({
    required String operationId,
    required String shopDomain,
    required String? accountId,
    required Map<String, int> quantities,
  }) =>
      _db.transaction(() async {
        final existing = await (_db.select(_db.checkoutReceipts)
              ..where((t) => t.operationId.equals(operationId)))
            .getSingleOrNull();
        if (existing != null) return;
        final rows = await all(accountId: accountId);
        for (final row in rows) {
          final purchased = quantities[row.variantId] ?? 0;
          if (purchased <= 0) continue;
          final remaining = row.quantity - purchased;
          if (remaining <= 0) {
            await remove(row.variantId, accountId: accountId);
          } else {
            await upsert(
              productId: row.productId,
              variantId: row.variantId,
              quantity: remaining,
              accountId: accountId,
            );
          }
        }
        await _db.into(_db.checkoutReceipts).insert(
              CheckoutReceiptsCompanion.insert(
                operationId: operationId,
                shopDomain: shopDomain,
                accountId: scopeKey(accountId),
              ),
            );
      });

  /// Guest rows (`accountId == ''`) become [accountId]. Rows already belonging
  /// to a different account are left untouched.
  Future<void> mergeDeviceItemsIntoAccount(String accountId) async {
    final guestRows = await (_db.select(_db.bagLines)
          ..where((t) => t.accountId.equals('')))
        .get();
    await _db.transaction(() async {
      for (final row in guestRows) {
        await (_db.delete(_db.bagLines)
              ..where(
                (t) =>
                    t.variantId.equals(row.variantId) & t.accountId.equals(''),
              ))
            .go();
        await _db.into(_db.bagLines).insertOnConflictUpdate(
              BagLinesCompanion.insert(
                productId: row.productId,
                variantId: row.variantId,
                quantity: row.quantity,
                accountId: Value(accountId),
              ),
            );
      }
    });
  }
}
