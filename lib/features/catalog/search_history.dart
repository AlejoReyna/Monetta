/// Recent searches: what a shopper actually submitted, per account.
///
/// ## Why this is not a Drift table
///
/// The app already persists the bag and the wishlist in Drift, scoped by
/// account id. A `SearchQueries` table would be the natural home for this and
/// would match those scope keys exactly — but adding it means a schema
/// version bump and a regenerated `database.g.dart`, which is shared
/// storage this package does not own. So the history is defined here behind
/// [SearchHistoryPersistence] and defaults to the session, and the orchestrator
/// can hand it a durable adapter without a single change to the screens.
///
/// See `docs/` handover notes: this is the one open data dependency in
/// package B.
library;

import 'package:flutter/foundation.dart';

/// Fold accents, case and runs of whitespace so `Bolso Coach`, `bolso  coach`
/// and `BOLSO COACH` are one entry. The stored text keeps the shopper's own
/// spelling; only the comparison key is normalized.
String normalizeSearchText(String value) => value
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ü', 'u')
    .replaceAll('ñ', 'n')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Durable storage for the history. Implement and inject to survive a restart.
abstract class SearchHistoryPersistence {
  /// [scopeKey] is `''` for a guest and the account id once signed in —
  /// the same convention `WishlistStore.scopeKey` uses.
  Future<List<String>> load(String scopeKey);

  Future<void> save(String scopeKey, List<String> queries);
}

/// Per-scope hydration and mutation ledger.
///
/// Screens call [SearchHistory.setScope] and [SearchHistory.remember] without
/// awaiting them, so a restore can still be in flight while the shopper
/// submits, removes or clears a query. A late restore must never overwrite
/// those newer mutations: [loadGen]/[mutationGen] detect the interleave,
/// [tombstones] keep a restore from resurrecting forgotten queries, and
/// [clearedDuringLoad] keeps it from resurrecting a cleared list.
class _ScopeState {
  final List<String> list = <String>[];

  /// True once a restore for this scope has completed and been applied.
  bool hydrated = false;

  /// Bumped on every restore start; a completion whose generation no longer
  /// matches was superseded and is dropped.
  int loadGen = 0;

  /// Bumped on every [SearchHistory.remember], [SearchHistory.forget] and
  /// [SearchHistory.clear].
  int mutationGen = 0;

  /// A clear landed while a restore was in flight: the restore is dropped.
  bool clearedDuringLoad = false;

  /// Normalized keys removed while a restore was in flight: matching restored
  /// entries are skipped when the restore lands.
  final Set<String> tombstones = <String>{};
}

/// Most-recent-first list of submitted queries for the current account.
class SearchHistory extends ChangeNotifier {
  SearchHistory({SearchHistoryPersistence? persistence})
      : _persistence = persistence;

  /// The instance the screens read when nothing is injected. Durable once the
  /// app wires [SearchHistoryFilePersistence] at startup; session-scoped
  /// until then (tests inject their own adapter).
  static final SearchHistory instance = SearchHistory();

  /// Connects the shared instance to durable storage. Called once at startup;
  /// safe to call again (last writer wins).
  static void configureSharedPersistence(
    SearchHistoryPersistence? persistence,
  ) {
    instance._persistence = persistence;
  }

  /// A shopper recognises their own recent searches; a long list is a log.
  static const int maxEntries = 8;

  SearchHistoryPersistence? _persistence;

  /// One state per account scope. Two people signing into the same device
  /// never see each other's searches because nothing is ever merged across
  /// scopes — merges below only combine a scope's own live list with its own
  /// late restore.
  final Map<String, _ScopeState> _byScope = <String, _ScopeState>{};

  String _scope = '';

  String get scopeKey => _scope;

  List<String> get queries {
    final state = _byScope[_scope];
    if (state == null) return const <String>[];
    return List<String>.unmodifiable(state.list);
  }

  bool get isEmpty => queries.isEmpty;

