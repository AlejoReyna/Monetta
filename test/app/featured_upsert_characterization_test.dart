library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/firestore/catalog_realtime_source.dart';
import 'package:monetta_app/data/local/catalog_cache_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/repositories/catalog_repository.dart';
import 'package:monetta_app/data/shopify/catalog_sync.dart';
import 'package:monetta_app/data/shopify/storefront_client.dart';
import 'package:monetta_app/data/shopify/storefront_config.dart';
import 'package:monetta_app/domain/product.dart';

class _Source implements CatalogRealtimeSource {
  _Source() {
    controller = StreamController<List<CatalogRealtimeDocument>>.broadcast(
      onListen: () {
        listens++;
        if (listens == 1) subscribed.complete();
        if (listens == 2) reconnected.complete();
      },
    );
  }

  int listens = 0;
  final subscribed = Completer<void>();
  final reconnected = Completer<void>();
  late final StreamController<List<CatalogRealtimeDocument>> controller;

  @override
  Stream<List<CatalogRealtimeDocument>> watchProducts() => controller.stream;
}

Product _product(String id) => Product(
      id: 'gid://shopify/Product/$id',
      handle: 'p-$id',
      title: 'Featured $id',
      vendor: 'Monetta',
      productType: 'Bolsa',
      tags: const [],
      variants: const [],
      images: const [],
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026, 10, 1),
    );

CatalogRealtimeDocument _document() => const CatalogRealtimeDocument(
      documentId: '987',
      data: {
        'schemaVersion': 1,
        'source': 'shopify',
        'id': 'gid://shopify/Product/987',
        'shopifyLegacyId': '987',
        'handle': 'live',
        'title': 'Live',
        'vendor': 'Monetta',
        'productType': 'Bolsa',
        'tags': <String>[],
        'descriptionHtml': '',
        'images': <String>[],
        'collectionHandles': <String>[],
        'variants': <Map<String, Object?>>[],
        'createdAt': '2026-01-01T00:00:00Z',
        'updatedAt': '2026-10-01T00:00:00Z',
        'isPublished': true,
      },
    );

Future<void> _until(CatalogStore store, bool Function() condition) async {
  if (condition()) return;
  final done = Completer<void>();
  void changed() {
    if (condition() && !done.isCompleted) done.complete();
  }

  store.addListener(changed);
  try {
    await done.future;
  } finally {
    store.removeListener(changed);
  }
}

class _SyncGate {
  final started = Completer<void>();
  final release = Completer<void>();

  CatalogSync get sync => CatalogSync(
        client: StorefrontClient(
          config: const StorefrontConfig(
            shopDomain: 'monetta.mx',
            accessToken: 'test-token',
          ),
          transport: (endpoint, headers, body) async {
            if (!started.isCompleted) started.complete();
            await release.future;
            return {
              'data': {
                'products': {
                  'pageInfo': {'hasNextPage': false, 'endCursor': null},
                  'edges': [
                    {
                      'node': {
                        'id': 'gid://shopify/Product/901',
                        'handle': 'full-sync',
                        'title': 'Full sync',
                        'vendor': 'Monetta',
                        'productType': 'Bolsa',
                        'tags': <String>[],
                        'createdAt': '2026-01-01T00:00:00Z',
                        'updatedAt': '2026-10-01T00:00:00Z',
                        'images': {'edges': <dynamic>[]},
                        'variants': {
                          'pageInfo': {'hasNextPage': false, 'endCursor': null},
                          'edges': <dynamic>[],
                        },
                        'collections': {
                          'pageInfo': {'hasNextPage': false, 'endCursor': null},
                          'edges': <dynamic>[],
                        },
                      },
                    },
                  ],
                },
              },
            };
          },
        ),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'CHAR-14 localOnly writes, reloads facets and notifies after persistence',
      () async {
    final db = openTestDatabase();
    final store = CatalogStore(database: db);
    addTearDown(store.dispose);
    await store.loadFromAsset();
    await store.syncWithShopify();
    final product = _product('999');
    var notifications = 0;
    store.addListener(() {
      notifications++;
      expect(store.products.any((p) => p.id == product.id), isTrue);
      expect(store.facetsFor(product.id), isNotNull);
    });
    await store.upsertShopifyProducts([product]);
    expect(notifications, 1);
    expect(
      (await CatalogCacheStore(db).allProducts())
          .any((p) => p.id == product.id),
      isTrue,
    );
  });

  test('CHAR-14 empty or not ready does not write or notify', () async {
    final db = openTestDatabase();
    final store = CatalogStore(database: db);
    addTearDown(store.dispose);
    var notifications = 0;
    store.addListener(() => notifications++);
    await store.upsertShopifyProducts([_product('999')]);
    expect(await CatalogCacheStore(db).allProducts(), isEmpty);
    expect(notifications, 0);
    await store.loadFromAsset();
    await store.syncWithShopify();
    final before = await CatalogCacheStore(db).allProducts();
    notifications = 0;
    await store.upsertShopifyProducts([]);
    expect(
      (await CatalogCacheStore(db).allProducts()).map((p) => p.id),
      before.map((p) => p.id),
    );
    expect(notifications, 0);
  });

