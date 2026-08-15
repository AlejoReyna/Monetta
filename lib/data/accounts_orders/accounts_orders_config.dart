/// Build-time switch for the `services/accounts_orders` client — same shape
/// as `app/external_catalog_config.dart`'s `ExternalCatalogConfig`.
///
/// The same base URL powers first-party Monetta account registration and
/// order history. Off only when no service URL was supplied.
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
