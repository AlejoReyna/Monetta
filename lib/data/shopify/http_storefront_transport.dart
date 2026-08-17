/// Production `package:http` transport for [StorefrontClient].
///
/// Owns timeout, status validation, response-size guard, and bounded retry
/// with exponential backoff + jitter for transient failures. Never logs
/// request headers, tokens, cart IDs, or checkout URLs.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'storefront_client.dart';

/// Maximum JSON body accepted from Shopify (defensive; a healthy product
/// page is far smaller). Oversized responses fail closed.
const int kMaxStorefrontResponseBytes = 8 * 1024 * 1024;

class HttpStorefrontTransport {
  HttpStorefrontTransport({
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
    this.maxAttempts = 3,
    this.baseBackoff = const Duration(milliseconds: 250),
    Random? random,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _random = random ?? Random();

  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;
  final int maxAttempts;
  final Duration baseBackoff;
  final Random _random;

  /// Matches [GraphQLTransport].
  Future<Map<String, dynamic>> send(
    Uri endpoint,
    Map<String, String> headers,
    String body,
  ) async {
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await _attempt(endpoint, headers, body);
      } on StorefrontException catch (error) {
        lastError = error;
        if (!error.isRetryable || attempt == maxAttempts) rethrow;
        await Future<void>.delayed(_backoffFor(attempt));
      } catch (error) {
        lastError = error;
        if (attempt == maxAttempts) {
          throw StorefrontException(
            'Network failure talking to Shopify',
            isRetryable: true,
          );
        }
        await Future<void>.delayed(_backoffFor(attempt));
      }
    }
    throw StorefrontException(
      'Network failure talking to Shopify: $lastError',
      isRetryable: true,
    );
  }

  Future<Map<String, dynamic>> _attempt(
    Uri endpoint,
    Map<String, String> headers,
    String body,
  ) async {
    final http.Response response;
    try {
      response = await _client
          .post(endpoint, headers: headers, body: body)
          .timeout(timeout);
    } on TimeoutException {
      throw StorefrontException(
        'Storefront request timed out',
        isRetryable: true,
      );
    }

    if (response.statusCode == 429 || response.statusCode >= 500) {
      throw StorefrontException(
        'Storefront HTTP ${response.statusCode}',
        isRetryable: true,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StorefrontException(
        'Storefront HTTP ${response.statusCode}',
      );
    }

    final bytes = response.bodyBytes;
    if (bytes.length > kMaxStorefrontResponseBytes) {
      throw StorefrontException(
        'Storefront response exceeded size limit',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw StorefrontException('Storefront returned non-JSON body');
    }

    if (decoded is! Map<String, dynamic>) {
      throw StorefrontException('Storefront JSON root was not an object');
    }
    return decoded;
  }

  Duration _backoffFor(int attempt) {
    final exp = baseBackoff * (1 << (attempt - 1));
    final jitterMs = _random.nextInt(100);
    return exp + Duration(milliseconds: jitterMs);
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
