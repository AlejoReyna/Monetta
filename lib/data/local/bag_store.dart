/// Persists the shopper's pre-checkout bag, so it survives an app restart —
/// replacing `CatalogStore`'s previous in-memory-only bag map.
/// Device-scoped (empty [accountId]) until sign-in, when quantities merge into
/// the account bag. Lines are keyed by variant so two variants of one product
/// can coexist.
library;

import 'dart:math' show min;

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

  /// Removes the selected variants atomically within one account scope.
  Future<void> removeVariants(
    Iterable<String> variantIds, {
    String? accountId,
  }) {
    final scope = scopeKey(accountId);
    return (_db.delete(_db.bagLines)
          ..where(
            (t) => t.variantId.isIn(variantIds) & t.accountId.equals(scope),
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

  /// Sums guest and account quantities, capped at 10, keeping the guest product
  /// on a variant conflict. Other accounts are left untouched.
  Future<void> mergeDeviceItemsIntoAccount(String accountId) async {
    if (accountId.isEmpty) return;
    await _db.transaction(() async {
      // Both snapshots belong to this transaction, so concurrent merges cannot
      // consume the same guest quantities twice.
      final guestRows = await all();
      if (guestRows.isEmpty) return;
      final accountQuantities = {
        for (final row in await all(accountId: accountId))
          row.variantId: row.quantity,
      };
      for (final row in guestRows) {
        await upsert(
          productId: row.productId,
          variantId: row.variantId,
          quantity: min(
            row.quantity + (accountQuantities[row.variantId] ?? 0),
            10,
          ),
          accountId: accountId,
        );
      }
      await clear();
    });
  }
}
