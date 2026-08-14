/// Reads claims out of an id token's payload segment.
///
/// Deliberately does **not** verify the signature. That is a conscious
/// choice, not an oversight: this app receives the id token directly from
/// Shopify's token endpoint over TLS (via `AppAuthCustomerGateway`), the
/// same trust boundary an authorization-code exchange always relies on —
/// there is no untrusted third party in a position to hand this app a
/// forged token. Signature verification matters when a token arrives from
/// somewhere that *isn't* already trusted (e.g. a resource server accepting
/// bearer tokens from arbitrary callers); reimplementing JWS verification
/// here would add real cryptographic surface for no corresponding gain.
library;

import 'dart:convert';

/// Decodes an id token's payload (the middle `.`-separated segment) into its
/// claims. Throws [FormatException] if [idToken] isn't a three-segment JWT.
Map<String, dynamic> decodeIdTokenClaims(String idToken) {
  final segments = idToken.split('.');
  if (segments.length != 3) {
    throw const FormatException('Not a JWT: expected three "."-separated segments');
  }
  final normalized = base64Url.normalize(segments[1]);
  final payload = utf8.decode(base64Url.decode(normalized));
  return jsonDecode(payload) as Map<String, dynamic>;
}
