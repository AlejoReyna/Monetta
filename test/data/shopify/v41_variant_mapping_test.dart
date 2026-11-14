import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/shopify/mappers.dart';
import 'package:monetta_app/data/shopify/queries.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/product/variant_selection.dart';

import '../../support/v41_product_fixture.dart';

void main() {
  test('Storefront queries preserve options and image on every variant page',
      () {
    for (final query in [
      kProductFragment,
      productConnectionQuery('variants'),
    ]) {
      expect(query, contains('selectedOptions { name value }'));
      expect(query, contains('image { url(transform: {maxWidth: 1200}) }'));
    }
  });
  test('real wire options resolve exact stock/price/photo combinations', () {
    final product = v41Product();
    expect(productOptionValues(product), {
      'Color': ['Negro', 'Blanco'],
      'Talla': ['36', '37'],
    });
    final exhausted = product
        .variants[indexForOptions(product, {'Color': 'Negro', 'Talla': '37'})];
    expect(exhausted.available, false);
    expect(exhausted.price, 1400);
    expect(exhausted.compareAtPrice, isNull);
    expect(
      imagesForVariant(product, exhausted),
      ['https://cdn.shopify.com/fixture/black.jpg'],
    );
    expect(indexForOptions(product, {'Color': 'Blanco', 'Talla': '37'}), -1);
    expect(variantIndexForId(product, 'gid://shopify/ProductVariant/9103'), 2);
    expect(variantIndexForId(product, 'removed'), -1);
  });
  test('missing image membership stays missing, titles do not invent options',
      () {
    final json = v41ProductJson();
    final connection = json['variants'] as Map<String, dynamic>;
    final variants = (connection['edges'] as List).cast<Map<String, dynamic>>();
    for (final row in variants) {
      final node = row['node'] as Map<String, dynamic>;
      node.remove('selectedOptions');
      node.remove('image');
    }
    final product = productFromJson(json);
    expect(productOptionValues(product), isEmpty);
    expect(imagesForVariant(product, product.variants.first), isEmpty);
  });
}
