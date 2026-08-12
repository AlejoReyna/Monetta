/// Build-time switch for the external-catalog prototype.
///
/// Off by default, on purpose — this feature makes a network call to an
/// internal-only service and shows research listings from other merchants'
/// sites. It must be an explicit, visible choice at build time, not
/// something that can turn on by accident:
///
/// ```
/// flutter run \
///   --dart-define=ENABLE_EXTERNAL_CATALOG=true \
///   --dart-define=EXTERNAL_CATALOG_BASE_URL=http://localhost:8081
/// ```
library;

class ExternalCatalogConfig {
  const ExternalCatalogConfig({required this.enabled, required this.baseUrl});

  final bool enabled;
  final String? baseUrl;

  /// [enabled] is true only when both the flag is set *and* a base URL was
  /// provided — a flag with nowhere to point at is not really "on."
  factory ExternalCatalogConfig.fromEnvironment() {
    const flag = bool.fromEnvironment('ENABLE_EXTERNAL_CATALOG');
    const rawBaseUrl = String.fromEnvironment('EXTERNAL_CATALOG_BASE_URL');
    final baseUrl = rawBaseUrl.isEmpty ? null : rawBaseUrl;
    return ExternalCatalogConfig(
      enabled: flag && baseUrl != null,
      baseUrl: baseUrl,
    );
  }

  static const ExternalCatalogConfig disabled = ExternalCatalogConfig(
    enabled: false,
    baseUrl: null,
  );
}
