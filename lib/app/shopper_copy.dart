/// Shopper-facing Spanish. Inventory language only — brand, piece, price,
/// days, anticipo. Never slugs, never the recommender, never the scrape.
library;

import '../reco/explainer.dart';

const String kWhatsAppNumberDisplay = '826 106 6868';
const String kWhatsAppE164 = '528261066868';

const Map<String, String> kCategoryLabels = {
  'bolsa': 'Bolsa',
  'cartera': 'Cartera',
  'monedero': 'Monedero',
  'tarjetero': 'Tarjetero',
  'reloj': 'Reloj',
  'cosmetiquera': 'Cosmetiquera',
  'set': 'Set',
  'accesorio': 'Accesorio',
};

const Map<String, String> kCategoryPlural = {
  'bolsa': 'Bolsas',
  'cartera': 'Carteras',
  'monedero': 'Monederos',
  'tarjetero': 'Tarjeteros',
  'reloj': 'Relojes',
  'cosmetiquera': 'Cosmetiqueras',
  'set': 'Sets',
  'accesorio': 'Accesorios',
};

const Map<String, String> kSilhouetteLabels = {
  'crossbody': 'Crossbody',
  'tote': 'Tote',
  'shoulder': 'De hombro',
  'satchel': 'Satchel',
  'hobo': 'Hobo',
  'clutch': 'Clutch',
  'mini': 'Mini',
  'wristlet': 'Muñequera',
};

const Map<String, String> kColorLabels = {
  'negro': 'Negro',
  'blanco': 'Blanco',
  'cafe': 'Café',
  'beige': 'Beige',
  'gris': 'Gris',
  'rosa': 'Rosa',
  'azul': 'Azul',
  'rojo': 'Rojo',
  'dorado': 'Dorado',
  'verde': 'Verde',
  'morado': 'Morado',
  'amarillo': 'Amarillo',
  'multicolor': 'Multicolor',
};

const Map<String, String> kPatternLabels = {
  'monograma': 'Monograma',
  'floral': 'Floral',
  'cerezas': 'Cerezas',
  'limones': 'Limones',
  'rayas': 'Rayas',
  'animal_print': 'Animal print',
  'relieve': 'Relieve',
  'acolchado': 'Acolchado',
  'liso': 'Liso',
};

String categoryLabel(String? slug) =>
    slug == null ? '' : (kCategoryLabels[slug] ?? humanizeCatalogValue(slug));

String categoryPlural(String? slug) =>
    slug == null ? '' : (kCategoryPlural[slug] ?? humanizeCatalogValue(slug));

String silhouetteLabel(String? slug) =>
    slug == null ? '' : (kSilhouetteLabels[slug] ?? humanizeCatalogValue(slug));

String colorLabel(String? slug) =>
    slug == null ? '' : (kColorLabels[slug] ?? humanizeCatalogValue(slug));

String patternLabel(String? slug) =>
    slug == null ? '' : (kPatternLabels[slug] ?? humanizeCatalogValue(slug));

