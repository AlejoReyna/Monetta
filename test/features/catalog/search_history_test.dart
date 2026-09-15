import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/features/catalog/search_history.dart';
import 'package:monetta_app/features/catalog/search_history_persistence.dart';

class _Recording implements SearchHistoryPersistence {
  final Map<String, List<String>> saved = <String, List<String>>{};
  final Map<String, List<String>> seed = <String, List<String>>{};

  @override
  Future<List<String>> load(String scopeKey) async =>
      seed[scopeKey] ?? const <String>[];

  @override
  Future<void> save(String scopeKey, List<String> queries) async {
    saved[scopeKey] = List<String>.of(queries);
  }
}

void main() {
  test('keeps the most recent first and never duplicates a query', () async {
    final history = SearchHistory();
    await history.remember('bolso coach');
    await history.remember('cartera michael kors');
    await history.remember('Bolso  Coach');

    expect(history.queries.first, 'Bolso  Coach');
    expect(history.queries, hasLength(2));
  });

  test('accents and case do not create a second entry', () async {
    final history = SearchHistory();
    await history.remember('bolsa café');
    await history.remember('BOLSA CAFE');
    expect(history.queries, hasLength(1));
  });

  test('drops the oldest past the limit', () async {
    final history = SearchHistory();
    for (var i = 0; i < SearchHistory.maxEntries + 4; i++) {
      await history.remember('consulta $i');
    }
    expect(history.queries, hasLength(SearchHistory.maxEntries));
    expect(history.queries.first, 'consulta 11');
    expect(history.queries.contains('consulta 0'), isFalse);
  });

  test('blank input is not a search', () async {
    final history = SearchHistory();
    await history.remember('   ');
    expect(history.isEmpty, isTrue);
  });

  test('one entry can be removed and the whole list cleared', () async {
    final history = SearchHistory();
    await history.remember('reloj guess');
    await history.remember('bolso coach');

    await history.forget('RELOJ GUESS');
    expect(history.queries, ['bolso coach']);

    await history.clear();
    expect(history.isEmpty, isTrue);
  });

  test('two accounts never see each other\'s searches', () async {
    final history = SearchHistory();
    await history.remember('guest');

    await history.setScope('account-a');
    expect(history.queries, isEmpty);
    await history.remember('coach');

    await history.setScope('account-b');
    expect(history.queries, isEmpty);

    await history.setScope(null);
    expect(history.queries, ['guest']);

    await history.setScope('account-a');
    expect(history.queries, ['coach']);
  });

  test('persistence is restored per scope and written on every change',
      () async {
    final store = _Recording()..seed['account-a'] = <String>['bolso coach'];
    final history = SearchHistory(persistence: store);

    await history.setScope('account-a');
    expect(history.queries, ['bolso coach']);

    await history.remember('reloj guess');
    expect(store.saved['account-a'], ['reloj guess', 'bolso coach']);

    await history.clear();
    expect(store.saved['account-a'], isEmpty);
  });

  test('normalizeSearchText folds accents, case and whitespace', () {
    expect(normalizeSearchText('  Bolsó   CAFÉ Ñ '), 'bolso cafe n');
  });

  test('a submitted query survives an in-flight history restore', () async {
    final storage = _DelayedStorage();
    final history = SearchHistory(persistence: storage);

    final loading = history.setScope('account-a');
    await history.remember('new query');
    storage.restored.complete(['older query']);
    await loading;

    expect(history.queries, contains('new query'));
    expect(history.queries.first, 'new query');
  });

  test('a removal during restore is not resurrected', () async {
    final storage = _DelayedStorage();
    final history = SearchHistory(persistence: storage);

    final loading = history.setScope('account-a');
    await history.forget('older query');
    storage.restored.complete(['older query', 'coach']);
    await loading;

    expect(history.queries, isNot(contains('older query')));
    expect(history.queries, contains('coach'));
  });

  test('a clear during restore drops the late payload', () async {
    final storage = _DelayedStorage();
    final history = SearchHistory(persistence: storage);

    final loading = history.setScope('account-a');
    await history.remember('new query');
    await history.clear();
    storage.restored.complete(['older query']);
    await loading;

    expect(history.queries, isEmpty);
  });

  for (final action in ['remember', 'forget', 'clear']) {
    test('$action during restore remains correct after restart', () async {
      final dir = await Directory.systemTemp.createTemp('monetta-durable-');
      addTearDown(() => dir.delete(recursive: true));
      final disk = SearchHistoryFilePersistence(
        directoryProvider: () async => dir,
      );
      await disk.save('a', ['older query', 'coach']);
      final gated = _GatedRestore(disk);
      final history = SearchHistory(persistence: gated);

      final loading = history.setScope('a');
      await gated.started.future;
      switch (action) {
        case 'remember':
          await history.remember('new query');
        case 'forget':
          await history.forget('older query');
        case 'clear':
          await history.clear();
      }
      gated.release.complete();
      await loading;

      final List<String> expected = switch (action) {
        'remember' => ['new query', 'older query', 'coach'],
        'forget' => ['coach'],
        _ => <String>[],
      };
      expect(history.queries, expected, reason: 'live state');
      final restarted = SearchHistory(persistence: disk);
      await restarted.setScope('a');
      expect(restarted.queries, expected, reason: 'durable state');
    });
  }

  test('late completion saves under the hydrated scope, later wins', () async {
    final dir = await Directory.systemTemp.createTemp('monetta-switch-');
    addTearDown(() => dir.delete(recursive: true));
    final disk = SearchHistoryFilePersistence(
      directoryProvider: () async => dir,
    );
    await disk.save('a', ['older query', 'coach']);
    await disk.save('b', ['bee']);
    final gated = _ScopedGate(disk, {'a'});
    final history = SearchHistory(persistence: gated);

    final loadingA = history.setScope('a');
    while (!gated.started.containsKey('a')) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    // Switch accounts mid-load, then mutate the live scope.
    await history.setScope('b');
    await history.remember('bee-two');
    gated.release['a']!.complete();
    await loadingA;

    // The late completion for 'a' must not touch 'b'.
    expect(history.queries, ['bee-two', 'bee']);
    final checkB = SearchHistory(persistence: disk);
    await checkB.setScope('b');
    expect(checkB.queries, ['bee-two', 'bee']);

    // Back on 'a': pristine restore persisted; a later mutation wins.
    await history.setScope('a');
    expect(history.queries, ['older query', 'coach']);
    await history.remember('after');
    final checkA = SearchHistory(persistence: disk);
    await checkA.setScope('a');
    expect(checkA.queries, ['after', 'older query', 'coach']);
  });

  test('listener mutation wins even if merged snapshot path resolves later',
      () async {
    final dir = await Directory.systemTemp.createTemp('monetta-fifo-');
    addTearDown(() => dir.delete(recursive: true));
    var holdNextPath = false;
    final pathStarted = Completer<void>();
    final releasePath = Completer<void>();
    final disk = SearchHistoryFilePersistence(
      directoryProvider: () async {
        if (holdNextPath) {
          holdNextPath = false;
          pathStarted.complete();
          await releasePath.future;
        }
        return dir;
      },
    );
    final pending = _PendingRestore(disk);
    final history = SearchHistory(persistence: pending);
    final loading = history.setScope('a');
    await history.remember('new query');
    Future<void>? listenerSave;
    var reacted = false;
    history.addListener(() {
      if (!reacted && history.queries.contains('older query')) {
        reacted = true;
        listenerSave = history.remember('listener query');
      }
    });
    holdNextPath = true;
    pending.release.complete(['older query']);
    await pathStarted.future;
    await Future.any<void>([
      listenerSave!,
      Future<void>.delayed(const Duration(milliseconds: 100)),
    ]);
    releasePath.complete();
    await Future.wait<void>([loading, listenerSave!]);
    final expected = ['listener query', 'new query', 'older query'];
    expect(history.queries, expected, reason: 'live state');
    final restarted = SearchHistory(persistence: disk);
    await restarted.setScope('a');
    expect(
      restarted.queries,
      expected,
      reason: 'newer listener mutation must survive restart',
    );
  });

  test('queued path failure does not block subsequent saves', () async {
    final dir = await Directory.systemTemp.createTemp('monetta-path-error-');
    addTearDown(() => dir.delete(recursive: true));
    final release = Completer<void>();
    var calls = 0;
    final storage = SearchHistoryFilePersistence(
      directoryProvider: () async {
        final call = ++calls;
        if (call == 1) await release.future;
        if (call == 2) throw const FileSystemException('Unavailable directory');
        return dir;
      },
    );
    final first = storage.save('a', ['first']);
    final failed = storage.save('b', ['not saved']);
    final last = storage.save('a', ['last']);
    // Let the second resolution fail while waiting behind the first write.
    await Future<void>.delayed(Duration.zero);
    release.complete();
    await Future.wait([first, failed, last]);
    expect(await storage.load('a'), ['last']);
    expect(await storage.load('b'), isEmpty);
  });

  test('save snapshots its input before resolving the directory', () async {
    final dir = await Directory.systemTemp.createTemp('monetta-snapshot-');
    addTearDown(() => dir.delete(recursive: true));
    final release = Completer<void>();
    final storage = SearchHistoryFilePersistence(
      directoryProvider: () async {
        await release.future;
        return dir;
      },
    );
    final queries = ['submitted'];
    final saved = storage.save('a', queries);
    queries[0] = 'modified later';
    release.complete();
    await saved;
    expect(await storage.load('a'), ['submitted']);
  });

  test('concurrent file saves retain both account scopes', () async {
    final dir = await Directory.systemTemp.createTemp('monetta-search-');
    addTearDown(() => dir.delete(recursive: true));
    final reads = Completer<void>();
    var calls = 0;
    // Gate the first two path resolutions on each other so both saves read
    // the same snapshot before either writes — the interleave that used to
    // lose one scope.
    final storage = SearchHistoryFilePersistence(
      directoryProvider: () async {
        calls++;
        if (calls <= 2) {
          if (calls == 2) reads.complete();
          await reads.future;
        }
        return dir;
      },
    );

    await Future.wait([
      storage.save('account-a', ['coach']),
      storage.save('account-b', ['guess']),
    ]);

    expect(await storage.load('account-a'), ['coach']);
    expect(await storage.load('account-b'), ['guess']);
  });
}

