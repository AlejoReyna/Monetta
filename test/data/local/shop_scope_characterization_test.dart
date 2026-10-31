/// CHAR-03: characterization of the per-shop reset (R10, decision E11).
///
/// These tests pin what the code does today when the configured Storefront
/// domain does not match the provenance stored in the local database
/// (`CatalogRepository._cursorForConfiguredShop`). They open a frozen v7
/// database fixture as a real file, start the real `CatalogStore` and read the
/// rows back. Nothing here is a target behaviour: when a later work package
/// changes one of these rules, the matching test must change explicitly.
library;

import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/firestore/catalog_realtime_source.dart';
import 'package:monetta_app/data/local/catalog_cache_store.dart';
import 'package:monetta_app/data/local/bag_store.dart';
import 'package:monetta_app/data/local/database.dart' hide SyncCursor;
import 'package:monetta_app/data/local/sync_cursor_store.dart';
import 'package:monetta_app/data/local/wishlist_store.dart';
import 'package:monetta_app/data/normalize/rules.dart';
import 'package:monetta_app/data/repositories/catalog_repository.dart';
import 'package:monetta_app/data/shopify/catalog_sync.dart';

import '../../shopify/catalog_sync_test.dart' show FakeTransport, syncWith;

const _fixturePath = 'test/fixtures/db/monetta_v7_monetta_mx.sql';

const _tables = <String>[
  'cached_products',
  'cached_variants',
  'cached_collections',
  'sync_cursors',
  'catalog_states',
  'app_preferences',
  'wishlist_items',
  'bag_lines',
  'interaction_events',
  'devices',
  'accounts',
  'sessions',
  'order_summaries',
  'checkout_receipts',
];

/// Row counts of the fixture, per table.
const _fixtureCounts = <String, int>{
  'cached_products': 2,
  'cached_variants': 3,
  'cached_collections': 1,
  'sync_cursors': 1,
  'catalog_states': 1,
  'app_preferences': 1,
  'wishlist_items': 2,
  'bag_lines': 3,
  'interaction_events': 2,
  'devices': 1,
  'accounts': 1,
  'sessions': 1,
  'order_summaries': 1,
  'checkout_receipts': 1,
};

/// Tables that `CatalogCacheStore.resetShopState` plus the bag and wishlist
/// stores empty on a shop switch (cursor and metadata are rewritten, devices
/// are detached from the account but kept).
const _clearedByReset = <String>[
  'cached_products',
  'cached_variants',
  'cached_collections',
  'wishlist_items',
  'bag_lines',
  'interaction_events',
  'sessions',
  'order_summaries',
  'accounts',
];

const _accountId = 'acct-fixture-1';
const _productOne = 'gid://shopify/Product/9001';
const _productTwo = 'gid://shopify/Product/9002';
const _variantOne = 'gid://shopify/ProductVariant/9101';
const _variantTwo = 'gid://shopify/ProductVariant/9201';

typedef _Snapshot = Map<String, List<Map<String, Object?>>>;

/// Creates a temporary database file from the frozen SQL fixture.
Future<File> _installFixture() async {
  final dir = await Directory.systemTemp.createTemp('monetta-char03-');
  addTearDown(() => dir.delete(recursive: true));
  final file = File('${dir.path}/monetta.sqlite');
  final script = File(_fixturePath).readAsStringSync();
  final seed = AppDatabase(
    NativeDatabase(file, setup: (rawDb) => rawDb.execute(script)),
  );
  await seed.customSelect('SELECT 1').get();
  await seed.close();
  return file;
}

AppDatabase _open(File file) => AppDatabase(
      NativeDatabase(
        file,
        setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;'),
      ),
    );

Future<_Snapshot> _snapshot(AppDatabase db) async {
  final out = <String, List<Map<String, Object?>>>{};
  for (final table in _tables) {
    final rows =
        await db.customSelect('SELECT * FROM $table ORDER BY rowid').get();
    out[table] = [
      for (final row in rows) Map<String, Object?>.from(row.data),
    ];
  }
  return out;
}

Map<String, int> _counts(_Snapshot snapshot) =>
    {for (final entry in snapshot.entries) entry.key: entry.value.length};

