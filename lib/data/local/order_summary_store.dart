/// Local read cache of `services/accounts_orders`'s order-mirror — see
/// `tables.dart`'s `OrderSummaries` doc comment. Cache-first, same contract
/// as `data/external_catalog/external_catalog_repository.dart`: a failed
/// refresh must never clear what's already here.
library;

import 'package:drift/drift.dart';

import 'database.dart';

class OrderSummaryStore {
  OrderSummaryStore(this._db);

  final AppDatabase _db;

  Future<List<OrderSummary>> allForAccount(String accountId) {
    return (_db.select(_db.orderSummaries)
          ..where((t) => t.accountId.equals(accountId))
          ..orderBy([(t) => OrderingTerm.desc(t.placedAt)]))
        .get();
  }

  /// Replaces every row for [accountId] with [orders] — a full resync from
  /// `services/accounts_orders`, not a patch. There is no delta-sync
  /// contract here yet (unlike `data/shopify`'s catalog sync): order
  /// history is small per shopper, so refetching all of it is cheap.
  Future<void> replaceAllForAccount(
    String accountId,
    List<OrderSummariesCompanion> orders,
  ) async {
    await _db.transaction(() async {
      await (_db.delete(_db.orderSummaries)
            ..where((t) => t.accountId.equals(accountId)))
          .go();
      for (final order in orders) {
        await _db.into(_db.orderSummaries).insertOnConflictUpdate(order);
      }
    });
  }
}
