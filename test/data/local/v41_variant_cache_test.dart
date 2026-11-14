import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/catalog_cache_store.dart';
import '../../support/v41_product_fixture.dart';

void main() {
  test('variant options and image membership survive database cold reopen',
      () async {
    final dir = await Directory.systemTemp.createTemp('monetta-v41-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/catalog.sqlite');
    final first = AppDatabase(NativeDatabase(file));
    await CatalogCacheStore(first).upsertProducts([v41Product()]);
    await first.close();
    final second = AppDatabase(NativeDatabase(file));
    addTearDown(second.close);
    final product = (await CatalogCacheStore(second).allProducts()).single;
    expect(
      product.variants[1].selectedOptions,
      {'Color': 'Negro', 'Talla': '37'},
    );
    expect(product.variants[1].available, false);
    expect(product.variants[1].price, 1400);
    expect(product.variants[1].compareAtPrice, isNull);
    expect(
      product.variants[2].imageUrls,
      ['https://cdn.shopify.com/fixture/white.jpg'],
    );
  });
  test(
      'actual schema9 upgrade preserves catalog, bag and identity, resets cursor',
      () async {
    final dir = await Directory.systemTemp.createTemp('monetta-v41-upgrade-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/catalog.sqlite');
    final legacy = AppDatabase(NativeDatabase(file));
    await CatalogCacheStore(legacy).upsertProducts([v41Product()]);
    await legacy.customStatement(
      "INSERT INTO bag_lines (product_id,variant_id,account_id,quantity) VALUES ('gid://shopify/Product/9001','gid://shopify/ProductVariant/9101','',2)",
    );
    await legacy.customStatement(
      "INSERT INTO accounts (local_account_id,created_at,last_seen_at) VALUES ('account-preserved',1,1)",
    );
    await legacy.customStatement(
      "INSERT INTO sync_cursors (id,last_updated_at,last_full_sync_at,shop_domain) VALUES (0,1,1,'test.myshopify.com')",
    );
    await legacy.customStatement(
      'ALTER TABLE cached_variants DROP COLUMN selected_options',
    );
    await legacy
        .customStatement('ALTER TABLE cached_variants DROP COLUMN image_urls');
    await legacy.customStatement('PRAGMA user_version = 9');
    await legacy.close();
    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    final products = await CatalogCacheStore(upgraded).allProducts();
    expect(products.single.variants, hasLength(3));
    expect(products.single.variants.first.selectedOptions, isEmpty);
    expect(products.single.variants.first.imageUrls, isEmpty);
    expect((await upgraded.select(upgraded.bagLines).get()).single.quantity, 2);
    expect(
      (await upgraded.select(upgraded.accounts).get()).single.localAccountId,
      'account-preserved',
    );
    expect(await upgraded.select(upgraded.syncCursors).get(), isEmpty);
    expect(
      (await upgraded.customSelect('PRAGMA user_version').getSingle())
          .data
          .values
          .single,
      10,
    );
  });
}
