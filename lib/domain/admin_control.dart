/// App-native control-plane entities shared by the admin UI and its client.
library;

enum AdminChannel { shopify, app, externalCatalog }

enum AdminConnectionMode { preview, live }

class AdminProductVariant {
  const AdminProductVariant({
    required this.id,
    required this.title,
    required this.price,
    this.compareAtPrice,
    required this.availableForSale,
    this.currencyCode = 'MXN',
  });

  final String id;
  final String title;
  final double price;
  final double? compareAtPrice;
  final bool availableForSale;
  final String currencyCode;

  AdminProductVariant copyWith({
    String? title,
    double? price,
    double? compareAtPrice,
    bool? availableForSale,
    String? currencyCode,
  }) {
    return AdminProductVariant(
      id: id,
      title: title ?? this.title,
      price: price ?? this.price,
      compareAtPrice: compareAtPrice ?? this.compareAtPrice,
      availableForSale: availableForSale ?? this.availableForSale,
      currencyCode: currencyCode ?? this.currencyCode,
    );
  }
}

class AdminProductRecord {
  const AdminProductRecord({
    required this.id,
    required this.title,
    required this.price,
    required this.inStock,
    required this.visible,
    required this.variantCount,
    this.imageUrl,
    this.descriptionHtml = '',
    this.status = 'ACTIVE',
    this.publishedToMonetta = true,
    this.updatedAt,
    this.variants = const [],
  });

  final String id;
  final String title;
  final String? imageUrl;
  final double price;
  final bool inStock;
  final bool visible;
  final int variantCount;
  final String descriptionHtml;
  final String status;
  final bool publishedToMonetta;
  final DateTime? updatedAt;
  final List<AdminProductVariant> variants;

  bool get hasShopifyDescription => descriptionHtml.trim().isNotEmpty;

  String get descriptionExcerpt {
    final plain = descriptionHtml
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return plain.length <= 120 ? plain : '${plain.substring(0, 117)}…';
  }

  AdminProductRecord copyWith({
    String? title,
    double? price,
    bool? inStock,
    bool? visible,
    String? descriptionHtml,
    bool? publishedToMonetta,
    DateTime? updatedAt,
    List<AdminProductVariant>? variants,
  }) {
    final nextVariants = variants ??
        (price != null && this.variants.isNotEmpty
            ? [this.variants.first.copyWith(price: price)]
            : this.variants);
    return AdminProductRecord(
      id: id,
      title: title ?? this.title,
      imageUrl: imageUrl,
      price: price ?? this.price,
      inStock: inStock ?? this.inStock,
      visible: visible ?? this.visible,
      variantCount: variantCount,
      descriptionHtml: descriptionHtml ?? this.descriptionHtml,
      status: status,
      publishedToMonetta:
          publishedToMonetta ?? visible ?? this.publishedToMonetta,
      updatedAt: updatedAt ?? this.updatedAt,
      variants: nextVariants,
    );
  }
}

class AdminFeaturedCatalog {
  const AdminFeaturedCatalog({
    required this.eligibleProducts,
    required this.selectedProductIds,
    this.collectionId,
    this.collectionHandle = 'monetta-todays-picks',
    this.collectionTitle = 'Today\'s Picks',
    this.collectionUpdatedAt,
    this.healthStatus = 'unavailable',
    this.healthErrorCode,
  });

  final List<AdminProductRecord> eligibleProducts;
  final List<String> selectedProductIds;
  final String? collectionId;
  final String collectionHandle;
  final String collectionTitle;
  final DateTime? collectionUpdatedAt;
  final String healthStatus;
  final String? healthErrorCode;

  bool get isReady => healthStatus == 'ready' && collectionId != null;

  AdminFeaturedCatalog copyWith({
    List<AdminProductRecord>? eligibleProducts,
    List<String>? selectedProductIds,
    String? collectionId,
    String? collectionHandle,
    String? collectionTitle,
    DateTime? collectionUpdatedAt,
    String? healthStatus,
    String? healthErrorCode,
  }) {
    return AdminFeaturedCatalog(
      eligibleProducts: eligibleProducts ?? this.eligibleProducts,
      selectedProductIds: selectedProductIds ?? this.selectedProductIds,
      collectionId: collectionId ?? this.collectionId,
      collectionHandle: collectionHandle ?? this.collectionHandle,
      collectionTitle: collectionTitle ?? this.collectionTitle,
      collectionUpdatedAt: collectionUpdatedAt ?? this.collectionUpdatedAt,
      healthStatus: healthStatus ?? this.healthStatus,
      healthErrorCode: healthErrorCode ?? this.healthErrorCode,
    );
  }
}

