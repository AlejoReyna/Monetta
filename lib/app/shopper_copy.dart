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
    slug == null ? '' : (kCategoryLabels[slug] ?? slug);

String categoryPlural(String? slug) =>
    slug == null ? '' : (kCategoryPlural[slug] ?? slug);

String silhouetteLabel(String? slug) =>
    slug == null ? '' : (kSilhouetteLabels[slug] ?? slug);

String colorLabel(String? slug) =>
    slug == null ? '' : (kColorLabels[slug] ?? slug);

String patternLabel(String? slug) =>
    slug == null ? '' : (kPatternLabels[slug] ?? slug);

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
    buffer.write(title);
  }
  if (brand != null) buffer.write(' $brand');
  if (color.isNotEmpty) buffer.write(' en ${color.toLowerCase()}');
  buffer.write('. Original, importada de Estados Unidos.');
  return buffer.toString();
}

Uri conciergeWhatsAppUri({String? productTitle}) {
  final text = productTitle == null
      ? '¡Hola Monetta! Quiero ayuda para elegir una pieza.'
      : '¡Hola Monetta! Quiero información sobre *$productTitle*.';
  return Uri.https('wa.me', '/$kWhatsAppE164', <String, String>{'text': text});
}

Uri wholesaleWhatsAppUri() {
  return Uri.https('wa.me', '/$kWhatsAppE164', <String, String>{
    'text':
        '¡Hola Monetta! Quiero información de mayoreo (desde 3 piezas).',
  });
}
