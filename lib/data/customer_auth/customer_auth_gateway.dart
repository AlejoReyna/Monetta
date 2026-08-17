/// The OAuth 2.0 + PKCE exchange with Shopify's Customer Account API.
///
/// [CustomerAuthGateway] is injected, the same shape as
/// `data/shopify/storefront_client.dart`'s `GraphQLTransport` — it keeps
/// `CustomerSessionRepository` testable with a fake and no platform channel.
/// The real implementation, [AppAuthCustomerGateway], hands the entire
/// browser hand-off and PKCE code_verifier/code_challenge generation to
/// AppAuth's native iOS/Android SDKs (via `package:flutter_appauth`) rather
/// than hand-rolling either — see `lib/data/customer_auth/README.md` for why
/// that line is not worth crossing for auth code.
library;

import 'package:flutter_appauth/flutter_appauth.dart';

import 'customer_account_config.dart';
import 'customer_auth_error.dart';

/// The subset of a token response this app actually persists. `idToken` is
/// kept only long enough to read claims from it
/// (`jwt.dart#decodeIdTokenClaims`) — never stored.
class CustomerAuthResult {
  const CustomerAuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.idToken,
    required this.accessTokenExpiresAt,
  });

  final String accessToken;

  /// Null is possible in principle (a provider that doesn't issue one), but
  /// unusable in practice: without it, this app cannot silently refresh and
  /// the shopper is signed out the moment the access token expires.
  final String? refreshToken;

  final String? idToken;
  final DateTime? accessTokenExpiresAt;
}

abstract class CustomerAuthGateway {
  /// Opens Shopify's hosted login page and exchanges the resulting code for
  /// tokens. Throws on cancellation or failure — there is no "partial"
  /// result to represent. Implementations throw [CustomerAuthException] so no
  /// caller above this layer has to know what AppAuth or Shopify called the
  /// problem.
  Future<CustomerAuthResult> login();

  Future<CustomerAuthResult> refresh(String refreshToken);
}

class AppAuthCustomerGateway implements CustomerAuthGateway {
  AppAuthCustomerGateway({required this.config, FlutterAppAuth? appAuth})
      : _appAuth = appAuth ?? const FlutterAppAuth();

  final CustomerAccountConfig config;
  final FlutterAppAuth _appAuth;

  AuthorizationServiceConfiguration get _serviceConfiguration =>
      AuthorizationServiceConfiguration(
        authorizationEndpoint: config.authorizationEndpoint,
        tokenEndpoint: config.tokenEndpoint,
      );

  @override
  Future<CustomerAuthResult> login() async {
    if (!config.isUsable) {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.configuration,
        debugDetail: 'CustomerAccountConfig is not usable',
      );
    }
    final TokenResponse response;
    try {
      response = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          config.clientId,
          config.redirectUri,
          serviceConfiguration: _serviceConfiguration,
          scopes: CustomerAccountConfig.scopes,
        ),
      );
    } catch (error) {
      throw _classified(error);
    }
    return _fromResponse(response);
  }

  @override
  Future<CustomerAuthResult> refresh(String refreshToken) async {
    final TokenResponse response;
    try {
      response = await _appAuth.token(
        TokenRequest(
          config.clientId,
          config.redirectUri,
          serviceConfiguration: _serviceConfiguration,
          refreshToken: refreshToken,
          grantType: 'refresh_token',
        ),
      );
    } catch (error) {
      throw _classified(error);
    }
    return _fromResponse(response, fallbackRefreshToken: refreshToken);
  }

  /// Deliberately drops the original exception rather than chaining it: an
  /// AppAuth `PlatformException`'s `message`/`details` can carry the
  /// authorization request's own parameters, and this object ends up in
  /// `AccountController.lastError` and from there potentially in a crash
  /// report. [classifyCustomerAuthError] has already read everything from it
  /// that anyone above needs.
  CustomerAuthException _classified(Object error) => CustomerAuthException(
        classifyCustomerAuthError(error),
        debugDetail: 'appauth ${error.runtimeType}',
      );

  CustomerAuthResult _fromResponse(
    TokenResponse response, {
    String? fallbackRefreshToken,
  }) {
    final accessToken = response.accessToken;
    if (accessToken == null) {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'token response carried no access token',
      );
    }
    return CustomerAuthResult(
      accessToken: accessToken,
      // A refresh grant does not always return a new refresh token; when it
      // doesn't, the existing one remains valid and must be kept.
      refreshToken: response.refreshToken ?? fallbackRefreshToken,
      idToken: response.idToken,
      accessTokenExpiresAt: response.accessTokenExpirationDateTime,
    );
  }
}
