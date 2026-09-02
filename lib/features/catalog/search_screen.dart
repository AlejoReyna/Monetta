/// Product-led search with a quiet, type-ahead-first entry state.
library;

import 'package:flutter/material.dart';

import '../../app/motion.dart';
import '../../app/product_telemetry.dart';
import '../../app/shopper_copy.dart';
import '../../app/theme.dart';
import '../../data/normalize/facets.dart' show FacetValue;
import '../../domain/product.dart';
import '../../main.dart';
import '../../reco/explainer.dart';
import 'product_card.dart';

/// A warmer invitation makes an empty search field feel like discovery rather
/// than a dead end. The sequence advances whenever the search is opened (and
/// when Home returns to the foreground), so a shopper sees each prompt before
/// the cycle repeats.
const List<String> kSearchPrompts = <String>[
  'Encuentra algo muy tú',
  'Tu próxima favorita espera',
  'Date un gusto, empieza por aquí',
  'Hoy es día de estrenarte',
  'Descubre una pieza para ti',
];

int _nextSearchPromptIndex = 0;

String nextSearchPrompt() {
  final prompt = kSearchPrompts[_nextSearchPromptIndex];
  _nextSearchPromptIndex = (_nextSearchPromptIndex + 1) % kSearchPrompts.length;
  return prompt;
}

