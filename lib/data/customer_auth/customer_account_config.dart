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
    this.apiVersion = defaultApiVersion,
  });

  /// The numeric shop id Shopify assigns per store — distinct from
  /// `StorefrontConfig.shopDomain`. Appears in both the OAuth endpoint URLs
  /// and the required redirect URI scheme.
  final String shopId;

  /// The Customer Account API Mobile client's id, from the store's Headless
  /// / Customer Accounts settings. A bare UUID today (older docs describe an
  /// `shp_` prefix; Shopify issues both, and this app must not care which).
  /// There is no client secret: a mobile client is a *public* OAuth client by
  /// design (a compiled app cannot keep one), authenticated instead by PKCE.
  final String clientId;

  /// Must use the custom scheme `shop.{shopId}.*`, registered as this
  /// client's callback URL in the Partner dashboard and as a URL type in the
  /// native iOS/Android project — see `ios/Runner/Info.plist` and
  /// `android/app/build.gradle`.
  final String redirectUri;

  /// Customer Account API version for [graphQlEndpoint]. Shopify releases the
  /// Customer Account API on the same quarterly calendar as the Storefront
  /// API and with the same version strings, so this reads the one
  /// `SHOPIFY_API_VERSION` define the Storefront config already uses rather
  /// than adding a second knob that can drift.
  final String apiVersion;

  /// Pinned, never `unstable` — see `StorefrontConfig.defaultApiVersion`,
  /// which this deliberately mirrors.
  static const String defaultApiVersion = '2026-07';

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

  /// The Customer Account API GraphQL endpoint — a different host path shape
  /// from the OAuth endpoints above, and unrelated to the Storefront API's
  /// `/api/{version}/graphql.json` on the shop domain.
  ///
  /// Shopify recommends discovering this from
  /// `/.well-known/customer-account-api` instead of composing it; that is
  /// deliberately deferred (see `README.md` § 8) because discovery needs its
  /// own caching and last-known-good handling to not become a new cold-start
  /// failure mode, and the composed URL is stable and documented.
  Uri get graphQlEndpoint => Uri.parse(
        'https://shopify.com/$shopId/account/customer/api/$apiVersion/graphql',
      );

  /// False until a Partner-dashboard registration exists — the honest
  /// default today. Callers must treat login as unavailable rather than
  /// attempting it, the same pattern as `StorefrontConfig.isUsable`.
  bool get isUsable =>
      shopId.isNotEmpty &&
      clientId.isNotEmpty &&
      redirectUri.isNotEmpty &&
      apiVersion.isNotEmpty &&
      shopId != _placeholderShopId;

  /// Mirrors `ExternalCatalogConfig.fromEnvironment()`'s shape
  /// (`lib/app/external_catalog_config.dart`): build-time `--dart-define`
  /// values, empty string standing in for "not set".
  ///
  /// ```
  /// flutter run --dart-define-from-file=config/dart_defines.staging.json
  /// ```
  ///
  /// The redirect URI is *derived* from the shop id rather than independently
  /// configurable — it must match `ios/Runner/Info.plist`'s
  /// `CFBundleURLTypes` and `android/app/build.gradle.kts`'s
  /// `appAuthRedirectScheme` exactly, and deriving it here is one fewer
  /// place that pair can drift out of sync. Both native files now carry the
  /// staging shop id, so a production build needs its own flavor before it
  /// can log in — see `README.md` § 8.
  factory CustomerAccountConfig.fromEnvironment() {
    const shopId = String.fromEnvironment(
      'CUSTOMER_ACCOUNT_SHOP_ID',
      defaultValue: _placeholderShopId,
    );
    const clientId = String.fromEnvironment('CUSTOMER_ACCOUNT_CLIENT_ID');
    const apiVersion = String.fromEnvironment(
      'SHOPIFY_API_VERSION',
      defaultValue: defaultApiVersion,
    );
    return CustomerAccountConfig(
      shopId: shopId,
      clientId: clientId,
      redirectUri: 'shop.$shopId.oauth://callback',
      apiVersion: apiVersion,
    );
  }

  /// Matches the literal placeholder committed in `Info.plist` and
  /// `build.gradle.kts` — lowercase, since AppAuth's Android redirect
  /// matching is case-sensitive (see `flutter_appauth`'s README).
  static const String _placeholderShopId = 'replace_with_shop_id';
}
