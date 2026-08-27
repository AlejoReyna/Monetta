import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:monetta_app/data/reviews/loox_reviews_repository.dart';

void main() {
  test('maps public Loox reviews without customer-private data', () async {
    final repository = LooxReviewsRepository(
      config: const LooxConfig(publicStoreId: 'public-store'),
      get: (uri) async {
        expect(
          uri.toString(),
          'https://storefront-api.loox.io/storefront/v1/store/'
          'public-store/product-reviews',
        );
        return http.Response(
          '''{
            "data": {
              "reviews": [
                {
                  "reviewerName": "Ana G.",
                  "body": "Todo llegó original y muy bien empacado.",
                  "rating": 5,
                  "verified": true,
                  "photos": [{"url": "https://cdn.loox.io/review.jpg"}]
                }
              ],
              "averageRating": 4.9,
              "totalReviews": 139
            }
          }''',
          200,
        );
      },
    );

    final result = await repository.fetch();

    expect(result.reviews, hasLength(1));
    expect(result.reviews.single.reviewer, 'Ana G.');
    expect(result.reviews.single.rating, 5);
    expect(result.reviews.single.verified, isTrue);
    expect(result.reviews.single.imageUrl, 'https://cdn.loox.io/review.jpg');
    expect(result.average, 4.9);
    expect(result.count, 139);
  });

  test('keeps bundled testimonials when Loox returns no published reviews',
      () async {
    final repository = LooxReviewsRepository(
      config: const LooxConfig(publicStoreId: 'public-store'),
      get: (_) async => http.Response('{"reviews": []}', 200),
    );

    final result = await repository.fetch();

    expect(result.reviews, isNotEmpty);
    expect(result.reviews.first.reviewer, 'Monse C.');
  });
}