/// Starts the real store and lets the background delta sync settle.
Future<CatalogStore> _start(
  AppDatabase db, {
  String? shopDomain,
  CatalogSync? catalogSync,
}) async {
  final store = CatalogStore(
    database: db,
    shopDomain: shopDomain,
    catalogSync: catalogSync,
  );
  await store.loadFromAsset();
  await store.syncWithShopify();
  return store;
}

/// Closes the database and waits for it before anyone reopens the file.
Future<void> _shutdown(CatalogStore store, AppDatabase db) async {
  await store.syncWithShopify();
  await db.close();
  store.dispose();
}

Map<String, int> _bagByVariant(CatalogStore store) => {
      for (final line in store.bagLines) line.variant.id: line.quantity,
    };

/// Every fixture row survives and the shopper state is visible by scope.
Future<void> _expectFixtureIntact(
  CatalogStore store,
  AppDatabase db,
  _Snapshot before,
) async {
  final after = await _snapshot(db);
  expect(_counts(after), _fixtureCounts);
  expect(after, equals(before));

  expect(store.products.map((product) => product.id).toSet(), {
    _productOne,
    _productTwo,
  });
  expect(store.catalogMetadata?.shopDomain, 'monetta.mx');
  expect(store.eventCount, 2);

  await store.setAccountScope(null);
  expect(_bagByVariant(store), {_variantOne: 2});
  expect(store.wishlist, {_productOne});

  await store.setAccountScope(_accountId);
  expect(_bagByVariant(store), {_variantOne: 1, _variantTwo: 3});
  expect(store.wishlist, {_productTwo});
  await store.setAccountScope(null);
}

/// Shared expectations for any reset: what is gone, what is kept.
void _expectShopReset(
  _Snapshot before,
  _Snapshot after, {
  required String shop,
}) {
  for (final table in _clearedByReset) {
    expect(after[table], isEmpty, reason: '$table is cleared by the reset');
  }
  expect(
    after['app_preferences'],
    equals(before['app_preferences']),
    reason: 'preferences are not shop state',
  );
  expect(
    after['checkout_receipts'],
    equals(before['checkout_receipts']),
    reason: 'purchase receipts are kept',
  );
  expect(after['devices'], [
    {...before['devices']!.single, 'account_id': null},
  ]);

  final cursor = after['sync_cursors']!.single;
  expect(cursor['id'], 0);
  expect(cursor['shop_domain'], shop);
  expect(cursor['last_updated_at'], isNull);
  expect(cursor['last_full_sync_at'], isNull);

  final state = after['catalog_states']!.single;
  expect(state['id'], 0);
  expect(state['source'], 'shopify');
  expect(state['status'], 'invalid');
  expect(state['product_count'], 0);
  expect(state['detail'], 'Full sync required after shop migration.');
  expect(state['shop_domain'], shop);
  expect(state['synced_at'], isNull);
}

class _ControlledSource implements CatalogRealtimeSource {
  final controller = StreamController<List<CatalogRealtimeDocument>>();

  @override
  Stream<List<CatalogRealtimeDocument>> watchProducts() => controller.stream;
}

/// Lets the unawaited cache writes and stream events settle.
Future<void> _settleUntil(bool Function() done) async {
  for (var attempt = 0; attempt < 50 && !done(); attempt += 1) {
    await pumpEventQueue();
  }
}

/// A Storefront transport whose only page is malformed, so every sync fails.
CatalogSync _failingSync() => syncWith(
      FakeTransport([
        {
          'data': {'products': null},
        },
      ]),
    );

NormalizationRules _emptyRules() => NormalizationRules.fromJson(const {
      'brands': <dynamic>[],
      'categories': <dynamic>[],
      'silhouettes': <dynamic>[],
      'colors': <dynamic>[],
      'patterns': <dynamic>[],
      'facetWeights': <String, dynamic>{},
      'newArrivalDays': 30,
    });

