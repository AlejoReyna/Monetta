// Deterministic local fixture; never a deployed catalog or inventory claim.
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/normalize/normalizer.dart';
import 'package:monetta_app/domain/product.dart';

Product discoveryProduct(
  int index, {
  String brand = 'guess',
  String category = 'bolsa',
  List<ProductVariant>? variants,
  List<String> handles = const ['configured-bags'],
}) =>
    Product(
      id: 'gid://shopify/Product/${900000 + index}',
      handle: 'discovery-$index',
      title:
          '${category == 'bolsa' ? 'Bolso' : 'Cartera'} ${brand == 'guess' ? 'Guess' : 'Coach'} $index',
      vendor: 'Monetta',
      productType: '',
      tags: const ['Crossbody'],
      brandOverride: brand,
      categoryOverride: category,
      variants: variants ??
          [
            ProductVariant(
              id: 'v-$index',
              title: 'Negro',
              price: 1000 + index.toDouble(),
              available: true,
              compareAtPrice: index.isEven ? 2000 : null,
              selectedOptions: const {'Color': 'Black'},
            ),
          ],
      images: const [],
      createdAt: DateTime.utc(2026, 10, 1).add(Duration(days: index)),
      updatedAt: DateTime.utc(2026, 11, 11),
      collectionHandles: handles,
    );
Future<CatalogStore> discoveryStore({int count = 8}) async {
  final db = openTestDatabase();
  final store = CatalogStore(database: db);
  addTearDown(() async {
    store.dispose();
    await db.close();
  });
  await store.loadFromAsset();
  final products = [
    for (var i = 1; i <= count; i++)
      discoveryProduct(i, brand: i % 3 == 0 ? 'coach' : 'guess'),
  ];
  setDiscoveryProducts(store, products);
  return store;
}

void setDiscoveryProducts(CatalogStore store, List<Product> products) {
  store.products = products;
  store.facetsById = {
    for (final p in products)
      p.id:
          Normalizer(store.rules).normalize(p, now: DateTime.utc(2026, 11, 11)),
  };
}
