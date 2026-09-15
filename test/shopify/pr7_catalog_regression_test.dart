import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/local/catalog_cache_store.dart';
import 'package:monetta_app/data/local/database.dart' hide SyncCursor;
import 'package:monetta_app/data/local/sync_cursor_store.dart';
import 'package:monetta_app/data/normalize/rules.dart';
import 'package:monetta_app/data/repositories/catalog_repository.dart';
import 'package:monetta_app/data/shopify/catalog_sync.dart';
import 'package:monetta_app/data/shopify/featured_catalog_repository.dart';
import 'catalog_sync_test.dart' show FakeTransport, productNode, page, syncWith;

Map<String, dynamic> connection(List<dynamic> nodes, {String? after}) => {
      'nodes': nodes,
      'pageInfo': {'hasNextPage': after != null, 'endCursor': after},
    };

void main() {
  test('R1 featured cache writer also completes variants before publishing',
      () async {
    final node = productNode(id: '1', updatedAt: '2026-09-01T00:00:00Z');
    final original = (node['variants'] as Map)['edges'] as List;
    final variant =
        Map<String, dynamic>.from((original.first as Map)['node'] as Map);
    node['variants'] = connection(
      List.generate(
        50,
        (i) => <String, dynamic>{
          ...variant,
          'id': 'gid://shopify/ProductVariant/$i',
        },
      ),
      after: 'v50',
    );
    final transport = FakeTransport([
      {
        'data': {
          'collection': {
            'products': {
              'edges': [
                {'node': node},
              ],
            },
          },
        },
      },
      {
        'data': {
          'product': {
            'variants': connection([
              <String, dynamic>{
                ...variant,
                'id': 'gid://shopify/ProductVariant/50',
              }
            ]),
          },
        },
      },
    ]);
    final products =
        await FeaturedCatalogRepository(client: syncWith(transport).client)
            .fetch();
    expect(products.single.variants, hasLength(51));
    expect(transport.requestedVariables[1]['after'], 'v50');
  });

  test(
      'R1 seven-image product preview, 51 variants and 26 collections complete',
      () async {
    final node = productNode(id: '1', updatedAt: '2026-09-01T00:00:00Z');
    final variant = (((node['variants'] as Map)['edges'] as List).first
        as Map)['node'] as Map;
    node['images'] = {
      'edges': List.generate(
        6,
        (i) => {
          'node': {'url': 'https://cdn.shopify.com/$i.jpg'},
        },
      ),
      'pageInfo': {'hasNextPage': true, 'endCursor': 'image6'},
    };
    node['variants'] = connection(
      List.generate(
        50,
        (i) => {...variant, 'id': 'gid://shopify/ProductVariant/$i'},
      ),
      after: 'v50',
    );
    node['collections'] =
        connection(List.generate(25, (i) => {'handle': 'c$i'}), after: 'c25');
    final transport = FakeTransport([
      page([node]),
      {
        'data': {
          'product': {
            'variants': connection([
              {...variant, 'id': 'gid://shopify/ProductVariant/50'},
            ]),
          },
        },
      },
      {
        'data': {
          'product': {
            'collections': connection([
              {'handle': 'c25'},
            ]),
          },
        },
      },
    ]);
    final result = await syncWith(transport)
        .run(cursor: const SyncCursor(), now: DateTime.utc(2026, 9, 7));
    expect(result.products.single.images, hasLength(6));
    expect(result.products.single.variants, hasLength(51));
    expect(result.products.single.collectionHandles, hasLength(26));
    expect(transport.requestedVariables[1]['after'], 'v50');
    expect(transport.requestedVariables[2]['after'], 'c25');
  });

  for (final malformed in <Map<String, dynamic>>[
    {
      'data': {'products': null},
    },
    {'data': <String, dynamic>{}},
    {
      'data': {
        'products': {
          'nodes': null,
          'pageInfo': {'hasNextPage': false},
        },
      },
    },
    {
      'data': {
        'products': {
          'edges': [null],
          'pageInfo': {'hasNextPage': false},
        },
      },
    },
    {
      'data': {
        'products': {'nodes': <dynamic>[]},
      },
    },
    {
      'data': {
        'products': {
          'nodes': <dynamic>[],
          'pageInfo': {'hasNextPage': 'false'},
        },
      },
    },
  ]) {
    test(
        'R2 malformed ${malformed.toString()} preserves successful cache/cursor',
        () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final transport = FakeTransport([
        page([productNode(id: '1', updatedAt: '2026-09-01T00:00:00Z')]),
        malformed,
      ]);
      final cache = CatalogCacheStore(db);
      final cursors = SyncCursorStore(db);
      final repo = CatalogRepository(
        cache: cache,
        cursorStore: cursors,
        rules: NormalizationRules.fromJson(const {}),
        catalogSync: syncWith(transport),
      );
      expect((await repo.sync()).outcome, CatalogSyncOutcome.updated);
      final before = await cursors.load();
      expect((await repo.sync()).outcome, CatalogSyncOutcome.failed);
      expect(await cache.allProducts(), hasLength(1));
      expect((await cursors.load()).lastUpdatedAt, before.lastUpdatedAt);
      expect((await cursors.load()).lastFullSyncAt, before.lastFullSyncAt);
    });
  }

  test('R1 later required page fails without publishing partial products',
      () async {
    final node = productNode(id: '1', updatedAt: '2026-09-01T00:00:00Z');
    (node['variants'] as Map)['pageInfo'] = {
      'hasNextPage': true,
      'endCursor': 'more',
    };
    final transport = FakeTransport([
      page([node]),
      {
        'data': {'product': null},
      }
    ]);
    await expectLater(
      syncWith(transport).run(cursor: const SyncCursor(), now: DateTime.now()),
      throwsA(isA<CatalogSyncIncompleteException>()),
    );
  });

  test('R8 confirmed empty survives offline seed and recovers on later sync',
      () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final cache = CatalogCacheStore(db);
    final cursors = SyncCursorStore(db);
    final rules = NormalizationRules.fromJson(const {});
    final repo = CatalogRepository(
      cache: cache,
      cursorStore: cursors,
      rules: rules,
      catalogSync: syncWith(FakeTransport([page([])])),
    );
    expect((await repo.sync()).outcome, CatalogSyncOutcome.updated);
    final restarted =
        CatalogRepository(cache: cache, cursorStore: cursors, rules: rules);
    // Deliberately invalid asset proves it is never read for confirmed emptiness.
    await restarted.seedFromAssetIfEmpty(const {});
    expect((await restarted.loadCached()).products, isEmpty);
    final recovered = CatalogRepository(
      cache: cache,
      cursorStore: cursors,
      rules: rules,
      catalogSync: syncWith(
        FakeTransport([
          page([productNode(id: '2', updatedAt: '2026-09-07T00:00:00Z')]),
        ]),
      ),
    );
    expect((await recovered.sync()).outcome, CatalogSyncOutcome.updated);
    expect(
      (await recovered.loadCached()).products.single.id,
      'gid://shopify/Product/2',
    );
  });
}
