/// Text normalization shared by every catalog query.
library;

/// Fold accents, case and runs of whitespace so `Bolso Coach`, `bolso  coach`
/// and `BOLSO COACH` are one entry. The stored text keeps the shopper's own
/// spelling; only the comparison key is normalized.
String normalizeSearchText(String value) => value
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ü', 'u')
    .replaceAll('ñ', 'n')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
