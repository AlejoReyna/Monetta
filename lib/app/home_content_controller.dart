/// Best-effort Shopify + Loox state for the home screen.
library;

import 'package:flutter/foundation.dart';

import '../data/reviews/loox_reviews_repository.dart';
import '../data/shopify/home_content_repository.dart';
import '../domain/home_content.dart';

class HomeContentController extends ChangeNotifier {
  HomeContentController({
    HomeContentRepository? repository,
    LooxReviewsRepository? reviewsRepository,
  })  : _repository = repository,
        _reviewsRepository = reviewsRepository;

  final HomeContentRepository? _repository;
  final LooxReviewsRepository? _reviewsRepository;
  HomeContent _content = HomeContent.fallback;

  HomeContent get content => _content;

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
      try {
        final result = await reviewsRepository.fetch(
          fallback: next.testimonials,
        );
        next = next.copyWith(
          testimonials: result.reviews,
          reviewAverage: result.average,
          reviewCount: result.count,
        );
      } on Object {
        // Loox availability depends on plan/CORS. The local reviews remain.
      }
    }

    if (!identical(next, _content)) {
      _content = next;
      notifyListeners();
    }
  }
}
