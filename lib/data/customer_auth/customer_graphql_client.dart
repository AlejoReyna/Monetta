/// Customer Account data transport. Endpoint discovery is public; private data
/// and bearer tokens are never cached. Mutations are sent once only.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'customer_account_config.dart';
import 'customer_auth_error.dart';
import 'customer_identity.dart' show kMaxCustomerApiResponseBytes;

class CustomerDataException implements Exception {
  const CustomerDataException(
    this.code, {
    this.mutationMayHaveSucceeded = false,
  });
  final String code;
  final bool mutationMayHaveSucceeded;
  @override
  String toString() => 'CustomerDataException($code)';
}

class CustomerGraphqlClient {
  CustomerGraphqlClient({
    required this.config,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final CustomerAccountConfig config;
  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;
  Uri? _endpoint;

  Future<Map<String, dynamic>> execute(
    String accessToken,
    String document, {
    Map<String, Object?> variables = const {},
    bool mutation = false,
  }) async {
    if (!config.isUsable) {
      throw const CustomerAuthException(CustomerAuthErrorKind.configuration);
    }
    if (accessToken.trim().isEmpty) {
      throw const CustomerAuthException(CustomerAuthErrorKind.sessionExpired);
    }
    final endpoint = await _discover();
    final http.Response response;
    try {
      response = await _client
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': accessToken,
            },
            body: jsonEncode({'query': document, 'variables': variables}),
          )
          .timeout(timeout);
    } catch (_) {
      // Never include provider response bodies, tokens or customer PII.
      throw CustomerDataException(
        'transport_failed',
        mutationMayHaveSucceeded: mutation,
      );
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const CustomerAuthException(CustomerAuthErrorKind.sessionExpired);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CustomerDataException(
        'provider_failed',
        mutationMayHaveSucceeded: mutation,
      );
    }
    final Map<String, dynamic> body;
    try {
      body = _object(response);
    } on CustomerDataException catch (error) {
      throw CustomerDataException(
        error.code,
        mutationMayHaveSucceeded: mutation,
      );
    }
    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) {
      // Inspect machine codes, never return potentially sensitive messages.
      final codes = errors.whereType<Map<dynamic, dynamic>>().map((e) {
        final extensions = e['extensions'];
        return extensions is Map ? extensions['code'] : null;
      });
      if (codes.any((c) => c == 'UNAUTHENTICATED' || c == 'ACCESS_DENIED')) {
        throw const CustomerAuthException(CustomerAuthErrorKind.sessionExpired);
      }
      throw CustomerDataException(
        'graphql_failed',
        mutationMayHaveSucceeded: mutation,
      );
    }
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw CustomerDataException(
        'malformed_response',
        mutationMayHaveSucceeded: mutation,
      );
    }
    return data;
  }

  Future<Uri> _discover() async {
    if (_endpoint != null) return _endpoint!;
    final http.Response response;
    try {
      response = await _client.get(
        config.customerApiDiscoveryEndpoint,
        headers: const {'Accept': 'application/json'},
      ).timeout(timeout);
    } catch (_) {
      throw const CustomerDataException('discovery_failed');
    }
    if (response.statusCode != 200) {
      throw const CustomerDataException('discovery_failed');
    }
    final raw = _object(response)['graphql_api'];
    final uri = raw is String ? Uri.tryParse(raw) : null;
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw const CustomerDataException('invalid_discovery');
    }
    return _endpoint = uri;
  }

  static Map<String, dynamic> _object(http.Response response) {
    if (response.bodyBytes.length > kMaxCustomerApiResponseBytes) {
      throw const CustomerDataException('response_too_large');
    }
    try {
      final value = jsonDecode(utf8.decode(response.bodyBytes));
      if (value is Map<String, dynamic>) return value;
    } catch (_) {/* classified below */}
    throw const CustomerDataException('malformed_response');
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}

/// Session-local read cache, explicitly invalidated on sign-out/account change.
/// The application owner must call bindAccount even when changing A -> B -> A;
/// responses started in the previous session cannot repopulate it.
class AccountReadScope<T> {
  String? _accountId;
  int _generation = 0;
  int _requestId = 0;
  T? _value;
  T? get value => _value;
  void bindAccount(String? accountId) {
    if (_accountId == accountId) return;
    _accountId = accountId;
    _generation++;
    _value = null;
  }

  void clear() {
    _generation++;
    _value = null;
  }

  Future<T> read(Future<T> Function() fetch) async {
    if (_accountId == null) {
      throw const CustomerDataException('unauthenticated');
    }
    final generation = _generation;
    final requestId = ++_requestId;
    final result = await fetch();
    if (generation != _generation || requestId != _requestId) {
      throw const CustomerDataException('stale_session');
    }
    _value = result;
    return result;
  }
}

/// Distinguishes an unpublished capability from a failed provider read.
enum CapabilityReadStatus { supported, unavailable, failed }

class CapabilityRead<T> {
  const CapabilityRead.supported(T this.value)
      : status = CapabilityReadStatus.supported,
        reason = null;
  const CapabilityRead.unavailable(this.reason)
      : status = CapabilityReadStatus.unavailable,
        value = null;
  const CapabilityRead.failed(this.reason)
      : status = CapabilityReadStatus.failed,
        value = null;
  final CapabilityReadStatus status;
  final T? value;
  final String? reason;
}
