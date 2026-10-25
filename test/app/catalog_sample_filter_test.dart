import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/featured_catalog_controller.dart';
import 'package:monetta_app/data/local/bag_store.dart';
import 'package:monetta_app/data/local/catalog_cache_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/wishlist_store.dart';
import 'package:monetta_app/data/shopify/featured_catalog_repository.dart';
import 'package:monetta_app/data/shopify/home_content_repository.dart';
import 'package:monetta_app/data/shopify/storefront_client.dart';
import 'package:monetta_app/data/shopify/storefront_config.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/catalog/catalog_query.dart';

const _shop = 'monetta-staging.myshopify.com';
const _sampleVendors = [
  'Monetta Staging',
  'Snowboard Vendor',
  'Hydrogen Vendor',
  'Multi-managed Vendor',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final vendor in _sampleVendors) {
    for (final spelling in [
      vendor,
      vendor.toLowerCase(),
      ' ${vendor.toUpperCase()} '
    ]) {
      test('T2-SAMPLE products setter hides vendor "$spelling"', () {
        final store = CatalogStore(database: openTestDatabase());
        addTearDown(store.dispose);
        final real = _product(1, vendor: 'Guess');
        final sample = _product(2, vendor: spelling);

        store.products = [real, sample];

        expect(store.products.map((product) => product.id), [real.id]);
      });
    }
  }

  test('T2-SAMPLE real vendors remain visible regardless of title or type', () {
    final store = CatalogStore(database: openTestDatabase());
    addTearDown(store.dispose);
    final real = _realProducts();

    store.products = real;

    expect(store.products.map((product) => product.id),
        real.map((product) => product.id));
    expect(store.products.last.title, 'Snowboard Gift Card');
    expect(store.products.last.productType, 'snowboard');
  });

  test('T2-SAMPLE Gift Card with Snowboard Vendor is hidden', () {
    final store = CatalogStore(database: openTestDatabase());
    addTearDown(store.dispose);
    final real = _product(1, vendor: 'Monetta ');
    final giftCard = _product(
      2,
      vendor: 'Snowboard Vendor',
      title: 'Gift Card',
      productType: 'giftcard',
    );

    store.products = [real, giftCard];

    expect(store.products.map((product) => product.id), [real.id]);
  });

  for (final surface in [
    'products',
    'facetsById',
    'availableBrands',
    'feed',
    'mixedFeed',
    'recentlyViewed',
    'catalogItems',
    'searchProducts',
    'moreFromBrand',
  ]) {
    test('T2-SAMPLE cached $surface excludes samples after normalization',
        () async {
      final real = _realProducts();
      final samples = _sampleProducts();
      final fixture = await _loadedCatalog([...real, ...samples]);
      final store = fixture.store;
      for (final product in [...real, ...samples]) {
        store.markRecentlyViewed(product.id);
      }
      final realIds = real.map((product) => product.id).toSet();
      final sampleIds = samples.map((product) => product.id).toSet();
      final visibleIds = switch (surface) {
        'products' => store.products.map((product) => product.id),
        'facetsById' => store.facetsById.keys,
        'availableBrands' => store.availableBrands,
        'feed' => store.feed(limit: 100).map((entry) => entry.product.id),
        'mixedFeed' => store.mixedFeed(
            external: const [], limit: 100).map((entry) => entry.product!.id),
        'recentlyViewed' =>
          store.recentlyViewed(limit: 100).map((product) => product.id),
        'catalogItems' => store.catalogItems.map((item) => item.sourceScopedId),
        'searchProducts' =>
          searchProducts(store, 'SampleProbe').map((product) => product.id),
        'moreFromBrand' => store
            .moreFromBrand('sample_brand', limit: 100)
            .map((product) => product.id),
        _ => throw StateError('Unknown surface'),
      };

      if (surface == 'availableBrands') {
        expect(visibleIds, isNot(contains('sample_brand')));
        expect(visibleIds, contains('guess'));
      } else if (surface == 'searchProducts' || surface == 'moreFromBrand') {
        expect(visibleIds, isEmpty);
      } else if (surface == 'catalogItems') {
        expect(store.catalogItems.map((item) => item.title),
            isNot(contains('SampleProbe')));
        expect(store.catalogItems, hasLength(real.length));
      } else {
        expect(visibleIds.toSet().intersection(sampleIds), isEmpty);
        expect(visibleIds.toSet(), realIds);
      }
    });
  }

  test(
      'T2-SAMPLE filtering keeps the full cache and existing bag and wishlist rows',
      () async {
    final db = openTestDatabase();
    final rows = [..._realProducts(), ..._sampleProducts()];
    await _cacheCatalog(db, rows);
    final sample = rows.last;
    final bags = BagStore(db);
    final wishlist = WishlistStore(db);
    for (final accountId in [null, 'existing-account']) {
      await bags.upsert(
        productId: sample.id,
        variantId: sample.variants.single.id,
        quantity: 2,
        accountId: accountId,
      );
      await wishlist.add(sample.id, accountId: accountId);
    }
    final store = CatalogStore(database: db, shopDomain: _shop);
    addTearDown(store.dispose);

    await store.loadFromAsset();
    await store.syncWithShopify();

    expect(
        (await CatalogCacheStore(db).allProducts())
            .map((product) => product.id)
            .toSet(),
        rows.map((product) => product.id).toSet());
    expect((await CatalogCacheStore(db).metadata())?.productCount, rows.length);
    expect(await db.select(db.bagLines).get(), hasLength(2));
    expect(await db.select(db.wishlistItems).get(), hasLength(2));
    for (final accountId in [null, 'existing-account']) {
      expect((await bags.all(accountId: accountId)).single.quantity, 2);
      expect(await wishlist.allProductIds(accountId: accountId), {sample.id});
    }
    expect(store.products.map((product) => product.id),
        isNot(contains(sample.id)));
  });

  test('T2-SAMPLE featured rail filters after caching the complete response',
      () async {
    final real = _product(1, vendor: 'Guess');
    final sample = _product(2,
        vendor: 'Snowboard Vendor',
        title: 'Gift Card',
        productType: 'giftcard');
    List<Product>? cached;
    final controller = FeaturedCatalogController(
      repository: _FeaturedRows([real, sample]),
      cacheProducts: (products) async => cached = List.of(products),
    );
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(cached?.map((product) => product.id), [real.id, sample.id]);
    expect(controller.products.map((product) => product.id), [real.id]);
    expect(controller.status, FeaturedCatalogStatus.live);
  });

  test('T2-SAMPLE featured rail containing only samples is empty', () async {
    final samples = _sampleProducts();
    List<Product>? cached;
    final controller = FeaturedCatalogController(
      repository: _FeaturedRows(samples),
      cacheProducts: (products) async => cached = List.of(products),
    );
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(cached?.length, samples.length);
    expect({
      'products': controller.products.length,
      'status': controller.status,
    }, {
      'products': 0,
      'status': FeaturedCatalogStatus.empty,
    });
  });

  for (final handles in [
    ['hydrogen', 'automated-collection', 'guess'],
    [' HYDROGEN ', ' AuToMaTeD-CoLlEcTiOn ', 'guess'],
  ]) {
    test('T2-SAMPLE home excludes configured sample collections $handles',
        () async {
      final repository = HomeContentRepository(
        client: _client({
          'shop': {
            'homeCollections': {'value': jsonEncode(handles)},
            'homeBagTypes': {'value': jsonEncode(handles)},
          },
          'collections': {
            'edges': [
              for (final handle in [
                'hydrogen',
                'automated-collection',
                'guess'
              ])
                {'node': _collectionNode(handle)},
            ],
          },
        }),
      );

      final content = await repository.fetch();

      expect({
        'collections': content.collections.map((card) => card.handle).toList(),
        'bagTypes': content.bagTypes.map((card) => card.handle).toList(),
      }, {
        'collections': ['guess'],
        'bagTypes': ['guess'],
      });
    });
  }
}

