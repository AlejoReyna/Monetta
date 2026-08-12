import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/external_catalog/external_catalog_cache.dart';
import 'package:monetta_app/data/external_catalog/external_catalog_client.dart';
import 'package:monetta_app/data/external_catalog/external_catalog_models.dart';
import 'package:monetta_app/data/external_catalog/external_catalog_repository.dart';

class _FakeClient implements ExternalCatalogClient {
  _FakeClient(this._results);
  final List<Future<ExternalCatalogFetchResult> Function()> _results;
  int calls = 0;
  final List<String?> receivedEtags = [];

  @override
  Future<ExternalCatalogFetchResult> fetch({String? etag}) {
    receivedEtags.add(etag);
    final result = _results[calls];
    calls++;
    return result();
  }
}

class _FakeCache implements ExternalCatalogCache {
  CachedExternalCatalog? stored;
  int saveCalls = 0;

  @override
  Future<CachedExternalCatalog?> load() async => stored;

  @override
  Future<void> save(CachedExternalCatalog snapshot) async {
    saveCalls++;
    stored = snapshot;
  }
}

ExternalCatalogResponse _response(String title) => ExternalCatalogResponse(
      schemaVersion: 1,
      generatedAt: DateTime.utc(2026, 8, 10),
      sources: const [],
      items: [
        {'sourceScopedId': 'coach_us:C1', 'title': title},
      ],
    );

void main() {
  group('ExternalCatalogRepository — disabled', () {
    test('loadCache and refresh are no-ops, items stays empty', () async {
      final client = _FakeClient([]);
      final cache = _FakeCache();
      final repo = ExternalCatalogRepository(
        enabled: false,
        client: client,
        cache: cache,
      );

      await repo.loadCache();
      await repo.refresh();

      expect(repo.items, isEmpty);
      expect(client.calls, 0);
      expect(cache.saveCalls, 0);
    });
  });

  group('ExternalCatalogRepository — enabled', () {
    test('loadCache surfaces the on-disk snapshot before any network call',
        () async {
      final cache = _FakeCache()
        ..stored = CachedExternalCatalog(
          etag: '"cached"',
          response: _response('Cached Bag'),
        );
      final client = _FakeClient([]);
      final repo = ExternalCatalogRepository(
        enabled: true,
        client: client,
        cache: cache,
      );

      await repo.loadCache();

      expect(repo.current!.items.single['title'], 'Cached Bag');
      expect(client.calls, 0);
    });

    test(
        'refresh() sends the cached ETag and replaces the snapshot on a fresh fetch',
        () async {
      final cache = _FakeCache()
        ..stored = CachedExternalCatalog(
          etag: '"old"',
          response: _response('Old Bag'),
        );
      final client = _FakeClient([
        () async => ExternalCatalogFetchResult.modified(
              response: _response('New Bag'),
              etag: '"new"',
            ),
      ]);
      final repo = ExternalCatalogRepository(
        enabled: true,
        client: client,
        cache: cache,
      );

      await repo.loadCache();
      await repo.refresh();

      expect(client.receivedEtags.single, '"old"');
      expect(repo.current!.items.single['title'], 'New Bag');
      expect(cache.stored!.etag, '"new"');
      expect(cache.saveCalls, 1);
    });

    test('a 304 leaves the cached snapshot untouched and does not re-save',
        () async {
      final cache = _FakeCache()
        ..stored = CachedExternalCatalog(
          etag: '"same"',
          response: _response('Same Bag'),
        );
      final client = _FakeClient([
        () async => const ExternalCatalogFetchResult.notModified(),
      ]);
      final repo = ExternalCatalogRepository(
        enabled: true,
        client: client,
        cache: cache,
      );

      await repo.loadCache();
      await repo.refresh();

      expect(repo.current!.items.single['title'], 'Same Bag');
      expect(cache.saveCalls, 0);
    });

    test(
        'a failed refresh preserves the cached catalog rather than clearing it',
        () async {
      final cache = _FakeCache()
        ..stored = CachedExternalCatalog(
          etag: '"good"',
          response: _response('Good Bag'),
        );
      final client = _FakeClient([
        () async => throw ExternalCatalogException('simulated outage'),
      ]);
      final repo = ExternalCatalogRepository(
        enabled: true,
        client: client,
        cache: cache,
      );

      await repo.loadCache();
      await repo.refresh();

      expect(repo.current!.items.single['title'], 'Good Bag'); // still there
      expect(cache.saveCalls, 0);
    });

    test('refresh() before any loadCache() still works from a cold start',
        () async {
      final cache = _FakeCache();
      final client = _FakeClient([
        () async => ExternalCatalogFetchResult.modified(
              response: _response('Fresh Bag'),
              etag: '"fresh"',
            ),
      ]);
      final repo = ExternalCatalogRepository(
        enabled: true,
        client: client,
        cache: cache,
      );

      await repo.refresh();

      expect(client.receivedEtags.single, isNull);
      expect(repo.current!.items.single['title'], 'Fresh Bag');
      expect(cache.saveCalls, 1);
    });
  });
}
