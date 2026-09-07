/// Proves `CatalogRepository` actually wires `data/local` and `data/shopify`
/// together — a real sync run (via a fake transport, no network) lands in
/// the Drift cache and advances a cursor that survives the call.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/local/catalog_cache_store.dart';
import 'package:monetta_app/data/local/database.dart' hide SyncCursor;
import 'package:monetta_app/data/local/sync_cursor_store.dart';
import 'package:monetta_app/data/normalize/rules.dart';
import 'package:monetta_app/data/repositories/catalog_repository.dart';
import 'package:monetta_app/data/shopify/catalog_sync.dart';
import 'package:monetta_app/data/shopify/storefront_client.dart';
import 'package:monetta_app/data/shopify/storefront_config.dart';
import 'package:monetta_app/domain/product.dart';

class _FakeTransport {
  _FakeTransport(this.pages);
  final List<Map<String, dynamic>> pages;
  int _call = 0;

  Future<Map<String, dynamic>> call(
    Uri endpoint,
    Map<String, String> headers,
    String body,
  ) async {
    final page = pages[_call.clamp(0, pages.length - 1)];
    _call++;
    return page;
  }
}

Map<String, dynamic> _productNode({
  required String id,
  required String updatedAt,
}) =>
    {
      'id': 'gid://shopify/Product/$id',
      'handle': 'p-$id',
      'title': 'Bolsa Guess Crossbody',
      'vendor': 'Monetta ',
      'productType': '',
      'tags': <String>['Guess'],
      'descriptionHtml': '',
      'createdAt': '2026-07-01T10:00:00-06:00',
      'updatedAt': updatedAt,
      'images': {
        'edges': [
          {
            'node': {'url': 'https://cdn.shopify.com/x.jpg'},
          },
        ],
      },
      'variants': {
        'edges': [
          {
            'node': {
              'id': 'gid://shopify/ProductVariant/$id',
              'title': 'Default Title',
              'availableForSale': true,
              'price': {'amount': '1749.00', 'currencyCode': 'MXN'},
              'compareAtPrice': null,
              'sku': null,
            },
          },
        ],
      },
      'collections': {'edges': <dynamic>[]},
    };

Map<String, dynamic> _page(
  List<Map<String, dynamic>> nodes, {
  bool hasNextPage = false,
  String? endCursor,
}) =>
    {
      'data': {
        'products': {
          'pageInfo': {'hasNextPage': hasNextPage, 'endCursor': endCursor},
          'edges': nodes.map((n) => {'node': n}).toList(),
        },
      },
    };

