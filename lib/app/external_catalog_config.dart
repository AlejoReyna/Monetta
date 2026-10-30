/// Build-time switch for the retired external-catalog prototype.
///
/// Product decision (WP-02 / F03): Monetta sells its own Shopify products
/// only. Third-party extraction via `catalog_monitor` / `dashboard` is not
/// part of the customer storefront. This config always reports disabled so
/// builds that bypass Makefile validation still cannot admit the flag.
library;

class ExternalCatalogConfig {
  const ExternalCatalogConfig({required this.enabled, required this.baseUrl});

  final bool enabled;
  final String? baseUrl;

  /// Always disabled. `ENABLE_EXTERNAL_CATALOG` / `EXTERNAL_CATALOG_BASE_URL`
  /// dart-defines are ignored so production and staging cannot re-enable the
  /// retired monitor path by accident.
  factory ExternalCatalogConfig.fromEnvironment() {
    return ExternalCatalogConfig.disabled;
  }

  /// True when a build still passes `--dart-define=ENABLE_EXTERNAL_CATALOG=true`.
  /// Used by [RuntimeConfig] / validators to fail closed rather than silently
  /// ignore a forbidden flag in release configs.
  static bool get flagRequestedInEnvironment =>
      const bool.fromEnvironment('ENABLE_EXTERNAL_CATALOG');

  static const ExternalCatalogConfig disabled = ExternalCatalogConfig(
    enabled: false,
    baseUrl: null,
  );
}
