/// The owner-autonomy contract, as a test.
///
/// If these fail, adding a product in Shopify Admin stops reaching the app —
/// which is the one property this project cannot lose.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/shopify/catalog_sync.dart';
import 'package:monetta_app/data/shopify/storefront_client.dart';
import 'package:monetta_app/data/shopify/storefront_config.dart';

/// Records what was asked for and replays canned pages.
class FakeTransport {
  FakeTransport(this.pages);

  /// One entry per request, in order.
  final List<Map<String, dynamic>> pages;

  final List<Map<String, dynamic>> requestedVariables = [];
  int _call = 0;

  Future<Map<String, dynamic>> call(
    Uri endpoint,
    Map<String, String> headers,
    String body,
  ) async {
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    requestedVariables.add(decoded['variables'] as Map<String, dynamic>);
    final page = pages[_call.clamp(0, pages.length - 1)];
    _call++;
    return page;
  }
}

Map<String, dynamic> productNode({
  required String id,
  required String updatedAt,
  String title = 'Bolsa Guess Crossbody Negro',
}) =>
    <String, dynamic>{
      'id': 'gid://shopify/Product/$id',
      'handle': 'p-$id',
      'title': title,
      'vendor': 'Monetta ',
      'productType': '',
      'tags': <String>['Guess', 'Crossbody'],
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
        'pageInfo': {'hasNextPage': false, 'endCursor': null},
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
      'collections': {
        'pageInfo': {'hasNextPage': false, 'endCursor': null},
        'edges': <dynamic>[],
      },
    };

Map<String, dynamic> page(
  List<Map<String, dynamic>> nodes, {
  bool hasNextPage = false,
  String? endCursor,
}) =>
    <String, dynamic>{
      'data': {
        'products': {
          'pageInfo': {'hasNextPage': hasNextPage, 'endCursor': endCursor},
          'edges': nodes.map((n) => {'node': n}).toList(),
        },
      },
    };

CatalogSync syncWith(FakeTransport transport) => CatalogSync(
      client: StorefrontClient(
        config: const StorefrontConfig(
          shopDomain: 'monetta.mx',
          accessToken: 'test-token',
        ),
        transport: transport.call,
      ),
    );