NormalizationRules _emptyRules() => NormalizationRules.fromJson(const {
      'brands': <dynamic>[],
      'categories': <dynamic>[],
      'silhouettes': <dynamic>[],
      'colors': <dynamic>[],
      'patterns': <dynamic>[],
      'facetWeights': <String, dynamic>{},
      'newArrivalDays': 30,
    });

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  group('CatalogRepository', () {
    test('sync() is a safe no-op when Shopify is not configured', () async {
      final repo = CatalogRepository(
        cache: CatalogCacheStore(db),
        cursorStore: SyncCursorStore(db),
        rules: _emptyRules(),
      );

      expect(repo.canSyncWithShopify, isFalse);
      final result = await repo.sync();
      expect(result.outcome, CatalogSyncOutcome.skippedNotConfigured);
    });

    test(
        'seedFromAssetIfEmpty writes the bundled snapshot only on a cold cache',
        () async {
      final cache = CatalogCacheStore(db);
      final repo = CatalogRepository(
        cache: cache,
        cursorStore: SyncCursorStore(db),
        rules: _emptyRules(),
      );

      final snapshotJson = {
        'products': [
          {
            'id': 1,
            'handle': 'p1',
            'title': 'Bolsa',
            'vendor': 'Monetta',
            'product_type': 'Bolsa',
            'tags': <String>[],
            'description_html': '<p>Descripción Shopify</p>',
            'images': <String>[],
            'created_at': '2026-01-01T00:00:00Z',
            'updated_at': '2026-01-01T00:00:00Z',
            'variants': [
              {
                'id': 11,
                'title': 'Default Title',
                'price': '999.00',
                'available': true,
                'compare_at_price': null,
              },
            ],
          },
        ],
      };

      await repo.seedFromAssetIfEmpty(snapshotJson);
      final seeded = await cache.allProducts();
      expect(seeded.single.id, 'gid://shopify/Product/1');
      expect(
        seeded.single.variants.single.id,
        'gid://shopify/ProductVariant/11',
      );
      expect(seeded.single.descriptionHtml, '<p>Descripción Shopify</p>');
      final metadata = await cache.metadata();
      expect(metadata?.source, CatalogCacheSource.asset);
      expect(metadata?.productCount, seeded.length);
      expect(metadata?.fingerprint, isNotEmpty);

      // A second seed call must not touch an already-populated cache.
      await cache.upsertProducts([]); // no-op, cache still has the seeded row
      await repo.seedFromAssetIfEmpty({
        'products': [
          {
            'id': 2,
            'handle': 'p2',
            'title': 'Other',
            'vendor': 'Monetta',
            'product_type': 'Bolsa',
            'tags': <String>[],
            'images': <String>[],
            'created_at': '2026-01-01T00:00:00Z',
            'updated_at': '2026-01-01T00:00:00Z',
            'variants': <Map<String, dynamic>>[],
          },
        ],
      });
      expect(await cache.allProducts(), hasLength(1));
    });

    test('asset repair backfills only a missing cached description', () async {
      final cache = CatalogCacheStore(db);
      final repo = CatalogRepository(
        cache: cache,
        cursorStore: SyncCursorStore(db),
        rules: _emptyRules(),
      );
      await repo.seedFromAssetIfEmpty({
        'products': [
          {
            'id': 1,
            'handle': 'cached-handle',
            'title': 'Nombre guardado',
            'vendor': 'Monetta',
            'product_type': 'Bolsa',
            'tags': <String>[],
            'images': <String>[],
            'created_at': '2026-01-01T00:00:00Z',
            'updated_at': '2026-08-30T00:00:00Z',
            'variants': <Map<String, dynamic>>[],
          },
        ],
      });

      await repo.addMissingFromAsset({
        'products': [
          {
            'id': 1,
            'handle': 'older-asset-handle',
            'title': 'Nombre obsoleto',
            'vendor': 'Monetta',
            'product_type': 'Bolsa',
            'tags': <String>[],
            'description_html': '<p>Descripción recuperada</p>',
            'images': <String>[],
            'created_at': '2026-01-01T00:00:00Z',
            'updated_at': '2026-01-01T00:00:00Z',
            'variants': <Map<String, dynamic>>[],
          },
        ],
      });

      final repaired = (await cache.allProducts()).single;
      expect(repaired.title, 'Nombre guardado');
      expect(repaired.handle, 'cached-handle');
      expect(repaired.descriptionHtml, '<p>Descripción recuperada</p>');
    });

    test('the bundled asset cannot mutate an authoritative remote cache',
        () async {
      final cache = CatalogCacheStore(db);
      final remote = Product(
        id: 'gid://shopify/Product/99',
        handle: 'remote',
        title: 'Remoto',
        vendor: 'Monetta',
        productType: 'Bolsa',
        tags: const [],
        variants: const [],
        images: const [],
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      await cache.replaceProducts(
        [remote],
        metadata: CatalogCacheMetadata.forProducts(
          source: CatalogCacheSource.firestore,
          products: [remote],
          syncedAt: DateTime.utc(2026, 8, 30),
          status: CatalogCacheStatus.healthy,
        ),
      );
      final repo = CatalogRepository(
        cache: cache,
        cursorStore: SyncCursorStore(db),
        rules: _emptyRules(),
      );

      await repo.addMissingFromAsset({
        'products': [
          {
            'id': 1,
            'handle': 'stale-asset',
            'title': 'Obsoleto',
            'vendor': 'Monetta',
            'product_type': 'Bolsa',
            'tags': <String>[],
            'images': <String>[],
            'created_at': '2026-01-01T00:00:00Z',
            'updated_at': '2026-01-01T00:00:00Z',
            'variants': <Map<String, dynamic>>[],
          },
        ],
      });

      expect((await cache.allProducts()).single.id, remote.id);
    });

    test(
        'sync() runs a real delta sync via a fake transport and writes into the cache',
        () async {
      final cache = CatalogCacheStore(db);
      final cursorStore = SyncCursorStore(db);
      final transport = _FakeTransport([
        _page([_productNode(id: '1', updatedAt: '2026-08-01T00:00:00Z')]),
      ]);
      final catalogSync = CatalogSync(
        client: StorefrontClient(
          config: const StorefrontConfig(
            shopDomain: 'monetta.mx',
            accessToken: 'test-token',
          ),
          transport: transport.call,
        ),
      );
      final repo = CatalogRepository(
        cache: cache,
        cursorStore: cursorStore,
        rules: _emptyRules(),
        catalogSync: catalogSync,
      );

      expect(repo.canSyncWithShopify, isTrue);
      final result = await repo.sync();

      expect(result.outcome, CatalogSyncOutcome.updated);
      expect(result.changedCount, 1);
      expect(await cache.allProducts(), hasLength(1));

      final cursor = await cursorStore.load();
      expect(cursor.isFirstRun, isFalse);
      expect(cursor.lastFullSyncAt, isNotNull);
    });

    test('loadCached() normalizes cached products via the real normalizer',
        () async {
      final cache = CatalogCacheStore(db);
      final repo = CatalogRepository(
        cache: cache,
        cursorStore: SyncCursorStore(db),
        rules: _emptyRules(),
      );

      final empty = await repo.loadCached();
      expect(empty.products, isEmpty);

      await repo.seedFromAssetIfEmpty({
        'products': [
          {
            'id': 1,
            'handle': 'p1',
            'title': 'Bolsa',
            'vendor': 'Monetta',
            'product_type': 'Bolsa',
            'tags': <String>[],
            'images': <String>[],
            'created_at': '2026-01-01T00:00:00Z',
            'updated_at': '2026-01-01T00:00:00Z',
            'variants': <Map<String, dynamic>>[],
          },
        ],
      });

      final snapshot = await repo.loadCached();
      expect(snapshot.products, hasLength(1));
      expect(
        snapshot.facetsById.containsKey('gid://shopify/Product/1'),
        isTrue,
      );
    });

    test('full sync A+B then B-only removes A (F08)', () async {
      final cache = CatalogCacheStore(db);
      final cursorStore = SyncCursorStore(db);
      final transport = _FakeTransport([
        _page([
          _productNode(id: '101', updatedAt: '2026-08-01T00:00:00Z'),
          _productNode(id: '102', updatedAt: '2026-08-02T00:00:00Z'),
        ]),
      ]);
      final repo = CatalogRepository(
        cache: cache,
        cursorStore: cursorStore,
        rules: _emptyRules(),
        catalogSync: CatalogSync(
          client: StorefrontClient(
            config: const StorefrontConfig(
              shopDomain: 'monetta.mx',
              accessToken: 'test-token',
            ),
            transport: transport.call,
          ),
          fullResyncInterval: Duration.zero,
        ),
        shopDomain: 'monetta.mx',
      );

      final first = await repo.sync();
      expect(first.outcome, CatalogSyncOutcome.updated);
      expect(
        (await cache.allProducts()).map((p) => p.id).toSet(),
        {
          'gid://shopify/Product/101',
          'gid://shopify/Product/102',
        },
      );

      final transport2 = _FakeTransport([
        _page([_productNode(id: '102', updatedAt: '2026-08-03T00:00:00Z')]),
      ]);
      final repo2 = CatalogRepository(
        cache: cache,
        cursorStore: cursorStore,
        rules: _emptyRules(),
        catalogSync: CatalogSync(
          client: StorefrontClient(
            config: const StorefrontConfig(
              shopDomain: 'monetta.mx',
              accessToken: 'test-token',
            ),
            transport: transport2.call,
          ),
          fullResyncInterval: Duration.zero,
        ),
        shopDomain: 'monetta.mx',
      );
      await repo2.sync();
      final left = await cache.allProducts();
      expect(left, hasLength(1));
      expect(left.single.id, 'gid://shopify/Product/102');
    });

    test('valid empty full sync clears the catalog (F08)', () async {
      final cache = CatalogCacheStore(db);
      await cache.upsertProducts([
        Product(
          id: 'gid://shopify/Product/101',
          handle: 'a',
          title: 'A',
          vendor: 'Monetta',
          productType: '',
          tags: const [],
          variants: const [],
          images: const [],
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      ]);
      final cursorStore = SyncCursorStore(db);
      final transport = _FakeTransport([_page([])]);
      final repo = CatalogRepository(
        cache: cache,
        cursorStore: cursorStore,
        rules: _emptyRules(),
        catalogSync: CatalogSync(
          client: StorefrontClient(
            config: const StorefrontConfig(
              shopDomain: 'monetta.mx',
              accessToken: 't',
            ),
            transport: transport.call,
          ),
          fullResyncInterval: Duration.zero,
        ),
        shopDomain: 'monetta.mx',
      );
      await repo.sync();
      expect(await cache.allProducts(), isEmpty);
    });

    test('incomplete pagination does not advance cursor or delete (F09)',
        () async {
      final cache = CatalogCacheStore(db);
      final cursorStore = SyncCursorStore(db);
      await cursorStore.save(
        SyncCursor(
          lastUpdatedAt: DateTime.utc(2026, 8, 1),
          lastFullSyncAt: DateTime.utc(2026, 8, 1),
          shopDomain: 'monetta.mx',
        ),
      );
      await cache.upsertProducts([
        Product(
          id: 'gid://shopify/Product/201',
          handle: 'keep',
          title: 'Keep',
          vendor: 'Monetta',
          productType: '',
          tags: const [],
          variants: const [],
          images: const [],
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026, 8, 1),
        ),
      ]);

      final transport = _FakeTransport([
        _page(
          [_productNode(id: '1', updatedAt: '2026-08-05T00:00:00Z')],
          hasNextPage: true,
          endCursor: 'c1',
        ),
      ]);
      final repo = CatalogRepository(
        cache: cache,
        cursorStore: cursorStore,
        rules: _emptyRules(),
        catalogSync: CatalogSync(
          client: StorefrontClient(
            config: const StorefrontConfig(
              shopDomain: 'monetta.mx',
              accessToken: 't',
            ),
            transport: transport.call,
          ),
          maxPages: 1,
          fullResyncInterval: const Duration(days: 7),
        ),
        shopDomain: 'monetta.mx',
      );

      final result = await repo.sync();
      expect(result.outcome, CatalogSyncOutcome.failed);
      expect(result.error, isA<CatalogSyncIncompleteException>());
      final cursor = await cursorStore.load();
      expect(cursor.lastUpdatedAt, DateTime.utc(2026, 8, 1));
      expect(
        (await cache.allProducts()).single.id,
        'gid://shopify/Product/201',
      );
    });

    test('shop domain mismatch clears foreign catalog and cursor (F10)',
        () async {
      final cache = CatalogCacheStore(db);
      final cursorStore = SyncCursorStore(db);
      await cursorStore.save(
        const SyncCursor(shopDomain: 'old-shop.myshopify.com'),
      );
      await cache.replaceProducts(
        [
          Product(
            id: 'gid://shopify/Product/301',
            handle: 'old',
            title: 'Old',
            vendor: 'X',
            productType: '',
            tags: const [],
            variants: const [],
            images: const [],
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
        ],
        metadata: CatalogCacheMetadata.forProducts(
          source: CatalogCacheSource.shopify,
          products: const [],
          syncedAt: DateTime.utc(2026),
          status: CatalogCacheStatus.healthy,
          shopDomain: 'old-shop.myshopify.com',
        ),
      );

      final transport = _FakeTransport([
        _page([_productNode(id: '302', updatedAt: '2026-08-05T00:00:00Z')]),
      ]);
      final repo = CatalogRepository(
        cache: cache,
        cursorStore: cursorStore,
        rules: _emptyRules(),
        catalogSync: CatalogSync(
          client: StorefrontClient(
            config: const StorefrontConfig(
              shopDomain: 'monetta.mx',
              accessToken: 't',
            ),
            transport: transport.call,
          ),
          fullResyncInterval: Duration.zero,
        ),
        shopDomain: 'monetta.mx',
      );
      await repo.sync();
      final products = await cache.allProducts();
      expect(products, hasLength(1));
      expect(products.single.id, 'gid://shopify/Product/302');
      expect((await cursorStore.load()).shopDomain, 'monetta.mx');
      expect((await cache.metadata())?.shopDomain, 'monetta.mx');
    });
  });
}
