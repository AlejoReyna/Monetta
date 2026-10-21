/// Builds a taste profile from an event log.
///
/// Pure Dart, deterministic, no clock access — `now` is always injected.
library;

import 'dart:math' as math;

import '../data/normalize/facets.dart';
import 'events.dart';

/// A user's learned taste: a sparse, L2-normalized vector over facet keys.
///
/// Small enough to hold in memory and to *show the user* — the "Tu perfil"
/// screen renders this directly, which is both the privacy disclosure and the
/// correction mechanism.
class TasteProfile {
  const TasteProfile({
    required this.weights,
    required this.eventCount,
    required this.builtAt,
  });

  const TasteProfile.empty()
      : weights = const {},
        eventCount = 0,
        builtAt = null;

  /// Facet key (`brand:guess`) → affinity, L2-normalized so cosine similarity
  /// is a plain dot product.
  final Map<String, double> weights;

  /// Number of events that contributed. Drives the cold-start decision.
  final int eventCount;

  final DateTime? builtAt;

  bool get isEmpty => weights.isEmpty;

  /// Below this, the profile is too thin to personalize with and the feed falls
  /// back to cold-start. Roughly "the user has viewed a handful of products".
  static const int minEventsForPersonalization = 5;

  bool get isConfident => eventCount >= minEventsForPersonalization;

  /// Top facet values of one kind, strongest first.
  ///
  /// `topOf('brand')` → `['guess', 'coach']`. Used by the explainer and by the
  /// "new arrival in your brand" push trigger.
  List<String> topOf(String kind, {int limit = 3}) {
    final prefix = '$kind:';
    final matching = weights.entries
        .where((e) => e.key.startsWith(prefix) && e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return matching
        .take(limit)
        .map((e) => e.key.substring(prefix.length))
        .toList();
  }

  double affinityFor(String facetKey) => weights[facetKey] ?? 0;

  /// Cosine similarity against a product vector.
  ///
  /// [weights] is already L2-normalized, so this normalizes only the product
  /// side. Result is 0..1 for non-negative vectors.
  double similarityTo(Map<String, double> productVector) {
    if (weights.isEmpty || productVector.isEmpty) return 0;

    var dot = 0.0;
    var productNorm = 0.0;
    for (final entry in productVector.entries) {
      productNorm += entry.value * entry.value;
      final mine = weights[entry.key];
      if (mine != null) dot += mine * entry.value;
    }
    if (productNorm == 0) return 0;
    return dot / math.sqrt(productNorm);
  }
}

class ProfileBuilder {
  const ProfileBuilder({
    this.halfLifeDays = 14,
    this.maxImpressionsPerSession = 20,
  });

  /// Days after which an event counts half as much.
  ///
  /// 14 days is tuned to this category: handbag taste is stable over months,
  /// but *shopping intent* ("I want a black crossbody right now") turns over in
  /// weeks. A longer half-life makes the feed feel stale after a purchase; a
  /// much shorter one makes it thrash on a single browsing session.
  final int halfLifeDays;

  /// Impressions beyond this, per session, are discarded before weighting.
  final int maxImpressionsPerSession;

  /// Build a profile from an event log.
  ///
  /// [facetsByProductId] supplies the facet vector for each product the events
  /// refer to; events whose product is unknown (deleted from the catalog) are
  /// skipped rather than guessed at.
  TasteProfile build({
    required List<InteractionEvent> events,
    required Map<String, CanonicalFacets> facetsByProductId,
    required Map<String, double> facetWeights,
    required DateTime now,
  }) {
    if (events.isEmpty) return const TasteProfile.empty();

    final accumulated = <String, double>{};
    var counted = 0;
    var impressionsSeen = 0;

    for (final event in events) {
      if (event.type == EventType.impression) {
        if (impressionsSeen >= maxImpressionsPerSession) continue;
        impressionsSeen++;
      }

      final decay = _decayFactor(now.difference(event.timestamp));
      // Older than ~6 half-lives contributes under 2%; skip the arithmetic.
      if (decay < 0.02) continue;

      final weight = event.rawWeight * decay;

      // An explicit filter/search teaches the profile directly, even when the
      // user never opens a product.
      final hint = event.facetHint;
      if (hint != null) {
        accumulated.update(hint, (v) => v + weight, ifAbsent: () => weight);
        counted++;
        continue;
      }

      final productId = event.productId;
      if (productId == null) continue;
      final facets = facetsByProductId[productId];
      if (facets == null) continue;

      final vector = facets.toVector(facetWeights);
      for (final entry in vector.entries) {
        final contribution = entry.value * weight;
        accumulated.update(
          entry.key,
          (v) => v + contribution,
          ifAbsent: () => contribution,
        );
      }
      counted++;
    }

    return TasteProfile(
      weights: _normalize(accumulated),
      eventCount: counted,
      builtAt: now,
    );
  }

  /// Exponential decay: `0.5 ^ (ageDays / halfLife)`.
  double _decayFactor(Duration age) {
    final days = age.inMinutes / (60 * 24);
    if (days <= 0) return 1;
    return math.pow(0.5, days / halfLifeDays).toDouble();
  }

  /// Clamp negatives to zero, then L2-normalize.
  ///
  /// Negative affinities are dropped rather than kept: "removed from wishlist"
  /// should stop us pushing that facet, but it should not make the *opposite*
  /// facet attractive, which is what a negative component in a cosine would do.
  Map<String, double> _normalize(Map<String, double> raw) {
    final positive = <String, double>{};
    var sumSquares = 0.0;
    for (final entry in raw.entries) {
      if (entry.value <= 0) continue;
      positive[entry.key] = entry.value;
      sumSquares += entry.value * entry.value;
    }
    if (sumSquares == 0) return const {};
    final norm = math.sqrt(sumSquares);
    return positive.map((k, v) => MapEntry(k, v / norm));
  }
}

/// Seeds a profile from the 3-tap onboarding, so the very first feed is already
/// personalized on install day with zero browsing history.
TasteProfile seedProfileFromOnboarding({
  required List<String> brands,
  required List<String> categories,
  List<String> silhouettes = const [],
  String? priceBand,
  required DateTime now,
}) {
  final raw = <String, double>{
    for (final brand in brands) 'brand:$brand': 1.0,
    for (final category in categories) 'category:$category': 0.8,
    for (final silhouette in silhouettes) 'silhouette:$silhouette': 0.8,
    if (priceBand != null) 'price_band:$priceBand': 0.6,
  };
  if (raw.isEmpty) return const TasteProfile.empty();

  var sumSquares = 0.0;
  for (final value in raw.values) {
    sumSquares += value * value;
  }
  final norm = math.sqrt(sumSquares);

  return TasteProfile(
    weights: raw.map((k, v) => MapEntry(k, v / norm)),
    // Counts as one "event" so the profile is usable but still yields to real
    // behaviour as soon as any arrives.
    eventCount: TasteProfile.minEventsForPersonalization,
    builtAt: now,
  );
}
