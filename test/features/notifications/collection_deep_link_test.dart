import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';

void main() {
  test('notification collection routes use collectionHandle identity', () {
    // F28: category facet != Shopify collection handle.
    const viaHandle = CollectionFilter(collectionHandle: 'steve-madden');
    const viaCategory = CollectionFilter(category: 'steve-madden');
    expect(viaHandle.collectionHandle, 'steve-madden');
    expect(viaHandle.category, isNull);
    expect(viaCategory.category, 'steve-madden');
    expect(viaCategory.collectionHandle, isNull);
  });
}
