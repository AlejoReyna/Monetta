import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/firestore/catalog_realtime_source.dart';
import 'package:monetta_app/data/local/catalog_cache_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/repositories/realtime_catalog_repository.dart';

class _Source implements CatalogRealtimeSource {
  @override
  Stream<List<CatalogRealtimeDocument>> watchProducts() => const Stream.empty();
}

CatalogRealtimeDocument document({
  bool metadata = true,
  bool invalid = false,
}) =>
    CatalogRealtimeDocument(
      documentId: '9001',
      data: {
        'schemaVersion': 1,
        'source': 'shopify',
        'id': 'gid://shopify/Product/9001',
        'shopifyLegacyId': '9001',
        'handle': 'fixture',
        'title': 'Producto de prueba',
        'vendor': 'Coach',
        'productType': 'Calzado',
        'tags': <String>[],
        'descriptionHtml': '',
        'images': <String>[],
        'collectionHandles': <String>[],
        'createdAt': '2026-10-01T00:00:00Z',
        'updatedAt': '2026-11-01T00:00:00Z',
        'isPublished': true,
        'variants': [
          {
            'id': 'gid://shopify/ProductVariant/9101',
            'title': 'Negro / 36',
            'price': 1200,
            'compareAtPrice': null,
            'available': true,
            if (metadata)
              'selectedOptions':
                  invalid ? {'Color': 5} : {'Color': 'Negro', 'Talla': '36'},
            if (metadata)
              'imageUrls': ['https://cdn.shopify.com/fixture/black.jpg'],
          }
        ],
      },
    );
void main() {
  for (final legacy in [false, true]) {
    test('Firestore ${legacy ? 'legacy' : 'producer'} metadata survives cache',
        () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final cache = CatalogCacheStore(db);
      final repository =
          RealtimeCatalogRepository(source: _Source(), cache: cache);
      final update =
          await repository.applySnapshot([document(metadata: !legacy)]);
      expect(update.outcome, RealtimeCatalogOutcome.applied);
      final variant = (await cache.allProducts()).single.variants.single;
      expect(
        variant.selectedOptions,
        legacy ? isEmpty : {'Color': 'Negro', 'Talla': '36'},
      );
      expect(
        variant.imageUrls,
        legacy ? isEmpty : ['https://cdn.shopify.com/fixture/black.jpg'],
      );
    });
  }
  test('invalid producer options preserve last confirmed catalog', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final cache = CatalogCacheStore(db);
    final repository =
        RealtimeCatalogRepository(source: _Source(), cache: cache);
    await repository.applySnapshot([document()]);
    expect(
      (await repository.applySnapshot([document(invalid: true)])).outcome,
      RealtimeCatalogOutcome.invalid,
    );
    expect(
      (await cache.allProducts())
          .single
          .variants
          .single
          .selectedOptions['Color'],
      'Negro',
    );
  });
}
