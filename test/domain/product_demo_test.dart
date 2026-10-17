import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/domain/product.dart';

Product _product({required String vendor, String productType = ''}) => Product(
      id: 'gid://shopify/Product/1',
      handle: 'p',
      title: 'P',
      vendor: vendor,
      productType: productType,
      tags: const [],
      variants: const [],
      images: const [],
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

void main() {
  test('Shopify sample products are flagged as demo', () {
    expect(_product(vendor: 'Monetta Staging').isDemoProduct, isTrue);
    expect(_product(vendor: ' monetta staging ').isDemoProduct, isTrue);
    expect(
      _product(vendor: 'Hydrogen Vendor', productType: 'Snowboard')
          .isDemoProduct,
      isTrue,
    );
  });

  test('real Monetta products are not demo', () {
    expect(_product(vendor: 'Monetta ').isDemoProduct, isFalse);
    expect(
        _product(vendor: 'Guess', productType: 'Bolsa').isDemoProduct, isFalse);
  });
}
