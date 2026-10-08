/// Who the shopper actually is, according to Shopify rather than according to
/// a token this app decoded itself.
///
/// The id token's claims (`jwt.dart`) are read without verifying its
/// signature — defensible for what they are used for there (README § 3), but
/// not something to hang a stored account identity on. One authenticated
/// `customer { id }` call is the cheapest way to make the identity Monetta
/// persists come from an API answer instead of a decode, so that is what
/// `CustomerSessionRepository.login` does with the fresh access token before
/// it writes an `Accounts` row.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'customer_account_config.dart';
import 'customer_api_discovery.dart';
import 'customer_auth_error.dart';

export 'customer_api_discovery.dart' show kMaxCustomerApiResponseBytes;

class CustomerIdentity {
  const CustomerIdentity({
    required this.shopifyCustomerId,
    this.email,
    this.displayName,
  });

  /// A globally-unique `gid://shopify/Customer/...` id, straight from the API.
  final String shopifyCustomerId;

  final String? email;
  final String? displayName;
}

/// Injected into [CustomerSessionRepository] the same way
/// `CustomerAuthGateway` is, so login stays testable without a socket.
abstract class CustomerIdentityService {
  /// Throws [CustomerAuthException] — never an HTTP or socket error.
  Future<CustomerIdentity> fetch(String accessToken);
}

class HttpCustomerIdentityService implements CustomerIdentityService {
  HttpCustomerIdentityService({
    required this.config,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
    CustomerApiDiscoveryService? discovery,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null {
    // Without an injected discovery, build one over this service's client and
    // timeout; it does not own the client, so [close] stays the only closer.
    _discovery = discovery ??
        CustomerApiDiscoveryService(
          config: config,
          client: _client,
          timeout: timeout,
        );
  }

  final CustomerAccountConfig config;
  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;
  late final CustomerApiDiscoveryService _discovery;

  /// Only what identity needs. Profile, addresses and orders are Phase 5
  /// (`docs/SHOPIFY_PRODUCTION_IMPLEMENTATION_PLAN.md`) and deliberately not
  /// requested here: this call sits on the login path, so every extra field
  /// is latency between the browser closing and the account appearing.
  static const String identityQuery = '''
query MonettaCustomerIdentity {
  customer {
    id
    displayName
    emailAddress {
      emailAddress
    }
  }
}''';

  @override
  Future<CustomerIdentity> fetch(String accessToken) async {
    final endpoint = await _discovery.graphQlEndpoint();
    final http.Response response;
    try {
      response = await _client
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              // Raw, with no `Bearer ` prefix: the Customer Account API is
              // specified that way, and prefixing it fails as a flat 401.
              'Authorization': accessToken,
            },
            body: jsonEncode({'query': identityQuery}),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.offline,
        debugDetail: 'customer identity request timed out',
      );
    } catch (error) {
      // Anything that prevents a response at all — DNS, no route, TLS,
      // captive portal. Deliberately not matched on `SocketException`, which
      // would drag `dart:io` into a file that has no other reason to need it.
      throw CustomerAuthException(
        CustomerAuthErrorKind.offline,
        debugDetail:
            'customer identity transport failure: ${error.runtimeType}',
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.sessionExpired,
        debugDetail: 'customer identity rejected the access token',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'customer identity HTTP ${response.statusCode}',
      );
    }
    if (response.bodyBytes.length > kMaxCustomerApiResponseBytes) {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'customer identity response exceeded size limit',
      );
    }

    return parseIdentity(response.bodyBytes);
  }

  /// Separated from the HTTP call so the parsing rules are testable on their
  /// own, the same split `StorefrontClient` makes between transport and
  /// response handling.
  static CustomerIdentity parseIdentity(List<int> bodyBytes) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bodyBytes));
    } catch (_) {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'customer identity returned a non-JSON body',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'customer identity JSON root was not an object',
      );
    }

    // Shopify answers GraphQL-level problems with HTTP 200 and an `errors`
    // array, so the status code alone proves nothing — the same trap
    // `StorefrontClient.query` documents. An `UNAUTHENTICATED`/`ACCESS_DENIED`
    // extension code here means the token, not the shop, is the problem.
    final errors = decoded['errors'];
    if (errors is List && errors.isNotEmpty) {
      final text = errors.join(' ').toUpperCase();
      final unauthenticated = text.contains('UNAUTHENTICATED') ||
          text.contains('ACCESS_DENIED') ||
          text.contains('UNAUTHORIZED');
      throw CustomerAuthException(
        unauthenticated
            ? CustomerAuthErrorKind.sessionExpired
            : CustomerAuthErrorKind.server,
        debugDetail: 'customer identity returned ${errors.length} GraphQL '
            'error(s)',
      );
    }

    final data = decoded['data'];
    final customer = data is Map<String, dynamic> ? data['customer'] : null;
    if (customer is! Map<String, dynamic>) {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'customer identity response carried no customer object',
      );
    }
    final id = customer['id'];
    if (id is! String || id.isEmpty) {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'customer identity response carried no customer id',
      );
    }

    final emailAddress = customer['emailAddress'];
    final displayName = customer['displayName'];
    return CustomerIdentity(
      shopifyCustomerId: id,
      email: emailAddress is Map<String, dynamic>
          ? emailAddress['emailAddress'] as String?
          : null,
      displayName: displayName is String && displayName.trim().isNotEmpty
          ? displayName.trim()
          : null,
    );
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
