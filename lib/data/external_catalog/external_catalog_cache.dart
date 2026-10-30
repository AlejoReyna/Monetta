/// Last-successful-snapshot cache, stored as a single JSON file in the app's
/// support directory. Written atomically (write to a temp file, then
/// rename over the real one) so a crash or a killed app mid-write can never
/// leave a half-written, unparseable cache file behind.
///
/// The directory is injected as a function rather than calling
/// `path_provider` directly, so this is testable against a plain temp
/// directory with no plugin channel.
library;

import 'dart:convert';
import 'dart:io';

import 'external_catalog_models.dart';

class CachedExternalCatalog {
  const CachedExternalCatalog({required this.etag, required this.response});

  final String? etag;
  final ExternalCatalogResponse response;

  Map<String, dynamic> toJson() =>
      {'etag': etag, 'response': response.toJson()};

  factory CachedExternalCatalog.fromJson(Map<String, dynamic> json) {
    return CachedExternalCatalog(
      etag: json['etag'] as String?,
      response: ExternalCatalogResponse.fromJson(
        json['response'] as Map<String, dynamic>,
      ),
    );
  }
}

abstract class ExternalCatalogCache {
  Future<CachedExternalCatalog?> load();
  Future<void> save(CachedExternalCatalog snapshot);
}

const String _cacheFileName = 'external_catalog_cache.json';

class FileExternalCatalogCache implements ExternalCatalogCache {
  FileExternalCatalogCache({
    required Future<Directory> Function() directoryProvider,
  }) : _directoryProvider = directoryProvider;

  final Future<Directory> Function() _directoryProvider;

  Future<File> _cacheFile() async {
    final dir = await _directoryProvider();
    return File('${dir.path}/$_cacheFileName');
  }

  @override
  Future<CachedExternalCatalog?> load() async {
    try {
      final file = await _cacheFile();
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      return CachedExternalCatalog.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      // A corrupt or unreadable cache must never crash startup — treat it
      // as "no cache yet."
      return null;
    }
  }

  @override
  Future<void> save(CachedExternalCatalog snapshot) async {
    final file = await _cacheFile();
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(snapshot.toJson()), flush: true);
    await tmp.rename(file.path);
  }
}
