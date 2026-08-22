import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/customer_auth/customer_auth_error.dart';

FlutterAppAuthPlatformException _platformException({
  String? error,
  String? errorDescription,
}) {
  return FlutterAppAuthPlatformException(
    code: 'authorize_and_exchange_code_failed',
    platformErrorDetails: FlutterAppAuthPlatformErrorDetails(
      error: error,
      errorDescription: errorDescription,
    ),
  );
}

void main() {
  group('classifyCustomerAuthError', () {
    test('a closed browser is a cancellation, not a failure', () {
      final error = FlutterAppAuthUserCancelledException(
        code: 'authorize_and_exchange_code_failed',
        platformErrorDetails: FlutterAppAuthPlatformErrorDetails(),
      );
      expect(
        classifyCustomerAuthError(error),
        CustomerAuthErrorKind.cancelled,
      );
    });

    test('invalid_grant is a revoked or expired session', () {
      expect(
        classifyCustomerAuthError(
          _platformException(error: FlutterAppAuthOAuthError.invalidGrant),
        ),
        CustomerAuthErrorKind.sessionExpired,
      );
    });

    test('client-side OAuth errors mean this build is misconfigured', () {
      for (final oauthError in [
        FlutterAppAuthOAuthError.invalidClient,
        FlutterAppAuthOAuthError.unauthorizedClient,
        FlutterAppAuthOAuthError.invalidScope,
        FlutterAppAuthOAuthError.invalidRequest,
      ]) {
        expect(
          classifyCustomerAuthError(_platformException(error: oauthError)),
          CustomerAuthErrorKind.configuration,
          reason: oauthError,
        );
      }
    });

    test('a network failure is offline', () {
      expect(
        classifyCustomerAuthError(
          _platformException(errorDescription: 'Network error'),
        ),
        CustomerAuthErrorKind.offline,
      );
    });

    test('an already-classified exception passes through unchanged', () {
      expect(
        classifyCustomerAuthError(
          const CustomerAuthException(CustomerAuthErrorKind.offline),
        ),
        CustomerAuthErrorKind.offline,
      );
    });

    test('anything unrecognised is unknown, never a throw', () {
      expect(
        classifyCustomerAuthError(StateError('something else entirely')),
        CustomerAuthErrorKind.unknown,
      );
      expect(
        classifyCustomerAuthError(_platformException()),
        CustomerAuthErrorKind.unknown,
      );
    });
  });
}
