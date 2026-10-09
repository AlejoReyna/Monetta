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
import '../../domain/product.dart';
import '../../app/composition/app_scopes.dart';
import '../boutique/boutique_tokens.dart';
import '../product/quick_view.dart';
import 'catalog_controls.dart';
import 'collection_screen.dart';
import 'product_card.dart';
import 'search_history.dart';
import 'search_view_model.dart';

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
  late final SearchViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _focus = FocusNode();
    _prompt = widget.prompt ?? nextSearchPrompt();
    _history = widget.history ?? SearchHistory.instance;
    // The store is read without subscribing: the view model decides when a
    // store notification is worth a rebuild.
    final store = context.getInheritedWidgetOfExactType<StoreScope>()?.notifier;
    assert(store != null, 'StoreScope is missing from the tree');
    _viewModel = SearchViewModel(
      store: store!,
      history: _history,
      initialQuery: widget.initialQuery,
    );
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

  @override
  void dispose() {
    _viewModel.dispose();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String text) => _viewModel.queryChanged(text);

  void _submit() {
    final query = _controller.text.trim();
    unawaited(_viewModel.submit.execute(_controller.text));
    if (query.isEmpty) return;

    _focus.unfocus();
    logProductEvent(
      context,
      ProductEvent.searchSubmitted,
      parameters: {
        'query_length': query.length,
        'result_count': _viewModel.state.results.length,
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

  void _selectSuggestion(SearchSuggestion suggestion) =>
      _runQuery(suggestion.label);

  void _clear() {
    _controller.clear();
    _viewModel.clear();
    _focus.requestFocus();
  }

  void _edit() {
    _viewModel.edit();
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

    return Scaffold(
      backgroundColor: palette.canvas,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) {
            final state = _viewModel.state;
            final query = state.query;
            final emptyQuery = state.isEmptyQuery;
            return Column(
              children: [
                _SearchField(
                  controller: _controller,
                  focusNode: _focus,
                  prompt: _prompt,
                  showClear: !emptyQuery,
                  onChanged: _onChanged,
                  onSubmitted: (_) => _submit(),
                  onClear: _clear,
                  onBack: () => Navigator.of(context).pop(),
                ),
                Divider(height: 0.5, color: palette.hairline),
                Expanded(
                  child: emptyQuery
                      ? _DiscoveryState(
                          key: const ValueKey('search-empty-state'),
                          history: state.history,
                          categories: state.categories,
                          products: state.discovery,
                          onQuery: _runQuery,
                          onForget: (value) =>
                              unawaited(_viewModel.forget.execute(value)),
                          onClearHistory: () =>
                              unawaited(_viewModel.clearHistory.execute()),
                          onCategory: _openCategory,
                        )
                      : state.showResults
                          ? state.results.isEmpty
                              ? _NoResults(
                                  query: query.trim(),
                                  categories: state.categories,
                                  onEdit: _edit,
                                  onClear: _clear,
                                  onCategory: _openCategory,
                                )
                              : _Results(
                                  query: query.trim(),
                                  products: state.results,
                                  onSeeAll: () => _openAllResults(query.trim()),
                                )
                          : _SearchSuggestions(
                              query: query,
                              suggestions: state.suggestions,
                              onSelected: _selectSuggestion,
                            ),
                ),
              ],
            );
          },
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
    required this.onBack,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String prompt;
  final bool showClear;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final border = OutlineInputBorder(
      borderRadius: BoutiqueRadius.capsule,
      borderSide: BorderSide(color: palette.hairline),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BoutiqueSpace.sm,
        BoutiqueSpace.md,
        BoutiqueSpace.lg,
        BoutiqueSpace.md,
      ),
      child: Row(
        children: [
          SizedBox(
            width: BoutiqueSpace.tapTarget,
            height: BoutiqueSpace.tapTarget,
            child: IconButton(
              key: const ValueKey('search-back-button'),
              tooltip: 'Volver',
              onPressed: onBack,
              icon: Icon(
                Icons.arrow_back_rounded,
                size: 24,
                color: palette.ink,
              ),
            ),
          ),
          const SizedBox(width: BoutiqueSpace.sm),
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

class _SearchSuggestions extends StatelessWidget {
  const _SearchSuggestions({
    required this.query,
    required this.suggestions,
    required this.onSelected,
  });

  final String query;
  final List<SearchSuggestion> suggestions;
  final ValueChanged<SearchSuggestion> onSelected;

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
            padding: const EdgeInsets.fromLTRB(
              BoutiqueSpace.gutter,
              BoutiqueSpace.xs,
              BoutiqueSpace.gutter,
              BoutiqueSpace.xxl,
            ),
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
