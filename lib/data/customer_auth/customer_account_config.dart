/// Connection settings for Shopify's Customer Account API — the account-side
/// counterpart to `data/shopify/storefront_config.dart`.
///
/// Classic Liquid-based customer accounts (and Multipass with them) were
/// deprecated by Shopify in February 2026; this OAuth 2.0 + PKCE flow is the
/// only supported way left to authenticate a shopper. See
/// `docs/ACCOUNTS_AND_SYNC_PLAN.md` § 2.
library;

class CustomerAccountConfig {
  const CustomerAccountConfig({
    required this.shopId,
    required this.clientId,
    required this.redirectUri,
  });

  /// The numeric shop id Shopify assigns per store — distinct from
  /// `StorefrontConfig.shopDomain`. Appears in both the OAuth endpoint URLs
  /// and the required redirect URI scheme.
  final String shopId;

  /// A `shp_`-prefixed UUID from the Customer Account API's Mobile client
  /// registration in the Shopify Partner dashboard. There is no client
  /// secret: a mobile client is a *public* OAuth client by design (a
  /// compiled app cannot keep one), authenticated instead by PKCE.
  final String clientId;

  /// Must use the custom scheme `shop.{shopId}.*`, registered as this
  /// client's callback URL in the Partner dashboard and as a URL type in the
  /// native iOS/Android project — see `ios/Runner/Info.plist` and
  /// `android/app/build.gradle`.
  final String redirectUri;

  /// `openid` + `email` for identity claims in the id token, plus the scope
  /// that actually unlocks Customer Account API data — without it, calls
  /// fail with a misleadingly generic "Invalid token".
  static const List<String> scopes = [
    'openid',
    'email',
    'customer-account-api:full',
  ];

  String get authorizationEndpoint =>
      'https://shopify.com/authentication/$shopId/oauth/authorize';

  String get tokenEndpoint =>
      'https://shopify.com/authentication/$shopId/oauth/token';

  /// False until a Partner-dashboard registration exists — the honest
  /// default today. Callers must treat login as unavailable rather than
  /// attempting it, the same pattern as `StorefrontConfig.isUsable`.
  bool get isUsable =>
      shopId.isNotEmpty &&
      clientId.isNotEmpty &&
      redirectUri.isNotEmpty &&
      shopId != _placeholderShopId;

  /// Mirrors `ExternalCatalogConfig.fromEnvironment()`'s shape
  /// (`lib/app/external_catalog_config.dart`): build-time `--dart-define`
  /// values, empty string standing in for "not set".
  ///
  /// ```
  /// flutter run \
  ///   --dart-define=CUSTOMER_ACCOUNT_SHOP_ID=12345678 \
  ///   --dart-define=CUSTOMER_ACCOUNT_CLIENT_ID=shp_...
  /// ```
  ///
  /// The redirect URI is *derived* from the shop id rather than independently
  /// configurable — it must match `ios/Runner/Info.plist`'s
  /// `CFBundleURLTypes` and `android/app/build.gradle.kts`'s
  /// `appAuthRedirectScheme` exactly, and deriving it here is one fewer
  /// place that pair can drift out of sync. All three currently carry the
  /// same placeholder shop id; see `README.md` § 8.
  factory CustomerAccountConfig.fromEnvironment() {
    const shopId = String.fromEnvironment(
      'CUSTOMER_ACCOUNT_SHOP_ID',
      defaultValue: _placeholderShopId,
    );
    const clientId = String.fromEnvironment('CUSTOMER_ACCOUNT_CLIENT_ID');
    return CustomerAccountConfig(
      shopId: shopId,
      clientId: clientId,
      redirectUri: 'shop.$shopId.oauth://callback',
    );
  }

  /// Matches the literal placeholder committed in `Info.plist` and
  /// `build.gradle.kts` — lowercase, since AppAuth's Android redirect
  /// matching is case-sensitive (see `flutter_appauth`'s README).
  static const String _placeholderShopId = 'replace_with_shop_id';
}
