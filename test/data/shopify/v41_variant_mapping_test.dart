import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/shopify/mappers.dart';
import 'package:monetta_app/data/shopify/queries.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/product/variant_selection.dart';

import '../../support/v41_product_fixture.dart';

void main() {
  test(
      'Storefront queries preserve options, image and sixMsiAmount on every variant page',
      () {
    for (final query in [
      kProductFragment,
      productConnectionQuery('variants'),
    ]) {
      expect(query, contains('selectedOptions { name value }'));
      expect(query, contains('image { url(transform: {maxWidth: 1200}) }'));
      expect(
        query,
        contains(
          'sixMsiAmount: metafield(namespace: "monetta", key: "six_msi_amount") { value }',
        ),
      );
    }
  });
  test('maps monetta.six_msi_amount metafield into sixMsiInstallmentAmount',
      () {
    final json = v41ProductJson();
    final connection = json['variants'] as Map<String, dynamic>;
    final variants = (connection['edges'] as List).cast<Map<String, dynamic>>();
    (variants[0]['node'] as Map<String, dynamic>)['sixMsiAmount'] = {
      'value': '283.50',
    };
    (variants[1]['node'] as Map<String, dynamic>)['sixMsiAmount'] = {
      'value': '{"amount":"233.33","currency_code":"MXN"}',
    };
    (variants[2]['node'] as Map<String, dynamic>)['sixMsiAmount'] = {
      'value': '0',
    };
    final product = productFromJson(json);
    expect(product.variants[0].sixMsiInstallmentAmount, 283.50);
    expect(product.variants[1].sixMsiInstallmentAmount, 233.33);
    expect(product.variants[2].sixMsiInstallmentAmount, isNull);
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
