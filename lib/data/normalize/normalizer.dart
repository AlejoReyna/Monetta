/// `Product` → `CanonicalFacets`.
///
/// Pure Dart, deterministic, no I/O, no clock access. See
/// `lib/data/normalize/README.md` for the taxonomy and the catalog measurements
/// that justify every precedence decision in here.
library;

import '../../domain/product.dart';
import 'facets.dart';
import 'rules.dart';
import 'text.dart';

/// One piece of evidence to match against, tagged with where it came from.
class _Signal {
  const _Signal(this.text, this.source);

  final String text;
  final FacetSource source;
}

/// Category slugs in order of specificity.
///
/// When a product matches several categories at the same evidence tier — a
/// wallet that ships with a crossbody strap will match both `cartera` and
/// `bolsa` — the more specific one wins. `bolsa` is deliberately last because
/// its alias list is the broadest and it acts as the catch-all for this store.
const List<String> _categoryPriority = <String>[
  'reloj',
  'cosmetiquera',
  'tarjetero',
  'monedero',
  'cartera',
  'set',
  'accesorio',
  'bolsa',
];

class Normalizer {
  const Normalizer(this.rules);

  final NormalizationRules rules;

  /// Normalize one product.
  ///
  /// [now] is injected rather than read from the clock so `newArrival` is
  /// deterministic in tests.
  CanonicalFacets normalize(Product product, {required DateTime now}) {
    final foldedTitle = fold(product.title);
    final foldedType = fold(product.productType);
    final foldedVendor = fold(product.vendor);

    // Evidence tiers, strongest first. Tags are listed individually so the
    // matched tag can be reported as evidence in the health report.
    final signals = <_Signal>[
      for (final tag in product.tags) _Signal(fold(tag), FacetSource.tag),
      if (foldedType.isNotEmpty) _Signal(foldedType, FacetSource.productType),
      if (foldedTitle.isNotEmpty) _Signal(foldedTitle, FacetSource.title),
      for (final handle in product.collectionHandles)
        _Signal(fold(handle.replaceAll('-', ' ')), FacetSource.collection),
    ];

    final brand = _resolveBrand(product, signals, foldedVendor);
    final category = _resolveCategory(product, signals);
    final silhouette = category?.value == 'bolsa'
        ? _resolveSingle(rules.silhouettes, signals)
        : null;

    return CanonicalFacets(
      productId: product.id,
      brand: brand,
      category: category,
      silhouette: silhouette,
      colors: _resolveMulti(rules.colors, signals, limit: 3),
      patterns: _resolveMulti(rules.patterns, signals, limit: 2),
      priceBand: rules.priceBandFor(product.price),
      onSale: product.isOnSale,
      inStock: product.isInStock,
      newArrival:
          now.difference(product.createdAt).inDays <= rules.newArrivalDays,
    );
  }

  /// Brand precedence: owner override → tag → title → vendor → collection.
  ///
  /// `vendor` sits *below* title on purpose. It is the store name (`Monetta `,
  /// trailing space) on 36 of 271 products, and where it does hold a real brand
  /// the tags almost always hold it too. Trusting vendor first would hand a
  /// third of the catalog the same meaningless affinity.
  FacetValue? _resolveBrand(
    Product product,
    List<_Signal> signals,
    String foldedVendor,
  ) {
    final override = product.brandOverride;
    if (override != null && override.trim().isNotEmpty) {
      final canonical = _canonicalFor(rules.brands, fold(override)) ??
          fold(override).replaceAll(' ', '_');
      return FacetValue(
        canonical,
        FacetSource.metafieldOverride,
        evidence: override,
      );
    }

    final resolved = _resolveSingle(
      rules.brands,
      signals.where((s) => s.source != FacetSource.collection).toList(),
    );
    if (resolved != null) return resolved;

    // Vendor last, and only when it is not the store's own name.
    if (foldedVendor.isNotEmpty &&
        !rules.storeVendorAliases.contains(foldedVendor)) {
      final canonical = _canonicalFor(rules.brands, foldedVendor);
      if (canonical != null) {
        return FacetValue(
          canonical,
          FacetSource.vendor,
          evidence: product.vendor,
        );
      }
    }

    // Collections are a last resort: brand collections exist (`coach`,
    // `steve-madden`) but so do mislabelled ones (`guess` is titled "Bolsas").
    return _resolveSingle(
      rules.brands,
      signals.where((s) => s.source == FacetSource.collection).toList(),
    );
  }

  FacetValue? _resolveCategory(Product product, List<_Signal> signals) {
    final override = product.categoryOverride;
    if (override != null && override.trim().isNotEmpty) {
      final canonical = _canonicalFor(rules.categories, fold(override)) ??
          fold(override);
      return FacetValue(
        canonical,
        FacetSource.metafieldOverride,
        evidence: override,
      );
    }
    return _resolveSingle(
      rules.categories,
      signals,
      priority: _categoryPriority,
    );
  }

