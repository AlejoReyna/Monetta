library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/firestore/catalog_realtime_source.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/repositories/catalog_repository.dart';
import 'package:monetta_app/data/shopify/catalog_sync.dart';
import 'package:monetta_app/data/shopify/storefront_client.dart';
import 'package:monetta_app/data/shopify/storefront_config.dart';

class _ControlledSource implements CatalogRealtimeSource {
  final controller = StreamController<List<CatalogRealtimeDocument>>();

  @override
  Stream<List<CatalogRealtimeDocument>> watchProducts() => controller.stream;
}

class _FailThenWaitSource implements CatalogRealtimeSource {
  final waiting = StreamController<List<CatalogRealtimeDocument>>.broadcast();
  int listens = 0;

  @override
  Stream<List<CatalogRealtimeDocument>> watchProducts() {
    listens += 1;
    if (listens == 1) return Stream.error(StateError('offline'));
    return waiting.stream;
  }
}

class _CountingTransport {
  int calls = 0;

  Future<Map<String, dynamic>> call(
    Uri endpoint,
    Map<String, String> headers,
    String body,
  ) async {
    calls += 1;
    return {
      'data': {
        'products': {
          'pageInfo': {'hasNextPage': false, 'endCursor': null},
          'edges': <dynamic>[],
        },
      },
    };
  }
}

CatalogRealtimeDocument _document() => const CatalogRealtimeDocument(
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

  test('CatalogStore publishes a validated real-time snapshot', () async {
    final source = _ControlledSource();
    final transport = _CountingTransport();
    final store = CatalogStore(
      database: openTestDatabase(),
      realtimeSource: source,
      catalogSync: CatalogSync(
        client: StorefrontClient(
          config: const StorefrontConfig(
            shopDomain: 'monetta.mx',
            accessToken: 'test-token',
          ),
          transport: transport.call,
        ),
      ),
    );
    await store.loadFromAsset();
    expect(store.realtimeStatus, CatalogRealtimeStatus.connecting);
    expect(transport.calls, 0);

    final connectingSync = await store.syncWithShopify();
    expect(
      connectingSync.outcome,
      CatalogSyncOutcome.skippedRealtimeAuthoritative,
    );
    expect(transport.calls, 0);

    source.controller.add([_document()]);
    for (var attempt = 0;
        attempt < 20 && store.realtimeStatus != CatalogRealtimeStatus.live;
        attempt += 1) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(store.realtimeStatus, CatalogRealtimeStatus.live);
    expect(store.products.single.title, 'Producto desde Firestore');
    expect(store.facetsById, contains('gid://shopify/Product/987'));

    final liveSync = await store.syncWithShopify();
    expect(liveSync.outcome, CatalogSyncOutcome.skippedRealtimeAuthoritative);
    expect(transport.calls, 0);

    store.dispose();
    await source.controller.close();
  });

  test('a Firestore error activates delta sync as fallback', () async {
    final source = _FailThenWaitSource();
    final transport = _CountingTransport();
    final store = CatalogStore(
      database: openTestDatabase(),
      realtimeSource: source,
      catalogSync: CatalogSync(
        client: StorefrontClient(
          config: const StorefrontConfig(
            shopDomain: 'monetta.mx',
            accessToken: 'test-token',
          ),
          transport: transport.call,
        ),
      ),
    );

    await store.loadFromAsset();
    for (var attempt = 0; attempt < 20 && transport.calls == 0; attempt += 1) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(store.realtimeStatus, CatalogRealtimeStatus.reconnecting);
    expect(transport.calls, 1);

    store.dispose();
    await source.waiting.close();
  });
}
