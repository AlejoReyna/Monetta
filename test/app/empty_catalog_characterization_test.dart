/// CHAR-06: characterization of the empty catalog, as `CatalogStore` (what the
/// app paints) and the database see it.
///
/// Today the two live sources disagree. A verified empty Storefront full sync
/// replaces the catalog at once and the asset never comes back; an empty
/// Firestore snapshot is ignored and only flags the cache as invalid. E10 will
/// make an empty catalog apply only after a second sync confirms it (RF-42 and
/// RF-50), so these tests must then change explicitly.
library;

import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/firestore/catalog_realtime_source.dart';
import 'package:monetta_app/data/local/catalog_cache_store.dart';
import 'package:monetta_app/data/local/database.dart' hide SyncCursor;
import 'package:monetta_app/data/local/sync_cursor_store.dart';
import 'package:monetta_app/data/repositories/catalog_repository.dart';
import 'package:monetta_app/data/shopify/catalog_sync.dart';
import 'package:monetta_app/data/shopify/storefront_client.dart';
import 'package:monetta_app/data/shopify/storefront_config.dart';
import 'package:monetta_app/domain/product.dart';

const _shop = 'monetta.mx';

Product _product(String id) => Product(
      id: 'gid://shopify/Product/$id',
      handle: 'producto-$id',
      title: 'Producto $id',
      vendor: 'Monetta',
      productType: 'Bolsa',
      tags: const [],
      variants: [
        ProductVariant(
          id: 'gid://shopify/ProductVariant/$id',
          title: 'Default Title',
          price: 1000,
          available: true,
        ),
      ],
      images: const ['https://cdn.example/x.jpg'],
      createdAt: DateTime.utc(2026, 7, 1),
      updatedAt: DateTime.utc(2026, 8, 1),
    );

AppDatabase _open(File file) => AppDatabase(
      NativeDatabase(
        file,
        setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;'),
      ),
    );

/// Gives a verified full sync of zero products once [release] completes.
class _EmptyCatalogTransport {
  final release = Completer<void>();
  int calls = 0;

  Future<Map<String, dynamic>> call(
    Uri endpoint,
    Map<String, String> headers,
    String body,
  ) async {
    calls += 1;
    await release.future;
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

CatalogSync _syncOver(_EmptyCatalogTransport transport) => CatalogSync(
      client: StorefrontClient(
        config: const StorefrontConfig(
          shopDomain: _shop,
          accessToken: 'test-token',
        ),
        transport: transport.call,
      ),
    );

class _ControlledSource implements CatalogRealtimeSource {
  final controller = StreamController<List<CatalogRealtimeDocument>>();

  @override
  Stream<List<CatalogRealtimeDocument>> watchProducts() => controller.stream;
}

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

/// Lets the unawaited cache writes and stream events settle.
Future<void> _settleUntil(bool Function() done) async {
  for (var attempt = 0; attempt < 50 && !done(); attempt += 1) {
    await pumpEventQueue();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'CHAR-06 (vigente, cambia según E10) Storefront: un full sync '
      'verificado de 0 productos vacía el catálogo de inmediato y el asset '
      'no vuelve al reabrir', () async {
    final dir = await Directory.systemTemp.createTemp('monetta-char06-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/monetta.sqlite');

    // A synchronised monetta.mx install with two products whose cursor has no
    // high-water mark, so the next sync is a full one without any clock.
    var db = _open(file);
    final seedProducts = [_product('1'), _product('2')];
    await CatalogCacheStore(db).replaceProducts(
      seedProducts,
      metadata: CatalogCacheMetadata.forProducts(
        source: CatalogCacheSource.shopify,
        products: seedProducts,
        syncedAt: DateTime.utc(2026, 8, 10, 12),
        status: CatalogCacheStatus.healthy,
        shopDomain: _shop,
      ),
    );
    await SyncCursorStore(db).save(const SyncCursor(shopDomain: _shop));

    final transport = _EmptyCatalogTransport();
    var store = CatalogStore(
      database: db,
      shopDomain: _shop,
      catalogSync: _syncOver(transport),
    );
    await store.loadFromAsset();
    expect(
      store.products.map((product) => product.id).toSet(),
      {'gid://shopify/Product/1', 'gid://shopify/Product/2'},
      reason: 'the cached catalog paints first',
    );

    transport.release.complete();
    final result = await store.syncWithShopify();

    expect(transport.calls, 1);
    expect(result.outcome, CatalogSyncOutcome.updated);
    expect(store.products, isEmpty);
    expect(store.facetsById, isEmpty);
    expect(store.catalogMetadata?.source, CatalogCacheSource.shopify);
    expect(store.catalogMetadata?.productCount, 0);
    expect(store.catalogMetadata?.status, CatalogCacheStatus.healthy);
    expect(await CatalogCacheStore(db).allProducts(), isEmpty);
    final stored = await CatalogCacheStore(db).metadata();
    expect(stored?.source, CatalogCacheSource.shopify);
    expect(stored?.productCount, 0);
    expect(stored?.status, CatalogCacheStatus.healthy);

    await db.close();
    store.dispose();

    // Reopening on the same shop: still empty, the asset is not re-seeded.
    db = _open(file);
    store = CatalogStore(database: db, shopDomain: _shop);
    await store.loadFromAsset();
    await store.syncWithShopify();
    expect(store.products, isEmpty);
    expect(await CatalogCacheStore(db).allProducts(), isEmpty);
    expect(store.catalogMetadata?.source, CatalogCacheSource.shopify);
    expect(store.catalogMetadata?.productCount, 0);
    await db.close();
    store.dispose();
  });

  test(
      'CHAR-06 (vigente, cambia según E10) Firestore: un snapshot vacío '
      'conserva el catálogo y la caché, pero marca la metadata como inválida '
      'con detalle Vacío', () async {
    final source = _ControlledSource();
    final db = openTestDatabase();
    final store = CatalogStore(database: db, realtimeSource: source);
    await store.loadFromAsset();
    expect(store.realtimeStatus, CatalogRealtimeStatus.connecting);

    source.controller.add([_firestoreDocument()]);
    await _settleUntil(
      () => store.realtimeStatus == CatalogRealtimeStatus.live,
    );
    expect(store.realtimeStatus, CatalogRealtimeStatus.live);
    expect(store.products.single.id, 'gid://shopify/Product/987');

    source.controller.add(const []);
    await _settleUntil(
      () => store.realtimeStatus == CatalogRealtimeStatus.empty,
    );
    // The metadata write is not awaited by the store: let it finish.
    await _settleUntil(
      () => store.catalogMetadata?.status == CatalogCacheStatus.invalid,
    );

    expect(store.realtimeStatus, CatalogRealtimeStatus.empty);
    expect(
      store.products.single.id,
      'gid://shopify/Product/987',
      reason: 'the previous catalog stays in memory',
    );
    final cache = CatalogCacheStore(db);
    expect(
      (await cache.allProducts()).single.id,
      'gid://shopify/Product/987',
      reason: 'the Drift cache keeps its rows',
    );
    expect(store.catalogMetadata?.status, CatalogCacheStatus.invalid);
    expect(store.catalogMetadata?.detail, 'Vacío');
    final stored = await cache.metadata();
    expect(stored?.source, CatalogCacheSource.firestore);
    expect(stored?.productCount, 1);
    expect(stored?.status, CatalogCacheStatus.invalid);
    expect(stored?.detail, 'Vacío');

    store.dispose();
    await source.controller.close();
  });
}
