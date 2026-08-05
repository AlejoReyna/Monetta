/// Connection settings for the Shopify Storefront API.
///
/// Pure Dart. The values arrive from Firebase Remote Config at runtime so both
/// the API version and the access token can be changed without shipping a
/// build — see `lib/data/shopify/README.md` § 3.
library;

class StorefrontConfig {
  const StorefrontConfig({
    required this.shopDomain,
    required this.accessToken,
    this.apiVersion = defaultApiVersion,
  });

  /// The store's public domain. Using `monetta.mx` rather than
  /// `fakcei-n9.myshopify.com` keeps requests on the branded domain, which
  /// matters for the `checkoutUrl` the customer eventually sees.
  final String shopDomain;

  /// Storefront API public access token.
  ///
  /// Storefront tokens are designed to be embedded in clients — they expose a
  /// deliberately limited, read-mostly surface. It is still delivered via Remote
  /// Config rather than compiled in, so it can be rotated in minutes if it is
  /// ever abused.
  final String accessToken;

  final String apiVersion;

  /// Pinned explicitly. Shopify sunsets a version roughly 12 months after
  /// release, so this is scheduled maintenance twice a year — never use
  /// `unstable`.
  static const String defaultApiVersion = '2026-07';

  Uri get endpoint => Uri.https(shopDomain, '/api/$apiVersion/graphql.json');

  Map<String, String> get headers => <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Shopify-Storefront-Access-Token': accessToken,
        // Locale is fixed for Phase 1; the store ships only to Mexico.
        'Accept-Language': 'es-MX',
      };

  bool get isUsable => shopDomain.isNotEmpty && accessToken.isNotEmpty;

  StorefrontConfig copyWith({
    String? shopDomain,
    String? accessToken,
    String? apiVersion,
  }) =>
      StorefrontConfig(
        shopDomain: shopDomain ?? this.shopDomain,
        accessToken: accessToken ?? this.accessToken,
        apiVersion: apiVersion ?? this.apiVersion,
      );
}
