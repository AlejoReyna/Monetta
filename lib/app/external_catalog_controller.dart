/// Wires [ExternalCatalogConfig] to a repository and exposes it to the
/// widget tree as a [ChangeNotifier], the same pattern `CatalogStore` uses.
///
/// When the feature is disabled (the default), this controller does not
/// construct a repository at all — no HTTP client, no cache file, nothing.
/// [items] simply returns an empty list forever, so `features/home` can
/// render its external section unconditionally on `controller.items` without
/// a separate enabled check scattered through the UI.
library;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../data/external_catalog/external_catalog_cache.dart';
import '../data/external_catalog/external_catalog_client.dart';
import '../data/external_catalog/external_catalog_models.dart';
import '../data/external_catalog/external_catalog_repository.dart';
import '../domain/catalog_item.dart';
import 'external_catalog_config.dart';

class ExternalCatalogController extends ChangeNotifier {
  ExternalCatalogController({
    required this.config,
    ExternalCatalogRepository? repository,
  }) : _repository = repository ?? _buildRepository(config);

  final ExternalCatalogConfig config;
  final ExternalCatalogRepository? _repository;

  bool get enabled => config.enabled && _repository != null;
  List<CatalogItem> get items => _repository?.items ?? const [];
  DateTime? get generatedAt => _repository?.current?.generatedAt;
  List<ExternalCatalogSourceStatus> get sources =>
      _repository?.current?.sources ?? const [];

  /// Loads the cache immediately (so the UI can show it as soon as it's
  /// ready), then attempts one network refresh in the background.
  Future<void> loadAndRefresh() async {
    final repository = _repository;
    if (repository == null) return;
    await repository.loadCache();
    notifyListeners();
    await repository.refresh();
    notifyListeners();
  }

  static ExternalCatalogRepository? _buildRepository(
    ExternalCatalogConfig config,
  ) {
    final baseUrl = config.baseUrl;
    if (!config.enabled || baseUrl == null) return null;
    return ExternalCatalogRepository(
      enabled: true,
      client: HttpExternalCatalogClient(baseUrl: baseUrl),
      cache: FileExternalCatalogCache(
        directoryProvider: getApplicationSupportDirectory,
      ),
    );
  }
}
