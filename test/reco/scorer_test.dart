/// Behavioural contract for the recommender.
///
/// These five claims were validated against the real catalog before the engine
/// was written; the numbers in the comments are what that simulation produced.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/normalize/facets.dart';
import 'package:monetta_app/data/normalize/normalizer.dart';
import 'package:monetta_app/data/normalize/rules.dart';
import 'package:monetta_app/reco/profile.dart';
import 'package:monetta_app/reco/scorer.dart';

import '../fixtures/catalog_fixture.dart';

void main() {
  final raw = File('assets/rules/normalization_rules.json').readAsStringSync();
  final rules = NormalizationRules.fromJson(
    jsonDecode(raw) as Map<String, dynamic>,
  );
  final products = loadCatalogFixture();
  final normalizer = Normalizer(rules);
  final facets = products
      .map((p) => normalizer.normalize(p, now: kSnapshotDate))
      .toList();

  final recommender = Recommender(facetWeights: rules.facetWeights);

  /// A user who has only ever looked at Guess crossbody bags.
  TasteProfile guessCrossbodyProfile() => seedProfileFromOnboarding(
        brands: const ['guess'],
        categories: const ['bolsa'],
        now: kSnapshotDate,
      );

  String? brandOf(ScoredProduct s) => s.facets.brand?.value;

  group('Recommender', () {
    test('a Guess-crossbody profile surfaces Guess crossbodies first', () {
      final ranked = recommender.rank(
        profile: guessCrossbodyProfile(),
        candidates: facets,
        limit: 12,
      );

      final guessCount = ranked.where((s) => brandOf(s) == 'guess').length;
      // Simulation on real data: 8 of the top 12 (the rest are the diversity
      // slots, filled by Steve Madden crossbodies).
      expect(guessCount, greaterThanOrEqualTo(7));
      expect(brandOf(ranked.first), 'guess');
    });

    test('never returns more than 2 consecutive products of one brand', () {
      final ranked = recommender.rank(
        profile: guessCrossbodyProfile(),
        candidates: facets,
        limit: 40,
      );

      var longestRun = 1;
      var run = 1;
      for (var i = 1; i < ranked.length; i++) {
        if (brandOf(ranked[i]) == brandOf(ranked[i - 1])) {
          run++;
          if (run > longestRun) longestRun = run;
        } else {
          run = 1;
        }
      }

      // Without this, 147 of 271 products being Guess would make the feed look
      // broken rather than personalized.
      expect(longestRun, lessThanOrEqualTo(2));
    });

    test('out-of-stock ranks below in-stock at comparable affinity', () {
      final ranked = recommender.rank(
        profile: guessCrossbodyProfile(),
        candidates: facets,
        limit: 271,
      );

      final bestInStock = ranked.firstWhere((s) => s.facets.inStock);
      final bestOutOfStock = ranked.firstWhere((s) => !s.facets.inStock);

      // Penalized 4×, not filtered: seeing a sold-out bag you love is what
      // drives the back-in-stock opt-in.
      expect(bestInStock.score, greaterThan(bestOutOfStock.score));
      expect(
        ranked.any((s) => !s.facets.inStock),
        isTrue,
        reason: 'out-of-stock products must still appear',
      );
    });

    test('cold start returns a full feed from an empty profile', () {
      final ranked = recommender.rank(
        profile: const TasteProfile.empty(),
        candidates: facets,
        limit: 20,
      );
      expect(ranked, hasLength(20));
    });

    test('a different profile produces a substantially different feed', () {
      final bags = recommender.rank(
        profile: guessCrossbodyProfile(),
        candidates: facets,
        limit: 8,
      );
      final watches = recommender.rank(
        profile: seedProfileFromOnboarding(
          brands: const ['coach'],
          categories: const ['reloj'],
          now: kSnapshotDate,
        ),
        candidates: facets,
        limit: 8,
      );

      final overlap = bags
          .map((s) => s.productId)
          .toSet()
          .intersection(watches.map((s) => s.productId).toSet());

      // Simulation: 0 of 8 overlapped.
      expect(overlap.length, lessThanOrEqualTo(1));
      expect(watches.first.facets.category?.value, 'reloj');
    });

    test('purchased products are excluded outright', () {
      final purchased = facets.first.productId;
      final ranked = recommender.rank(
        profile: guessCrossbodyProfile(),
        candidates: facets,
        context: ScoringContext(purchasedProductIds: {purchased}),
        limit: 271,
      );
      expect(ranked.map((s) => s.productId), isNot(contains(purchased)));
    });

    test('scoring is deterministic', () {
      List<String> run() => recommender
          .rank(
            profile: guessCrossbodyProfile(),
            candidates: facets,
            limit: 30,
          )
          .map((s) => s.productId)
          .toList();
      expect(run(), equals(run()));
    });
  });
}