Future<void> openSearch(
  BuildContext context, {
  String initialQuery = '',
  String? prompt,
}) async {
  final store = StoreScope.of(context);
  await Navigator.of(context).push<void>(
    monettaFadeRoute(
      StoreScope(
        notifier: store,
        child: SearchScreen(initialQuery: initialQuery, prompt: prompt),
      ),
    ),
  );
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({this.initialQuery = '', this.prompt, super.key});

  final String initialQuery;
  final String? prompt;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  late final String _prompt;
  late bool _showResults;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _focus = FocusNode();
    _prompt = widget.prompt ?? nextSearchPrompt();
    _showResults = widget.initialQuery.trim().isNotEmpty;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.initialQuery.isEmpty) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<String> _searchTerms(Product product) {
    final store = StoreScope.of(context);
    final facets = store.facetsFor(product.id);
    return [
      product.title,
      product.productType,
      ...product.tags,
      if (facets?.brand != null) brandLabel(facets!.brand!.value),
      if (facets?.category != null) categoryLabel(facets!.category!.value),
      if (facets?.silhouette != null)
        silhouetteLabel(facets!.silhouette!.value),
      ...?facets?.colors.map((facet) => colorLabel(facet.value)),
      ...?facets?.patterns.map((facet) => patternLabel(facet.value)),
    ].where((term) => term.trim().isNotEmpty).toList();
  }

  List<Product> _matches(String raw) {
    final normalized = _normalizeSearchText(raw);
    if (normalized.isEmpty) return const [];
    return StoreScope.of(context).products.where((product) {
      return _searchTerms(product).any(
        (term) => _normalizeSearchText(term).contains(normalized),
      );
    }).toList();
  }

  List<_SearchSuggestion> _suggestions(String raw) {
    final query = _normalizeSearchText(raw);
    if (query.isEmpty) return const [];

    final byLabel = <String, _SearchSuggestion>{};

    void add(String? label, int priority) {
      final cleanLabel = label?.trim() ?? '';
      final normalizedLabel = _normalizeSearchText(cleanLabel);
      if (cleanLabel.isEmpty || !normalizedLabel.contains(query)) return;

      final existing = byLabel[normalizedLabel];
      if (existing == null || priority < existing.priority) {
        byLabel[normalizedLabel] = _SearchSuggestion(
          label: cleanLabel,
          priority: priority,
        );
      }
    }

    for (final product in StoreScope.of(context).products) {
      final facets = StoreScope.of(context).facetsFor(product.id);
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
        final aStarts = _normalizeSearchText(a.label).startsWith(query);
        final bStarts = _normalizeSearchText(b.label).startsWith(query);
        if (aStarts != bStarts) return aStarts ? -1 : 1;

        final priority = a.priority.compareTo(b.priority);
        if (priority != 0) return priority;

        final length = a.label.length.compareTo(b.label.length);
        if (length != 0) return length;
        return a.label.compareTo(b.label);
      });
    return suggestions.take(6).toList();
  }

  void _onChanged(String _) {
    setState(() => _showResults = false);
  }

  void _submit() {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() => _showResults = false);
      return;
    }

    final resultCount = _matches(query).length;
    setState(() => _showResults = true);
    _focus.unfocus();
    logProductEvent(
      context,
      ProductEvent.searchSubmitted,
      parameters: {
        'query_length': query.length,
        'result_count': resultCount,
      },
    );
  }

  void _selectSuggestion(_SearchSuggestion suggestion) {
    _controller.value = TextEditingValue(
      text: suggestion.label,
      selection: TextSelection.collapsed(offset: suggestion.label.length),
    );
    _submit();
  }

  void _clear() {
    _controller.clear();
    setState(() => _showResults = false);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text;
    final emptyQuery = query.trim().isEmpty;
    final matches = _matches(query);
    final suggestions = _suggestions(query);
    final colors = context.monettaColors;
    final fieldBorder = colors.contentPrimary.withValues(alpha: .16);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 20, 16),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    height: 56,
                    child: IconButton(
                      key: const ValueKey('search-back-button'),
                      tooltip: 'Volver',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, size: 30),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: TextField(
                        key: const ValueKey('search-query-field'),
                        controller: _controller,
                        focusNode: _focus,
                        cursorColor: colors.contentPrimary,
                        style: sans(size: 16, color: colors.contentPrimary),
                        textInputAction: TextInputAction.search,
                        onChanged: _onChanged,
                        onSubmitted: (_) => _submit(),
                        onTap: () {
                          if (_showResults && query.trim().isNotEmpty) {
                            setState(() => _showResults = false);
                          }
                        },
                        decoration: InputDecoration(
                          hintText: _prompt,
                          hintStyle: sans(
                            size: 14,
                            color: colors.contentMuted,
                            height: 1.2,
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: colors.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 17,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide(color: fieldBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide(color: fieldBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide(
                              color: colors.contentPrimary.withValues(
                                alpha: .34,
                              ),
                            ),
                          ),
                          suffixIcon: emptyQuery
                              ? null
                              : IconButton(
                                  key: const ValueKey('search-clear-button'),
                                  tooltip: 'Borrar búsqueda',
                                  onPressed: _clear,
                                  padding: EdgeInsets.zero,
                                  icon: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: colors.surfaceMuted,
                                      shape: BoxShape.circle,
                                    ),
                                    child: SizedBox(
                                      width: 30,
                                      height: 30,
                                      child: Icon(
                                        Icons.close,
                                        size: 19,
                                        color: colors.contentMuted,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: .5, color: colors.divider),
            Expanded(
              child: emptyQuery
                  ? const SizedBox(key: ValueKey('search-empty-state'))
                  : _showResults
                      ? matches.isEmpty
                          ? _NoResults(query: query.trim())
                          : _ResultGrid(products: matches)
                      : _SearchSuggestions(
                          query: query,
                          suggestions: suggestions,
                          onSelected: _selectSuggestion,
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchSuggestion {
  const _SearchSuggestion({required this.label, required this.priority});

  final String label;
  final int priority;
}

class _SearchSuggestions extends StatelessWidget {
  const _SearchSuggestions({
    required this.query,
    required this.suggestions,
    required this.onSelected,
  });

  final String query;
  final List<_SearchSuggestion> suggestions;
  final ValueChanged<_SearchSuggestion> onSelected;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return const SizedBox(key: ValueKey('search-no-suggestions'));
    }

    return ListView.separated(
      key: const ValueKey('search-suggestions'),
      padding: EdgeInsets.zero,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: suggestions.length,
      separatorBuilder: (context, _) => Divider(
        height: .5,
        color: context.monettaColors.divider,
      ),
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        return Semantics(
          button: true,
          label: 'Buscar ${suggestion.label}',
          child: InkWell(
            onTap: () => onSelected(suggestion),
            child: SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _SuggestionLabel(
                    label: suggestion.label,
                    query: query,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SuggestionLabel extends StatelessWidget {
  const _SuggestionLabel({required this.label, required this.query});

  final String label;
  final String query;

  @override
  Widget build(BuildContext context) {
    final normalStyle =
        sans(size: 16, color: context.monettaColors.contentPrimary);
    final matchStyle = normalStyle.copyWith(fontWeight: FontWeight.w700);
    final queryStart = label.toLowerCase().indexOf(query.trim().toLowerCase());

    if (queryStart < 0) return Text(label, style: normalStyle);

    final queryEnd = queryStart + query.trim().length;
    return Text.rich(
      TextSpan(
        style: normalStyle,
        children: [
          TextSpan(text: label.substring(0, queryStart)),
          TextSpan(
            text: label.substring(queryStart, queryEnd),
            style: matchStyle,
          ),
          TextSpan(text: label.substring(queryEnd)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Text(
          'Aún no encontramos piezas para “$query”.',
          style: sans(size: 15, color: context.monettaColors.contentMuted),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ResultGrid extends StatelessWidget {
  const _ResultGrid({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      key: const ValueKey('search-result-grid'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.52,
        crossAxisSpacing: 8,
        mainAxisSpacing: 28,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) => ProductCard(product: products[index]),
    );
  }
}

String _normalizeSearchText(String value) => value
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
