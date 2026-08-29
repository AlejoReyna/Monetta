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
import 'customer_auth_error.dart';

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

/// Maximum JSON body accepted from the Customer Account API. An identity
/// response is a few hundred bytes; anything near this is not one.
const int kMaxCustomerApiResponseBytes = 256 * 1024;

class HttpCustomerIdentityService implements CustomerIdentityService {
  HttpCustomerIdentityService({
    required this.config,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final CustomerAccountConfig config;
  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;

  Uri? _graphQlEndpoint;
  Future<Uri>? _discoveryInFlight;

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
    final endpoint = await _resolveGraphQlEndpoint();
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

  /// Discovers and caches Shopify's account API URL from the storefront
  /// domain. The discovered URL can use a branded account domain, and Shopify
  /// explicitly recommends discovery over composing a `shopify.com` path.
  /// Failed attempts are not cached so a temporary offline state can recover
  /// on the next login.
  Future<Uri> _resolveGraphQlEndpoint() {
    final cached = _graphQlEndpoint;
    if (cached != null) return Future.value(cached);

    final inFlight = _discoveryInFlight;
    if (inFlight != null) return inFlight;

    late final Future<Uri> future;
    future = _discoverGraphQlEndpoint().then((endpoint) {
      _graphQlEndpoint = endpoint;
      return endpoint;
    }).whenComplete(() {
      if (identical(_discoveryInFlight, future)) {
        _discoveryInFlight = null;
      }
    });
    _discoveryInFlight = future;
    return future;
  }

  Future<Uri> _discoverGraphQlEndpoint() async {
    final http.Response response;
    try {
      response = await _client.get(
        config.customerApiDiscoveryEndpoint,
        headers: const {'Accept': 'application/json'},
      ).timeout(timeout);
    } on TimeoutException {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.offline,
        debugDetail: 'customer API discovery timed out',
      );
    } catch (error) {
      throw CustomerAuthException(
        CustomerAuthErrorKind.offline,
        debugDetail: 'customer API discovery transport failure: '
            '${error.runtimeType}',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'customer API discovery HTTP ${response.statusCode}',
      );
    }
    if (response.bodyBytes.length > kMaxCustomerApiResponseBytes) {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'customer API discovery response exceeded size limit',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'customer API discovery returned non-JSON',
      );
    }
    final endpointValue =
        decoded is Map<String, dynamic> ? decoded['graphql_api'] : null;
    final endpoint =
        endpointValue is String ? Uri.tryParse(endpointValue) : null;
    if (endpoint == null ||
        endpoint.scheme != 'https' ||
        endpoint.host.isEmpty ||
        endpoint.hasFragment) {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'customer API discovery carried no valid graphql_api',
      );
    }
    return endpoint;
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