  /// Resolve at most one value, walking evidence tiers strongest-first.
  ///
  /// All signals within a tier are considered together before dropping to the
  /// next tier, so a weak-but-correct tag always beats a strong-looking title
  /// keyword.
  FacetValue? _resolveSingle(
    Map<String, List<String>> vocabulary,
    List<_Signal> signals, {
    List<String>? priority,
  }) {
    for (final source in _tiers(signals)) {
      final matches = <String, String>{}; // canonical → evidence
      for (final signal in signals.where((s) => s.source == source)) {
        final hit = _matchWithEvidence(vocabulary, signal.text);
        if (hit != null) matches.putIfAbsent(hit.key, () => hit.value);
      }
      if (matches.isEmpty) continue;

      final winner = _pick(matches.keys, priority);
      return FacetValue(winner, source, evidence: matches[winner]);
    }
    return null;
  }

  /// Resolve several values (colours, patterns).
  ///
  /// Once a tier produces any match we stop, rather than merging tiers. A
  /// product tagged `Negro` should not also pick up `dorado` because the title
  /// mentions a gold chain — the tag is the owner's stated intent.
  List<FacetValue> _resolveMulti(
    Map<String, List<String>> vocabulary,
    List<_Signal> signals, {
    required int limit,
  }) {
    for (final source in _tiers(signals)) {
      final matches = <String, String>{};
      for (final signal in signals.where((s) => s.source == source)) {
        for (final entry in vocabulary.entries) {
          if (matches.containsKey(entry.key)) continue;
          for (final alias in entry.value) {
            if (containsWord(signal.text, alias)) {
              matches[entry.key] = alias;
              break;
            }
          }
        }
      }
      if (matches.isNotEmpty) {
        return matches.entries
            .take(limit)
            .map((e) => FacetValue(e.key, source, evidence: e.value))
            .toList();
      }
    }
    return const [];
  }

  /// Evidence tiers present in [signals], strongest first.
  Iterable<FacetSource> _tiers(List<_Signal> signals) {
    const order = <FacetSource>[
      FacetSource.tag,
      FacetSource.productType,
      FacetSource.title,
      FacetSource.collection,
    ];
    return order.where((s) => signals.any((sig) => sig.source == s));
  }

  /// First canonical value whose alias appears as a whole word in [text].
  /// Aliases are pre-sorted longest-first by [NormalizationRules], so
  /// `rosa claro` is tried before `rosa`.
  MapEntry<String, String>? _matchWithEvidence(
    Map<String, List<String>> vocabulary,
    String text,
  ) {
    for (final entry in vocabulary.entries) {
      for (final alias in entry.value) {
        if (containsWord(text, alias)) {
          return MapEntry(entry.key, alias);
        }
      }
    }
    return null;
  }

  String? _canonicalFor(Map<String, List<String>> vocabulary, String folded) {
    for (final entry in vocabulary.entries) {
      if (entry.key == folded) return entry.key;
      if (entry.value.contains(folded)) return entry.key;
    }
    return null;
  }

  String _pick(Iterable<String> candidates, List<String>? priority) {
    if (priority == null) return candidates.first;
    for (final preferred in priority) {
      if (candidates.contains(preferred)) return preferred;
    }
    return candidates.first;
  }
}

/// A product the recommender cannot classify well, for the owner-facing
/// catalog health report.
class CatalogHealthIssue {
  const CatalogHealthIssue({
    required this.productId,
    required this.handle,
    required this.title,
    required this.missing,
    required this.confidence,
  });

  final String productId;
  final String handle;
  final String title;

  /// Which facets could not be resolved, e.g. `['brand', 'silhouette']`.
  final List<String> missing;

  final double confidence;

  /// Owner-facing, Spanish, and specific about the fix. This text goes straight
  /// into the report Monetta reads — it has to say what to *do*, not what is
  /// wrong.
  String get advice {
    if (missing.contains('brand') && missing.contains('category')) {
      return 'Agrega etiquetas de marca y categoría (ej. "Guess", "Bolsa") '
          'en Shopify. Sin ellas este producto casi no se recomienda.';
    }
    if (missing.contains('brand')) {
      return 'Agrega la etiqueta de marca (ej. "Guess") o usa el campo '
          'app.brand_override en el producto.';
    }
    if (missing.contains('category')) {
      return 'Agrega la etiqueta de categoría (ej. "Bolsa", "Cartera", "Reloj").';
    }
    if (missing.contains('silhouette')) {
      return 'Agrega el tipo de bolsa (ej. "Crossbody", "Tote", "Satchel") '
          'para que aparezca en los filtros.';
    }
    return 'Revisa las etiquetas de este producto.';
  }
}

/// Build the catalog health report from normalized facets.
///
/// Sorted worst-first so the owner's effort goes where it pays most.
List<CatalogHealthIssue> buildHealthReport(
  List<Product> products,
  List<CanonicalFacets> facets,
) {
  final byId = {for (final f in facets) f.productId: f};
  final issues = <CatalogHealthIssue>[];

  for (final product in products) {
    final facet = byId[product.id];
    if (facet == null || !facet.needsAttention) continue;

    final missing = <String>[
      if (facet.brand == null) 'brand',
      if (facet.category == null) 'category',
      if (facet.category?.value == 'bolsa' && facet.silhouette == null)
        'silhouette',
    ];
    if (missing.isEmpty) continue;

    issues.add(
      CatalogHealthIssue(
        productId: product.id,
        handle: product.handle,
        title: product.title,
        missing: missing,
        confidence: facet.confidence,
      ),
    );
  }

  issues.sort((a, b) => a.confidence.compareTo(b.confidence));
  return issues;
}
