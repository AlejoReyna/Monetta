/// JSON models for `GET /v1/external-catalog`, matching
/// `services/catalog_monitor/src/api/schema.ts` (`schemaVersion: 1`).
///
/// These are deliberately *not* [CatalogItem] — this file is the untyped
/// wire shape, `external_catalog_mapper.dart` is where it becomes the
/// canonical domain type. Keeping them separate means a backend schema
/// change shows up as a mapper diff, not a domain-model diff.
library;

class ExternalCatalogSourceStatus {
  const ExternalCatalogSourceStatus({
    required this.source,
    required this.merchant,
    required this.lastSuccessfulRunAt,
    required this.freshnessHours,
    required this.itemCount,
  });

  final String source;
  final String merchant;
  final DateTime? lastSuccessfulRunAt;
  final double? freshnessHours;
  final int itemCount;

  factory ExternalCatalogSourceStatus.fromJson(Map<String, dynamic> json) {
    final rawTimestamp = json['lastSuccessfulRunAt'];
    return ExternalCatalogSourceStatus(
      source: '${json['source'] ?? ''}',
      merchant: '${json['merchant'] ?? ''}',
      lastSuccessfulRunAt:
          rawTimestamp is String ? DateTime.tryParse(rawTimestamp) : null,
      freshnessHours: (json['freshnessHours'] as num?)?.toDouble(),
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'source': source,
        'merchant': merchant,
        'lastSuccessfulRunAt': lastSuccessfulRunAt?.toIso8601String(),
        'freshnessHours': freshnessHours,
        'itemCount': itemCount,
      };
}

class ExternalCatalogResponse {
  const ExternalCatalogResponse({
    required this.schemaVersion,
    required this.generatedAt,
    required this.sources,
    required this.items,
  });

  final int schemaVersion;
  final DateTime generatedAt;
  final List<ExternalCatalogSourceStatus> sources;

  /// Raw item JSON — converted to [CatalogItem] by `external_catalog_mapper.dart`.
  final List<Map<String, dynamic>> items;

  factory ExternalCatalogResponse.fromJson(Map<String, dynamic> json) {
    return ExternalCatalogResponse(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 0,
      generatedAt: DateTime.tryParse('${json['generatedAt']}') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      sources: (json['sources'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ExternalCatalogSourceStatus.fromJson)
          .toList(),
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'generatedAt': generatedAt.toIso8601String(),
        'sources': sources.map((s) => s.toJson()).toList(),
        'items': items,
      };
}
