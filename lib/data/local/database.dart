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
    CatalogStates,
    AppPreferences,
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
  factory AppDatabase.connect() => AppDatabase(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) => migrator.createAll(),
        onUpgrade: (migrator, from, to) async {
          if (from < 2) await _migrateShopifyIdsToGids();
          if (from < 3) await migrator.createTable(appPreferences);
          if (from < 4) await migrator.createTable(catalogStates);
        },
        beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON;'),
      );

  /// Version 1 persisted ids from the bundled Ajax snapshot as decimal text.
  /// Storefront and Firestore use GIDs, so an upgraded installation must move
  /// the catalog and every shopper-owned reference as one migration. Existing
  /// GID rows win if a partially-upgraded database contains both identities.
  Future<void> _migrateShopifyIdsToGids() async {
    const numeric =
        "%s GLOB '[0-9]*' AND %s NOT GLOB '*[^0-9]*' AND length(%s) > 0";
    final productNumeric = numeric.replaceAll('%s', 'id');
    final variantNumeric = numeric.replaceAll('%s', 'id');
    final productReferenceNumeric = numeric.replaceAll('%s', 'product_id');
    final variantReferenceNumeric = numeric.replaceAll('%s', 'variant_id');

    await customStatement('''
      INSERT OR IGNORE INTO cached_products (
        id, handle, title, vendor, product_type, tags, images,
        description_html, collection_handles, brand_override,
        category_override, created_at, updated_at
      )
      SELECT 'gid://shopify/Product/' || id, handle, title, vendor,
        product_type, tags, images, description_html, collection_handles,
        brand_override, category_override, created_at, updated_at
      FROM cached_products WHERE $productNumeric
    ''');
    await customStatement('''
      INSERT OR IGNORE INTO cached_variants (
        id, product_id, title, price, compare_at_price, available, sku
      )
      SELECT 'gid://shopify/ProductVariant/' || id,
        'gid://shopify/Product/' || product_id, title, price,
        compare_at_price, available, sku
      FROM cached_variants
      WHERE $variantNumeric AND $productReferenceNumeric
    ''');
    await customStatement('''
      INSERT OR IGNORE INTO wishlist_items (product_id, account_id, added_at)
      SELECT 'gid://shopify/Product/' || product_id, account_id, added_at
      FROM wishlist_items WHERE $productReferenceNumeric
    ''');
    await customStatement('''
      INSERT OR IGNORE INTO bag_lines (
        product_id, variant_id, account_id, quantity
      )
      SELECT 'gid://shopify/Product/' || product_id,
        CASE WHEN $variantReferenceNumeric
          THEN 'gid://shopify/ProductVariant/' || variant_id
          ELSE variant_id END,
        account_id, quantity
      FROM bag_lines WHERE $productReferenceNumeric
    ''');
    await customStatement('''
      UPDATE interaction_events
      SET product_id = 'gid://shopify/Product/' || product_id
      WHERE $productReferenceNumeric
    ''');

    await customStatement(
      'DELETE FROM wishlist_items WHERE $productReferenceNumeric',
    );
    await customStatement(
      'DELETE FROM bag_lines WHERE $productReferenceNumeric',
    );
    await customStatement(
      'DELETE FROM cached_variants WHERE $variantNumeric',
    );
    await customStatement(
      'DELETE FROM cached_products WHERE $productNumeric',
    );
  }

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
