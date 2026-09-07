/// Persists the single `SyncCursors` row — the on-device half of
/// `lib/data/shopify/catalog_sync.dart`'s `SyncCursor`, which is pure Dart
/// and knows nothing about storage.
library;

import 'package:drift/drift.dart';

import '../shopify/catalog_sync.dart' as shopify;
import 'database.dart';

class SyncCursorStore {
  SyncCursorStore(this._db);

  final AppDatabase _db;

  /// The row's primary key is always `0` — this is a singleton table. It
  /// must be passed explicitly on every write: SQLite auto-assigns a fresh
  /// rowid for an omitted `INTEGER PRIMARY KEY`, silently defeating both the
  /// singleton intent and the `ON CONFLICT` upsert below.
  static const _singletonId = 0;

  Future<shopify.SyncCursor> load() async {
    final row = await (_db.select(_db.syncCursors)
          ..where((t) => t.id.equals(_singletonId)))
        .getSingleOrNull();
    if (row == null) return const shopify.SyncCursor();
    return shopify.SyncCursor(
      lastUpdatedAt: row.lastUpdatedAt?.toUtc(),
      lastFullSyncAt: row.lastFullSyncAt?.toUtc(),
      shopDomain: row.shopDomain,
    );
  }

  Future<void> save(shopify.SyncCursor cursor) {
    return _db.into(_db.syncCursors).insertOnConflictUpdate(
          SyncCursorsCompanion.insert(
            id: const Value(_singletonId),
            lastUpdatedAt: Value(cursor.lastUpdatedAt),
            lastFullSyncAt: Value(cursor.lastFullSyncAt),
            shopDomain: Value(cursor.shopDomain),
          ),
        );
  }

  Future<void> clear() {
    return (_db.delete(_db.syncCursors)
          ..where((t) => t.id.equals(_singletonId)))
        .go();
  }
}
