/// Product-led search: recent queries, real categories and a short product
/// selection while the field is empty; type-ahead while typing; counted
/// results once submitted.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/motion.dart';
import '../../app/product_telemetry.dart';
import '../../app/shopper_copy.dart';
import '../../app/text_scale_policy.dart';
import '../../data/normalize/facets.dart' show FacetValue;
import '../../domain/product.dart';
import '../../main.dart';
import '../../reco/explainer.dart';
import '../boutique/boutique_tokens.dart';
import '../navigation/monetta_page_header.dart';
import '../product/quick_view.dart';
import 'catalog_controls.dart';
import 'catalog_query.dart';
import 'collection_screen.dart';
import 'product_card.dart';
import 'search_history.dart';

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
    monettaPageRoute(
      StoreScope(
        notifier: store,
        child: SearchScreen(initialQuery: initialQuery, prompt: prompt),
      ),
    ),
  );
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    this.initialQuery = '',
    this.prompt,
    this.history,
    super.key,
  });

  final String initialQuery;
  final String? prompt;

  /// Injected in tests. Production reads [SearchHistory.instance].
  final SearchHistory? history;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  late final String _prompt;
  late final SearchHistory _history;
  late bool _showResults;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _focus = FocusNode();
    _prompt = widget.prompt ?? nextSearchPrompt();
    _history = widget.history ?? SearchHistory.instance;
    _history.addListener(_onHistoryChanged);
    _showResults = widget.initialQuery.trim().isNotEmpty;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.initialQuery.isEmpty) _focus.requestFocus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Two shoppers on one device never see each other's searches. The scope
    // key matches the bag/wishlist convention: '' while signed out.
    final account = AccountScope.maybeOf(context)?.account;
    unawaited(_history.setScope(account?.localAccountId));
  }

  void _onHistoryChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _history.removeListener(_onHistoryChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<Product> _matches(String raw) =>
      searchProducts(StoreScope.of(context), raw);

  List<_SearchSuggestion> _suggestions(String raw) {
    final query = normalizeSearchText(raw);
    if (query.isEmpty) return const [];

    final byLabel = <String, _SearchSuggestion>{};

    void add(String? label, int priority) {
      final cleanLabel = label?.trim() ?? '';
      final normalizedLabel = normalizeSearchText(cleanLabel);
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
        final aStarts = normalizeSearchText(a.label).startsWith(query);
        final bStarts = normalizeSearchText(b.label).startsWith(query);
        if (aStarts != bStarts) return aStarts ? -1 : 1;

        final priority = a.priority.compareTo(b.priority);
        if (priority != 0) return priority;

        final length = a.label.length.compareTo(b.label.length);
        if (length != 0) return length;
        return a.label.compareTo(b.label);
      });
    return suggestions.take(6).toList();
  }

  /// Categories that actually have products behind them, in the catalog's own
  /// display order.
  List<String> _availableCategories() {
    final store = StoreScope.of(context);
    final slugs = <String>{
      for (final product in store.products)
        if (store.facetsFor(product.id)?.category?.value case final value?)
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
    final store = StoreScope.of(context);
    final recent = store.recentlyViewed(limit: limit);
    if (recent.isNotEmpty) return recent;
    final ranked = store.feed(limit: limit);
    if (ranked.isNotEmpty) {
      return [for (final item in ranked.take(limit)) item.product];
    }
    return store.products.take(limit).toList();
  }

  void _onChanged(String _) {
    setState(() => _showResults = false);
  }

  void _submit({bool remember = true}) {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() => _showResults = false);
      return;
    }

    final resultCount = _matches(query).length;
    setState(() => _showResults = true);
    _focus.unfocus();
    if (remember) unawaited(_history.remember(query));
    logProductEvent(
      context,
      ProductEvent.searchSubmitted,
      parameters: {
        'query_length': query.length,
        'result_count': resultCount,
      },
    );
  }

  void _runQuery(String query) {
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    _submit();
  }

  void _selectSuggestion(_SearchSuggestion suggestion) =>
      _runQuery(suggestion.label);

  void _clear() {
    _controller.clear();
    setState(() => _showResults = false);
    _focus.requestFocus();
  }

  void _edit() {
    setState(() => _showResults = false);
    _focus.requestFocus();
  }

  void _openCategory(String slug) {
    openCollection(
      context,
      CollectionScreen(
        title: categoryPlural(slug),
        filter: CollectionFilter(category: slug),
      ),
    );
  }

  /// The full result list as a real destination, so a shopper can keep the
  /// query and pick up the collection's own filters and ordering.
  void _openAllResults(String query) {
    openCollection(
      context,
      CollectionScreen(
        title: query,
        filter: CollectionFilter(query: query),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final query = _controller.text;
    final emptyQuery = query.trim().isEmpty;
    final matches = _matches(query);
    final suggestions = _suggestions(query);

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: buildMonettaPageAppBar(
        context,
        title: 'Buscar',
        backKey: const ValueKey('search-back-button'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _SearchField(
              controller: _controller,
              focusNode: _focus,
              prompt: _prompt,
              showClear: !emptyQuery,
              onChanged: _onChanged,
              onSubmitted: (_) => _submit(),
              onClear: _clear,
            ),
            Divider(height: 0.5, color: palette.hairline),
            Expanded(
              child: emptyQuery
                  ? _DiscoveryState(
                      key: const ValueKey('search-empty-state'),
                      history: _history.queries,
                      categories: _availableCategories(),
                      products: _discoveryProducts(),
                      onQuery: _runQuery,
                      onForget: (value) => unawaited(_history.forget(value)),
                      onClearHistory: () => unawaited(_history.clear()),
                      onCategory: _openCategory,
                    )
                  : _showResults
                      ? matches.isEmpty
                          ? _NoResults(
                              query: query.trim(),
                              categories: _availableCategories(),
                              onEdit: _edit,
                              onClear: _clear,
                              onCategory: _openCategory,
                            )
                          : _Results(
                              query: query.trim(),
                              products: matches,
                              onSeeAll: () => _openAllResults(query.trim()),
                            )
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

// ---------------------------------------------------------------------------
// Field
// ---------------------------------------------------------------------------

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.prompt,
    required this.showClear,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String prompt;
  final bool showClear;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final border = OutlineInputBorder(
      borderRadius: BoutiqueRadius.capsule,
      borderSide: BorderSide(color: palette.hairline),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BoutiqueSpace.gutter,
        BoutiqueSpace.md,
        BoutiqueSpace.gutter,
        BoutiqueSpace.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('search-query-field'),
              controller: controller,
              focusNode: focusNode,
              cursorColor: palette.ink,
              style: boutiqueText(size: 16, color: palette.ink),
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              decoration: InputDecoration(
                hintText: prompt,
                hintStyle: boutiqueText(
                  size: 15,
                  color: palette.inkMuted,
                  height: 1.2,
                ),
                isDense: true,
                filled: true,
                fillColor: palette.surfaceDeep,
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 21,
                  color: palette.inkMuted,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 46,
                  minHeight: BoutiqueSpace.tapTarget,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: BoutiqueSpace.lg,
                  vertical: 15,
                ),
                border: border,
                enabledBorder: border,
                focusedBorder: OutlineInputBorder(
                  borderRadius: BoutiqueRadius.capsule,
                  borderSide: BorderSide(color: palette.ink, width: 1.2),
                ),
                suffixIcon: showClear
                    ? IconButton(
                        key: const ValueKey('search-clear-button'),
                        tooltip: 'Borrar búsqueda',
                        onPressed: onClear,
                        icon: Icon(
                          Icons.cancel_rounded,
                          size: 20,
                          color: palette.inkMuted,
                        ),
                      )
                    : null,
                suffixIconConstraints: const BoxConstraints(
                  minWidth: BoutiqueSpace.tapTarget,
                  minHeight: BoutiqueSpace.tapTarget,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty query
// ---------------------------------------------------------------------------

/// What an empty field offers: the shopper's own recent searches, the
/// categories the catalog really has, and a short product selection.
///
/// A section with nothing behind it is not drawn at all — no empty headings.
class _DiscoveryState extends StatelessWidget {
  const _DiscoveryState({
    required this.history,
    required this.categories,
    required this.products,
    required this.onQuery,
    required this.onForget,
    required this.onClearHistory,
    required this.onCategory,
    super.key,
  });

  final List<String> history;
  final List<String> categories;
  final List<Product> products;
  final ValueChanged<String> onQuery;
  final ValueChanged<String> onForget;
  final VoidCallback onClearHistory;
  final ValueChanged<String> onCategory;

  @override
  Widget build(BuildContext context) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: BoutiqueSpace.xxl),
      children: [
        if (history.isNotEmpty) ...[
          _SectionTitle(
            title: 'Búsquedas recientes',
            actionLabel: 'Borrar historial',
            onAction: onClearHistory,
            actionKey: const ValueKey('search-history-clear'),
          ),
          for (final entry in history)
            _HistoryRow(
              key: ValueKey('search-history-$entry'),
              query: entry,
              onTap: () => onQuery(entry),
              onForget: () => onForget(entry),
            ),
          const SizedBox(height: BoutiqueSpace.lg),
        ],
        if (categories.isNotEmpty) ...[
          const _SectionTitle(title: 'Sugerencias'),
          for (final slug in categories)
            _CategoryRow(
              key: ValueKey('search-category-$slug'),
              slug: slug,
              onTap: () => onCategory(slug),
            ),
          const SizedBox(height: BoutiqueSpace.lg),
        ],
        if (products.isNotEmpty) ...[
          const _SectionTitle(title: 'Productos'),
          _ProductRail(products: products),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.actionLabel,
    this.onAction,
    this.actionKey,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Key? actionKey;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BoutiqueSpace.gutter,
        BoutiqueSpace.xl,
        BoutiqueSpace.gutter,
        BoutiqueSpace.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: boutiqueSectionHeading(color: palette.ink),
            ),
          ),
          if (actionLabel case final label? when onAction != null)
            TextButton(
              key: actionKey,
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, BoutiqueSpace.tapTarget),
                foregroundColor: palette.inkMuted,
              ),
              child: Text(
                label,
                style: boutiqueText(
                  size: 13,
                  color: palette.inkMuted,
                  weight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.query,
    required this.onTap,
    required this.onForget,
    super.key,
  });

  final String query;
  final VoidCallback onTap;
  final VoidCallback onForget;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Semantics(
      button: true,
      label: 'Buscar $query',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(left: BoutiqueSpace.gutter),
          child: Row(
            children: [
              Icon(
                Icons.history_rounded,
                size: 20,
                color: palette.inkMuted,
              ),
              const SizedBox(width: BoutiqueSpace.md),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    query,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: boutiqueText(size: 15, color: palette.ink),
                  ),
                ),
              ),
              SizedBox(
                width: BoutiqueSpace.tapTarget,
                height: BoutiqueSpace.tapTarget,
                child: IconButton(
                  tooltip: 'Quitar “$query” del historial',
                  onPressed: onForget,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: palette.inkMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Category row with the drawn mark the reference uses for each family.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.slug, required this.onTap, super.key});

  final String slug;
  final VoidCallback onTap;

  static const Map<String, IconData> _marks = <String, IconData>{
    'bolsa': Icons.shopping_bag_outlined,
    'cartera': Icons.account_balance_wallet_outlined,
    'monedero': Icons.savings_outlined,
    'tarjetero': Icons.credit_card_outlined,
    'reloj': Icons.watch_outlined,
    'cosmetiquera': Icons.brush_outlined,
    'set': Icons.category_outlined,
    'accesorio': Icons.auto_awesome_outlined,
    'perfume': Icons.local_florist_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Semantics(
      button: true,
      label: 'Ver ${categoryPlural(slug)}',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BoutiqueSpace.gutter,
            vertical: 12,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.surfaceDeep,
                  borderRadius: BoutiqueRadius.tile,
                ),
                child: Icon(
                  _marks[slug] ?? Icons.style_outlined,
                  size: 19,
                  color: palette.ink,
                ),
              ),
              const SizedBox(width: BoutiqueSpace.md),
              Expanded(
                child: Text(
                  categoryPlural(slug),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: boutiqueText(size: 15, color: palette.ink),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: palette.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductRail extends StatelessWidget {
  const _ProductRail({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cardWidth = (width * .40).clamp(140.0, 200.0);
    final caption = ProductTileDensity.compact.captionHeight *
        textScaleFactorFor(
          MediaQuery.textScalerOf(context),
          ProductTileDensity.compact.nameSize,
        );

    return SizedBox(
      key: const ValueKey('search-product-rail'),
      height: cardWidth * ProductTileDensity.compact.imageHeightFactor +
          caption +
          BoutiqueSpace.md,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(horizontal: BoutiqueSpace.gutter),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: BoutiqueSpace.md),
        itemBuilder: (context, index) {
          final product = products[index];
          return SizedBox(
            width: cardWidth,
            child: ProductCard(
              product: product,
              density: ProductTileDensity.compact,
              onQuickView: () => showProductQuickView(context, product),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Typing
// ---------------------------------------------------------------------------

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
        indent: BoutiqueSpace.gutter,
        color: context.boutique.hairline,
      ),
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        return Semantics(
          button: true,
          label: 'Buscar ${suggestion.label}',
          child: InkWell(
            onTap: () => onSelected(suggestion),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: 56,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: BoutiqueSpace.gutter,
                  vertical: BoutiqueSpace.md,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 19,
                      color: context.boutique.inkMuted,
                    ),
                    const SizedBox(width: BoutiqueSpace.md),
                    Expanded(
                      child: _SuggestionLabel(
                        label: suggestion.label,
                        query: query,
                      ),
                    ),
                  ],
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
    final normalStyle = boutiqueText(size: 15, color: context.boutique.ink);
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

// ---------------------------------------------------------------------------
// Submitted
// ---------------------------------------------------------------------------

class _Results extends StatelessWidget {
  const _Results({
    required this.query,
    required this.products,
    required this.onSeeAll,
  });

  final String query;
  final List<Product> products;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            BoutiqueSpace.gutter,
            BoutiqueSpace.lg,
            BoutiqueSpace.gutter,
            BoutiqueSpace.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '“$query”',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: boutiqueScreenTitle(size: 22, color: palette.ink),
                ),
              ),
              const SizedBox(width: BoutiqueSpace.md),
              // The count is taken from the same list the grid builds from.
              CatalogResultCount(count: products.length),
            ],
          ),
        ),
        Expanded(
          child: ProductCardGrid(
            key: const ValueKey('search-result-grid'),
            products: products,
            variant: ProductTileVariant.edgeToEdge,
            showWishlist: false,
            padding: const EdgeInsets.only(top: BoutiqueSpace.md),
            onQuickView: (product) => showProductQuickView(context, product),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              BoutiqueSpace.gutter,
              BoutiqueSpace.sm,
              BoutiqueSpace.gutter,
              BoutiqueSpace.md,
            ),
            child: BoutiqueButton(
              key: const ValueKey('search-see-all'),
              label: 'Ver todo',
              onPressed: onSeeAll,
              filled: false,
            ),
          ),
        ),
      ],
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({
    required this.query,
    required this.categories,
    required this.onEdit,
    required this.onClear,
    required this.onCategory,
  });

  final String query;
  final List<String> categories;
  final VoidCallback onEdit;
  final VoidCallback onClear;
  final ValueChanged<String> onCategory;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('search-no-results'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        CatalogEmptyState(
          title: 'Sin resultados',
          body: 'No encontramos piezas para “$query”. '
              'Prueba con otra palabra o explora una categoría.',
          actionLabel: 'Editar búsqueda',
          onAction: onEdit,
          suggestions: [
            for (final slug in categories.take(6))
              MonettaCapsuleChip(
                key: ValueKey('search-no-results-category-$slug'),
                label: categoryPlural(slug),
                onTap: () => onCategory(slug),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BoutiqueSpace.gutter,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('search-no-results-clear'),
              onPressed: onClear,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, BoutiqueSpace.tapTarget),
                foregroundColor: context.boutique.ink,
              ),
              child: Text(
                'Limpiar búsqueda',
                style: boutiqueText(
                  size: 14,
                  weight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
