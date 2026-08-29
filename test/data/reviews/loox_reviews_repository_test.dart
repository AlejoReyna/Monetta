import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:monetta_app/data/reviews/loox_reviews_repository.dart';

String _carouselJson(String reviews) => '''
{
  "data": {
    "agg": {
      "reviews": [$reviews]
    }
  }
}
''';

String _reviewsPageHtml({
  required String id,
  required String reviewer,
  required String body,
  int rating = 5,
  String? nextPage,
}) {
  final stars = List<String>.generate(
    rating,
    (_) => '<svg data-lx-fill="full"></svg>',
  ).join();
  final next = nextPage == null
      ? ''
      : '<button id="loadMore" data-url="h=&amp;total=42&amp;limit=20&amp;'
          'language=es&amp;page=$nextPage"></button>';
  return '''
    <div data-testid="rating-summary-avg"
        aria-label="Average rating: 4.9 / 5 star review"></div>
    <div data-testid="rating-summary-count"><span>42 Reseñas</span></div>
    <div data-id="$id" data-media-type="photo" class="grid-item-wrap">
      <div class="grid-item">
        <div data-testid="review-$id-media" class="item-img">
          <img src="//images.loox.io/$id.jpg" alt="Foto del producto">
        </div>
        <div data-testid="review-$id-title" class="feed-item-title-wrapper">
          <div class="title">$reviewer
            <span class="verified-badge-and-text">
              <svg class="loox-verified-badge"></svg>
            </span>
          </div>
        </div>
        <div data-testid="review-$id-stars" class="stars">$stars</div>
        <div data-testid="review-$id-text" class="main-text">$body</div>
        <div class="product-box"><div class="name">Bolsa de prueba</div></div>
      </div>
    </div>
    $next
  ''';
}

LooxReviewsRepository _repository({
  required Future<http.Response> Function(Uri uri) get,
}) {
  return LooxReviewsRepository(
    config: const LooxConfig(publicStoreId: 'o68QLEOJFW'),
    get: get,
  );
}

