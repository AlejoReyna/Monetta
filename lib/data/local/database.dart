/// The on-device SQLite database — the real implementation of the `data/local`
/// module `docs/ARCHITECTURE.md` has described since Phase 1 planning, wired
/// up for the first time here.
///
/// The connection is injected (see [openConnection] vs the constructor)
/// rather than owned, so tests run against `NativeDatabase.memory()` with no
/// disk I/O and no plugin channel.
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
    CheckoutReceipts,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Opens the real on-device file, under the app's support directory (not
  /// documents — this is app data, not something the shopper should see in
  /// the Files app).
  factory AppDatabase.connect() => AppDatabase(_openConnection());

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) => migrator.createAll(),
        onUpgrade: (migrator, from, to) async {
          if (from < 2) await _migrateShopifyIdsToGids();
          if (from < 3) await migrator.createTable(appPreferences);
          if (from < 4) await migrator.createTable(catalogStates);
          if (from < 5) {
            // `createTable` is intentionally idempotent, but `addColumn` is
            // not. A partially upgraded install (or a fixture that carries a
            // newer table while retaining an older user_version) can already
            // have this column. Inspect the actual SQLite schema before
            // issuing the ALTER TABLE so reopening it remains safe.
            final columns = await customSelect(
              'PRAGMA table_info(${appPreferences.actualTableName})',
            ).get();
            final hasOnboardingState = columns.any(
              (row) => row.read<String>('name') == 'onboarding_state',
            );
            if (!hasOnboardingState) {
              await migrator.addColumn(
                appPreferences,
                appPreferences.onboardingState,
              );
            }
          }
          if (from < 6) await _migrateShopScopeAndBagVariantKeys();
          if (from < 7) {
            await migrator.createTable(checkoutReceipts);
            // History is a remote cache. Rebuild its key without reinterpreting
            // the old display-number-as-ID values as canonical identities.
            await customStatement(
              'ALTER TABLE order_summaries RENAME TO order_summaries_v6',
            );
            await migrator.createTable(orderSummaries);
            await customStatement(
              'INSERT INTO order_summaries (id, account_id, shopify_order_id, display_number, source, attribution_code, status, total_amount, currency_code, placed_at) SELECT id, account_id, CASE WHEN id LIKE \'gid://shopify/Order/%\' THEN id ELSE shopify_order_id END, CASE WHEN id LIKE \'gid://shopify/Order/%\' THEN shopify_order_id ELSE NULL END, source, attribution_code, status, total_amount, currency_code, placed_at FROM order_summaries_v6',
            );
            await customStatement('DROP TABLE order_summaries_v6');
          }
        },
        beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON;'),
      );

  /// Version 6 namespaces catalog authority by shop and rekeys bag/wishlist so
  /// variants and accounts cannot collide on the same device.
  Future<void> _migrateShopScopeAndBagVariantKeys() async {
    await _addColumnIfMissing('sync_cursors', 'shop_domain', 'TEXT');
    await _addColumnIfMissing('catalog_states', 'shop_domain', 'TEXT');

    await customStatement(
      'CREATE TABLE IF NOT EXISTS wishlist_items_v6 ('
      'product_id TEXT NOT NULL, '
      "account_id TEXT NOT NULL DEFAULT '', "
      'added_at INTEGER NOT NULL, '
      'PRIMARY KEY (product_id, account_id)'
      ')',
    );
    await customStatement(
      'INSERT OR IGNORE INTO wishlist_items_v6 (product_id, account_id, added_at) '
      "SELECT product_id, COALESCE(account_id, ''), added_at FROM wishlist_items",
    );
    await customStatement('DROP TABLE wishlist_items');
    await customStatement(
      'ALTER TABLE wishlist_items_v6 RENAME TO wishlist_items',
    );

    await customStatement(
      'CREATE TABLE IF NOT EXISTS bag_lines_v6 ('
      'product_id TEXT NOT NULL, '
      'variant_id TEXT NOT NULL, '
      "account_id TEXT NOT NULL DEFAULT '', "
      'quantity INTEGER NOT NULL, '
      'PRIMARY KEY (variant_id, account_id)'
      ')',
    );
    await customStatement(
      'INSERT OR IGNORE INTO bag_lines_v6 ('
      'product_id, variant_id, account_id, quantity'
      ') '
      "SELECT product_id, variant_id, COALESCE(account_id, ''), quantity "
      'FROM bag_lines',
    );
    await customStatement('DROP TABLE bag_lines');
    await customStatement('ALTER TABLE bag_lines_v6 RENAME TO bag_lines');
  }

  Future<void> _addColumnIfMissing(
    String table,
    String column,
    String typeSql,
  ) async {
    final columns = await customSelect('PRAGMA table_info($table)').get();
    final exists = columns.any((row) => row.read<String>('name') == column);
    if (exists) return;
    await customStatement(
      'ALTER TABLE $table ADD COLUMN $column $typeSql',
    );
  }

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
