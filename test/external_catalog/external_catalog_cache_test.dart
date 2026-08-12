import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/external_catalog/external_catalog_cache.dart';
import 'package:monetta_app/data/external_catalog/external_catalog_models.dart';

ExternalCatalogResponse _sampleResponse() => ExternalCatalogResponse(
      schemaVersion: 1,
      generatedAt: DateTime.utc(2026, 8, 10, 9),
      sources: const [],
      items: const [
        {'sourceScopedId': 'coach_us:C1', 'title': 'Bag'},
      ],
    );

void main() {
  group('FileExternalCatalogCache', () {
    late Directory tempDir;

    setUp(() async {
      tempDir =
          await Directory.systemTemp.createTemp('external_catalog_cache_test');
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('load() returns null when no cache file exists yet', () async {
      final cache =
          FileExternalCatalogCache(directoryProvider: () async => tempDir);
      expect(await cache.load(), isNull);
    });

    test('save() then load() round-trips the snapshot', () async {
      final cache =
          FileExternalCatalogCache(directoryProvider: () async => tempDir);
      final snapshot =
          CachedExternalCatalog(etag: '"abc"', response: _sampleResponse());

      await cache.save(snapshot);
      final loaded = await cache.load();

      expect(loaded, isNotNull);
      expect(loaded!.etag, '"abc"');
      expect(loaded.response.items.single['sourceScopedId'], 'coach_us:C1');
    });

    test('save() replaces the file atomically — no .tmp file left behind',
        () async {
      final cache =
          FileExternalCatalogCache(directoryProvider: () async => tempDir);
      await cache.save(
        CachedExternalCatalog(etag: '"a"', response: _sampleResponse()),
      );
      await cache.save(
        CachedExternalCatalog(etag: '"b"', response: _sampleResponse()),
      );

      final entries = await tempDir.list().toList();
      final names = entries
          .map((e) => e.path.split(Platform.pathSeparator).last)
          .toList();
      expect(names, contains('external_catalog_cache.json'));
      expect(names.any((n) => n.endsWith('.tmp')), isFalse);

      final loaded = await cache.load();
      expect(loaded!.etag, '"b"');
    });

    test(
        'load() treats a corrupt cache file as "no cache" rather than throwing',
        () async {
      final file = File('${tempDir.path}/external_catalog_cache.json');
      await file.writeAsString('{not valid json');

      final cache =
          FileExternalCatalogCache(directoryProvider: () async => tempDir);
      expect(await cache.load(), isNull);
    });

    test('CachedExternalCatalog round-trips through JSON encoding', () {
      final snapshot =
          CachedExternalCatalog(etag: '"x"', response: _sampleResponse());
      final decoded = CachedExternalCatalog.fromJson(
        jsonDecode(jsonEncode(snapshot.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.etag, '"x"');
      expect(decoded.response.schemaVersion, 1);
    });
  });
}