  test('CHAR-14 failed write propagates without reload or notification',
      () async {
    final db = openTestDatabase();
    final store = CatalogStore(database: db);
    addTearDown(store.dispose);
    await store.loadFromAsset();
    await store.syncWithShopify();
    final before = store.products;
    await db.customStatement(
      "CREATE TRIGGER fail_featured BEFORE INSERT ON cached_products BEGIN SELECT RAISE(ABORT, 'featured write failed'); END",
    );
    var notifications = 0;
    store.addListener(() => notifications++);
    await expectLater(
      store.upsertShopifyProducts([_product('999')]),
      throwsA(
        predicate<Object>(
          (e) => e.toString().contains('featured write failed'),
        ),
      ),
    );
    expect(store.products, same(before));
    expect(notifications, 0);
    expect(
      (await CatalogCacheStore(db).allProducts())
          .any((p) => p.id == _product('999').id),
      isFalse,
    );
  });

// TARGET_TESTS_START
  for (final live in [false, true]) {
    test(
        'CHAR-14b ${live ? 'firestoreLive' : 'awaitingFirestore'} blocks featured cache writes',
        () async {
      final source = _Source();
      final db = openTestDatabase();
      final store = CatalogStore(database: db, realtimeSource: source);
      addTearDown(() async {
        store.dispose();
        await source.controller.close();
      });
      await store.loadFromAsset();
      await source.subscribed.future;
      if (live) {
        source.controller.add([_document()]);
        await _until(
          store,
          () => store.realtimeStatus == CatalogRealtimeStatus.live,
        );
      }
      final before = await CatalogCacheStore(db).allProducts();
      var notifications = 0;
      store.addListener(() => notifications++);
      await store.upsertShopifyProducts([_product('999')]);
      expect(
        (await CatalogCacheStore(db).allProducts()).map((p) => p.id),
        before.map((p) => p.id),
      );
      expect(notifications, 0);
    });
  }

  test(
      'CHAR-14b featured upsert waits for a full sync and survives replacement',
      () async {
    final gate = _SyncGate();
    final db = openTestDatabase();
    final store = CatalogStore(database: db, catalogSync: gate.sync);
    await store.loadFromAsset();
    await gate.started.future;
    final syncing = store.syncWithShopify();
    final order = <String>[];
    final synced = syncing.then((result) {
      order.add('sync');
      return result;
    });
    final upsert = store.upsertShopifyProducts([_product('999')]).then(
      (_) => order.add('featured'),
    );
    // Drain database reads while the transport remains explicitly blocked.
    await CatalogCacheStore(db).allProducts();
    gate.release.complete();
    final result = await synced;
    await upsert;
    final ids =
        (await CatalogCacheStore(db).allProducts()).map((p) => p.id).toSet();
    store.dispose();
    expect(result.outcome, CatalogSyncOutcome.updated);
    expect(order, ['sync', 'featured']);
    expect(ids, {_product('901').id, _product('999').id});
  });

  test(
      'CHAR-14b realtime status queued during sync preserves its newer metadata',
      () async {
    final gate = _SyncGate();
    final source = _Source();
    final db = openTestDatabase();
    final store = CatalogStore(
      database: db,
      realtimeSource: source,
      catalogSync: gate.sync,
    );
    await store.loadFromAsset();
    await source.subscribed.future;
    // Error enables fallback without completing the source or waiting for retry.
    source.controller.addError(StateError('offline'));
    await gate.started.future;
    final syncing = store.syncWithShopify();
    await source.reconnected.future;
    final sourceSeen = _until(
      store,
      () => store.realtimeStatus == CatalogRealtimeStatus.empty,
    );
    final recorded = _until(
      store,
      () => store.catalogMetadata?.status == CatalogCacheStatus.invalid,
    );
    source.controller.add([]);
    await sourceSeen;
    gate.release.complete();
    final result = await syncing;
    await recorded;
    final freshProducts = await CatalogCacheStore(db).allProducts();
    final fresh = CatalogCacheMetadata.forProducts(
      source: CatalogCacheSource.shopify,
      products: freshProducts,
      syncedAt: null,
      status: CatalogCacheStatus.healthy,
    );
    final actual = await CatalogCacheStore(db).metadata();
    store.dispose();
    await source.controller.close();
    expect(result.outcome, CatalogSyncOutcome.updated);
    expect(actual?.source, fresh.source);
    expect(actual?.productCount, 1);
    expect(actual?.fingerprint, fresh.fingerprint);
    expect(actual?.syncedAt, isNotNull);
    expect(actual?.status, CatalogCacheStatus.invalid);
    expect(actual?.detail, 'Vacío');
  });
  test(
      'CHAR-14b status rereads persisted metadata instead of a stale store copy',
      () async {
    final gate = _SyncGate();
    final source = _Source();
    final db = openTestDatabase();
    final store = CatalogStore(
      database: db,
      realtimeSource: source,
      catalogSync: gate.sync,
    );
    await store.loadFromAsset();
    await source.subscribed.future;
    final stale = store.catalogMetadata;
    source.controller.addError(StateError('offline'));
    await gate.started.future;
    final syncing = store.syncWithShopify();
    gate.release.complete();
    await syncing;
    final fresh = await CatalogCacheStore(db).metadata();
    await source.reconnected.future;
    store.catalogMetadata = stale;
    final recorded = _until(
      store,
      () => store.catalogMetadata?.status == CatalogCacheStatus.invalid,
    );
    source.controller.add([]);
    await recorded;
    final actual = await CatalogCacheStore(db).metadata();
    store.dispose();
    await source.controller.close();
    expect(actual?.source, CatalogCacheSource.shopify);
    expect(actual?.productCount, fresh?.productCount);
    expect(actual?.fingerprint, fresh?.fingerprint);
    expect(actual?.syncedAt, fresh?.syncedAt);
    expect(actual?.shopDomain, fresh?.shopDomain);
    expect(actual?.status, CatalogCacheStatus.invalid);
    expect(actual?.detail, 'Vacío');
  });
// TARGET_TESTS_END
}