  /// Switch accounts. Call alongside `CatalogStore.setAccountScope`.
  ///
  /// Fire-and-forget safe: when mutations land while the restore is in
  /// flight, the restore is merged underneath them instead of replacing them,
  /// and the merged outcome is persisted — otherwise a restart would replay
  /// the pre-merge file and lose the mutation (or resurrect a removal).
  Future<void> setScope(String? accountId) async {
    final next = accountId ?? '';
    final switched = next != _scope;
    _scope = next;
    final state = _byScope.putIfAbsent(next, _ScopeState.new);
    if (state.hydrated) {
      if (switched) notifyListeners();
      return;
    }
    final gen = ++state.loadGen;
    final baseMutations = state.mutationGen;
    final restored = await _persistence?.load(next);
    if (gen != state.loadGen) return;
    final interleaved =
        state.mutationGen != baseMutations || state.list.isNotEmpty;
    if (interleaved) {
      _mergeRestore(state, restored);
    } else {
      state.list
        ..clear()
        ..addAll((restored ?? const <String>[]).take(maxEntries));
    }
    state.hydrated = true;
    state.tombstones.clear();
    state.clearedDuringLoad = false;
    final persistence = _persistence;
    if (interleaved && persistence != null) {
      // Durability for the merge: without this save, mutations flushed
      // before the restore landed (e.g. remember's pre-merge snapshot) or
      // removals recorded only as tombstones would be lost on restart.
      // Pinned to the hydrated scope's own identity — [_scope] may already
      // point at another account. Enqueued before notifying so any
      // listener-driven mutation flushes behind this snapshot, never ahead
      // of it (the file adapter serializes saves in enqueue order).
      final pendingSave = persistence.save(
        next,
        List<String>.unmodifiable(state.list),
      );
      notifyListeners();
      await pendingSave;
      return;
    }
    notifyListeners();
  }

  /// Merges a late restore underneath newer mutations: live entries stay
  /// first, restored entries fill behind unless forgotten or cleared away.
  void _mergeRestore(_ScopeState state, List<String>? restored) {
    if (!state.clearedDuringLoad && restored != null) {
      final seen = <String>{
        for (final entry in state.list) normalizeSearchText(entry),
      };
      for (final entry in restored) {
        final key = normalizeSearchText(entry);
        if (key.isEmpty ||
            seen.contains(key) ||
            state.tombstones.contains(key)) {
          continue;
        }
        seen.add(key);
        state.list.add(entry);
      }
    }
    if (state.list.length > maxEntries) {
      state.list.removeRange(maxEntries, state.list.length);
    }
  }

  /// Record a *submitted* query or a chosen suggestion — never a keystroke.
  Future<void> remember(String raw) async {
    final query = raw.trim();
    if (query.isEmpty) return;
    final key = normalizeSearchText(query);
    if (key.isEmpty) return;

    final state = _byScope.putIfAbsent(_scope, _ScopeState.new);
    state.mutationGen++;
    state.tombstones.remove(key);
    state.list
      ..removeWhere((entry) => normalizeSearchText(entry) == key)
      ..insert(0, query);
    if (state.list.length > maxEntries) {
      state.list.removeRange(maxEntries, state.list.length);
    }
    notifyListeners();
    await _flush();
  }

  Future<void> forget(String query) async {
    final key = normalizeSearchText(query);
    final state = _byScope[_scope];
    if (state == null || key.isEmpty) return;
    final before = state.list.length;
    state.list.removeWhere((entry) => normalizeSearchText(entry) == key);
    if (state.list.length == before) {
      // Nothing visible to remove, but a restore in flight may still carry
      // this query — tombstone it so it never resurfaces. Durability comes
      // from setScope's completion save, which persists the merged outcome.
      if (!state.hydrated) {
        state.tombstones.add(key);
        state.mutationGen++;
      }
      return;
    }
    state.mutationGen++;
    if (!state.hydrated) state.tombstones.add(key);
    notifyListeners();
    await _flush();
  }

  Future<void> clear() async {
    final state = _byScope[_scope];
    if (state == null) return;
    state.mutationGen++;
    if (!state.hydrated) {
      // Even with an empty visible list this must stick: the completion save
      // in setScope persists the dropped restore. Returning early below
      // without flushing is safe because of that save.
      state.clearedDuringLoad = true;
      state.tombstones.addAll(state.list.map(normalizeSearchText));
    }
    if (state.list.isEmpty) return;
    state.list.clear();
    notifyListeners();
    await _flush();
  }

  Future<void> _flush() async {
    final persistence = _persistence;
    if (persistence == null) return;
    await persistence.save(_scope, queries);
  }
}
