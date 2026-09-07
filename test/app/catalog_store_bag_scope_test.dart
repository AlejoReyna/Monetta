/// Variant persistence and account scoping for the local bag / wishlist (F04, F11).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/local/bag_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/wishlist_store.dart';
import 'package:monetta_app/domain/product.dart';

Product _productWithVariants() => Product(
      id: 'gid://shopify/Product/bag-scope-1',
      handle: 'bag-scope-1',
      title: 'Bolsa Scope',
      vendor: 'Monetta',
      productType: 'Bolsa',
      tags: const [],
      images: const ['https://cdn.example/x.jpg'],
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
      variants: const [
        ProductVariant(
          id: 'gid://shopify/ProductVariant/A',
          title: 'A',
          price: 100,
          available: true,
        ),
        ProductVariant(
          id: 'gid://shopify/ProductVariant/B',
          title: 'B',
          price: 200,
          available: true,
        ),
        ProductVariant(
          id: 'gid://shopify/ProductVariant/C',
          title: 'C',
          price: 50,
          available: false,
        ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CatalogStore store;

  setUp(() async {
    db = openTestDatabase();
    store = CatalogStore(database: db, shopDomain: 'monetta.mx');
    await store.loadFromAsset();
    // Overlay a controlled multi-variant product for these assertions.
    store.products = [...store.products, _productWithVariants()];
  });

  tearDown(() async {
    store.dispose();
  });

  test('selected variant B persists and coexists with A (F04)', () async {
    final product = store.products.firstWhere(
      (p) => p.id == 'gid://shopify/Product/bag-scope-1',
    );

    await store.addToBag(product, variantId: 'gid://shopify/ProductVariant/B');
    await store.addToBag(product, variantId: 'gid://shopify/ProductVariant/A');

    expect(
      store.bagLines
          .where((l) => l.product.id == product.id)
          .map((l) => l.variant.id)
          .toSet(),
      {
        'gid://shopify/ProductVariant/A',
        'gid://shopify/ProductVariant/B',
      },
    );

    final durable = await BagStore(db).all();
    expect(
      durable
          .where((r) => r.productId == product.id)
          .map((r) => r.variantId)
          .toSet(),
      {
        'gid://shopify/ProductVariant/A',
        'gid://shopify/ProductVariant/B',
      },
    );

    await store.setAccountScope(null);
    final b = store.bagLines.firstWhere(
      (l) => l.variant.id == 'gid://shopify/ProductVariant/B',
    );
    expect(b.variant.title, 'B');
    expect(b.variant.price, 200);
    expect(
      store.bagLines
          .any((l) => l.variant.id == 'gid://shopify/ProductVariant/C'),
      isFalse,
    );
  });

  test('account B never reads account A bag or wishlist (F11)', () async {
    final product = store.products.firstWhere(
      (p) => p.id == 'gid://shopify/Product/bag-scope-1',
    );

    await store.setAccountScope('acct-a');
    await store.addToBag(product, variantId: 'gid://shopify/ProductVariant/A');
    await store.toggleWishlist(product.id);
    expect(
      store.bagLines
          .any((l) => l.variant.id == 'gid://shopify/ProductVariant/A'),
      isTrue,
    );
    expect(store.wishlist, contains(product.id));

    await store.setAccountScope('acct-b');
    expect(
      store.bagLines.any((l) => l.product.id == product.id),
      isFalse,
    );
    expect(store.wishlist.contains(product.id), isFalse);

    await store.addToBag(product, variantId: 'gid://shopify/ProductVariant/B');
    expect(
      store.bagLines.singleWhere((l) => l.product.id == product.id).variant.id,
      'gid://shopify/ProductVariant/B',
    );

    await store.setAccountScope('acct-a');
    expect(
      store.bagLines.singleWhere((l) => l.product.id == product.id).variant.id,
      'gid://shopify/ProductVariant/A',
    );
    expect(store.wishlist, contains(product.id));

    expect(await WishlistStore(db).allProductIds(accountId: 'acct-b'), isEmpty);
  });
}
