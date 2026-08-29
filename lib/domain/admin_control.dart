/// App-native control-plane entities shared by the admin UI and its client.
library;

enum AdminChannel { shopify, app, externalCatalog }

enum AdminConnectionMode { preview, live }

class AdminProductRecord {
  const AdminProductRecord({
    required this.id,
    required this.title,
    required this.price,
    required this.inStock,
    required this.visible,
    required this.variantCount,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String? imageUrl;
  final double price;
  final bool inStock;
  final bool visible;
  final int variantCount;

  AdminProductRecord copyWith({
    String? title,
    double? price,
    bool? inStock,
    bool? visible,
  }) {
    return AdminProductRecord(
      id: id,
      title: title ?? this.title,
      imageUrl: imageUrl,
      price: price ?? this.price,
      inStock: inStock ?? this.inStock,
      visible: visible ?? this.visible,
      variantCount: variantCount,
    );
  }
}

class AdminStorefrontSettings {
  const AdminStorefrontSettings({
    required this.announcement,
    required this.showHero,
    required this.showNewest,
    required this.showExternalPicks,
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
  final bool showExternalPicks;

  AdminStorefrontSettings copyWith({
    String? announcement,
    bool? showHero,
    bool? showNewest,
    bool? showExternalPicks,
  }) {
    return AdminStorefrontSettings(
      announcement: announcement ?? this.announcement,
      showHero: showHero ?? this.showHero,
      showNewest: showNewest ?? this.showNewest,
      showExternalPicks: showExternalPicks ?? this.showExternalPicks,
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

  AdminSourcePolicy copyWith({
    bool? enabled,
    int? itemLimit,
    double? baseCommissionRate,
    double? highValueCommissionRate,
    double? highValueThreshold,
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
  });

  final List<AdminProductRecord> products;
  final AdminStorefrontSettings storefront;
  final List<AdminSourcePolicy> sources;
}
