import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/wholesale/wholesale_screen.dart';

void main() {
  test('editorial recommendations preserve unique real input up to 40', () {
    Product fixture(int id) => Product(
        id: '$id',
        handle: '$id',
        title: 'Fixture $id',
        vendor: '',
        productType: '',
        tags: const [],
        variants: const [],
        images: const [],
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026));
    final products = [
      fixture(0),
      fixture(0),
      for (var i = 1; i < 45; i++) fixture(i)
    ];
    final result = wholesaleRecommendations(products);
    expect(result, hasLength(40));
    expect(result.map((p) => p.id).toSet(), hasLength(40));
    expect(result.first.id, '0');
    expect(wholesaleRecommendations(products.take(2)), hasLength(1));
  });
}
