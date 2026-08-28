/// Converts the on-device taste vector into a deliberately small server view.
library;

import '../../reco/profile.dart';

class InterestProfileSnapshot {
  const InterestProfileSnapshot({
    required this.profileVersion,
    required this.topBrands,
    required this.topCategories,
    required this.priceBand,
    required this.intentTier,
    required this.signalCountBucket,
    required this.generatedAt,
  });

  final int profileVersion;
  final List<Map<String, Object>> topBrands;
  final List<Map<String, Object>> topCategories;
  final String? priceBand;
  final String intentTier;
  final String signalCountBucket;
  final DateTime generatedAt;

  factory InterestProfileSnapshot.fromTasteProfile(
    TasteProfile profile, {
    required int profileVersion,
    DateTime? now,
  }) {
    final generatedAt = now ?? DateTime.now().toUtc();
    return InterestProfileSnapshot(
      profileVersion: profileVersion,
      topBrands: _affinities(profile, 'brand', 3),
      topCategories: _affinities(profile, 'category', 2),
      priceBand: profile.topOf('price_band', limit: 1).firstOrNull,
      intentTier: profile.eventCount >= 25
          ? 'high'
          : profile.eventCount >= 10
              ? 'medium'
              : 'low',
      signalCountBucket: profile.eventCount >= 25
          ? '25_plus'
          : profile.eventCount >= 10
              ? '10_24'
              : profile.eventCount >= 5
                  ? '5_9'
                  : '0_4',
      generatedAt: generatedAt,
    );
  }

  Map<String, Object?> toJson() => {
        'profileVersion': profileVersion,
        'topBrands': topBrands,
        'topCategories': topCategories,
        'priceBand': priceBand,
        'intentTier': intentTier,
        'signalCountBucket': signalCountBucket,
        'generatedAt': generatedAt.toIso8601String(),
      };

  static List<Map<String, Object>> _affinities(
    TasteProfile profile,
    String kind,
    int limit,
  ) {
    final prefix = '$kind:';
    final entries = profile.weights.entries
        .where((entry) => entry.key.startsWith(prefix) && entry.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final entry in entries.take(limit))
        {
          'key': entry.key.substring(prefix.length),
          'score': (entry.value * 100).round().clamp(0, 100),
        },
    ];
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
