library;

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/firestore/catalog_realtime_source.dart';
import 'package:monetta_app/data/local/catalog_cache_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/repositories/realtime_catalog_repository.dart';
import 'package:monetta_app/domain/product.dart';

CatalogRealtimeDocument _document({
  String documentId = '123',
  String title = 'Bolsa en tiempo real',
}) =>
    CatalogRealtimeDocument(
      documentId: documentId,
      data: {
        'schemaVersion': 1,
        'source': 'shopify',
        'id': 'gid://shopify/Product/$documentId',
        'shopifyLegacyId': documentId,
        'handle': 'bolsa-tiempo-real',
        'title': title,
        'vendor': 'Monetta',
        'productType': 'Bolsas',
        'tags': <String>['Coach'],
        'descriptionHtml': '<p>Descripción</p>',
        'images': <String>['https://cdn.shopify.com/product.jpg'],
        'collectionHandles': <String>['bolsas'],
        'brandOverride': 'Coach',
        'categoryOverride': null,
        'variants': <Map<String, Object?>>[
          {
            'id': 'gid://shopify/ProductVariant/456',
            'title': 'Default Title',
            'price': 1299,
            'compareAtPrice': 1499.0,
            'sku': null,
            'available': true,
          },
        ],
        'createdAt': '2026-08-01T12:00:00Z',
        'updatedAt': '2026-08-27T12:00:00Z',
        'publishedAt': '2026-08-01T12:00:00Z',
        'isPublished': true,
        'isInStock': true,
        'minPrice': 1299,
      },
    );

Product _cachedProduct(String id) => Product(
      id: id,
      handle: 'cached',
      title: 'Catálogo válido en caché',
      vendor: 'Monetta',
      productType: 'Bolsas',
      tags: const [],
      variants: const [],
      images: const [],
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

class _StaticSource implements CatalogRealtimeSource {
  _StaticSource(this.streamFactory);

  final Stream<List<CatalogRealtimeDocument>> Function() streamFactory;
  int listenCount = 0;

  @override
  Stream<List<CatalogRealtimeDocument>> watchProducts() {
    listenCount += 1;
    return streamFactory();
  }
}

void main() {
  late AppDatabase database;
  late CatalogCacheStore cache;

  setUp(() {
    database = openTestDatabase();
    cache = CatalogCacheStore(database);
  });

  tearDown(() => database.close());

  test('a valid non-empty snapshot atomically replaces stale cache rows',
      () async {
    await cache.upsertProducts([_cachedProduct('stale')]);
    final repository = RealtimeCatalogRepository(
      source: _StaticSource(
        () => const Stream<List<CatalogRealtimeDocument>>.empty(),
      ),
      cache: cache,
    );

    final update = await repository.applySnapshot([_document()]);

    expect(update.outcome, RealtimeCatalogOutcome.applied);
    expect(update.products.single.title, 'Bolsa en tiempo real');
    final cached = await cache.allProducts();
    expect(cached, hasLength(1));
    expect(cached.single.id, 'gid://shopify/Product/123');
    final metadata = await cache.metadata();
    expect(metadata?.source, CatalogCacheSource.firestore);
    expect(metadata?.status, CatalogCacheStatus.healthy);
    expect(metadata?.productCount, 1);
  });

  test('an empty snapshot never erases a valid cached catalog', () async {
    await cache.upsertProducts([_cachedProduct('cached')]);
    final repository = RealtimeCatalogRepository(
      source: _StaticSource(
        () => const Stream<List<CatalogRealtimeDocument>>.empty(),
      ),
      cache: cache,
    );

    final update = await repository.applySnapshot(const []);

    expect(update.outcome, RealtimeCatalogOutcome.empty);
    expect((await cache.allProducts()).single.id, 'cached');
  });

  test('one invalid document rejects the full snapshot without data loss',
      () async {
    await cache.upsertProducts([_cachedProduct('cached')]);
    final invalid = CatalogRealtimeDocument(
      documentId: 'broken',
      data: {..._document(documentId: 'broken').data, 'title': null},
    );
    final repository = RealtimeCatalogRepository(
      source: _StaticSource(
        () => const Stream<List<CatalogRealtimeDocument>>.empty(),
      ),
      cache: cache,
    );

    final update = await repository.applySnapshot([_document(), invalid]);

    expect(update.outcome, RealtimeCatalogOutcome.invalid);
    expect(update.invalidDocumentIds, ['broken']);
    expect((await cache.allProducts()).single.id, 'cached');
  });

  test('numeric variant identities are canonicalized at the boundary',
      () async {
    final originalVariant = Map<String, Object?>.from(
      (_document().data['variants']! as List).single as Map,
    );
    final invalid = CatalogRealtimeDocument(
      documentId: '123',
      data: {
        ..._document().data,
        'variants': <Map<String, Object?>>[
          {
            ...originalVariant,
            'id': '456',
          },
        ],
      },
    );
    final repository = RealtimeCatalogRepository(
      source: _StaticSource(
        () => const Stream<List<CatalogRealtimeDocument>>.empty(),
      ),
      cache: cache,
    );

    final update = await repository.applySnapshot([invalid]);

    expect(update.outcome, RealtimeCatalogOutcome.applied);
    expect(
      update.products.single.variants.single.id,
      'gid://shopify/ProductVariant/456',
    );
  });

  test('stream errors reconnect and later deliver a valid snapshot', () async {
    late _StaticSource source;
    source = _StaticSource(
      () => source.listenCount == 1
          ? Stream.error(StateError('offline'))
          : Stream.value([_document()]),
    );
    final repository = RealtimeCatalogRepository(
      source: source,
      cache: cache,
      retryDelay: (_) async {},
    );

    final updates = await repository.watch().take(2).toList();

    expect(
      updates.map((update) => update.outcome),
      [RealtimeCatalogOutcome.error, RealtimeCatalogOutcome.applied],
    );
    expect(source.listenCount, 2);
  });
}