class _DelayedStorage implements SearchHistoryPersistence {
  final Completer<List<String>> restored = Completer<List<String>>();

  @override
  Future<List<String>> load(String scopeKey) => restored.future;

  @override
  Future<void> save(String scopeKey, List<String> queries) async {}
}

/// Delays a real file-backed restore until the test mutates mid-flight.
class _GatedRestore implements SearchHistoryPersistence {
  _GatedRestore(this.disk);

  final SearchHistoryFilePersistence disk;
  final Completer<void> started = Completer<void>();
  final Completer<void> release = Completer<void>();

  @override
  Future<List<String>> load(String scopeKey) async {
    final snapshot = await disk.load(scopeKey);
    started.complete();
    await release.future;
    return snapshot;
  }

  @override
  Future<void> save(String scopeKey, List<String> queries) =>
      disk.save(scopeKey, queries);
}

/// Gates restores for [gatedScopes] only, letting other scopes load freely.
class _ScopedGate implements SearchHistoryPersistence {
  _ScopedGate(this.disk, this.gatedScopes);

  final SearchHistoryFilePersistence disk;
  final Set<String> gatedScopes;
  final Map<String, Completer<void>> started = {};
  final Map<String, Completer<void>> release = {};

  @override
  Future<List<String>> load(String scopeKey) async {
    final snapshot = await disk.load(scopeKey);
    if (gatedScopes.contains(scopeKey)) {
      started[scopeKey] = Completer<void>();
      release[scopeKey] = Completer<void>();
      started[scopeKey]!.complete();
      await release[scopeKey]!.future;
    }
    return snapshot;
  }

  @override
  Future<void> save(String scopeKey, List<String> queries) =>
      disk.save(scopeKey, queries);
}

class _PendingRestore implements SearchHistoryPersistence {
  _PendingRestore(this.disk);
  final SearchHistoryFilePersistence disk;
  final release = Completer<List<String>>();
  @override
  Future<List<String>> load(String key) => release.future;
  @override
  Future<void> save(String key, List<String> queries) =>
      disk.save(key, queries);
}
