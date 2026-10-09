/// State and actions of the search screen, away from its widgets.
///
/// The view model listens to the catalog store and to the search history and
/// derives one immutable [SearchViewState] from them. It notifies only when
/// that state changed by value, so a store notification that does not concern
/// search (an event recorded about some other piece, say) no longer rebuilds
/// the screen.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../app/catalog_store.dart';
import '../../app/command.dart';
import '../../app/shopper_copy.dart';
import '../../data/normalize/facets.dart' show FacetValue;
import '../../domain/product.dart';
import '../../reco/explainer.dart';
import 'query/product_search.dart';
import 'query/search_text.dart';
import 'search_history.dart';

/// One type-ahead line: a label that contains the query, ranked by how
/// specific its source is (brand first, product title last).
@immutable
class SearchSuggestion {
  const SearchSuggestion({required this.label, required this.priority});

  final String label;
  final int priority;

  @override
  bool operator ==(Object other) =>
      other is SearchSuggestion &&
      other.label == label &&
      other.priority == priority;

  @override
  int get hashCode => Object.hash(label, priority);
}

/// What the search screen shows. Only the parts the current mode draws are
/// filled in; the rest stay empty:
///
/// - empty query: [history], [categories] and [discovery];
/// - typing: [suggestions];
/// - submitted: [results], plus [categories] when there are none.
@immutable
class SearchViewState {
  const SearchViewState({
    required this.query,
    required this.showResults,
    this.results = const <Product>[],
    this.suggestions = const <SearchSuggestion>[],
    this.history = const <String>[],
    this.categories = const <String>[],
    this.discovery = const <Product>[],
  });

  /// The text in the field, as typed.
  final String query;

  /// True once the query was submitted and until it is edited.
  final bool showResults;

  final List<Product> results;
  final List<SearchSuggestion> suggestions;
  final List<String> history;
  final List<String> categories;
  final List<Product> discovery;

  bool get isEmptyQuery => query.trim().isEmpty;

  @override
  bool operator ==(Object other) =>
      other is SearchViewState &&
      other.query == query &&
      other.showResults == showResults &&
      listEquals(other.results, results) &&
      listEquals(other.suggestions, suggestions) &&
      listEquals(other.history, history) &&
      listEquals(other.categories, categories) &&
      listEquals(other.discovery, discovery);

  @override
  int get hashCode => Object.hash(
        query,
        showResults,
        Object.hashAll(results),
        Object.hashAll(suggestions),
        Object.hashAll(history),
        Object.hashAll(categories),
        Object.hashAll(discovery),
      );
}

class SearchViewModel extends ChangeNotifier {
  SearchViewModel({
    required CatalogStore store,
    required SearchHistory history,
    String initialQuery = '',
  })  : _store = store,
        _history = history,
        _query = initialQuery,
        _showResults = initialQuery.trim().isNotEmpty {
    _store.addListener(_onSourceChanged);
    _history.addListener(_onSourceChanged);
    _state = _derive();
  }

  final CatalogStore _store;
  final SearchHistory _history;

  String _query;
  bool _showResults;
  late SearchViewState _state;
  bool _disposed = false;

  SearchViewState get state => _state;

  /// Submits the text in the field: shows its results and remembers it in the
  /// history. Blank text only hides the results.
  ///
  /// The history mutation applies at once; its durable flush carries on in the
  /// background and is deliberately not awaited, so the command's no-overlap
  /// guard never drops a second rapid submission.
  late final Command1<void, String> submit =
      Command1<void, String>(_submitQuery);

  /// Removes one entry from the history.
  late final Command1<void, String> forget =
      Command1<void, String>(_forgetQuery);

  /// Empties the history.
  late final Command0<void> clearHistory = Command0<void>(_clearHistory);

  /// The field's text changed: back to type-ahead.
  void queryChanged(String text) => _update(query: text, showResults: false);

  /// The field was emptied.
  void clear() => _update(query: '', showResults: false);

  /// Leaves the results to edit the query, keeping its text.
  void edit() => _update(showResults: false);

  Future<void> _submitQuery(String raw) async {
    final query = raw.trim();
    if (query.isEmpty) {
      _update(query: raw, showResults: false);
      return;
    }
    _update(query: raw, showResults: true);
    unawaited(_history.remember(query));
  }

