/// Best-effort Shopify + Loox state for the home screen.
library;

import 'package:flutter/foundation.dart';

import '../data/reviews/loox_reviews_repository.dart';
import '../data/shopify/home_content_repository.dart';
import '../domain/home_content.dart';

enum HomeReviewsStatus { loading, live, empty, fallback }

class HomeContentController extends ChangeNotifier {
  HomeContentController({
    HomeContentRepository? repository,
    LooxReviewsRepository? reviewsRepository,
  })  : _repository = repository,
        _reviewsRepository = reviewsRepository,
        _reviewsStatus = reviewsRepository == null
            ? HomeReviewsStatus.fallback
            : HomeReviewsStatus.loading;

  final HomeContentRepository? _repository;
  final LooxReviewsRepository? _reviewsRepository;
  HomeContent _content = HomeContent.fallback;
  HomeReviewsStatus _reviewsStatus;
  bool _hasLiveReviews = false;

  HomeContent get content => _content;
  HomeReviewsStatus get reviewsStatus => _reviewsStatus;
  LooxReviewsRepository? get reviewsRepository => _reviewsRepository;

  Future<void> refresh() async {
    var next = _content;
    final repository = _repository;
    if (repository != null) {
      try {
        next = await repository.fetch(fallback: next);
      } on Object {
        // Keep the complete bundled/last-known content.
      }
    }

    final reviewsRepository = _reviewsRepository;
    if (reviewsRepository != null) {
      if (!_hasLiveReviews) {
        _reviewsStatus = HomeReviewsStatus.loading;
        notifyListeners();
      }
      try {
        final result = await reviewsRepository.fetch(
          fallback: next.testimonials,
        );
        if (result.fromRemote && result.reviews.isEmpty) {
          next = next.copyWith(testimonials: const <HomeTestimonial>[]);
          _reviewsStatus = HomeReviewsStatus.empty;
          _hasLiveReviews = false;
        } else if (result.fromRemote) {
          next = next.copyWith(
            testimonials: result.reviews,
            reviewAverage: result.average ?? next.reviewAverage,
            reviewCount: result.count ?? next.reviewCount,
          );
          _reviewsStatus = HomeReviewsStatus.live;
          _hasLiveReviews = true;
        } else if (!_hasLiveReviews) {
          _reviewsStatus = HomeReviewsStatus.fallback;
        }
      } on Object {
        if (!_hasLiveReviews) {
          _reviewsStatus = HomeReviewsStatus.fallback;
        }
      }
    }

    _content = next;
    notifyListeners();
  }
}
