/// Owner-controlled content for the storefront home.
///
/// Shopify may override every value at runtime. These bundled values mirror
/// the current mobile store and keep the home complete while offline.
library;

enum HomeSectionId {
  collections,
  newProducts,
  bagTypes,
  brands,
  about,
  social,
  testimonials;

  static HomeSectionId? fromWire(String value) {
    return switch (value.trim().toLowerCase().replaceAll('-', '_')) {
      'collections' || 'colecciones' => collections,
      'new_products' || 'newest' || 'nuevos_productos' => newProducts,
      'bag_types' || 'tipos_de_bolsa' || 'tipo_de_bolsas' => bagTypes,
      'brands' || 'marcas' => brands,
      'about' || 'about_monetta' || 'mas_sobre_monetta' => about,
      'social' || 'social_links' || 'redes' => social,
      'testimonials' || 'reviews' || 'experiencias' => testimonials,
      _ => null,
    };
  }

  String get wireValue => switch (this) {
        collections => 'collections',
        newProducts => 'new_products',
        bagTypes => 'bag_types',
        brands => 'brands',
        about => 'about',
        social => 'social',
        testimonials => 'testimonials',
      };
}

class HomeCollectionCard {
  const HomeCollectionCard({
    required this.title,
    required this.handle,
    required this.fallbackAsset,
    this.imageUrl,
    this.category,
    this.silhouette,
  });

  final String title;
  final String handle;
  final String fallbackAsset;
  final String? imageUrl;
  final String? category;
  final String? silhouette;

  HomeCollectionCard copyWith({
    String? title,
    String? handle,
    String? fallbackAsset,
    String? imageUrl,
    String? category,
    String? silhouette,
  }) {
    return HomeCollectionCard(
      title: title ?? this.title,
      handle: handle ?? this.handle,
      fallbackAsset: fallbackAsset ?? this.fallbackAsset,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      silhouette: silhouette ?? this.silhouette,
    );
  }
}

class HomeSocialLink {
  const HomeSocialLink({
    required this.id,
    required this.label,
    required this.url,
  });

  final String id;
  final String label;
  final String url;

  Uri? get uri {
    final parsed = Uri.tryParse(url);
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) return null;
    return parsed;
  }
}

class HomeTestimonial {
  const HomeTestimonial({
    required this.reviewer,
    required this.body,
    required this.rating,
    required this.fallbackAsset,
    this.imageUrl,
    this.imageAlt,
    this.productName,
    this.verified = true,
  });

  final String reviewer;
  final String body;
  final int rating;
  final String fallbackAsset;
  final String? imageUrl;
  final String? imageAlt;
  final String? productName;
  final bool verified;
}

class HomeContent {
  const HomeContent({
    required this.sectionOrder,
    required this.collections,
    required this.bagTypes,
    required this.socialLinks,
    required this.testimonials,
    this.aboutImageUrl,
    this.reviewAverage,
    this.reviewCount,
  });

  final List<HomeSectionId> sectionOrder;
  final List<HomeCollectionCard> collections;
  final List<HomeCollectionCard> bagTypes;
  final List<HomeSocialLink> socialLinks;
  final List<HomeTestimonial> testimonials;
  final String? aboutImageUrl;
  final double? reviewAverage;
  final int? reviewCount;

  HomeContent copyWith({
    List<HomeSectionId>? sectionOrder,
    List<HomeCollectionCard>? collections,
    List<HomeCollectionCard>? bagTypes,
    List<HomeSocialLink>? socialLinks,
    List<HomeTestimonial>? testimonials,
    String? aboutImageUrl,
    double? reviewAverage,
    int? reviewCount,
  }) {
    return HomeContent(
      sectionOrder: sectionOrder ?? this.sectionOrder,
      collections: collections ?? this.collections,
      bagTypes: bagTypes ?? this.bagTypes,
      socialLinks: socialLinks ?? this.socialLinks,
      testimonials: testimonials ?? this.testimonials,
      aboutImageUrl: aboutImageUrl ?? this.aboutImageUrl,
      reviewAverage: reviewAverage ?? this.reviewAverage,
      reviewCount: reviewCount ?? this.reviewCount,
    );
  }

  static const fallback = HomeContent(
    sectionOrder: <HomeSectionId>[
      HomeSectionId.collections,
      HomeSectionId.newProducts,
      HomeSectionId.bagTypes,
      HomeSectionId.brands,
      HomeSectionId.about,
      HomeSectionId.social,
      HomeSectionId.testimonials,
    ],
    collections: <HomeCollectionCard>[
      HomeCollectionCard(
        title: 'Bolsas',
        handle: 'guess',
        category: 'bolsa',
        fallbackAsset: 'assets/images/home_collection_bags.webp',
      ),
      HomeCollectionCard(
        title: 'Carteras',
        handle: 'carteras-1',
        category: 'cartera',
        fallbackAsset: 'assets/images/home_collection_wallets.webp',
      ),
      HomeCollectionCard(
        title: 'Relojes',
        handle: 'relojes',
        category: 'reloj',
        fallbackAsset: 'assets/images/home_collection_watches.webp',
      ),
    ],
    bagTypes: <HomeCollectionCard>[
      HomeCollectionCard(
        title: 'Totes',
        handle: 'totes',
        category: 'bolsa',
        silhouette: 'tote',
        fallbackAsset: 'assets/images/home_bag_tote.webp',
      ),
      HomeCollectionCard(
        title: 'Crossbodys',
        handle: 'crossbodys',
        category: 'bolsa',
        silhouette: 'crossbody',
        fallbackAsset: 'assets/images/home_bag_crossbody.webp',
      ),
      HomeCollectionCard(
        title: 'Hombro',
        handle: 'hombro',
        category: 'bolsa',
        silhouette: 'shoulder',
        fallbackAsset: 'assets/images/home_bag_shoulder.webp',
      ),
    ],
    socialLinks: <HomeSocialLink>[
      HomeSocialLink(
        id: 'instagram',
        label: 'Instagram',
        url: 'https://www.instagram.com/_monetta.mx',
      ),
      HomeSocialLink(
        id: 'tiktok',
        label: 'TikTok',
        url: 'https://www.tiktok.com/@monetta.oficial',
      ),
      HomeSocialLink(
        id: 'facebook',
        label: 'Facebook',
        url: 'https://www.facebook.com/profile.php?id=100091065527635',
      ),
    ],
    testimonials: <HomeTestimonial>[
      HomeTestimonial(
        reviewer: 'Monse C.',
        body: 'Excelente opción para emprender con productos originales, los '
            'precios de mayoreo son los mejores que he encontrado. Ya es mi '
            'quinto pedido.',
        rating: 5,
        fallbackAsset: 'assets/images/home_review_monse.jpg',
      ),
      HomeTestimonial(
        reviewer: 'Gaby E.',
        body: 'Me encanta que todo sea 100% original. Muy bonitos los bolsos '
            'y carteras, súper recomendados para negocio. Ya es mi tercer '
            'pedido.',
        rating: 5,
        fallbackAsset: 'assets/images/home_review_gaby.jpg',
      ),
      HomeTestimonial(
        reviewer: 'Guadalupe G.',
        body: 'Mis clientas amaron las bolsas, la calidad viene súper bien. '
            'Volveré a pedir.',
        rating: 5,
        fallbackAsset: 'assets/images/home_review_guadalupe.jpg',
      ),
    ],
    reviewAverage: 4.9,
    reviewCount: 139,
  );
}
