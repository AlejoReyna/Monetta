/// Owner-editable brand and reseller content shown outside the product grid.
///
/// The bundled values are a complete offline fallback. Shopify Metaobjects
/// may override them at runtime, but a missing definition or a network error
/// must never leave either screen empty.
library;

import 'seasonal_campaign.dart';

enum PartnerCatalogMode {
  wholesale,
  suggestedPrices,
  noPrices;

  String get label => switch (this) {
        wholesale => 'Mayoreo',
        suggestedPrices => 'Con precios',
        noPrices => 'Sin precios',
      };

  bool get isClientFacing => this != wholesale;

  static PartnerCatalogMode? fromWire(String value) => switch (value.trim()) {
        'wholesale' || 'mayoreo' => wholesale,
        'suggested_prices' || 'con_precios' => suggestedPrices,
        'no_prices' || 'sin_precios' => noPrices,
        _ => null,
      };
}

class StoryMilestone {
  const StoryMilestone({
    required this.year,
    required this.title,
    required this.body,
  });

  final String year;
  final String title;
  final String body;
}

class AboutMonettaContent {
  const AboutMonettaContent({
    required this.eyebrow,
    required this.headline,
    required this.body,
    required this.heroAsset,
    required this.milestones,
    required this.trustFacts,
  });

  final String eyebrow;
  final String headline;
  final String body;

  /// A bundled asset keeps the story usable without a network connection.
  final String heroAsset;
  final List<StoryMilestone> milestones;
  final List<String> trustFacts;

  AboutMonettaContent copyWith({
    String? eyebrow,
    String? headline,
    String? body,
    String? heroAsset,
    List<StoryMilestone>? milestones,
    List<String>? trustFacts,
  }) {
    return AboutMonettaContent(
      eyebrow: eyebrow ?? this.eyebrow,
      headline: headline ?? this.headline,
      body: body ?? this.body,
      heroAsset: heroAsset ?? this.heroAsset,
      milestones: milestones ?? this.milestones,
      trustFacts: trustFacts ?? this.trustFacts,
    );
  }
}

