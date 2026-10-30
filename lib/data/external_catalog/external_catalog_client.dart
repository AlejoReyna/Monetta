/// Injected client for `GET /v1/external-catalog`. See
/// `services/catalog_monitor/README.md` for the server side.
///
/// The transport (`http.Client`) is injected the same way
/// `data/shopify/storefront_client.dart` injects its `GraphQLTransport` —
/// so the repository and its ETag/outage behaviour can be tested with a
/// fake, with no real network. See `test/external_catalog/`.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'external_catalog_models.dart';

class ExternalCatalogException implements Exception {
  ExternalCatalogException(this.message);
  final String message;

  @override
  String toString() => 'ExternalCatalogException: $message';
}

/// Either "nothing changed since the ETag you sent" or a fresh snapshot.
class ExternalCatalogFetchResult {
  const ExternalCatalogFetchResult.notModified()
      : modified = false,
        response = null,
        etag = null;

  const ExternalCatalogFetchResult.modified({
    required ExternalCatalogResponse this.response,
    required this.etag,
  }) : modified = true;

  final bool modified;
  final ExternalCatalogResponse? response;
  final String? etag;
}

abstract class ExternalCatalogClient {
  Future<ExternalCatalogFetchResult> fetch({String? etag});
}

class HttpExternalCatalogClient implements ExternalCatalogClient {
  HttpExternalCatalogClient({required this.baseUrl, http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  @override
  Future<ExternalCatalogFetchResult> fetch({String? etag}) async {
    final uri = Uri.parse('$baseUrl/v1/external-catalog');
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Accept-Encoding': 'gzip',
        if (etag != null) 'If-None-Match': etag,
      },
    );

    if (response.statusCode == 304) {
      return const ExternalCatalogFetchResult.notModified();
    }
    if (response.statusCode != 200) {
      throw ExternalCatalogException(
        'GET /v1/external-catalog returned ${response.statusCode}',
      );
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw ExternalCatalogException('Malformed response body: $e');
    }

    return ExternalCatalogFetchResult.modified(
      response: ExternalCatalogResponse.fromJson(json),
      etag: response.headers['etag'],
    );
  }
}