void main() {
  test('maps the public Loox carousel JSON without customer-private data',
      () async {
    final repository = _repository(
      get: (uri) async {
        if (uri.path.contains('dynamic-carousel/reviews')) {
          expect(
            uri.toString(),
            'https://loox.io/widget/o68QLEOJFW/dynamic-carousel/reviews/',
          );
          return http.Response(
            _carouselJson('''
              {
                "id": "WpVh3R2iuj",
                "rating": 5,
                "reviewer": "Gaby E.",
                "review": "Me encanta que todo sea 100% original.",
                "verified": true,
                "poster": "//images.loox.io/uploads/review.jpg",
                "midImage": "//images.loox.io/uploads/review_mid.jpg",
                "productName": "Cartera Guess Negra Monograma",
                "altText": "Foto de Cartera Guess Negra Monograma",
                "email": "hidden@example.com",
                "phone": "5551234567",
                "address": "Calle Falsa 123"
              }
            '''),
            200,
          );
        }
        return http.Response(
          '''<div data-testid="rating-summary-avg" aria-label="Average rating: 4.9 / 5 star review"></div>
          <div data-testid="rating-summary-count" class="summary-text"><span>139 Reseñas</span></div>''',
          200,
        );
      },
    );

    final result = await repository.fetch();

    expect(result.fromRemote, isTrue);
    expect(result.reviews, hasLength(1));
    final review = result.reviews.single;
    expect(review.reviewer, 'Gaby E.');
    expect(review.rating, 5);
    expect(review.verified, isTrue);
    expect(
      review.imageUrl,
      'https://images.loox.io/uploads/review_mid.jpg',
    );
    expect(review.productName, 'Cartera Guess Negra Monograma');
    expect(review.imageAlt, 'Foto de Cartera Guess Negra Monograma');
    expect(result.average, 4.9);
    expect(result.count, 139);
    expect(review.body, isNot(contains('hidden@example.com')));
    expect(review.reviewer, isNot(contains('@')));
    expect(review.body, isNot(contains('5551234567')));
    expect(review.body, isNot(contains('Calle Falsa')));
  });

  test('keeps published order and stops at the live carousel limit', () async {
    final items = List<String>.generate(
      25,
      (index) => '''
        {
          "rating": 5,
          "reviewer": "Cliente $index",
          "review": "Reseña $index",
          "verified": true,
          "midImage": "https://images.loox.io/review-$index.jpg"
        }
      ''',
    );
    final repository = _repository(
      get: (uri) async {
        if (uri.path.contains('dynamic-carousel/reviews')) {
          return http.Response(_carouselJson(items.join(',')), 200);
        }
        return http.Response('', 404);
      },
    );

    final result = await repository.fetch();

    expect(result.reviews, hasLength(20));
    expect(result.reviews.first.reviewer, 'Cliente 0');
    expect(result.reviews.last.reviewer, 'Cliente 19');
  });

  test('rejects insecure image URLs', () async {
    final repository = _repository(
      get: (uri) async {
        if (uri.path.contains('dynamic-carousel/reviews')) {
          return http.Response(
            _carouselJson('''
              {
                "rating": 4,
                "reviewer": "Ana G.",
                "review": "Muy bien empacado.",
                "verified": true,
                "midImage": "http://images.loox.io/insecure.jpg"
              }
            '''),
            200,
          );
        }
        return http.Response('', 404);
      },
    );

    final result = await repository.fetch();

    expect(result.reviews.single.imageUrl, isNull);
    expect(result.reviews.single.reviewer, 'Ana G.');
  });

  test('does not expose reviewer emails or phone numbers', () async {
    final repository = _repository(
      get: (uri) async {
        if (uri.path.contains('dynamic-carousel/reviews')) {
          return http.Response(
            _carouselJson('''
              {
                "rating": 5,
                "reviewer": "ana@example.com",
                "review": "Todo original.",
                "phone": "+52 55 1234 5678",
                "email": "ana@example.com",
                "customerId": "gid://shopify/Customer/1"
              }
            '''),
            200,
          );
        }
        return http.Response('', 404);
      },
    );

    final result = await repository.fetch();
    final encoded = result.reviews.single.reviewer + result.reviews.single.body;
    expect(encoded, isNot(contains('@')));
    expect(encoded, isNot(contains('1234')));
    expect(encoded, isNot(contains('Customer')));
    expect(result.reviews.single.reviewer, 'Cliente Monetta');
  });

  test('returns an empty live list when Loox has no published reviews',
      () async {
    final repository = _repository(
      get: (uri) async {
        if (uri.path.contains('dynamic-carousel/reviews')) {
          return http.Response(_carouselJson(''), 200);
        }
        return http.Response('', 404);
      },
    );

    final result = await repository.fetch();

    expect(result.fromRemote, isTrue);
    expect(result.reviews, isEmpty);
  });

  test('throws when the public carousel endpoint fails', () async {
    final repository = _repository(
      get: (uri) async {
        if (uri.path.contains('dynamic-carousel/reviews')) {
          return http.Response('nope', 500);
        }
        return http.Response('', 404);
      },
    );

    await expectLater(repository.fetch(), throwsA(isA<http.ClientException>()));
  });

  test('maps a paginated full review page and its next batch', () async {
    final requestedPages = <String>[];
    final repository = _repository(
      get: (uri) async {
        final page = uri.queryParameters['page'] ?? '1';
        requestedPages.add(page);
        return http.Response(
          _reviewsPageHtml(
            id: 'review-$page',
            reviewer: 'Ana G.',
            body: 'Todo llegó perfecto &amp; rápido.',
            rating: 4,
            nextPage: page == '1' ? '2' : null,
          ),
          200,
        );
      },
    );

    final first = await repository.fetchPage();
    final second = await repository.fetchPage(
      page: first.page + 1,
      limit: first.limit,
      total: first.total,
    );

    expect(requestedPages, ['1', '2']);
    expect(first.reviews, hasLength(1));
    expect(first.reviews.single.reviewer, 'Ana G.');
    expect(first.reviews.single.body, 'Todo llegó perfecto & rápido.');
    expect(first.reviews.single.rating, 4);
    expect(first.reviews.single.verified, isTrue);
    expect(
      first.reviews.single.imageUrl,
      'https://images.loox.io/review-1.jpg',
    );
    expect(first.reviews.single.productName, 'Bolsa de prueba');
    expect(first.total, 42);
    expect(first.average, 4.9);
    expect(first.hasMore, isTrue);
    expect(second.hasMore, isFalse);
  });
}
