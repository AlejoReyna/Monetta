/// Shopper read path for the owner-managed Today's Picks collection.
library;

import '../../domain/product.dart';
import 'mappers.dart';
import 'queries.dart';
import 'storefront_client.dart';

class FeaturedCatalogRepository {
  const FeaturedCatalogRepository({required this.client});

  final StorefrontClient client;

  Future<List<Product>> fetch({int limit = 12}) async {
    final data = await client.query(
      kCollectionProductsQuery,
      variables: {
        'handle': 'monetta-todays-picks',
        'first': limit.clamp(1, 12),
        'after': null,
        'sortKey': null,
        'reverse': null,
      },
    );
    final collection = data['collection'];
    if (collection is! Map<String, dynamic>) return const [];
    return edgeNodes(collection['products'])
        .map(productFromJson)
        .toList(growable: false);
  }
}
