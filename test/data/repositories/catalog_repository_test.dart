/// Proves `CatalogRepository` actually wires `data/local` and `data/shopify`
/// together — a real sync run (via a fake transport, no network) lands in
/// the Drift cache and advances a cursor that survives the call.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/local/catalog_cache_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/sync_cursor_store.dart';
import 'package:monetta_app/data/normalize/rules.dart';
import 'package:monetta_app/data/repositories/catalog_repository.dart';
import 'package:monetta_app/data/shopify/catalog_sync.dart';
import 'package:monetta_app/data/shopify/storefront_client.dart';
import 'package:monetta_app/data/shopify/storefront_config.dart';

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

Map<String, dynamic> _productNode({required String id, required String updatedAt}) => {
      'id': id,
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
              'id': 'v-$id',
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

Map<String, dynamic> _page(List<Map<String, dynamic>> nodes) => {
      'data': {
        'products': {
          'pageInfo': {'hasNextPage': false, 'endCursor': null},
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

    test('seedFromAssetIfEmpty writes the bundled snapshot only on a cold cache', () async {
      final cache = CatalogCacheStore(db);
      final repo = CatalogRepository(
        cache: cache,
        cursorStore: SyncCursorStore(db),
        rules: _emptyRules(),
      );

      final snapshotJson = {
        'products': [
          {
            'id': 'gid://shopify/Product/1',
            'handle': 'p1',
            'title': 'Bolsa',
            'vendor': 'Monetta',
            'product_type': 'Bolsa',
            'tags': <String>[],
            'images': <String>[],
            'created_at': '2026-01-01T00:00:00Z',
            'updated_at': '2026-01-01T00:00:00Z',
            'variants': [
              {
                'id': 'v1',
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
      expect(await cache.allProducts(), hasLength(1));

      // A second seed call must not touch an already-populated cache.
      await cache.upsertProducts([]); // no-op, cache still has the seeded row
      await repo.seedFromAssetIfEmpty({
        'products': [
          {
            'id': 'gid://shopify/Product/2',
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

    test('sync() runs a real delta sync via a fake transport and writes into the cache', () async {
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

    test('loadCached() normalizes cached products via the real normalizer', () async {
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
            'id': 'p1',
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
      expect(snapshot.facetsById.containsKey('p1'), isTrue);
    });
  });
}
