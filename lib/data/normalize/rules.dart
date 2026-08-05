/// The normalization rules: canonical slug → list of aliases.
///
/// Pure Dart, hand-parsed from JSON (no codegen) so this module compiles before
/// `build_runner` has ever run.
///
/// The rules ship bundled in `assets/rules/normalization_rules.json` and are
/// overridden at runtime by Firebase Remote Config. That override is the whole
/// point of this file existing: when Monetta starts stocking a brand we have
/// never seen, we fix it in Remote Config in two minutes instead of shipping a
/// build and waiting on App Store review.
library;

import 'text.dart';

class PriceBand {
  const PriceBand(this.id, this.maxExclusive);

  final String id;

  /// Upper bound in MXN, exclusive. `null` means "no upper bound".
  final double? maxExclusive;
}

class NormalizationRules {
  NormalizationRules({
    required this.version,
    required Map<String, List<String>> brands,
    required Map<String, List<String>> categories,
    required Map<String, List<String>> silhouettes,
    required Map<String, List<String>> colors,
    required Map<String, List<String>> patterns,
    required this.priceBands,
    required this.facetWeights,
    required this.storeVendorAliases,
    required this.newArrivalDays,
  })  : brands = _foldAliases(brands),
        categories = _foldAliases(categories),
        silhouettes = _foldAliases(silhouettes),
        colors = _foldAliases(colors),
        patterns = _foldAliases(patterns);

  final int version;

  /// canonical slug → folded aliases, longest first (see [_foldAliases]).
  final Map<String, List<String>> brands;
  final Map<String, List<String>> categories;
  final Map<String, List<String>> silhouettes;
  final Map<String, List<String>> colors;
  final Map<String, List<String>> patterns;

  final List<PriceBand> priceBands;

  /// Relative importance of each facet kind when building the vector that the
  /// recommender scores against. Tune these once real CTR data exists.
  final Map<String, double> facetWeights;

  /// Vendor values that mean "the store", not "the brand". On this catalog
  /// `Monetta ` (trailing space) appears on 36 products; if we treated it as a
  /// brand, a third of the catalog would share one meaningless affinity.
  final Set<String> storeVendorAliases;

  final int newArrivalDays;

  /// Fold every alias and sort longest-first within each canonical value.
  ///
  /// Longest-first matters: `rosa claro` must be tried before `rosa`, otherwise
  /// every pale pink bag collapses into plain pink.
  static Map<String, List<String>> _foldAliases(Map<String, List<String>> raw) {
    return raw.map((canonical, aliases) {
      final folded = aliases.map(fold).where((a) => a.isNotEmpty).toSet().toList()
        ..sort((a, b) => b.length.compareTo(a.length));
      return MapEntry(canonical, folded);
    });
  }

  String priceBandFor(double price) {
    for (final band in priceBands) {
      final max = band.maxExclusive;
      if (max == null || price < max) return band.id;
    }
    return priceBands.isEmpty ? 'medio' : priceBands.last.id;
  }

  factory NormalizationRules.fromJson(Map<String, dynamic> json) {
    Map<String, List<String>> section(String key) {
      final raw = json[key];
      if (raw is! Map) return <String, List<String>>{};
      return raw.map(
        (k, v) => MapEntry(
          k as String,
          (v as List).map((e) => e as String).toList(),
        ),
      );
    }

    final bandsRaw = json['priceBands'];
    final bands = <PriceBand>[];
    if (bandsRaw is List) {
      for (final entry in bandsRaw) {
        if (entry is! Map) continue;
        bands.add(
          PriceBand(
            entry['id'] as String,
            (entry['maxExclusive'] as num?)?.toDouble(),
          ),
        );
      }
    }

    final weightsRaw = json['facetWeights'];
    final weights = <String, double>{};
    if (weightsRaw is Map) {
      weightsRaw.forEach((k, v) {
        if (v is num) weights[k as String] = v.toDouble();
      });
    }

    final storeVendors = <String>{};
    final storeVendorsRaw = json['storeVendorAliases'];
    if (storeVendorsRaw is List) {
      for (final entry in storeVendorsRaw) {
        if (entry is String) storeVendors.add(fold(entry));
      }
    }

    return NormalizationRules(
      version: (json['version'] as num?)?.toInt() ?? 0,
      brands: section('brands'),
      categories: section('categories'),
      silhouettes: section('silhouettes'),
      colors: section('colors'),
      patterns: section('patterns'),
      priceBands: bands,
      facetWeights: weights,
      storeVendorAliases: storeVendors,
      newArrivalDays: (json['newArrivalDays'] as num?)?.toInt() ?? 30,
    );
  }
}
