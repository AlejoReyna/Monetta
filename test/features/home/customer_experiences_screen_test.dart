import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/reviews/loox_reviews_repository.dart';
import 'package:monetta_app/domain/home_content.dart';
import 'package:monetta_app/features/home/customer_experiences_screen.dart';

String _pageHtml({
  required int start,
  required int count,
  required bool hasMore,
}) {
  final reviews = List<String>.generate(count, (offset) {
    final index = start + offset;
    return '''
      <div data-id="review-$index" class="grid-item-wrap">
        <div data-testid="review-review-$index-title"><div class="title">
          Cliente $index
        </div></div>
        <div data-testid="review-review-$index-stars">
          <svg data-lx-fill="full"></svg>
          <svg data-lx-fill="full"></svg>
          <svg data-lx-fill="full"></svg>
          <svg data-lx-fill="full"></svg>
          <svg data-lx-fill="full"></svg>
        </div>
        <div data-testid="review-review-$index-text" class="main-text">
          Reseña $index
        </div>
      </div>
    ''';
  }).join();
  final next = hasMore
      ? '<button id="loadMore" data-url="h=&amp;total=40&amp;limit=20&amp;'
          'language=es&amp;page=2"></button>'
      : '';
  return '''
    <div data-testid="rating-summary-avg"
        aria-label="Average rating: 4.9 / 5 star review"></div>
    <div data-testid="rating-summary-count"><span>40 Reseñas</span></div>
    $reviews
    $next
  ''';
}

HomeTestimonial _fallbackReview() => const HomeTestimonial(
      reviewer: 'Cliente fallback',
      body: 'Reseña fallback',
      rating: 5,
      fallbackAsset: '',
    );

void main() {
  testWidgets('loads the next batch when the review list nears its end',
      (tester) async {
    final requestedPages = <int>[];
    final repository = LooxReviewsRepository(
      config: const LooxConfig(publicStoreId: 'public-store'),
      get: (uri) async {
        final page = int.parse(uri.queryParameters['page'] ?? '1');
        requestedPages.add(page);
        return http.Response(
          _pageHtml(
            start: page == 1 ? 0 : 20,
            count: 20,
            hasMore: page == 1,
          ),
          200,
        );
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: CustomerExperiencesScreen(
          repository: repository,
          fallbackReviews: [_fallbackReview()],
          average: 4.9,
          count: 40,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(requestedPages, [1]);
    expect(find.text('Cliente 0'), findsWidgets);
    expect(find.text('Cliente 20'), findsNothing);

    await tester.fling(
      find.byKey(const ValueKey('customer-experiences-scroll')),
      const Offset(0, -20000),
      1000,
    );
    await tester.pumpAndSettle();

    expect(requestedPages, [1, 2]);
  });
}
