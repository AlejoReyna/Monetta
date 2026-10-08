/// Permanent guard for the retired external-catalog prototype.
///
/// Product decision (WP-02 / F03): Monetta sells its own Shopify products
/// only; third-party listings are not part of the customer storefront. The
/// prototype is gone from the app, but a build can still pass
/// `--dart-define=ENABLE_EXTERNAL_CATALOG=true`, and that must fail closed
/// rather than be silently ignored.
library;

abstract final class ExternalCatalogConfig {
  /// True when a build still passes `--dart-define=ENABLE_EXTERNAL_CATALOG=true`.
  /// Used by [RuntimeConfig] / validators to fail closed rather than silently
  /// ignore a forbidden flag in release configs.
  static bool get flagRequestedInEnvironment =>
      const bool.fromEnvironment('ENABLE_EXTERNAL_CATALOG');
}