Product _product(
  int id, {
  required String vendor,
  String title = 'Bolsa Guess',
  String productType = 'Bolsa',
  String? brandOverride,
}) =>
    Product(
      id: 'gid://shopify/Product/$id',
      handle: 'product-$id',
      title: title,
      vendor: vendor,
      productType: productType,
      tags: const [],
      variants: [
        ProductVariant(
            id: 'gid://shopify/ProductVariant/$id',
            title: 'Default Title',
            price: 100,
            available: true)
      ],
      images: const ['https://cdn.shopify.com/product.jpg'],
      createdAt: DateTime.utc(2026, 10, 1),
      updatedAt: DateTime.utc(2026, 10, 1),
      brandOverride: brandOverride,
      categoryOverride: 'bolsa',
    );

List<Product> _realProducts() => [
      _product(1, vendor: 'Guess'),
      _product(2, vendor: 'Monetta'),
      _product(3, vendor: 'Monetta '),
      _product(4,
          vendor: 'Guess',
          title: 'Snowboard Gift Card',
          productType: 'snowboard'),
    ];

List<Product> _sampleProducts() => [
      for (var index = 0; index < _sampleVendors.length; index++)
        _product(100 + index,
            vendor: _sampleVendors[index],
            title: 'SampleProbe',
            brandOverride: 'sample_brand'),
      _product(104,
          vendor: 'Snowboard Vendor',
          title: 'SampleProbe Gift Card',
          productType: 'giftcard',
          brandOverride: 'sample_brand'),
    ];

Future<void> _cacheCatalog(AppDatabase db, List<Product> products) =>
    CatalogCacheStore(db).replaceProducts(
      products,
      metadata: CatalogCacheMetadata.forProducts(
        source: CatalogCacheSource.shopify,
        products: products,
        syncedAt: DateTime.utc(2026, 10, 24),
        status: CatalogCacheStatus.healthy,
        shopDomain: _shop,
      ),
    );

Future<({CatalogStore store, AppDatabase db})> _loadedCatalog(
    List<Product> products) async {
  final db = openTestDatabase();
  await _cacheCatalog(db, products);
  final store = CatalogStore(database: db, shopDomain: _shop);
  addTearDown(store.dispose);
  await store.loadFromAsset();
  await store.syncWithShopify();
  return (store: store, db: db);
}

StorefrontClient _client(Map<String, dynamic> data) => StorefrontClient(
      config: const StorefrontConfig(
          shopDomain: _shop, accessToken: 'public-test-token'),
      transport: (_, __, ___) async => {'data': data},
    );

Map<String, Object?> _collectionNode(String handle) => {
      'id': 'gid://shopify/Collection/$handle',
      'handle': handle,
      'title': handle,
      'description': '',
      'products': {
        'pageInfo': {'hasNextPage': false},
        'edges': [
          {
            'node': {'id': 'gid://shopify/Product/1'}
          }
        ],
      },
    };

final class _FeaturedRows extends FeaturedCatalogRepository {
  _FeaturedRows(this.rows) : super(client: _client(const {}));

  final List<Product> rows;

  @override
  Future<List<Product>> fetch({int limit = 12}) async => rows;
}
