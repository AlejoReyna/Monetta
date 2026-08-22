/// One classified cause per login failure, so the UI can say something true
/// in Spanish without ever rendering a platform exception at the shopper.
///
/// AppAuth's exceptions (and Shopify's OAuth error codes inside them) are the
/// only place this information exists, and they are platform-shaped: an iOS
/// `OIDError` domain and code, an Android `AuthorizationException` type and
/// code, or an RFC 6749 `error` string from Shopify's token endpoint. This
/// file is the single place that reading happens — everything above it works
/// with [CustomerAuthErrorKind].
library;

import 'package:flutter_appauth/flutter_appauth.dart';

enum CustomerAuthErrorKind {
  /// The shopper closed the browser. The overwhelmingly common "failure",
  /// and not one worth an error message — they meant to back out.
  cancelled,

  /// No usable network. Nothing is wrong with the account or the app.
  offline,

  /// The client id / redirect URI / shop id this build was compiled with are
  /// not what Shopify has registered. A shopper can do nothing about this;
  /// it is a build or dashboard mistake.
  configuration,

  /// The refresh token was revoked or expired (Shopify `invalid_grant`), or
  /// the access token was rejected. Recoverable by logging in again.
  sessionExpired,

  /// Shopify answered, but with a failure of its own.
  server,

  unknown,
}

/// Everything above `data/customer_auth` catches this instead of an
/// AppAuth `PlatformException` or an HTTP status code.
class CustomerAuthException implements Exception {
  const CustomerAuthException(this.kind, {this.debugDetail});

  final CustomerAuthErrorKind kind;

  /// For logs and telemetry only — never shown to the shopper. Callers must
  /// keep tokens out of whatever they put here: this string can end up in a
  /// crash report.
  final String? debugDetail;

  @override
  String toString() =>
      'CustomerAuthException(${kind.name}${debugDetail == null ? '' : ': $debugDetail'})';
}

/// Best-effort classification of anything thrown on a login/refresh path.
///
/// Already-classified [CustomerAuthException]s pass through unchanged, so
/// this is safe to call at any depth.
CustomerAuthErrorKind classifyCustomerAuthError(Object error) {
  if (error is CustomerAuthException) return error.kind;
  if (error is FlutterAppAuthUserCancelledException) {
    return CustomerAuthErrorKind.cancelled;
  }
  if (error is FlutterAppAuthPlatformException) {
    return _kindFromPlatformDetails(error.platformErrorDetails);
  }
  return CustomerAuthErrorKind.unknown;
}

CustomerAuthErrorKind _kindFromPlatformDetails(
  FlutterAppAuthPlatformErrorDetails details,
) {
  switch (details.error) {
    case FlutterAppAuthOAuthError.invalidGrant:
      return CustomerAuthErrorKind.sessionExpired;
    case FlutterAppAuthOAuthError.invalidClient:
    case FlutterAppAuthOAuthError.unauthorizedClient:
    case FlutterAppAuthOAuthError.invalidScope:
    case FlutterAppAuthOAuthError.invalidRequest:
      // All four mean the same thing for a public mobile client: what this
      // binary was built with does not match the Mobile client registered in
      // the Shopify dashboard (client id, redirect URI, or scopes).
      return CustomerAuthErrorKind.configuration;
  }

  // Neither platform's AppAuth SDK exposes a stable "this was the network"
  // constant through `flutter_appauth` — iOS reports an `OIDError` domain
  // plus code, Android an `AuthorizationException` type plus code, and both
  // carry the word in their human-readable text. Matching on that text is
  // deliberately a heuristic: guessing `offline` wrong only costs a slightly
  // less specific Spanish sentence, so it is not worth pinning per-platform
  // numeric codes that change between SDK releases.
  final haystack = [
    details.errorDescription,
    details.errorDebugDescription,
    details.rootCauseDebugDescription,
  ].whereType<String>().join(' ').toLowerCase();
  if (haystack.contains('network') ||
      haystack.contains('offline') ||
      haystack.contains('internet') ||
      haystack.contains('unreachable') ||
      haystack.contains('timed out') ||
      haystack.contains('timeout')) {
    return CustomerAuthErrorKind.offline;
  }
  if (haystack.contains('server')) return CustomerAuthErrorKind.server;
  return CustomerAuthErrorKind.unknown;
}
