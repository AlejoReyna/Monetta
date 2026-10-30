/// Cache-first, ETag-conditional access to the external catalog.
///
/// Contract (see `services/catalog_monitor/README.md` and the root
/// `docs/ARCHITECTURE.md` § "External catalog prototype"):
///  1. Load whatever was cached from the *last successful* fetch, so the UI
///     has something to show immediately, even offline.
///  2. Refresh in the background using the stored ETag. A `304` means the
///     cache is already correct — no-op. A new snapshot replaces the cache
///     atomically.
///  3. A failed refresh (network error, non-200/304, malformed body) leaves
///     the cached catalog exactly as it was. It never clears it.
library;

import '../../domain/catalog_item.dart';
import 'external_catalog_cache.dart';
import 'external_catalog_client.dart';
import 'external_catalog_mapper.dart';
import 'external_catalog_models.dart';

class ExternalCatalogRepository {
  ExternalCatalogRepository({
    required this.enabled,
    required ExternalCatalogClient client,
    required ExternalCatalogCache cache,
  })  : _client = client,
        _cache = cache;

  final bool enabled;
  final ExternalCatalogClient _client;
  final ExternalCatalogCache _cache;

  ExternalCatalogResponse? _current;
  String? _etag;

  ExternalCatalogResponse? get current => _current;

  List<CatalogItem> get items =>
      _current?.items.map(catalogItemFromExternalJson).toList() ?? const [];

  /// Loads the on-disk cache, if any. Call once at startup, before [refresh].
  Future<void> loadCache() async {
    if (!enabled) return;
    final cached = await _cache.load();
    if (cached != null) {
      _current = cached.response;
      _etag = cached.etag;
    }
  }

  /// Attempts a network refresh. Never throws — a failure is swallowed and
  /// the previously-loaded cache (from [loadCache] or an earlier successful
  /// [refresh]) is left untouched, per the contract above.
  Future<void> refresh() async {
    if (!enabled) return;
    try {
      final result = await _client.fetch(etag: _etag);
      if (!result.modified) return;
      _current = result.response;
      _etag = result.etag;
      final response = _current;
      if (response != null) {
        await _cache
            .save(CachedExternalCatalog(etag: _etag, response: response));
      }
    } catch (_) {
      // Deliberately swallowed — see the class doc comment.
    }
  }
}
