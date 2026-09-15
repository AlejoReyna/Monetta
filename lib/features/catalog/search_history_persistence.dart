/// Durable adapter for recent searches.
///
/// File-based (application support directory) so history survives a restart
/// without a Drift schema bump — the `OrderSummaries`/`WishlistItems` tables
/// are shared storage this package does not own. One JSON map keyed by the
/// same scope convention `SearchHistory` uses (`''` = guest).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'search_history.dart';

/// `SearchHistoryPersistence` backed by `search_history.json`.
///
/// Every [save] runs its read-modify-write inside a process-wide mutex, so
/// two concurrent saves cannot read the same snapshot and lose each other's
/// scope. Writes go to a temp file followed by an atomic rename, so a
/// concurrent [load] always sees either the previous or the next complete
/// document — never a half-written one.
class SearchHistoryFilePersistence implements SearchHistoryPersistence {
  SearchHistoryFilePersistence({
    Future<Directory> Function()? directoryProvider,
  }) : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directoryProvider;

  static const String fileName = 'search_history.json';

  static int _tmpSeq = 0;

  /// Serializes read-modify-write cycles across all instances sharing this
  /// isolate. The chain itself never completes with an error: failures live
  /// inside the guarded callback.
  static Future<void> _tail = Future<void>.value();

  static Future<T> _serialized<T>(Future<T> Function() work) async {
    final previous = _tail;
    final gate = Completer<void>();
    _tail = gate.future;
    await previous;
    try {
      return await work();
    } finally {
      gate.complete();
    }
  }

  Future<File> _file() async {
    final dir = await _directoryProvider();
    return File('${dir.path}/$fileName');
  }

  Future<Map<String, List<String>>> _readAllFrom(File file) async {
    try {
      if (!await file.exists()) return <String, List<String>>{};
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return <String, List<String>>{};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, List<String>>{};
      final out = <String, List<String>>{};
      decoded.forEach((key, value) {
        if (key is! String || value is! List) return;
        out[key] = <String>[
          for (final entry in value)
            if (entry is String && entry.trim().isNotEmpty) entry,
        ];
      });
      return out;
    } on Object {
      return <String, List<String>>{};
    }
  }

  @override
  Future<List<String>> load(String scopeKey) async {
    final all = await _readAllFrom(await _file());
    return all[scopeKey] ?? const <String>[];
  }

  @override
  Future<void> save(String scopeKey, List<String> queries) {
    final snapshot = List<String>.of(queries);
    // Start resolution eagerly so concurrent providers can make progress,
    // but reserve the write's position before awaiting its path. Resolution
    // latency must never let an older snapshot overwrite a newer mutation.
    // Handle resolution errors immediately, even while this write is queued.
    final pendingFile = _file().then<File?>(
      (file) => file,
      onError: (Object _, StackTrace __) => null,
    );
    return _serialized(() async {
      try {
        final file = await pendingFile;
        if (file == null) return;
        final all = await _readAllFrom(file);
        all[scopeKey] = snapshot;
        await file.parent.create(recursive: true);
        final tmp = File('${file.path}.tmp.${_tmpSeq++}');
        await tmp.writeAsString(jsonEncode(all), flush: true);
        try {
          await tmp.rename(file.path);
        } on FileSystemException {
          // Non-POSIX filesystems refuse rename-over-existing: fall back to
          // a direct write. Atomicity is lost there, ordering is not.
          if (await tmp.exists()) await tmp.delete();
          await file.writeAsString(jsonEncode(all), flush: true);
        }
      } on Object {
        // Best-effort cache: a failed write must never break search.
      }
    });
  }
}
