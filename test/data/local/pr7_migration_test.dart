import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/catalog_cache_store.dart';
import 'package:monetta_app/data/local/bag_store.dart';
import 'package:monetta_app/data/local/wishlist_store.dart';
import 'package:monetta_app/data/local/sync_cursor_store.dart';
import 'package:monetta_app/data/normalize/rules.dart';
import 'package:monetta_app/data/repositories/catalog_repository.dart';
import '../../shopify/catalog_sync_test.dart'
    show FakeTransport, page, productNode, syncWith;

void main() {
  test('R3 empty catalog does not permit legacy account/session reuse',
      () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final now = DateTime.now();
    await db.into(db.accounts).insert(
          AccountsCompanion.insert(
            localAccountId: 'old-account',
            createdAt: now,
            lastSeenAt: now,
          ),
        );
    await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            accountId: 'old-account',
            secureStorageKeyRef: 'old-secure-reference',
            accessTokenExpiresAt: now.add(const Duration(days: 1)),
            createdAt: now,
          ),
        );
    final repo = CatalogRepository(
      cache: CatalogCacheStore(db),
      cursorStore: SyncCursorStore(db),
      rules: NormalizationRules.fromJson(const {}),
      shopDomain: 'new-shop.example',
    );
    await repo.prepareConfiguredShop();
    expect(await db.select(db.accounts).get(), isEmpty);
    expect(await db.select(db.sessions).get(), isEmpty);
    expect((await SyncCursorStore(db).load()).shopDomain, 'new-shop.example');
    await repo.seedFromAssetIfEmpty(const {});
    expect((await repo.loadCached()).products, isEmpty);
  });

  test(
      'R3 actual v5 keys/null provenance migrate before failed new-shop sync and restart',
      () async {
    final dir = await Directory.systemTemp.createTemp('monetta-pr7-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/db.sqlite');
    final old = AppDatabase(NativeDatabase(file));
    await old.customSelect('SELECT 1').get();
    // Recreate the actual schema-5 definitions from 766bbe8^, rather than
    // only changing user_version on schema-7 tables.
    await old.customStatement('DROP TABLE checkout_receipts');
    await old
        .customStatement('ALTER TABLE sync_cursors DROP COLUMN shop_domain');
    await old
        .customStatement('ALTER TABLE catalog_states DROP COLUMN shop_domain');
    await old.customStatement('DROP TABLE bag_lines');
    await old.customStatement(
      'CREATE TABLE bag_lines (product_id TEXT NOT NULL PRIMARY KEY, variant_id TEXT NOT NULL, account_id TEXT, quantity INTEGER NOT NULL)',
    );
    await old.customStatement('DROP TABLE wishlist_items');
    await old.customStatement(
      'CREATE TABLE wishlist_items (product_id TEXT NOT NULL PRIMARY KEY, account_id TEXT, added_at INTEGER NOT NULL)',
    );
    await old.customStatement('DROP TABLE order_summaries');
    await old.customStatement(
      'CREATE TABLE order_summaries (id TEXT NOT NULL PRIMARY KEY, account_id TEXT NOT NULL REFERENCES accounts(local_account_id) ON DELETE CASCADE, shopify_order_id TEXT, source TEXT NOT NULL, attribution_code TEXT, status TEXT NOT NULL, total_amount REAL NOT NULL, currency_code TEXT NOT NULL, placed_at INTEGER NOT NULL)',
    );
    await old.customStatement(
      "INSERT INTO bag_lines VALUES ('staging-product','staging-variant',NULL,2)",
    );
    await old.customStatement(
      "INSERT INTO wishlist_items VALUES ('staging-product',NULL,1)",
    );
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await old.customStatement(
      'INSERT INTO sync_cursors (id,last_updated_at,last_full_sync_at) VALUES (0,?,?)',
      [now, now],
    );
    await old.customStatement('PRAGMA user_version = 5');
    await old.close();
    final db = AppDatabase(NativeDatabase(file));
    expect((await BagStore(db).all()).single.variantId, 'staging-variant');
    expect(
      await WishlistStore(db).allProductIds(),
      contains('staging-product'),
    );
    expect((await SyncCursorStore(db).load()).shopDomain, isNull);
    final repo = CatalogRepository(
      cache: CatalogCacheStore(db),
      cursorStore: SyncCursorStore(db),
      rules: NormalizationRules.fromJson(const {}),
      shopDomain: 'monetta.mx',
      catalogSync: syncWith(
        FakeTransport([
          {
            'data': {'products': null},
          }
        ]),
      ),
    );
    expect((await repo.sync()).outcome, CatalogSyncOutcome.failed);
    expect(await BagStore(db).all(), isEmpty);
    expect(await WishlistStore(db).allProductIds(), isEmpty);
    expect((await SyncCursorStore(db).load()).lastFullSyncAt, isNull);
    await db.close();
    final restarted = AppDatabase(NativeDatabase(file));
    addTearDown(restarted.close);
    final next = CatalogRepository(
      cache: CatalogCacheStore(restarted),
      cursorStore: SyncCursorStore(restarted),
      rules: NormalizationRules.fromJson(const {}),
      shopDomain: 'monetta.mx',
      catalogSync: syncWith(
        FakeTransport([
          page([productNode(id: '900', updatedAt: '2026-09-07T00:00:00Z')]),
        ]),
      ),
    );
    await next.seedFromAssetIfEmpty(const {});
    expect((await next.loadCached()).products, isEmpty);
    expect((await next.sync()).outcome, CatalogSyncOutcome.updated);
    expect(
      (await next.loadCached()).products.single.id,
      'gid://shopify/Product/900',
    );
    expect((await SyncCursorStore(restarted).load()).shopDomain, 'monetta.mx');
  });
}
