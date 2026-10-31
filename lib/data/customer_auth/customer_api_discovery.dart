/// Discovery of the Customer Account GraphQL endpoint, shared by the identity
/// and order services so a session performs the discovery request once.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'customer_account_config.dart';
import 'customer_auth_error.dart';

/// Maximum JSON body accepted from the Customer Account API. An identity
/// response is a few hundred bytes; anything near this is not one.
const int kMaxCustomerApiResponseBytes = 256 * 1024;

/// Discovers the Customer Account GraphQL endpoint for the configured shop.
class CustomerApiDiscoveryService {
  CustomerApiDiscoveryService({
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

  /// Discovers and caches Shopify's account API URL from the storefront
  /// domain. The discovered URL can use a branded account domain, and Shopify
  /// explicitly recommends discovery over composing a `shopify.com` path.
  /// Failed attempts are not cached so a temporary offline state can recover
  /// on the next call. Concurrent callers share one request.
  ///
  /// Throws only [CustomerAuthException].
  Future<Uri> graphQlEndpoint() {
    final cached = _graphQlEndpoint;
    if (cached != null) return Future.value(cached);

    final inFlight = _discoveryInFlight;
    if (inFlight != null) return inFlight;

    late final Future<Uri> future;
    future = _discover().then((endpoint) {
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

  Future<Uri> _discover() async {
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

  /// Closes the client only when this service created it.
  void close() {
    if (_ownsClient) _client.close();
  }
}
