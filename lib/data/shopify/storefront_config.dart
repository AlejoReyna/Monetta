/// Connection settings for the Shopify Storefront API.
///
/// Pure Dart. Values arrive from `--dart-define` / `--dart-define-from-file`
/// at build time (see `config/dart_defines.*.json.example`). Firebase Remote
/// Config can later overlay the public token for rotation; a failed Remote
/// Config fetch must retain last-known-good values and never blank a working
/// config.
///
/// Only **public** Storefront values belong here. Never put a private
/// Storefront token, Admin API token, or app client secret in the app binary.
library;

class StorefrontConfig {
  const StorefrontConfig({
    required this.shopDomain,
    required this.accessToken,
    this.apiVersion = defaultApiVersion,
    this.country = defaultCountry,
    this.language = defaultLanguage,
  });

  /// Public shop host used for Storefront GraphQL and checkout URLs.
  /// Prefer the branded domain (e.g. `monetta.mx`) when it is the primary
  /// checkout host; `*.myshopify.com` is always valid.
  final String shopDomain;

  /// Storefront API **public** access token from the Headless channel.
  final String accessToken;

  final String apiVersion;

  /// ISO 3166-1 alpha-2 market for contextual pricing/availability.
  /// Mexico is the only market Monetta ships to today.
  final String country;

  /// BCP 47 language tag for Storefront content (Spanish for Mexico).
  final String language;

  /// Pinned explicitly. Shopify sunsets a version roughly 12 months after
  /// release — never use `unstable` in a release build.
  static const String defaultApiVersion = '2026-07';

  static const String defaultCountry = 'MX';
  static const String defaultLanguage = 'ES';

  Uri get endpoint => Uri.https(shopDomain, '/api/$apiVersion/graphql.json');

  Map<String, String> get headers => <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Shopify-Storefront-Access-Token': accessToken,
        'Accept-Language': 'es-MX',
      };

  /// True only when domain + token are non-empty and the domain looks like a
  /// host (no scheme, no path). Incomplete config fails closed: callers must
  /// treat Storefront as unavailable rather than sending a half-formed request.
  bool get isUsable =>
      shopDomain.isNotEmpty &&
      accessToken.isNotEmpty &&
      apiVersion.isNotEmpty &&
      _looksLikeHost(shopDomain);

  /// Build-time public values only:
  ///
  /// ```
  /// flutter run --dart-define-from-file=config/dart_defines.staging.json
  /// ```
  ///
  /// Empty strings mean "not configured" — the same pattern as
  /// `CustomerAccountConfig`.
  factory StorefrontConfig.fromEnvironment() {
    const shopDomain = String.fromEnvironment('SHOPIFY_STORE_DOMAIN');
    const accessToken =
        String.fromEnvironment('SHOPIFY_STOREFRONT_ACCESS_TOKEN');
    const apiVersion = String.fromEnvironment(
      'SHOPIFY_API_VERSION',
      defaultValue: defaultApiVersion,
    );
    const country = String.fromEnvironment(
      'SHOPIFY_COUNTRY',
      defaultValue: defaultCountry,
    );
    const language = String.fromEnvironment(
      'SHOPIFY_LANGUAGE',
      defaultValue: defaultLanguage,
    );
    return StorefrontConfig(
      shopDomain: shopDomain.trim(),
      accessToken: accessToken.trim(),
      apiVersion:
          apiVersion.trim().isEmpty ? defaultApiVersion : apiVersion.trim(),
      country: country.trim().isEmpty
          ? defaultCountry
          : country.trim().toUpperCase(),
      language: language.trim().isEmpty
          ? defaultLanguage
          : language.trim().toUpperCase(),
    );
  }

  /// Redacted description safe for logs and crash reports. Never includes the
  /// access token.
  @override
  String toString() =>
      'StorefrontConfig(shopDomain: $shopDomain, apiVersion: $apiVersion, '
      'country: $country, language: $language, token: ${_redact(accessToken)})';

  StorefrontConfig copyWith({
    String? shopDomain,
    String? accessToken,
    String? apiVersion,
    String? country,
    String? language,
  }) =>
      StorefrontConfig(
        shopDomain: shopDomain ?? this.shopDomain,
        accessToken: accessToken ?? this.accessToken,
        apiVersion: apiVersion ?? this.apiVersion,
        country: country ?? this.country,
        language: language ?? this.language,
      );

  static bool _looksLikeHost(String value) {
    if (value.contains('://') || value.contains('/') || value.contains(' ')) {
      return false;
    }
    return value.contains('.');
  }

  static String _redact(String token) {
    if (token.isEmpty) return '(empty)';
    if (token.length <= 8) return '***';
    return '${token.substring(0, 4)}…${token.substring(token.length - 2)}';
  }
}
