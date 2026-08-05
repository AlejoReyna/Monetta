/// Ranks catalog products against a [TasteProfile].
///
/// Pure Dart, deterministic. Given the same profile, candidates and context it
/// always returns the same ordering — which is what makes the tests in
/// `test/reco/` meaningful.
library;

import '../data/normalize/facets.dart';
import 'profile.dart';

/// Everything the scorer needs to know beyond the facets themselves.
class ScoringContext {
  const ScoringContext({
    this.viewedProductIds = const {},
    this.purchasedProductIds = const {},
    this.wishlistedProductIds = const {},
    this.discountByProductId = const {},
    this.recentlyRestockedIds = const {},
  });

  final Set<String> viewedProductIds;
  final Set<String> purchasedProductIds;
  final Set<String> wishlistedProductIds;

  /// productId → 0..1 fraction off. Drives both the boost and the
  /// "Bajó de precio" explanation.
  final Map<String, double> discountByProductId;

  /// Products whose stock went 0 → >0 recently. The highest-intent thing we can
  /// surface on this store, where 21% of variants are out of stock at any time.
  final Set<String> recentlyRestockedIds;
}

/// Tunable multipliers. Extracted so they can be moved to Remote Config and
/// A/B tested in Phase 3 without touching the algorithm.
class ScoringWeights {
  const ScoringWeights({
    this.outOfStockPenalty = 0.25,
    this.onSaleBoost = 1.08,
    this.newArrivalBoost = 1.05,
    this.restockedBoost = 1.20,
    this.alreadyViewedPenalty = 0.6,
    this.wishlistedPenalty = 0.5,
    this.lowConfidenceFloor = 0.35,
    this.maxConsecutiveSameBrand = 2,
  });

  /// Out-of-stock products are pushed down, not removed. Seeing a sold-out bag
  /// you love is what makes someone tap "avísame" — which is the notification
  /// with the best conversion on this store.
  final double outOfStockPenalty;

  final double onSaleBoost;
  final double newArrivalBoost;
  final double restockedBoost;

  /// Already-viewed products still appear (people revisit before buying a
  /// $1,749 bag) but yield to something new.
  final double alreadyViewedPenalty;

  /// Wishlisted items live on the wishlist screen; they don't need the feed.
  final double wishlistedPenalty;

  /// Poorly-classified products (see `data/normalize`) can still surface, but
  /// their score is floored so a confident match always outranks a guess.
  final double lowConfidenceFloor;

  final int maxConsecutiveSameBrand;
}

class ScoredProduct {
  const ScoredProduct({
    required this.productId,
    required this.score,
    required this.facets,
    required this.signals,
  });

  final String productId;
  final double score;
  final CanonicalFacets facets;

  /// Which boosts fired, for the explainer and for debugging a surprising feed.
  final Set<RecoSignal> signals;
}

enum RecoSignal { restocked, onSale, newArrival, outOfStock, alreadyViewed }

class Recommender {
  const Recommender({
    this.weights = const ScoringWeights(),
    this.facetWeights = const {},
  });

  final ScoringWeights weights;
  final Map<String, double> facetWeights;

  /// Rank [candidates] for [profile].
  ///
  /// Purchased products are excluded outright — nobody wants the bag they
  /// already own back at the top of their feed.
  List<ScoredProduct> rank({
    required TasteProfile profile,
    required List<CanonicalFacets> candidates,
    ScoringContext context = const ScoringContext(),
    int limit = 50,
  }) {
    final scored = <ScoredProduct>[];

    for (final facets in candidates) {
      final id = facets.productId;
      if (context.purchasedProductIds.contains(id)) continue;

      final signals = <RecoSignal>{};
      var score = profile.similarityTo(facets.toVector(facetWeights));

      // Confidence floor: a product we classified from a title guess shouldn't
      // beat one we classified from a tag, all else equal.
      score *= weights.lowConfidenceFloor +
          (1 - weights.lowConfidenceFloor) * facets.confidence;

      if (!facets.inStock) {
        score *= weights.outOfStockPenalty;
        signals.add(RecoSignal.outOfStock);
      }
      if (context.recentlyRestockedIds.contains(id)) {
        score *= weights.restockedBoost;
        signals.add(RecoSignal.restocked);
      }
      if (facets.onSale) {
        score *= weights.onSaleBoost;
        signals.add(RecoSignal.onSale);
      }
      if (facets.newArrival) {
        score *= weights.newArrivalBoost;
        signals.add(RecoSignal.newArrival);
      }
      if (context.viewedProductIds.contains(id)) {
        score *= weights.alreadyViewedPenalty;
        signals.add(RecoSignal.alreadyViewed);
      }
      if (context.wishlistedProductIds.contains(id)) {
        score *= weights.wishlistedPenalty;
      }

      scored.add(
        ScoredProduct(
          productId: id,
          score: score,
          facets: facets,
          signals: signals,
        ),
      );
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      // Tie-break on id so the ordering is stable and tests are deterministic.
      return byScore != 0 ? byScore : a.productId.compareTo(b.productId);
    });

    return _diversify(scored, limit: limit);
  }

  /// Greedy re-rank so no more than [ScoringWeights.maxConsecutiveSameBrand]
  /// consecutive items share a brand.
  ///
  /// Without this the feed collapses: 147 of 271 products are Guess, so a user
  /// who likes Guess would see nothing else and the app would look broken
  /// rather than personalized.
  List<ScoredProduct> _diversify(
    List<ScoredProduct> sorted, {
    required int limit,
  }) {
    final result = <ScoredProduct>[];
    final pending = List<ScoredProduct>.from(sorted);
    var runBrand = '';
    var runLength = 0;

    while (result.length < limit && pending.isNotEmpty) {
      var pickedIndex = 0;

      if (runLength >= weights.maxConsecutiveSameBrand) {
        // Scan the whole remaining list for the best-scoring candidate that
        // breaks the run.
        //
        // This deliberately does NOT use a bounded lookahead window. An earlier
        // version capped the scan at 40 and silently did nothing on this
        // catalog: 147 of 271 products are Guess, so the top 40 candidates for
        // a Guess-affinity profile are *all* Guess and no alternative is ever
        // found. The cost is O(limit × pending), which is microseconds at
        // catalog sizes this app will ever see.
        //
        // If nothing breaks the run, pickedIndex stays 0 — only one brand is
        // left, and returning fewer results would be worse than repeating.
        for (var i = 0; i < pending.length; i++) {
          if ((pending[i].facets.brand?.value ?? '') != runBrand) {
            pickedIndex = i;
            break;
          }
        }
      }

      final picked = pending.removeAt(pickedIndex);
      final brand = picked.facets.brand?.value ?? '';
      if (brand == runBrand) {
        runLength++;
      } else {
        runBrand = brand;
        runLength = 1;
      }
      result.add(picked);
    }

    return result;
  }
}
