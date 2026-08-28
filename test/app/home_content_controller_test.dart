import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:monetta_app/app/home_content_controller.dart';
import 'package:monetta_app/data/reviews/loox_reviews_repository.dart';

LooxReviewsRepository _reviews({
  required Future<http.Response> Function(Uri uri) get,
}) {
  return LooxReviewsRepository(
    config: const LooxConfig(publicStoreId: 'public-store'),
    get: get,
  );
}

String _oneReview(String name) => '''
{
  "data": {
    "agg": {
      "reviews": [
        {
          "rating": 5,
          "reviewer": "$name",
          "review": "Excelente compra.",
          "verified": true,
          "midImage": "https://images.loox.io/$name.jpg"
        }
      ]
    }
  }
}
''';

void main() {
  test('starts in loading then publishes live reviews', () async {
    final controller = HomeContentController(
      reviewsRepository: _reviews(
        get: (uri) async {
          if (uri.path.contains('dynamic-carousel/reviews')) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return http.Response(_oneReview('Gaby E.'), 200);
          }
          return http.Response('', 404);
        },
      ),
    );
    addTearDown(controller.dispose);

    expect(controller.reviewsStatus, HomeReviewsStatus.loading);
    expect(controller.content.testimonials.first.reviewer, 'Monse C.');

    final future = controller.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(controller.reviewsStatus, HomeReviewsStatus.loading);
    await future;

    expect(controller.reviewsStatus, HomeReviewsStatus.live);
    expect(controller.content.testimonials.single.reviewer, 'Gaby E.');
  });

  test('uses bundled testimonials when the live request fails', () async {
    final controller = HomeContentController(
      reviewsRepository: _reviews(
        get: (_) async => http.Response('nope', 500),
      ),
    );
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(controller.reviewsStatus, HomeReviewsStatus.fallback);
    expect(controller.content.testimonials.first.reviewer, 'Monse C.');
  });

  test('empty live payload is an empty state, not bundled reviews', () async {
    final controller = HomeContentController(
      reviewsRepository: _reviews(
        get: (uri) async {
          if (uri.path.contains('dynamic-carousel/reviews')) {
            return http.Response('{"data":{"agg":{"reviews":[]}}}', 200);
          }
          return http.Response('', 404);
        },
      ),
    );
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(controller.reviewsStatus, HomeReviewsStatus.empty);
    expect(controller.content.testimonials, isEmpty);
  });

  test('a later refresh replaces reviews without a new controller', () async {
    var payload = _oneReview('Gaby E.');
    final controller = HomeContentController(
      reviewsRepository: _reviews(
        get: (uri) async {
          if (uri.path.contains('dynamic-carousel/reviews')) {
            return http.Response(payload, 200);
          }
          return http.Response('', 404);
        },
      ),
    );
    addTearDown(controller.dispose);

    await controller.refresh();
    expect(controller.content.testimonials.single.reviewer, 'Gaby E.');

    payload = _oneReview('Paty G.');
    await controller.refresh();

    expect(controller.reviewsStatus, HomeReviewsStatus.live);
    expect(controller.content.testimonials.single.reviewer, 'Paty G.');
  });

  test('keeps last live reviews when a later refresh fails', () async {
    var fail = false;
    final controller = HomeContentController(
      reviewsRepository: _reviews(
        get: (uri) async {
          if (fail) return http.Response('nope', 503);
          if (uri.path.contains('dynamic-carousel/reviews')) {
            return http.Response(_oneReview('Gaby E.'), 200);
          }
          return http.Response('', 404);
        },
      ),
    );
    addTearDown(controller.dispose);

    await controller.refresh();
    fail = true;
    await controller.refresh();

    expect(controller.reviewsStatus, HomeReviewsStatus.live);
    expect(controller.content.testimonials.single.reviewer, 'Gaby E.');
  });

  test('without a reviews repository the bundled content stays in fallback',
      () async {
    final controller = HomeContentController();
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(controller.reviewsStatus, HomeReviewsStatus.fallback);
    expect(
      controller.content.testimonials.map((item) => item.reviewer),
      ['Monse C.', 'Gaby E.', 'Guadalupe G.'],
    );
  });
}
