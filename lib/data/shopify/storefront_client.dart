/// A minimal GraphQL client for the Storefront API.
///
/// Pure Dart: the actual HTTP call is injected as a [GraphQLTransport], so this
/// whole module is testable with a fake transport and no network, and the app
/// layer supplies the real `package:http` implementation.
library;

import 'dart:convert';

import 'storefront_config.dart';

/// Executes a GraphQL document and returns the decoded JSON body.
///
/// Implementations must NOT interpret the response — error handling lives in
/// [StorefrontClient] so it behaves identically under test and in production.
typedef GraphQLTransport = Future<Map<String, dynamic>> Function(
  Uri endpoint,
  Map<String, String> headers,
  String body,
);

/// Anything that went wrong talking to Shopify.
class StorefrontException implements Exception {
  StorefrontException(this.message, {this.errors, this.isRetryable = false});

  final String message;
  final List<String>? errors;

  /// True for throttling and transient network failures. The caller may retry
  /// with backoff; callers must not retry anything else, because a GraphQL
  /// validation error will fail identically forever.
  final bool isRetryable;

  @override
  String toString() => 'StorefrontException: $message'
      '${errors == null ? '' : ' ${errors!.join('; ')}'}';
}

class StorefrontClient {
  StorefrontClient({
    required this.config,
    required GraphQLTransport transport,
  }) : _transport = transport;

  final StorefrontConfig config;
  final GraphQLTransport _transport;

  /// Run [document] with [variables] and return the `data` object.
  ///
  /// Shopify returns HTTP 200 with a `errors` array for GraphQL-level problems,
  /// so checking the status code alone is not enough — this unwraps both.
  Future<Map<String, dynamic>> query(
    String document, {
    Map<String, dynamic> variables = const {},
  }) async {
    if (!config.isUsable) {
      throw StorefrontException(
        'Storefront config is incomplete — is Remote Config loaded?',
      );
    }

    final body = _encodeBody(document, variables);

    final Map<String, dynamic> response;
    try {
      response = await _transport(config.endpoint, config.headers, body);
    } on StorefrontException {
      rethrow;
    } catch (error) {
      throw StorefrontException(
        'Network failure talking to Shopify: $error',
        isRetryable: true,
      );
    }

    final errors = response['errors'];
    if (errors is List && errors.isNotEmpty) {
      final messages = errors
          .map((e) => e is Map ? '${e['message']}' : '$e')
          .toList(growable: false);

      // Shopify signals rate limiting as a GraphQL error, not a 429.
      final throttled = messages.any(
        (m) => m.toLowerCase().contains('throttled'),
      );

      throw StorefrontException(
        throttled ? 'Throttled by Shopify' : 'Shopify returned errors',
        errors: messages,
        isRetryable: throttled,
      );
    }

    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw StorefrontException('Response contained no data object');
    }
    return data;
  }

  static String _encodeBody(String document, Map<String, dynamic> variables) =>
      jsonEncode(<String, dynamic>{
        'query': document,
        'variables': variables,
      });
}