class PartnerStep {
  const PartnerStep({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final String body;
}

class PartnerTerm {
  const PartnerTerm({required this.value, required this.label});

  final String value;
  final String label;
}

class PartnerFaq {
  const PartnerFaq({required this.question, required this.answer});

  final String question;
  final String answer;
}

class PartnerCatalog {
  const PartnerCatalog({
    required this.id,
    required this.category,
    required this.categoryLabel,
    required this.mode,
    required this.url,
    required this.description,
    required this.sortOrder,
    this.updatedLabel,
  });

  final String id;
  final String category;
  final String categoryLabel;
  final PartnerCatalogMode mode;
  final String url;
  final String description;
  final int sortOrder;
  final String? updatedLabel;

  Uri? get uri {
    final parsed = Uri.tryParse(url);
    return parsed != null && isTrustedPartnerUri(parsed) ? parsed : null;
  }

  String get shareText =>
      'Te comparto mi catálogo de ${categoryLabel.toLowerCase()}. '
      'Aquí puedes ver los modelos disponibles:\n$url';
}

class PartnerProgramContent {
  const PartnerProgramContent({
    required this.eyebrow,
    required this.headline,
    required this.body,
    required this.steps,
    required this.terms,
    required this.catalogs,
    required this.faqs,
  });

  final String eyebrow;
  final String headline;
  final String body;
  final List<PartnerStep> steps;
  final List<PartnerTerm> terms;
  final List<PartnerCatalog> catalogs;
  final List<PartnerFaq> faqs;

  PartnerProgramContent copyWith({
    String? eyebrow,
    String? headline,
    String? body,
    List<PartnerStep>? steps,
    List<PartnerTerm>? terms,
    List<PartnerCatalog>? catalogs,
    List<PartnerFaq>? faqs,
  }) {
    return PartnerProgramContent(
      eyebrow: eyebrow ?? this.eyebrow,
      headline: headline ?? this.headline,
      body: body ?? this.body,
      steps: steps ?? this.steps,
      terms: terms ?? this.terms,
      catalogs: catalogs ?? this.catalogs,
      faqs: faqs ?? this.faqs,
    );
  }
}

class MonettaEditorialContent {
  const MonettaEditorialContent({
    required this.about,
    required this.partner,
    this.seasonalBanners = const <SeasonalCampaign>[],
  });

  final AboutMonettaContent about;
  final PartnerProgramContent partner;

  /// Every scheduled home banner. The home controller picks the one in window.
  /// Empty is not the shipped placeholder: that state is "no Storefront
  /// source", which this list cannot express on its own.
  final List<SeasonalCampaign> seasonalBanners;

  MonettaEditorialContent copyWith({
    AboutMonettaContent? about,
    PartnerProgramContent? partner,
    List<SeasonalCampaign>? seasonalBanners,
  }) {
    return MonettaEditorialContent(
      about: about ?? this.about,
      partner: partner ?? this.partner,
      seasonalBanners: seasonalBanners ?? this.seasonalBanners,
    );
  }

  static const fallback = MonettaEditorialContent(
    about: AboutMonettaContent(
      eyebrow: 'MÁS SOBRE MONETTA',
      headline: 'Tu boutique y proveedor de confianza.',
      body: 'Somos una boutique mexicana especializada en productos originales '
          'de tus marcas favoritas. Elegimos piezas importadas de Estados '
          'Unidos y las acercamos a todo México, tanto para consentirte como '
          'para ayudarte a crecer tu negocio.',
      heroAsset: 'assets/images/campaign_terracotta.jpg',
      milestones: <StoryMilestone>[
        StoryMilestone(
          year: '2023',
          title: 'Aquí comenzó todo',
          body: 'Abrimos nuestra boutique física en Montemorelos, Nuevo León, '
              'y llegaron las primeras ventas a mayoreo.',
        ),
        StoryMilestone(
          year: '2024',
          title: 'Nos convertimos en boutique online',
          body: 'Llevamos la experiencia completamente a internet e integramos '
              'bolsos, carteras y perfumes.',
        ),
        StoryMilestone(
          year: '2025',
          title: 'Ampliamos la selección',
          body: 'Sumamos skincare y maquillaje para ofrecer más formas de '
              'comprar y emprender con Monetta.',
        ),
        StoryMilestone(
          year: '2026',
          title: 'Una nueva era en casa',
          body: 'Hoy reunimos más de 3,000 productos en nuestros catálogos y '
              'enviamos a todo México.',
        ),
        StoryMilestone(
          year: 'AHORA',
          title: 'Monetta también vive en tu teléfono',
          body: 'La app hace más fácil descubrir piezas, comprar y acceder a '
              'las herramientas para vender con nosotros.',
        ),
      ],
      trustFacts: <String>[
        'Productos originales importados de Estados Unidos',
        'Mayoreo y menudeo en un mismo proveedor',
        'Envíos a todo México',
        'Atención personalizada por WhatsApp',
      ],
    ),
    partner: PartnerProgramContent(
      eyebrow: 'VENDE CON MONETTA',
      headline: 'Convierte tu buen gusto en un negocio.',
      body: 'Comparte más de 3,000 productos originales con tus clientes y '
          'accede a precios de mayoreo desde tres piezas. Tú eliges qué '
          'vender; Monetta te acompaña para hacerlo crecer.',
      steps: <PartnerStep>[
        PartnerStep(
          number: '01',
          title: 'Elige tu catálogo',
          body: 'Consulta mayoreo para preparar tu compra o elige una versión '
              'con precios sugeridos o sin precios para tus clientes.',
        ),
        PartnerStep(
          number: '02',
          title: 'Compártelo',
          body: 'Envíalo por WhatsApp, mensaje o redes sociales para que tus '
              'clientes elijan sus modelos favoritos.',
        ),
        PartnerStep(
          number: '03',
          title: 'Cotiza tu pedido',
          body: 'Mándanos los modelos elegidos para cotizar, apartar o '
              'completar la compra.',
        ),
      ],
      terms: <PartnerTerm>[
        PartnerTerm(value: '3', label: 'modelos para mayoreo'),
        PartnerTerm(value: r'$800', label: 'anticipo mayoreo'),
        PartnerTerm(value: '20 días', label: 'para liquidar'),
        PartnerTerm(value: '100%', label: 'productos originales'),
      ],
      catalogs: <PartnerCatalog>[
        PartnerCatalog(
          id: 'bags-wholesale',
          category: 'bags',
          categoryLabel: 'Bolsas y carteras',
          mode: PartnerCatalogMode.wholesale,
          url: 'https://canva.link/6p829fs82kj22aw',
          description: 'Precios para preparar y cotizar tu pedido.',
          sortOrder: 0,
        ),
        PartnerCatalog(
          id: 'bags-suggested',
          category: 'bags',
          categoryLabel: 'Bolsas y carteras',
          mode: PartnerCatalogMode.suggestedPrices,
          url: 'https://canva.link/nd89t2ygievrw3i',
          description: 'Listo para compartir con precios sugeridos de venta.',
          sortOrder: 1,
        ),
        PartnerCatalog(
          id: 'bags-no-prices',
          category: 'bags',
          categoryLabel: 'Bolsas y carteras',
          mode: PartnerCatalogMode.noPrices,
          url: 'https://canva.link/7h67zcfs7vhesay',
          description: 'Comparte los modelos y decide tu precio final.',
          sortOrder: 2,
        ),
        PartnerCatalog(
          id: 'beauty-wholesale',
          category: 'beauty',
          categoryLabel: 'Skincare y makeup',
          mode: PartnerCatalogMode.wholesale,
          url:
              'https://drive.google.com/file/d/1yt7krnpYVnXCYGYU7wrRkNkUfQxPd9mc/view?usp=sharing',
          description: 'Precios para preparar y cotizar tu pedido.',
          sortOrder: 3,
        ),
        PartnerCatalog(
          id: 'beauty-suggested',
          category: 'beauty',
          categoryLabel: 'Skincare y makeup',
          mode: PartnerCatalogMode.suggestedPrices,
          url:
              'https://drive.google.com/file/d/12w-QgoXQ_LNrRS0WiK7x1BVj60c52_u8/view?usp=sharing',
          description: 'Listo para compartir con precios sugeridos de venta.',
          sortOrder: 4,
        ),
        PartnerCatalog(
          id: 'beauty-no-prices',
          category: 'beauty',
          categoryLabel: 'Skincare y makeup',
          mode: PartnerCatalogMode.noPrices,
          url:
              'https://drive.google.com/file/d/1vMcO1obIrCsSk39XiowlhVwSYL3A_PK0/view?usp=sharing',
          description: 'Comparte los modelos y decide tu precio final.',
          sortOrder: 5,
        ),
        PartnerCatalog(
          id: 'perfume-wholesale',
          category: 'perfume',
          categoryLabel: 'Perfumes',
          mode: PartnerCatalogMode.wholesale,
          url:
              'https://drive.google.com/file/d/14VcCsOEVU0u-ueo7HHTV2MZL6itjyzSO/view?usp=sharing',
          description: 'Precios para preparar y cotizar tu pedido.',
          sortOrder: 6,
        ),
        PartnerCatalog(
          id: 'perfume-suggested',
          category: 'perfume',
          categoryLabel: 'Perfumes',
          mode: PartnerCatalogMode.suggestedPrices,
          url:
              'https://drive.google.com/file/d/15dFe_YlcJJkMyYJ0j_iXdioxboWCrJb8/view?usp=sharing',
          description: 'Listo para compartir con precios sugeridos de venta.',
          sortOrder: 7,
        ),
        PartnerCatalog(
          id: 'perfume-no-prices',
          category: 'perfume',
          categoryLabel: 'Perfumes',
          mode: PartnerCatalogMode.noPrices,
          url:
              'https://drive.google.com/file/d/11L3ax87ndWNSSg2qkrgHGFIA6cvDUq9l/view?usp=sharing',
          description: 'Comparte los modelos y decide tu precio final.',
          sortOrder: 8,
        ),
      ],
      faqs: <PartnerFaq>[
        PartnerFaq(
          question: '¿Qué catálogo comparto con mis clientes?',
          answer:
              'Usa “Con precios” si quieres empezar con precios sugeridos o '
              '“Sin precios” si prefieres definir tu propia ganancia. El '
              'catálogo de mayoreo es para preparar tu compra.',
        ),
        PartnerFaq(
          question: '¿Necesito registrarme?',
          answer: 'No hay registro ni aprobación automática de revendedor en '
              'la app. Puedes abrir y compartir los catálogos públicos. '
              'Cuando tengas un pedido, escríbenos por WhatsApp para cotizarlo.',
        ),
        PartnerFaq(
          question: '¿Cómo funciona el apartado?',
          answer:
              'Es un proceso manual. El anticipo de referencia de mayoreo es '
              'de \$800 MXN y tienes hasta 20 días para liquidar. Abrir '
              'WhatsApp no reserva ni cobra: Monetta confirma disponibilidad, '
              'recibe el anticipo y registra el pedido en Shopify.',
        ),
      ],
    ),
  );
}

const Set<String> _trustedPartnerHosts = <String>{
  'canva.link',
  'canva.com',
  'www.canva.com',
  'drive.google.com',
  'docs.google.com',
  'monetta.mx',
  'www.monetta.mx',
};

bool isTrustedPartnerUri(Uri uri) =>
    uri.scheme == 'https' && _trustedPartnerHosts.contains(uri.host);
