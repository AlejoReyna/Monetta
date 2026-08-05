/// Turns a score into a sentence the shopper understands.
///
/// Pure Dart. Every recommendation carries a reason chip — *"Porque te gustan
/// las bolsas crossbody de Guess"*. This is cheap to build, measurably lifts
/// CTR, and it is what makes the engine's value obvious in a demo.
///
/// Spanish is the only locale in Phase 1, and the strings live here rather than
/// in ARB files because they are *generated* from facet slugs and need gender
/// and number agreement — see [_CategoryLabel].
library;

import 'scorer.dart';

enum ReasonKind {
  /// Highest priority: 21% of variants are out of stock at any time, so a
  /// restock is the strongest thing we can tell someone.
  restocked,
  priceDrop,
  newFromBrand,
  taste,
  trending,
}

class RecoReason {
  const RecoReason(this.kind, this.text);

  final ReasonKind kind;

  /// Display string, es-MX.
  final String text;

  @override
  String toString() => '${kind.name}: $text';
}

/// Spanish display labels with the grammatical gender and number needed to
/// build agreeing phrases.
class _CategoryLabel {
  const _CategoryLabel(this.plural, this.feminine);

  /// Plural noun, e.g. `bolsas`.
  final String plural;

  /// Whether the noun is feminine — decides `las` vs `los`.
  final bool feminine;

  String get article => feminine ? 'las' : 'los';
}

const Map<String, _CategoryLabel> _categoryLabels = {
  'bolsa': _CategoryLabel('bolsas', true),
  'cartera': _CategoryLabel('carteras', true),
  'monedero': _CategoryLabel('monederos', false),
  'tarjetero': _CategoryLabel('tarjeteros', false),
  'reloj': _CategoryLabel('relojes', false),
  'cosmetiquera': _CategoryLabel('cosmetiqueras', true),
  'set': _CategoryLabel('sets', false),
  'accesorio': _CategoryLabel('accesorios', false),
};

const Map<String, String> _brandLabels = {
  'guess': 'Guess',
  'coach': 'Coach',
  'michael_kors': 'Michael Kors',
  'steve_madden': 'Steve Madden',
  'tommy_hilfiger': 'Tommy Hilfiger',
  'anne_klein': 'Anne Klein',
  'christian_dior': 'Christian Dior',
};

/// Silhouettes as they read inside a noun phrase: "bolsas **de hombro**".
const Map<String, String> _silhouetteLabels = {
  'crossbody': 'crossbody',
  'tote': 'tote',
  'shoulder': 'de hombro',
  'satchel': 'satchel',
  'hobo': 'hobo',
  'clutch': 'clutch',
  'mini': 'mini',
  'wristlet': 'wristlet',
};

String brandLabel(String slug) =>
    _brandLabels[slug] ??
    slug
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');

class Explainer {
  const Explainer();

  /// Explain why [scored] is being shown, given what we know the user likes.
  ///
  /// Priority is deliberate: urgency (restock, price drop) beats taste, because
  /// a reason that implies "act now" outperforms one that merely flatters. Only
  /// when nothing urgent applies do we explain the personalization.
  RecoReason explain(
    ScoredProduct scored, {
    required List<String> topBrands,
    required List<String> topSilhouettes,
    double discountFraction = 0,
  }) {
    final facets = scored.facets;
    final brand = facets.brand?.value;
    final silhouette = facets.silhouette?.value;
    final category = facets.category?.value;

    if (scored.signals.contains(RecoSignal.restocked)) {
      return const RecoReason(ReasonKind.restocked, 'Volvió a stock');
    }

    // Only shout about a discount worth noticing. Below ~10% the badge reads as
    // noise and trains people to ignore it.
    if (scored.signals.contains(RecoSignal.onSale) && discountFraction >= 0.10) {
      final percent = (discountFraction * 100).round();
      return RecoReason(ReasonKind.priceDrop, 'Bajó de precio · -$percent%');
    }

    if (scored.signals.contains(RecoSignal.newArrival) &&
        brand != null &&
        topBrands.contains(brand)) {
      return RecoReason(ReasonKind.newFromBrand, 'Nuevo de ${brandLabel(brand)}');
    }

    final matchesBrand = brand != null && topBrands.contains(brand);
    final matchesSilhouette =
        silhouette != null && topSilhouettes.contains(silhouette);

    if (matchesBrand || matchesSilhouette) {
      return RecoReason(
        ReasonKind.taste,
        _tastePhrase(
          category: category,
          silhouette: matchesSilhouette ? silhouette : null,
          brand: matchesBrand ? brand : null,
        ),
      );
    }

    if (scored.signals.contains(RecoSignal.newArrival)) {
      return const RecoReason(ReasonKind.newFromBrand, 'Recién llegado');
    }

    return const RecoReason(ReasonKind.trending, 'Popular ahora');
  }

  /// Compose an agreeing Spanish phrase from whichever facets matched.
  ///
  /// "Porque te gustan **las bolsas crossbody de Guess**"
  /// "Porque te gustan **los relojes de Coach**"
  /// "Porque te gusta **Guess**"  ← when we have a brand but no category
  String _tastePhrase({
    required String? category,
    required String? silhouette,
    required String? brand,
  }) {
    final label = category == null ? null : _categoryLabels[category];

    if (label == null) {
      if (brand != null) return 'Porque te gusta ${brandLabel(brand)}';
      return 'Para ti';
    }

    final parts = <String>[label.article, label.plural];
    if (silhouette != null) {
      final silhouetteLabel = _silhouetteLabels[silhouette];
      if (silhouetteLabel != null) parts.add(silhouetteLabel);
    }
    if (brand != null) {
      parts.add('de ${brandLabel(brand)}');
    }

    return 'Porque te gustan ${parts.join(' ')}';
  }
}
