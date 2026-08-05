/// Text folding used by every matcher in this module.
///
/// Pure Dart. This file exists because the single biggest source of duplicate
/// facet values on this catalog is *spelling*, not vocabulary: `Café` vs `Cafe`,
/// `Crossbody` vs `crossbody`, `Blanco` vs `Blanca`. Folding fixes accents and
/// case for free; the gender/language variants are handled by alias lists in
/// `normalization_rules.json`.
library;

const Map<String, String> _accents = <String, String>{
  'á': 'a',
  'à': 'a',
  'ä': 'a',
  'â': 'a',
  'ã': 'a',
  'é': 'e',
  'è': 'e',
  'ë': 'e',
  'ê': 'e',
  'í': 'i',
  'ì': 'i',
  'ï': 'i',
  'î': 'i',
  'ó': 'o',
  'ò': 'o',
  'ö': 'o',
  'ô': 'o',
  'õ': 'o',
  'ú': 'u',
  'ù': 'u',
  'ü': 'u',
  'û': 'u',
  'ñ': 'n',
  'ç': 'c',
};

/// Lowercase, strip accents, collapse whitespace, trim.
///
/// `fold('  Café  Negro ')` → `'cafe negro'`
///
/// Note the trim: 36 products on this store carry the vendor `'Monetta '` with a
/// trailing space, which is exactly the kind of thing that silently creates a
/// second, near-identical facet value if you skip this step.
String fold(String input) {
  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_accents[char] ?? char);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Whether [haystack] contains [needle] as a whole word.
///
/// Word-boundary matching rather than `contains` matters here: the alias `oro`
/// must not match inside `dorado`, and `tote` must not match inside `totemico`.
bool containsWord(String haystack, String needle) {
  if (needle.isEmpty) return false;
  final escaped = RegExp.escape(needle);
  // Spanish words can neighbour punctuation and digits; treat anything that is
  // not a letter or digit as a boundary.
  final pattern = RegExp(
    '(^|[^a-z0-9])$escaped(\$|[^a-z0-9])',
    caseSensitive: false,
  );
  return pattern.hasMatch(haystack);
}
