/// Build-time switch for the `services/accounts_orders` client — same shape
/// as `app/external_catalog_config.dart`'s `ExternalCatalogConfig`.
///
/// Off by default: this backend is a new, unauthenticated-endpoint
/// prototype (see `services/accounts_orders/README.md` § "Known
/// limitations") that hasn't been deployed anywhere yet.
///
/// ```
/// flutter run \
///   --dart-define=ACCOUNTS_ORDERS_BASE_URL=http://localhost:8082
/// ```
library;

class AccountsOrdersConfig {
  const AccountsOrdersConfig({required this.enabled, required this.baseUrl});

  final bool enabled;
  final String? baseUrl;

  factory AccountsOrdersConfig.fromEnvironment() {
    const rawBaseUrl = String.fromEnvironment('ACCOUNTS_ORDERS_BASE_URL');
    final baseUrl = rawBaseUrl.isEmpty ? null : rawBaseUrl;
    return AccountsOrdersConfig(enabled: baseUrl != null, baseUrl: baseUrl);
  }

  static const AccountsOrdersConfig disabled = AccountsOrdersConfig(
    enabled: false,
    baseUrl: null,
  );
}