void main() {
  final now = DateTime.utc(2026, 8, 5, 12);

  group('CatalogSync', () {
    test('first run fetches everything with no delta filter', () async {
      final transport = FakeTransport([
        page([productNode(id: '1', updatedAt: '2026-08-01T00:00:00Z')]),
      ]);

      final result = await syncWith(transport).run(
        cursor: const SyncCursor(),
        now: now,
      );

      expect(result.wasFullSync, isTrue);
      expect(transport.requestedVariables.single.containsKey('query'), isFalse);
      expect(result.products, hasLength(1));
    });

    test('subsequent runs send a delta filter and stay tiny', () async {
      final cursor = SyncCursor(
        lastUpdatedAt: DateTime.utc(2026, 8, 5, 7, 24, 40),
        lastFullSyncAt: now.subtract(const Duration(days: 1)),
      );
      final transport = FakeTransport([page([])]);

      final result = await syncWith(transport).run(cursor: cursor, now: now);

      expect(result.wasFullSync, isFalse);
      expect(result.products, isEmpty);
      expect(result.pagesFetched, 1);

      // The steady state: one request, no products.
      final query = transport.requestedVariables.single['query'] as String;
      expect(query, startsWith('updated_at:>'));
    });

    test('delta filter re-requests one second of overlap', () async {
      // updated_at has second granularity; an exact-boundary exclusive filter
      // would silently skip a product saved in that same second.
      const cursor = SyncCursor(
        lastUpdatedAt: null,
      );
      expect(cursor.deltaFilter, isNull);

      final withCursor = SyncCursor(
        lastUpdatedAt: DateTime.utc(2026, 8, 5, 7, 24, 40),
      );
      expect(withCursor.deltaFilter, 'updated_at:>2026-08-05T07:24:39Z');
    });

    test('cursor advances to the highest updatedAt seen', () async {
      final transport = FakeTransport([
        page([
          productNode(id: '1', updatedAt: '2026-08-05T01:24:53Z'),
          productNode(id: '2', updatedAt: '2026-08-05T01:25:28Z'),
          productNode(id: '3', updatedAt: '2026-08-05T01:25:01Z'),
        ]),
      ]);

      final result = await syncWith(transport).run(
        cursor: const SyncCursor(),
        now: now,
      );

      expect(
        result.cursor.lastUpdatedAt,
        DateTime.parse('2026-08-05T01:25:28Z'),
      );
    });

    test('paginates until hasNextPage is false', () async {
      final transport = FakeTransport([
        page(
          [productNode(id: '1', updatedAt: '2026-08-01T00:00:00Z')],
          hasNextPage: true,
          endCursor: 'cursor-1',
        ),
        page([productNode(id: '2', updatedAt: '2026-08-02T00:00:00Z')]),
      ]);

      final result = await syncWith(transport).run(
        cursor: const SyncCursor(),
        now: now,
      );

      expect(result.pagesFetched, 2);
      expect(result.products, hasLength(2));
      expect(transport.requestedVariables[1]['after'], 'cursor-1');
    });

    test('aborts when hasNextPage is true without an endCursor', () async {
      final transport = FakeTransport([
        page(
          [productNode(id: '1', updatedAt: '2026-08-01T00:00:00Z')],
          hasNextPage: true,
        ),
      ]);

      await expectLater(
        syncWith(transport).run(cursor: const SyncCursor(), now: now),
        throwsA(isA<CatalogSyncIncompleteException>()),
      );
    });

    test('aborts when maxPages is hit with hasNextPage still true', () async {
      final transport = FakeTransport([
        page(
          [productNode(id: '1', updatedAt: '2026-08-01T00:00:00Z')],
          hasNextPage: true,
          endCursor: 'cursor-1',
        ),
      ]);

      await expectLater(
        CatalogSync(
          client: StorefrontClient(
            config: const StorefrontConfig(
              shopDomain: 'monetta.mx',
              accessToken: 'test-token',
            ),
            transport: transport.call,
          ),
          maxPages: 1,
        ).run(cursor: const SyncCursor(), now: now),
        throwsA(isA<CatalogSyncIncompleteException>()),
      );
    });

    test('aborts on a repeated pagination cursor', () async {
      final transport = FakeTransport([
        page(
          [productNode(id: '1', updatedAt: '2026-08-01T00:00:00Z')],
          hasNextPage: true,
          endCursor: 'same',
        ),
        page(
          [productNode(id: '2', updatedAt: '2026-08-02T00:00:00Z')],
          hasNextPage: true,
          endCursor: 'same',
        ),
      ]);

      await expectLater(
        syncWith(transport).run(cursor: const SyncCursor(), now: now),
        throwsA(isA<CatalogSyncIncompleteException>()),
      );
    });

    test('passes country and language into @inContext variables', () async {
      final transport = FakeTransport([page([])]);
      await syncWith(transport).run(cursor: const SyncCursor(), now: now);
      final vars = transport.requestedVariables.single;
      expect(vars['country'], 'MX');
      expect(vars['language'], 'ES');
    });

    test('forces a full resync after 7 days to catch deletions', () async {
      // Unpublishing a product does not move updated_at on anything we can see,
      // so a delta-only client would keep showing it.
      final stale = SyncCursor(
        lastUpdatedAt: DateTime.utc(2026, 8, 1),
        lastFullSyncAt: DateTime.utc(2026, 7, 20),
      );
      final transport = FakeTransport([page([])]);

      final result = await syncWith(transport).run(cursor: stale, now: now);

      expect(result.wasFullSync, isTrue);
      expect(transport.requestedVariables.single.containsKey('query'), isFalse);
      expect(result.cursor.lastFullSyncAt, now);
    });
  });

  group('StorefrontClient', () {
    test('treats HTTP 200 with an errors array as a failure', () async {
      Future<Map<String, dynamic>> transport(
        Uri _,
        Map<String, String> __,
        String ___,
      ) async =>
          {
            'errors': [
              {'message': 'Field does not exist'},
            ],
          };

      final client = StorefrontClient(
        config: const StorefrontConfig(
          shopDomain: 'monetta.mx',
          accessToken: 't',
        ),
        transport: transport,
      );

      await expectLater(
        client.query('query { shop { name } }'),
        throwsA(
          isA<StorefrontException>()
              .having((e) => e.isRetryable, 'isRetryable', isFalse),
        ),
      );
    });

    test('marks throttling as retryable', () async {
      Future<Map<String, dynamic>> transport(
        Uri _,
        Map<String, String> __,
        String ___,
      ) async =>
          {
            'errors': [
              {'message': 'Throttled: too many requests'},
            ],
          };

      final client = StorefrontClient(
        config: const StorefrontConfig(
          shopDomain: 'monetta.mx',
          accessToken: 't',
        ),
        transport: transport,
      );

      await expectLater(
        client.query('query { shop { name } }'),
        throwsA(
          isA<StorefrontException>()
              .having((e) => e.isRetryable, 'isRetryable', isTrue),
        ),
      );
    });
  });
}