class AdminFeaturedMutationResult {
  const AdminFeaturedMutationResult({this.catalog, this.jobId});

  final AdminFeaturedCatalog? catalog;
  final String? jobId;
}

class AdminStorefrontSettings {
  const AdminStorefrontSettings({
    required this.announcement,
    required this.showHero,
    required this.showNewest,
    this.showTodaysPicks = true,
    required this.showExternalPicks,
    this.version = 0,
  });

  static const defaults = AdminStorefrontSettings(
    announcement: r'ENVÍO GRATIS DESDE $1,499',
    showHero: true,
    showNewest: true,
    showExternalPicks: true,
  );

  final String announcement;
  final bool showHero;
  final bool showNewest;
  final bool showTodaysPicks;
  final bool showExternalPicks;
  final int version;

  AdminStorefrontSettings copyWith({
    String? announcement,
    bool? showHero,
    bool? showNewest,
    bool? showTodaysPicks,
    bool? showExternalPicks,
    int? version,
  }) {
    return AdminStorefrontSettings(
      announcement: announcement ?? this.announcement,
      showHero: showHero ?? this.showHero,
      showNewest: showNewest ?? this.showNewest,
      showTodaysPicks: showTodaysPicks ?? this.showTodaysPicks,
      showExternalPicks: showExternalPicks ?? this.showExternalPicks,
      version: version ?? this.version,
    );
  }
}

class AdminSourcePolicy {
  const AdminSourcePolicy({
    required this.id,
    required this.merchant,
    required this.enabled,
    required this.itemLimit,
    required this.baseCommissionRate,
    required this.highValueCommissionRate,
    required this.highValueThreshold,
    required this.itemCount,
    this.lastSuccessfulRunAt,
    this.healthStatus = 'unavailable',
    this.healthErrorCode,
  });

  final String id;
  final String merchant;
  final bool enabled;
  final int itemLimit;
  final double baseCommissionRate;
  final double highValueCommissionRate;
  final double highValueThreshold;
  final int itemCount;
  final DateTime? lastSuccessfulRunAt;
  final String healthStatus;
  final String? healthErrorCode;

  AdminSourcePolicy copyWith({
    bool? enabled,
    int? itemLimit,
    double? baseCommissionRate,
    double? highValueCommissionRate,
    double? highValueThreshold,
    String? healthStatus,
    String? healthErrorCode,
  }) {
    return AdminSourcePolicy(
      id: id,
      merchant: merchant,
      enabled: enabled ?? this.enabled,
      itemLimit: itemLimit ?? this.itemLimit,
      baseCommissionRate: baseCommissionRate ?? this.baseCommissionRate,
      highValueCommissionRate:
          highValueCommissionRate ?? this.highValueCommissionRate,
      highValueThreshold: highValueThreshold ?? this.highValueThreshold,
      itemCount: itemCount,
      lastSuccessfulRunAt: lastSuccessfulRunAt,
      healthStatus: healthStatus ?? this.healthStatus,
      healthErrorCode: healthErrorCode ?? this.healthErrorCode,
    );
  }
}

class AdminAuditEvent {
  const AdminAuditEvent({
    required this.description,
    required this.channels,
    required this.createdAt,
    required this.previewOnly,
  });

  final String description;
  final Set<AdminChannel> channels;
  final DateTime createdAt;
  final bool previewOnly;
}

class AdminSnapshot {
  const AdminSnapshot({
    required this.products,
    required this.storefront,
    required this.sources,
    this.featured,
    this.shopifyHealthStatus,
    this.sourcesHealthStatus,
  });

  final List<AdminProductRecord> products;
  final AdminStorefrontSettings storefront;
  final List<AdminSourcePolicy> sources;
  final AdminFeaturedCatalog? featured;
  final String? shopifyHealthStatus;
  final String? sourcesHealthStatus;
}
