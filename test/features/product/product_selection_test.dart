import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/product/product_selection.dart';

Product _product({
  String id = 'p1',
  List<ProductVariant> variants = const [],
}) {
  return Product(
    id: id,
    handle: 'handle-$id',
    title: 'Bolsa Test',
    vendor: '',
    productType: '',
    tags: const [],
    variants: variants,
    images: const [],
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
}

ProductVariant _variant(
  String title, {
  String? id,
  double price = 1000,
  double? compare,
  bool available = true,
}) {
  return ProductVariant(
    id: id ?? 'v-$title',
    title: title,
    price: price,
    compareAtPrice: compare,
    available: available,
  );
}

void main() {
  test('single-variant Default Title has no selectable options', () {
    final product = _product(
      variants: [_variant('Default Title')],
    );
    expect(selectableVariants(product), isEmpty);
    expect(hasReliableColorOptions(product), isFalse);
    // Falls back to the only variant for pricing.
    expect(selectionPrice(product, 0), 1000);
    expect(selectionInStock(product, 0), isTrue);
  });

  test('discount renders only off real compare_at data', () {
    final onSale = _product(
      variants: [_variant('Negro', price: 1299, compare: 1549)],
    );
    expect(selectionOnSale(onSale, 0), isTrue);
    expect(selectionDiscountPercent(onSale, 0), 16);

    final noData = _product(
      variants: [_variant('Negro', price: 1299)],
    );
    expect(selectionOnSale(noData, 0), isFalse);
    expect(selectionDiscountPercent(noData, 0), 0);

    final inverted = _product(
      variants: [_variant('Negro', price: 1600, compare: 1549)],
    );
    expect(selectionOnSale(inverted, 0), isFalse);
    expect(selectionDiscountPercent(inverted, 0), 0);
  });

  test('selection clamps an out-of-range index', () {
    final product = _product(
      variants: [_variant('Negro'), _variant('Gris', available: false)],
    );
    expect(selectedVariant(product, 9)?.title, 'Negro');
    expect(selectedVariant(product, -1)?.title, 'Negro');
    expect(selectionInStock(product, 1), isFalse);
  });

  test('reliable colour mapping accepts only single colours', () {
    expect(reliableColorSlug('Negro'), 'negro');
    expect(reliableColorSlug('Azul Oscuro'), 'azul');
    expect(reliableColorSlug('Rosa Blush'), 'rosa');
    expect(reliableColorSlug('Gris'), 'gris');
    expect(reliableColorSlug('Blanco'), 'blanco');

    // Bicolors and composed colorways have no single swatch.
    expect(reliableColorSlug('Cafe/Dorado'), isNull);
    expect(
      reliableColorSlug('Arena/Beige Dorado Signature Canvas'),
      isNull,
    );
    expect(reliableColorSlug('Blanco y Plata'), isNull);
    // Unknown words are never invented.
    expect(reliableColorSlug('Marrón'), isNull);
    expect(reliableColorSlug(''), isNull);
  });

  test('swatches only when every option maps reliably', () {
    final reliable = _product(
      variants: [_variant('Azul Oscuro'), _variant('Gris')],
    );
    expect(hasReliableColorOptions(reliable), isTrue);

    final mixed = _product(
      variants: [_variant('Negro'), _variant('Cafe/Dorado')],
    );
    expect(hasReliableColorOptions(mixed), isFalse);

    final unknown = _product(
      variants: [_variant('Marrón'), _variant('Negro')],
    );
    expect(hasReliableColorOptions(unknown), isFalse);
  });
}
