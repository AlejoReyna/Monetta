library;

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/local/catalog_cache_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/domain/product.dart';

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
}
