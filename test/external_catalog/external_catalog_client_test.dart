import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monetta_app/data/external_catalog/external_catalog_client.dart';

final _sampleBody = jsonEncode({
  'schemaVersion': 1,
  'generatedAt': '2026-08-10T09:00:00.000Z',
  'sources': <Map<String, dynamic>>[],
  'items': <Map<String, dynamic>>[
    {
      'sourceScopedId': 'coach_us:C1',
      'source': 'coach_us',
      'merchant': 'Coach',
      'title': 'Bag',
      'brand': 'Coach',
      'category': null,
      'imageUrl': null,
      'price': {'amount': 100.0, 'currency': 'USD'},
      'availability': 'inStock',
      'detailUrl': 'https://www.coach.com/x/C1.html',
      'lastObservedAt': '2026-08-10T08:00:00.000Z',
    },
  ],
});

void main() {
  group('HttpExternalCatalogClient', () {
    test('parses a 200 response and surfaces the ETag header', () async {
      final client = HttpExternalCatalogClient(
        baseUrl: 'https://catalog.internal',
        httpClient: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://catalog.internal/v1/external-catalog',
          );
          return http.Response(_sampleBody, 200, headers: {'etag': '"abc123"'});
        }),
      );

      final result = await client.fetch();
      expect(result.modified, isTrue);
      expect(result.etag, '"abc123"');
      expect(result.response!.items, hasLength(1));
    });

    test('sends If-None-Match when an ETag is supplied', () async {
      String? sentIfNoneMatch;
      final client = HttpExternalCatalogClient(
        baseUrl: 'https://catalog.internal',
        httpClient: MockClient((request) async {
          sentIfNoneMatch = request.headers['if-none-match'];
          return http.Response('', 304);
        }),
      );

      await client.fetch(etag: '"abc123"');
      expect(sentIfNoneMatch, '"abc123"');
    });

    test('returns a not-modified result for a 304', () async {
      final client = HttpExternalCatalogClient(
        baseUrl: 'https://catalog.internal',
        httpClient: MockClient((request) async => http.Response('', 304)),
      );

      final result = await client.fetch(etag: '"abc123"');
      expect(result.modified, isFalse);
      expect(result.response, isNull);
    });

    test('throws ExternalCatalogException on a non-200/304 status', () async {
      final client = HttpExternalCatalogClient(
        baseUrl: 'https://catalog.internal',
        httpClient: MockClient((request) async => http.Response('', 500)),
      );

      expect(client.fetch(), throwsA(isA<ExternalCatalogException>()));
    });

    test('throws ExternalCatalogException on a malformed body', () async {
      final client = HttpExternalCatalogClient(
        baseUrl: 'https://catalog.internal',
        httpClient:
            MockClient((request) async => http.Response('not json', 200)),
      );

      expect(client.fetch(), throwsA(isA<ExternalCatalogException>()));
    });
  });
}
