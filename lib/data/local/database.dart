/// The on-device SQLite database — the real implementation of the `data/local`
/// module `docs/ARCHITECTURE.md` has described since Phase 1 planning, wired
/// up for the first time here.
///
/// The connection is injected (see [openConnection] vs the constructor)
/// rather than owned, so tests run against `NativeDatabase.memory()` with no
/// disk I/O and no plugin channel — the same DI shape as
/// `data/external_catalog/external_catalog_cache.dart`'s injected
/// `directoryProvider`.
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    CachedProducts,
    CachedVariants,
    CachedCollections,
    SyncCursors,
    WishlistItems,
    BagLines,
    InteractionEvents,
    Devices,
    Accounts,
    Sessions,
    OrderSummaries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Opens the real on-device file, under the app's support directory (not
  /// documents — this is app data, not something the shopper should see in
  /// the Files app).
  factory AppDatabase.connect() =>
      AppDatabase(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, 'monetta.sqlite'));
      // Required on Android before opening the database — see
      // sqlite3_flutter_libs' own setup instructions.
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
      return NativeDatabase.createInBackground(
        file,
        setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;'),
      );
    });
  }
}

/// In-memory database for tests: `AppDatabase(NativeDatabase.memory())`
/// directly is equally valid, but this keeps call sites (and the foreign-key
/// pragma, which tests need too — several tables enforce
/// `ON DELETE CASCADE`) in one place.
AppDatabase openTestDatabase() {
  return AppDatabase(
    NativeDatabase.memory(
      setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;'),
    ),
  );
}
