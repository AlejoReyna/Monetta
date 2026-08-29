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

/// Paired transport capability for carts.
///
/// Callers cannot provide an arbitrary mutation callback to [StorefrontClient];
/// production receives this capability from `HttpStorefrontTransport`, whose
/// mutation path is permanently single-attempt.
abstract interface class CartStorefrontTransport {
  Future<Map<String, dynamic>> query(
    Uri endpoint,
    Map<String, String> headers,
    String body,
  );

  Future<Map<String, dynamic>> mutate(
    Uri endpoint,
    Map<String, String> headers,
    String body,
  );
}

/// Anything that went wrong talking to Shopify.
class StorefrontException implements Exception {
  const StorefrontException(
    this.message, {
    this.isRetryable = false,
    this.isAmbiguous = false,
  });

  final String message;

  /// True for throttling and transient network failures. The caller may retry
  /// with backoff; callers must not retry anything else, because a GraphQL
  /// validation error will fail identically forever.
  final bool isRetryable;

  /// The server may have accepted a mutation although no response was seen.
  final bool isAmbiguous;

  @override
  String toString() => 'StorefrontException: $message';
}

class StorefrontClient {
  StorefrontClient({
    required this.config,
    required GraphQLTransport transport,
  })  : _transport = transport,
        _mutationTransport = null;

  StorefrontClient.forCart({
    required this.config,
    required CartStorefrontTransport transport,
  })  : _transport = transport.query,
        _mutationTransport = transport.mutate;

  final StorefrontConfig config;
  final GraphQLTransport _transport;
  final GraphQLTransport? _mutationTransport;

  /// Run [document] with [variables] and return the `data` object.
  ///
  /// Shopify returns HTTP 200 with a `errors` array for GraphQL-level problems,
  /// so checking the status code alone is not enough — this unwraps both.
  Future<Map<String, dynamic>> query(
    String document, {
    Map<String, dynamic> variables = const {},
  }) =>
      _execute(_transport, document, variables, isMutation: false);

  /// Executes a mutation through a transport that must not retry blindly.
  Future<Map<String, dynamic>> mutate(
    String document, {
    Map<String, dynamic> variables = const {},
  }) {
    final transport = _mutationTransport;
    if (transport == null) {
      throw const StorefrontException(
        'Mutation transport is not configured',
      );
    }
    return _execute(transport, document, variables, isMutation: true);
  }

  Future<Map<String, dynamic>> _execute(
    GraphQLTransport transport,
    String document,
    Map<String, dynamic> variables, {
    required bool isMutation,
  }) async {
    if (!config.isUsable) {
      throw StorefrontException(
        'Storefront config is incomplete — is Remote Config loaded?',
      );
    }

    final body = _encodeBody(document, variables);

    final Map<String, dynamic> response;
    try {
      response = await transport(config.endpoint, config.headers, body);
    } on StorefrontException {
      rethrow;
    } catch (_) {
      throw StorefrontException(
        'Network failure talking to Shopify',
        isRetryable: !isMutation,
        isAmbiguous: isMutation,
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
