import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/normalize/facets.dart';
import 'package:monetta_app/features/product/product_recommendations.dart';
import '../../support/product_screen_harness.dart';

void main() {
  test('rails retain 40 unique real products, source order and fewer-item sets',
      () {
    final products = List.generate(45, (i) => syntheticProduct(id: '$i'));
    final set = uniqueProductSet(
      [products[0], products[0], ...products],
      excluding: '2',
    );
    expect(set, hasLength(40));
    expect(set.map((p) => p.id).toSet(), hasLength(40));
    expect(set.map((p) => p.id), isNot(contains('2')));
    expect(
      uniqueProductSet(products.take(3), excluding: '1').map((p) => p.id),
      ['0', '2'],
    );
    expect(uniqueProductSet([], excluding: '1'), isEmpty);
  });
  test('related is actual category/silhouette membership, not the brand set',
      () {
    final products = List.generate(4, (i) => syntheticProduct(id: '$i'));
    CanonicalFacets? facets(String id) => id == '3'
        ? null
        : CanonicalFacets(
            productId: id,
            brand: FacetValue(
              id == '1' ? 'coach' : 'guess',
              FacetSource.metafieldOverride,
            ),
            category: const FacetValue('bolsa', FacetSource.metafieldOverride),
            silhouette: FacetValue(
              id == '2' ? 'tote' : 'crossbody',
              FacetSource.metafieldOverride,
            ),
            priceBand: null,
            onSale: false,
            inStock: true,
            newArrival: false,
          );
    expect(
      relatedProductSet(products[0], products, facets).map((p) => p.id),
      ['1'],
    );
    expect(relatedProductSet(products[3], products, facets), isEmpty);
  });
}