/// Converts an internal catalog token into shopper-facing text.
///
/// Canonical facets intentionally use values such as `michael_kors` and
/// `animal_print`. Those values are stable identifiers but must never leak
/// into the catalog UI. Consecutive duplicate tokens are also collapsed so
/// malformed input such as `coach_coach` does not become "Coach Coach".
String humanizeCatalogValue(String value) {
  final rawWords = value
      .trim()
      .replaceAll(RegExp(r'[_]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .split(' ')
      .where((word) => word.isNotEmpty);
  final words = <String>[];
  for (final word in rawWords) {
    if (words.isNotEmpty && words.last.toLowerCase() == word.toLowerCase()) {
      continue;
    }
    words.add(word);
  }
  return words
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

/// Cleans a source title for presentation without replacing Shopify's value.
String shopperProductName(String title) {
  final normalized = title.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) return '';
  if (normalized.contains('_')) return humanizeCatalogValue(normalized);

  final words = <String>[];
  for (final word in normalized.split(' ')) {
    if (words.isNotEmpty && words.last.toLowerCase() == word.toLowerCase()) {
      continue;
    }
    words.add(word);
  }
  return words.join(' ');
}

/// Turns common US merchant titles into Monetta's shopper-facing hierarchy.
///
/// Merchant feeds usually put the model first and the piece/silhouette last
/// (`Tabby Shoulder Bag 26`). Monetta cards lead with the piece and keep the
/// model as the distinguishing name (`Bolsa Tabby 26 de hombro`). This is a
/// presentation-only normalization: the source title remains untouched in
/// [CatalogItem] and can still be audited against the merchant page.
String externalProductName({required String title, String? category}) {
  final source = shopperProductName(title);
  if (source.isEmpty) return source;

  final terms = '$source ${category ?? ''}'.toLowerCase();
  final piece = switch (terms) {
    _
        when RegExp(r'\b(?:card case|card holder|tarjeter[oa])\b')
            .hasMatch(terms) =>
      'Tarjetero',
    _
        when RegExp(r'\b(?:wallet|billfold|cartera|monedero)\b')
            .hasMatch(terms) =>
      'Cartera',
    _ when RegExp(r'\b(?:wristlet|muñequera)\b').hasMatch(terms) => 'Muñequera',
    _
        when RegExp(r'\b(?:perfume|fragrance|eau de parfum|eau de toilette)\b')
            .hasMatch(terms) =>
      'Perfume',
    _
        when RegExp(r'\b(?:bag|handbag|purse|bags|handbags|bolsa)\b')
            .hasMatch(terms) =>
      'Bolsa',
    _ => '',
  };
  if (piece.isEmpty) return source;

  final silhouette = switch (source.toLowerCase()) {
    final value when RegExp(r'\bshoulder\b').hasMatch(value) => 'de hombro',
    final value when RegExp(r'\bcrossbody\b').hasMatch(value) => 'crossbody',
    final value when RegExp(r'\btote\b').hasMatch(value) => 'tote',
    final value when RegExp(r'\bsatchel\b').hasMatch(value) => 'satchel',
    final value when RegExp(r'\bhobo\b').hasMatch(value) => 'hobo',
    final value when RegExp(r'\bclutch\b').hasMatch(value) => 'clutch',
    final value when RegExp(r'\bbucket\b').hasMatch(value) => 'tipo cubeta',
    _ => '',
  };

  var model = source
      .replaceAll(
        RegExp(
          r'\b(?:shoulder|crossbody|tote|satchel|hobo|clutch|bucket)\b',
          caseSensitive: false,
        ),
        ' ',
      )
      .replaceAll(
        RegExp(
          r'\b(?:handbag|bag|purse|wallet|billfold|card case|card holder|wristlet|perfume|fragrance)\b',
          caseSensitive: false,
        ),
        ' ',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  const sizeWords = <String, String>{
    'small': 'Pequeña',
    'medium': 'Mediana',
    'large': 'Grande',
  };
  for (final entry in sizeWords.entries) {
    model = model.replaceAll(
      RegExp('\\b${entry.key}\\b', caseSensitive: false),
      entry.value,
    );
  }
  model = model.replaceAll(
    RegExp(r'\bzip around\b', caseSensitive: false),
    'con cierre',
  );

  return [
    piece,
    if (model.isNotEmpty) model,
    if (silhouette.isNotEmpty) silhouette,
  ].join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

String stripHtml(String html) {
  final withoutTags = html.replaceAll(RegExp(r'<[^>]+>'), ' ');
  return withoutTags
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Plain-text Shopify description that preserves the authored fact hierarchy.
///
/// Catalog descriptions commonly use `<br>` and paragraphs for brand, color,
/// type and dimensions. [stripHtml] is useful for excerpts, but flattening all
/// of those facts into one line makes a product page difficult to scan.
String shopifyDescriptionText(String html) {
  final withBreaks = html
      .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
      .replaceAll(
        RegExp(r'</\s*(?:p|div|li|h[1-6])\s*>', caseSensitive: false),
        '\n',
      )
      .replaceAll(RegExp(r'<\s*li\b[^>]*>', caseSensitive: false), '• ')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  return withBreaks
      .split(RegExp(r'[\r\n]+'))
      .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .join('\n');
}

/// One factual sentence when Shopify has no description.
String? factualDescription({
  required String title,
  String? brandSlug,
  String? categorySlug,
  String? silhouetteSlug,
  String? colorSlug,
}) {
  final brand = brandSlug == null ? null : brandLabel(brandSlug);
  final category = categoryLabel(categorySlug);
  final silhouette = silhouetteLabel(silhouetteSlug);
  final color = colorLabel(colorSlug);

  final kind = [
    if (category.isNotEmpty) category.toLowerCase(),
    if (silhouette.isNotEmpty) silhouette.toLowerCase(),
  ].join(' ');

  if (brand == null && kind.isEmpty) return null;

  final buffer = StringBuffer();
  if (kind.isNotEmpty) {
    buffer.write(kind[0].toUpperCase());
    buffer.write(kind.substring(1));
  } else {
    buffer.write(shopperProductName(title));
  }
  if (brand != null) buffer.write(' $brand');
  if (color.isNotEmpty) buffer.write(' en ${color.toLowerCase()}');
  buffer.write('. Original, importada de Estados Unidos.');
  return buffer.toString();
}

const String kDeleteAccountManualWhatsAppText =
    'Hola, quiero eliminar mi cuenta de Monetta.';

/// Support chat for account deletion. Uses the shop's existing WhatsApp
/// number; callers pass a placeholder only when that number is absent.
Uri accountDeletionSupportUri({String phoneE164 = kWhatsAppE164}) {
  final phone = phoneE164.trim().isEmpty ? '0000000000' : phoneE164.trim();
  return Uri.https('wa.me', '/$phone', <String, String>{
    'text': '¡Hola Monetta! Necesito ayuda para eliminar mi cuenta.',
  });
}

/// WhatsApp handoff when the app cannot delete the account itself.
Uri accountDeletionManualRequestUri({String phoneE164 = kWhatsAppE164}) {
  final phone = phoneE164.trim().isEmpty ? '0000000000' : phoneE164.trim();
  return Uri.https('wa.me', '/$phone', <String, String>{
    'text': kDeleteAccountManualWhatsAppText,
  });
}

Uri conciergeWhatsAppUri({String? productTitle}) {
  final text = productTitle == null
      ? '¡Hola Monetta! Quiero ayuda para elegir una pieza.'
      : '¡Hola Monetta! Quiero información sobre *$productTitle*.';
  return Uri.https('wa.me', '/$kWhatsAppE164', <String, String>{'text': text});
}

Uri wholesaleWhatsAppUri() {
  return Uri.https('wa.me', '/$kWhatsAppE164', <String, String>{
    'text': '¡Hola Monetta! Quiero información de mayoreo (desde 3 piezas).',
  });
}

/// Starts a reseller quote with the public mayoreo terms already understood.
/// Product-level wholesale apartados use [ApartadoRequest] instead; this is
/// the earlier catalog-to-quote handoff, before individual pieces are known.
Uri partnerQuoteWhatsAppUri({String? category, String? catalogMode}) {
  final details = <String>[
    if (category != null && category.trim().isNotEmpty)
      'Categoría: ${category.trim()}',
    if (catalogMode != null && catalogMode.trim().isNotEmpty)
      'Catálogo: ${catalogMode.trim()}',
  ];
  final text = <String>[
    '¡Hola Monetta! Quiero cotizar un pedido para reventa.',
    if (details.isNotEmpty) '',
    ...details,
    '',
    'Entiendo que el mayoreo comienza desde 3 modelos, el anticipo es de '
        '\$800 MXN y puedo liquidar en hasta 20 días.',
    '',
    'Sé que abrir WhatsApp no aprueba mayoreo, no reserva inventario ni '
        'crea un pedido o comisión automáticamente.',
    '',
    'Origen: app · Vende con Monetta',
  ].join('\n');
  return Uri.https('wa.me', '/$kWhatsAppE164', <String, String>{'text': text});
}

/// Deposit and window for WhatsApp apartado. Keep these next to the price,
/// never only inside an accordion.
const int kApartadoDepositMxn = 400;
const int kApartadoDays = 20;

const String kApartadoSentence =
    'Escríbenos por WhatsApp para solicitar apartado (\$400 MXN · 20 días). '
    'Abrir el chat no reserva stock ni confirma el anticipo.';

const List<String> kTrustRows = [
  'Piezas originales importadas de Estados Unidos',
  'Envío a todo México · gratis desde \$1,499',
  'Cambios por WhatsApp',
  'Apartado manual por WhatsApp · \$400 · 20 días',
];

/// Card title: Shopify name, with the colourway folded in when it is not
/// already in the string. Hierarchy on the card is letter-case, not extra
/// words.
String cardPieceName({required String title, String? colorSlug}) {
  title = shopperProductName(title);
  final color = colorLabel(colorSlug);
  if (color.isEmpty) return title;
  final lower = title.toLowerCase();
  final colour = color.toLowerCase();
  if (lower.contains(colour)) return title;
  final stem =
      colour.length > 3 && (colour.endsWith('o') || colour.endsWith('a'))
          ? colour.substring(0, colour.length - 1)
          : colour;
  if (stem.length >= 3 && lower.contains(stem)) return title;
  return '$title $colour';
}