CatalogRealtimeDocument _firestoreDocument() => const CatalogRealtimeDocument(
      documentId: '987',
      data: {
        'schemaVersion': 1,
        'source': 'shopify',
        'id': 'gid://shopify/Product/987',
        'shopifyLegacyId': '987',
        'handle': 'realtime-product',
        'title': 'Producto desde Firestore',
        'vendor': 'Monetta',
        'productType': 'Bolsa',
        'tags': <String>[],
        'descriptionHtml': '',
        'images': <String>[],
        'collectionHandles': <String>[],
        'brandOverride': null,
        'categoryOverride': null,
        'variants': <Map<String, Object?>>[],
        'createdAt': '2026-08-01T00:00:00Z',
        'updatedAt': '2026-08-27T00:00:00Z',
        'publishedAt': '2026-08-01T00:00:00Z',
        'isPublished': true,
        'isInStock': false,
        'minPrice': 0,
      },
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'CHAR-03 (vigente, ver E11) el fixture es v7: esquema idéntico al que '
      'crea AppDatabase y user_version 7', () async {
    final file = await _installFixture();

    int? versionBeforeDrift;
    final fixtureDb = AppDatabase(
      NativeDatabase(
        file,
        setup: (rawDb) {
          versionBeforeDrift =
              rawDb.select('PRAGMA user_version').first.columnAt(0) as int;
        },
      ),
    );
    final fresh = openTestDatabase();

    Future<Map<String, String>> schemaOf(AppDatabase db) async {
      final rows = await db
          .customSelect(
            'SELECT name, sql FROM sqlite_master '
            "WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%'",
          )
          .get();
      return {
        for (final row in rows)
          row.read<String>('name'): row.read<String>('sql'),
      };
    }

    final fixtureSchema = await schemaOf(fixtureDb);
    final freshSchema = await schemaOf(fresh);

    expect(fixtureDb.schemaVersion, 7);
    expect(versionBeforeDrift, 7);
    expect(freshSchema.keys.toSet(), _tables.toSet());
    expect(fixtureSchema, equals(freshSchema));
    expect(_counts(await _snapshot(fixtureDb)), _fixtureCounts);

    await fixtureDb.close();
    await fresh.close();
  });

  test(
      'CHAR-03 (vigente, ver E11) mismo dominio: no pierde ninguna fila ni '
      'el catálogo del fixture, antes y después de reabrir', () async {
    final file = await _installFixture();

    var db = _open(file);
    final before = await _snapshot(db);
    expect(_counts(before), _fixtureCounts);
    var store = await _start(db, shopDomain: 'monetta.mx');
    await _expectFixtureIntact(store, db, before);
    await _shutdown(store, db);

    db = _open(file);
    store = await _start(db, shopDomain: 'monetta.mx');
    await _expectFixtureIntact(store, db, before);
    await _shutdown(store, db);
  });

  test(
      'CHAR-03 (vigente, ver E11) dominio distinto: borra exactamente lo de '
      'resetShopState, conserva preferencias, recibos y device, y no siembra '
      'el asset', () async {
    final file = await _installFixture();
    const newShop = 'fakcei-n9.myshopify.com';

    var db = _open(file);
    final before = await _snapshot(db);
    var store = await _start(db, shopDomain: newShop);

    final after = await _snapshot(db);
    _expectShopReset(before, after, shop: newShop);
    expect(store.products, isEmpty, reason: 'the asset is not seeded');
    expect(store.bagQuantity, 0);
    expect(store.wishlist, isEmpty);
    expect(store.eventCount, 0);
    expect(store.catalogMetadata?.status, CatalogCacheStatus.invalid);
    expect(store.catalogMetadata?.shopDomain, newShop);
    await _shutdown(store, db);

    // The empty catalog is sticky until a verified full sync replaces it.
    db = _open(file);
    store = await _start(db, shopDomain: newShop);
    expect(store.products, isEmpty);
    expect(await _snapshot(db), equals(after));
    await _shutdown(store, db);
  });

  test(
      'CHAR-03 (vigente, ver E11) dominio que sólo difiere en mayúsculas: '
      'también hay reset porque la comparación es exacta', () async {
    final file = await _installFixture();

    final db = _open(file);
    final before = await _snapshot(db);
    final store = await _start(db, shopDomain: 'Monetta.mx');

    _expectShopReset(before, await _snapshot(db), shop: 'Monetta.mx');
    expect(store.products, isEmpty);
    await _shutdown(store, db);
  });

  test(
      'CHAR-03 (vigente, ver E11) dominio configurado null o vacío: no hay '
      'reset ni pérdida', () async {
    for (final shopDomain in <String?>[null, '']) {
      final file = await _installFixture();
      final db = _open(file);
      final before = await _snapshot(db);
      final store = await _start(db, shopDomain: shopDomain);
      await _expectFixtureIntact(store, db, before);
      await _shutdown(store, db);
    }
  });

  test(
      'CHAR-03 (vigente, ver E11) base sin catálogo pero con una bolsa sin '
      'procedencia: el arranque con dominio configurado la borra', () async {
    final dir = await Directory.systemTemp.createTemp('monetta-char03-bag-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/monetta.sqlite');

    var db = _open(file);
    await db.customStatement(
      'INSERT INTO bag_lines (product_id, variant_id, account_id, quantity) '
      "VALUES ('gid://shopify/Product/1', 'gid://shopify/ProductVariant/1', "
      "'', 2)",
    );
    await db.close();

    db = _open(file);
    final store = await _start(db, shopDomain: 'monetta.mx');
    final after = await _snapshot(db);
    expect(after['bag_lines'], isEmpty);
    expect(after['catalog_states']!.single['status'], 'invalid');
    expect(after['sync_cursors']!.single['shop_domain'], 'monetta.mx');
    expect(store.products, isEmpty);
    expect(store.bagQuantity, 0);
    await _shutdown(store, db);
  });

  test(
      'CHAR-03 (objetivo RF-24) un snapshot de Firestore registra la tienda '
      'configurada y el siguiente arranque con monetta.mx no hace reset',
      () async {
    final file = await _installFixture();

    var db = _open(file);
    final before = await _snapshot(db);
    final source = _ControlledSource();
    var store = CatalogStore(
      database: db,
      shopDomain: 'monetta.mx',
      realtimeSource: source,
    );
    await store.loadFromAsset();
    source.controller.add([_firestoreDocument()]);
    await _settleUntil(
      () => store.products.any((p) => p.id == 'gid://shopify/Product/987'),
    );
    expect(store.products.map((p) => p.id), ['gid://shopify/Product/987']);

    // The snapshot replaced the catalog and its metadata names the shop.
    final afterSnapshot = await _snapshot(db);
    final metadata = afterSnapshot['catalog_states']!.single;
    expect(metadata['source'], 'firestore');
    expect(metadata['shop_domain'], 'monetta.mx');
    expect(afterSnapshot['cached_products']!.single['id'], contains('987'));
    await db.close();
    store.dispose();
    await source.controller.close();

    // Restarting on the very same shop is not "another shop".
    db = _open(file);
    store = CatalogStore(database: db, shopDomain: 'monetta.mx');
    await store.loadFromAsset();
    await store.syncWithShopify();
    final after = await _snapshot(db);
    for (final table in const [
      'accounts',
      'sessions',
      'bag_lines',
      'wishlist_items',
      'order_summaries',
      'interaction_events',
      'devices',
    ]) {
      expect(after[table], equals(before[table]), reason: '$table is kept');
    }
    expect(after['devices']!.single['account_id'], _accountId);
    expect(
      store.products.map((product) => product.id).toList(),
      ['gid://shopify/Product/987'],
    );
    await _shutdown(store, db);
  });

  test(
      'CHAR-03 (objetivo RF-24) instalación nueva sin red en el primer '
      'arranque: el sync fallido conserva el asset sembrado y el segundo '
      'arranque sigue con catálogo', () async {
    final dir = await Directory.systemTemp.createTemp('monetta-char03-new-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/monetta.sqlite');

    // First launch: empty database, no network.
    var db = _open(file);
    var store = await _start(
      db,
      shopDomain: 'monetta.mx',
      catalogSync: _failingSync(),
    );
    // `_start` seeded the asset and already awaited the first (failed) sync.
    final firstLaunchIds = store.products.map((p) => p.id).toSet();
    expect(firstLaunchIds, isNotEmpty);

    // The failed sync must not run the shop reset over the seeded asset.
    final afterFirst = await _snapshot(db);
    expect(afterFirst['cached_products'], isNotEmpty);
    expect(afterFirst['cached_variants'], isNotEmpty);
    final state = afterFirst['catalog_states']!.single;
    expect(state['source'], 'asset');
    expect(state['status'], 'unavailable');
    expect(state['shop_domain'], 'monetta.mx');
    expect(afterFirst['sync_cursors'], hasLength(1));
    final cursor = afterFirst['sync_cursors']!.single;
    expect(cursor['shop_domain'], 'monetta.mx');
    expect(cursor['last_updated_at'], isNull);
    expect(cursor['last_full_sync_at'], isNull);
    await _shutdown(store, db);

    // Second launch, same shop, still offline: the catalog is still there.
    db = _open(file);
    store = await _start(db, shopDomain: 'monetta.mx');
    expect(store.products, isNotEmpty);
    expect(store.products.map((p) => p.id).toSet(), firstLaunchIds);
    await _shutdown(store, db);
  });

  test(
      'CHAR-03 (objetivo RF-24) instalación nueva: el primer arranque guarda '
      'el cursor con la tienda configurada y la semilla registra su tienda',
      () async {
    final dir = await Directory.systemTemp.createTemp('monetta-char03-seed-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/monetta.sqlite');

    final db = _open(file);
    final store = await _start(db, shopDomain: 'monetta.mx');
    final after = await _snapshot(db);

    expect(after['sync_cursors'], hasLength(1));
    final cursor = after['sync_cursors']!.single;
    expect(cursor['shop_domain'], 'monetta.mx');
    expect(cursor['last_updated_at'], isNull);
    expect(cursor['last_full_sync_at'], isNull);
    final state = after['catalog_states']!.single;
    expect(state['source'], 'asset');
    expect(state['shop_domain'], 'monetta.mx');
    expect(store.products, isNotEmpty);
    await _shutdown(store, db);
  });

  test(
      'CHAR-03 (guarda RF-24) instalación nueva con otra tienda configurada: '
      'el asset de monetta.mx se borra en el primer sync y no vuelve',
      () async {
    final dir = await Directory.systemTemp.createTemp('monetta-char03-other-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/monetta.sqlite');
    const otherShop = 'fakcei-n9.myshopify.com';

    var db = _open(file);
    var store = await _start(
      db,
      shopDomain: otherShop,
      catalogSync: _failingSync(),
    );
    final afterFirst = await _snapshot(db);
    expect(afterFirst['cached_products'], isEmpty);
    expect(afterFirst['cached_variants'], isEmpty);
    final state = afterFirst['catalog_states']!.single;
    expect(state['source'], 'shopify');
    expect(state['status'], 'unavailable');
    expect(state['shop_domain'], otherShop);
    await _shutdown(store, db);

    db = _open(file);
    store = await _start(db, shopDomain: otherShop);
    expect(store.products, isEmpty);
    expect((await _snapshot(db))['cached_products'], isEmpty);
    await _shutdown(store, db);
  });

  test(
      'CHAR-03 (guarda RF-24) asset sin _source: la semilla queda sin '
      'procedencia y el primer sync la trata como otra tienda', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final cache = CatalogCacheStore(db);
    final repository = CatalogRepository(
      cache: cache,
      cursorStore: SyncCursorStore(db),
      rules: _emptyRules(),
      catalogSync: _failingSync(),
      shopDomain: 'monetta.mx',
      bagStore: BagStore(db),
      wishlistStore: WishlistStore(db),
    );

    await repository.seedFromAssetIfEmpty({
      'products': [
        {
          'id': 1,
          'handle': 'p1',
          'title': 'Bolsa',
          'vendor': 'Monetta',
          'product_type': 'Bolsa',
          'tags': <String>[],
          'images': <String>[],
          'created_at': '2026-07-01T00:00:00Z',
          'updated_at': '2026-08-01T00:00:00Z',
          'variants': [
            {
              'id': 11,
              'title': 'Default Title',
              'price': '100.00',
              'available': true,
            },
          ],
        },
      ],
    });
    expect(await cache.isEmpty(), isFalse, reason: 'the asset was seeded');
    expect((await cache.metadata())?.shopDomain, isNull);

    final result = await repository.sync();
    expect(result.outcome, CatalogSyncOutcome.failed);
    expect(await cache.isEmpty(), isTrue);
    expect((await cache.metadata())?.shopDomain, 'monetta.mx');
  });
}