  Future<void> _forgetQuery(String query) async {
    unawaited(_history.forget(query));
  }

  Future<void> _clearHistory() async {
    unawaited(_history.clear());
  }

  void _update({String? query, required bool showResults}) {
    _query = query ?? _query;
    _showResults = showResults;
    _refresh();
  }

  void _onSourceChanged() => _refresh();

  void _refresh() {
    if (_disposed) return;
    final next = _derive();
    if (next == _state) return;
    _state = next;
    notifyListeners();
  }

  SearchViewState _derive() {
    final query = _query;
    if (query.trim().isEmpty) {
      return SearchViewState(
        query: query,
        showResults: _showResults,
        history: _history.queries,
        categories: _availableCategories(),
        discovery: _discoveryProducts(),
      );
    }
    if (_showResults) {
      final results = searchProductList(
        _store.products,
        _store.facetsFor,
        query,
      );
      return SearchViewState(
        query: query,
        showResults: true,
        results: results,
        categories: results.isEmpty ? _availableCategories() : const [],
      );
    }
    return SearchViewState(
      query: query,
      showResults: false,
      suggestions: _suggestions(query),
    );
  }

  List<SearchSuggestion> _suggestions(String raw) {
    final query = normalizeSearchText(raw);
    if (query.isEmpty) return const [];

    final byLabel = <String, SearchSuggestion>{};

    void add(String? label, int priority) {
      final cleanLabel = label?.trim() ?? '';
      final normalizedLabel = normalizeSearchText(cleanLabel);
      if (cleanLabel.isEmpty || !normalizedLabel.contains(query)) return;

      final existing = byLabel[normalizedLabel];
      if (existing == null || priority < existing.priority) {
        byLabel[normalizedLabel] = SearchSuggestion(
          label: cleanLabel,
          priority: priority,
        );
      }
    }

    for (final product in _store.products) {
      final facets = _store.facetsFor(product.id);
      add(facets?.brand == null ? null : brandLabel(facets!.brand!.value), 0);
      add(
        facets?.category == null
            ? null
            : categoryLabel(facets!.category!.value),
        1,
      );
      add(
        facets?.silhouette == null
            ? null
            : silhouetteLabel(facets!.silhouette!.value),
        2,
      );
      for (final color in facets?.colors ?? const <FacetValue>[]) {
        add(colorLabel(color.value), 3);
      }
      for (final pattern in facets?.patterns ?? const <FacetValue>[]) {
        add(patternLabel(pattern.value), 3);
      }
      add(product.title, 4);
    }

    final suggestions = byLabel.values.toList()
      ..sort((a, b) {
        final aStarts = normalizeSearchText(a.label).startsWith(query);
        final bStarts = normalizeSearchText(b.label).startsWith(query);
        if (aStarts != bStarts) return aStarts ? -1 : 1;

        final priority = a.priority.compareTo(b.priority);
        if (priority != 0) return priority;

        final length = a.label.length.compareTo(b.label.length);
        if (length != 0) return length;
        return a.label.compareTo(b.label);
      });
    return suggestions.take(6).toList(growable: false);
  }

  /// Categories that actually have products behind them, in the catalog's own
  /// display order.
  List<String> _availableCategories() {
    final slugs = <String>{
      for (final product in _store.products)
        if (_store.facetsFor(product.id)?.category?.value case final value?)
          value,
    }.toList()
      ..sort(
        (a, b) => categoryPlural(a).toLowerCase().compareTo(
              categoryPlural(b).toLowerCase(),
            ),
      );
    return slugs;
  }

  /// A short selection drawn from what the app already has: what the shopper
  /// looked at last, otherwise the ranked feed, otherwise the catalog head.
  List<Product> _discoveryProducts({int limit = 8}) {
    final recent = _store.recentlyViewed(limit: limit);
    if (recent.isNotEmpty) return recent;
    final ranked = _store.feed(limit: limit);
    if (ranked.isNotEmpty) {
      return [for (final item in ranked.take(limit)) item.product];
    }
    return _store.products.take(limit).toList(growable: false);
  }

  @override
  void dispose() {
    _disposed = true;
    _store.removeListener(_onSourceChanged);
    _history.removeListener(_onSourceChanged);
    submit.dispose();
    forget.dispose();
    clearHistory.dispose();
    super.dispose();
  }
}
