/// A real destination: one category, brand, silhouette or Shopify collection.
///
/// The editorial banner gives the destination its identity; everything below
/// it is the shared catalog grid and the same filter vocabulary the product
/// list uses. There is deliberately no second catalog implementation here —
/// scoping is the only thing this screen adds.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/catalog_store.dart';
import '../../app/motion.dart';
import '../../app/shopper_copy.dart';
import '../../app/theme.dart';
import '../../domain/product.dart';
import '../../app/composition/app_scopes.dart';
import '../../reco/explainer.dart';
import '../account/account_screen.dart';
import '../boutique/boutique_tokens.dart';
import '../checkout/checkout_screen.dart';
import '../navigation/monetta_bottom_navigation.dart';
import 'brand_screen.dart';
import 'catalog_browse_screen.dart';
import 'catalog_controls.dart';
import 'collection_view_model.dart';
import 'query/collection_filter.dart';
import 'product_card.dart';
import '../product/quick_view.dart';

export 'query/collection_filter.dart' show CollectionFilter;

extension on CollectionSort {
  String get label => switch (this) {
        CollectionSort.newest => 'Más nuevas',
        CollectionSort.priceAsc => 'Menor precio',
        CollectionSort.priceDesc => 'Mayor precio',
      };
}

/// Sections intentionally mirror the product catalog's filter panel, while
/// only offering facets that exist in the collection being viewed.
enum _CollectionFilterSection { sort, type, brand, availability }

extension on _CollectionFilterSection {
  String get label => switch (this) {
        _CollectionFilterSection.sort => 'Ordenar por',
        _CollectionFilterSection.type => 'Tipo de bolsa',
        _CollectionFilterSection.brand => 'Marca',
        _CollectionFilterSection.availability => 'Disponibilidad',
      };
}

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({
    required this.title,
    this.filter = const CollectionFilter(),
    this.description,
    this.heroImageUrl,
    this.heroImageAsset,
    this.ctaLabel,
    super.key,
  });

  final String title;
  final CollectionFilter filter;

  /// One short owner-authored line. Omitted when there is nothing real to say —
  /// the header then stands on its typography alone.
  final String? description;

  /// Editorial artwork for the banner. When both are null the screen renders
  /// the typographic header instead of a grey placeholder.
  final String? heroImageUrl;
  final String? heroImageAsset;

  /// Banner action. Defaults to "Ver la colección", which scrolls to the grid.
  final String? ctaLabel;

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  late final CatalogStore _store;
  late final CollectionViewModel _viewModel;
  final ScrollController _scroll = ScrollController();
  bool _titleInBar = false;

  bool get _hasHero =>
      widget.heroImageUrl != null || widget.heroImageAsset != null;

  @override
  void initState() {
    super.initState();
    // The store is read without subscribing: the view model decides when a
    // store notification is worth a rebuild.
    final store = context.getInheritedWidgetOfExactType<StoreScope>()?.notifier;
    assert(store != null, 'StoreScope is missing from the tree');
    _store = store!;
    _viewModel = CollectionViewModel(store: _store, filter: widget.filter);
    _scroll.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(CollectionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new destination keeps the shopper's applied choices; only the scope
    // and the "Limpiar" baseline follow it. The title is read from the widget.
    _viewModel.updateDestination(widget.filter);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// The destination's name belongs to the header. It only moves into the bar
  /// once the header has scrolled away, so the title is never printed twice.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final collapsed = _scroll.offset > 120;
    if (collapsed != _titleInBar) setState(() => _titleInBar = collapsed);
  }

  void _scrollToGrid() {
    if (!_scroll.hasClients) return;
    final target = _scroll.position.maxScrollExtent < 220
        ? _scroll.position.maxScrollExtent
        : 220.0;
    if (reduceMotion(context)) {
      _scroll.jumpTo(target);
      return;
    }
    unawaited(
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 420),
        curve: kMotionCurve,
      ),
    );
  }

  void _openFullCatalog() {
    openCatalogBrowse(
      context,
      products: _store.products,
      facetsById: _store.facetsById,
    );
  }

  void _handleBottomNavigation(MonettaBottomDestination destination) {
    switch (destination) {
      case MonettaBottomDestination.home:
        Navigator.of(context).popUntil((route) => route.isFirst);
      case MonettaBottomDestination.catalog:
        _openFullCatalog();
      case MonettaBottomDestination.bag:
        unawaited(openBag(context));
      case MonettaBottomDestination.account:
        unawaited(
          openAccount(
            context,
            controller: AccountScope.of(context),
          ),
        );
    }
  }

  Future<void> _openFilterSheet() async {
    final state = _viewModel.state;
    final result = await showModalBottomSheet<CollectionFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: context.monettaColors.scrim,
      builder: (_) => StoreScope(
        notifier: _store,
        child: _CollectionFilterSheet(
          initial: state.filters,
          reset: state.baseline,
          brands: state.brands,
          silhouettes: state.silhouettes,
          resultCount: _viewModel.countFor,
        ),
      ),
    );
    // A dismissed sheet returns null and the applied filters stand.
    if (result != null && mounted) _viewModel.applyFilters(result);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => _buildScaffold(context, _viewModel.state),
    );
  }

  Widget _buildScaffold(BuildContext context, CollectionViewState state) {
    final palette = context.boutique;
    final items = state.items;
    final activeCount = state.activeCount;
    final filters = state.filters;

    return Scaffold(
      backgroundColor: palette.canvas,
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          _CollectionAppBar(
            title: widget.title,
            showTitle: _titleInBar,
            onPhoto: _hasHero,
            activeCount: activeCount,
            onFilters: _openFilterSheet,
            heroImageUrl: widget.heroImageUrl,
            heroImageAsset: widget.heroImageAsset,
            description: widget.description,
            ctaLabel: widget.ctaLabel ?? 'Ver la colección',
            onCta: _scrollToGrid,
          ),
          if (!_hasHero)
            SliverToBoxAdapter(
              child: CatalogEditorialBanner(
                title: widget.title,
                description: widget.description,
              ),
            ),
          SliverToBoxAdapter(
            child: _CollectionToolbar(
              count: items.length,
              activeCount: activeCount,
              onClear: activeCount == 0 ? null : _viewModel.clearFilters,
              // Only when the destination really is one brand; a mixed
              // collection has no single marca to open.
              brandSlug: filters.brand,
              onOpenBrand: filters.brand == null
                  ? null
                  : () => unawaited(
                        openBrand(context, brandSlug: filters.brand!),
                      ),
            ),
          ),
          if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyFilter(
                onClear: _viewModel.clearFilters,
                onBrowseAll: _openFullCatalog,
                hasActiveFilter: activeCount > 0,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                BoutiqueSpace.gutter,
                BoutiqueSpace.lg,
                BoutiqueSpace.gutter,
                BoutiqueSpace.xxl,
              ),
              sliver: _ProductSliverGrid(products: items),
            ),
        ],
      ),
      bottomNavigationBar: MonettaBottomNavigation(
        current: MonettaBottomDestination.catalog,
        bagCount: state.bagCount,
        onSelected: _handleBottomNavigation,
      ),
    );
  }
}

/// The shared grid as a sliver, so a collection scrolls as one page — banner,
/// chips and products together — instead of a header above a nested list.
class _ProductSliverGrid extends StatelessWidget {
  const _ProductSliverGrid({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width - BoutiqueSpace.gutter * 2;
    return SliverGrid(
      gridDelegate: productGridDelegate(context, availableWidth: width),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final product = products[index];
          return ProductCard(
            key: ValueKey('product-card-${product.id}'),
            product: product,
            onQuickView: () => showProductQuickView(context, product),
          );
        },
        childCount: products.length,
      ),
    );
  }
}

class _CollectionAppBar extends StatelessWidget {
  const _CollectionAppBar({
    required this.title,
    required this.showTitle,
    required this.onPhoto,
    required this.activeCount,
    required this.onFilters,
    required this.heroImageUrl,
    required this.heroImageAsset,
    required this.description,
    required this.ctaLabel,
    required this.onCta,
  });

  final String title;
  final bool showTitle;
  final bool onPhoto;
  final int activeCount;
  final VoidCallback onFilters;
  final String? heroImageUrl;
  final String? heroImageAsset;
  final String? description;
  final String ctaLabel;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final foreground = onPhoto && !showTitle ? palette.onDark : palette.ink;
    // The banner and the bar are sized from one number so the photograph can
    // never be cropped by a taller bar than it was laid out for.
    final bannerHeight = onPhoto ? catalogBannerHeight(context) : null;

    return SliverAppBar(
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: onPhoto && !showTitle ? Colors.transparent : palette.bar,
      surfaceTintColor: Colors.transparent,
      foregroundColor: foreground,
      expandedHeight: bannerHeight,
      flexibleSpace: bannerHeight == null
          ? null
          : FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: CatalogEditorialBanner(
                title: title,
                description: description,
                imageUrl: heroImageUrl,
                imageAsset: heroImageAsset,
                actionLabel: ctaLabel,
                onAction: onCta,
                height: bannerHeight,
              ),
            ),
      title: showTitle
          ? Text(
              title,
              style: boutiqueHeaderName(color: palette.ink),
            )
          : null,
      actions: [
        _CollectionFilterIconButton(
          activeCount: activeCount,
          onPressed: onFilters,
          color: foreground,
        ),
        const SizedBox(width: BoutiqueSpace.xs),
      ],
    );
  }
}

/// Count, brand link and the way back to the unfiltered destination. It takes
/// no space at all when there is nothing to show: the filter button in the
/// bar is the only entry to ordering and filtering.
class _CollectionToolbar extends StatelessWidget {
  const _CollectionToolbar({
    required this.count,
    required this.activeCount,
    required this.onClear,
    required this.brandSlug,
    required this.onOpenBrand,
  });

  final int count;
  final int activeCount;
  final VoidCallback? onClear;
  final String? brandSlug;
  final VoidCallback? onOpenBrand;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final showCount = CatalogResultCount.visibleFor(context);
    final brand = brandSlug;
    final showBrand = brand != null && onOpenBrand != null;
    if (!showCount && !showBrand && onClear == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BoutiqueSpace.gutter,
        BoutiqueSpace.lg,
        BoutiqueSpace.gutter,
        0,
      ),
      // Wrap instead of Row+Spacer: on a narrow phone the count, the brand
      // link and the clear action can exceed 350pt together. Wrapping flows
      // the actions below instead of overflowing the row.
      child: Wrap(
        spacing: BoutiqueSpace.md,
        runSpacing: BoutiqueSpace.sm,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (showCount || showBrand)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showCount) CatalogResultCount(count: count),
                if (showCount && showBrand)
                  const SizedBox(width: BoutiqueSpace.md),
                if (showBrand)
                  Flexible(
                    child: TextButton(
                      key: const Key('collection-open-brand'),
                      onPressed: onOpenBrand,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, BoutiqueSpace.tapTarget),
                        padding: EdgeInsets.zero,
                        foregroundColor: palette.goldText,
                      ),
                      child: Text(
                        'Ver ${brandLabel(brand)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: boutiqueText(
                          size: 13,
                          weight: FontWeight.w600,
                          color: palette.goldText,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          if (onClear != null)
            TextButton(
              key: const Key('collection-clear-inline'),
              onPressed: onClear,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, BoutiqueSpace.tapTarget),
                foregroundColor: palette.inkMuted,
              ),
              child: Text(
                'Limpiar ($activeCount)',
                style: boutiqueText(
                  size: 13,
                  weight: FontWeight.w600,
                  color: palette.inkMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyFilter extends StatelessWidget {
  const _EmptyFilter({
    required this.onClear,
    required this.onBrowseAll,
    required this.hasActiveFilter,
  });

  final VoidCallback onClear;
  final VoidCallback onBrowseAll;
  final bool hasActiveFilter;

  @override
  Widget build(BuildContext context) {
    return CatalogEmptyState(
      title: 'Sin resultados',
      body: hasActiveFilter
          ? 'No hay piezas con ese filtro. Quita un filtro para volver a '
              'la colección completa.'
          : 'Muy pronto encontrarás nuevas piezas aquí.',
      actionLabel: hasActiveFilter ? 'Limpiar filtros' : 'Ver todo el catálogo',
      onAction: hasActiveFilter ? onClear : onBrowseAll,
    );
  }
}

class _CollectionFilterIconButton extends StatelessWidget {
  const _CollectionFilterIconButton({
    required this.activeCount,
    required this.onPressed,
    required this.color,
  });

  final int activeCount;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          key: const Key('collection-filter-button'),
          tooltip: 'Filtrar y ordenar',
          onPressed: onPressed,
          icon: Icon(Icons.tune_rounded, size: 24, color: color),
        ),
        if (activeCount > 0)
          Positioned(
            right: 3,
            top: 5,
            child: IgnorePointer(
              child: Container(
                key: const Key('collection-filter-count'),
                constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: context.boutique.ink,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$activeCount',
                  style: boutiqueEyebrow(
                    size: 9,
                    color: context.boutique.canvas,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Filter sheet
// ---------------------------------------------------------------------------

class _CollectionFilterSheet extends StatefulWidget {
  const _CollectionFilterSheet({
    required this.initial,
    required this.reset,
    required this.brands,
    required this.silhouettes,
    required this.resultCount,
  });

  final CollectionFilters initial;

  /// The destination's own filters. "Limpiar" returns here, never to the
  /// whole catalog.
  final CollectionFilters reset;
  final List<String> brands;
  final List<String> silhouettes;
  final int Function(CollectionFilters filters) resultCount;

  @override
  State<_CollectionFilterSheet> createState() => _CollectionFilterSheetState();
}

class _CollectionFilterSheetState extends State<_CollectionFilterSheet> {
  late CollectionFilters _selection = widget.initial;
  final Set<_CollectionFilterSection> _expanded = {
    _CollectionFilterSection.sort,
  };

  void _toggleExpanded(_CollectionFilterSection section) {
    setState(() {
      _expanded.contains(section)
          ? _expanded.remove(section)
          : _expanded.add(section);
    });
  }

  void _clear() => setState(() => _selection = widget.reset);

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final resultCount = widget.resultCount(_selection);
    return FractionallySizedBox(
      heightFactor: 0.94,
      child: Material(
        color: palette.canvas,
        clipBehavior: Clip.antiAlias,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 68,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      'Filtrar y ordenar',
                      style: boutiqueTitle(size: 20, color: palette.ink),
                    ),
                    Positioned(
                      left: BoutiqueSpace.sm,
                      child: TextButton(
                        key: const Key('collection-filter-cancel'),
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, BoutiqueSpace.tapTarget),
                          foregroundColor: palette.inkMuted,
                        ),
                        child: Text(
                          'Cancelar',
                          style: boutiqueText(
                            size: 14,
                            color: palette.inkMuted,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: BoutiqueSpace.sm,
                      child: IconButton(
                        key: const Key('collection-filter-close'),
                        tooltip: 'Cerrar filtros',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close_rounded,
                          size: 24,
                          color: palette.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 0.5, color: palette.hairline),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: BoutiqueSpace.gutter,
                  ),
                  child: Column(
                    children: [
                      _CollectionFilterAccordion(
                        section: _CollectionFilterSection.sort,
                        expanded:
                            _expanded.contains(_CollectionFilterSection.sort),
                        onTap: () =>
                            _toggleExpanded(_CollectionFilterSection.sort),
                        child: Column(
                          children: [
                            for (final option in CollectionSort.values)
                              _CollectionFilterChoiceRow(
                                key: Key(
                                  'collection-filter-sort-${option.name}',
                                ),
                                label: option.label,
                                selected: _selection.sort == option,
                                radio: true,
                                onTap: () => setState(
                                  () => _selection = _selection.copyWith(
                                    sort: option,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (widget.silhouettes.isNotEmpty)
                        _CollectionFilterAccordion(
                          section: _CollectionFilterSection.type,
                          expanded:
                              _expanded.contains(_CollectionFilterSection.type),
                          onTap: () =>
                              _toggleExpanded(_CollectionFilterSection.type),
                          child: Column(
                            children: [
                              for (final slug in widget.silhouettes)
                                _CollectionFilterChoiceRow(
                                  key: Key(
                                    'collection-filter-silhouette-$slug',
                                  ),
                                  label: silhouetteLabel(slug),
                                  selected: _selection.silhouette == slug,
                                  radio: true,
                                  onTap: () => setState(
                                    () => _selection = _selection.copyWith(
                                      silhouette: _selection.silhouette == slug
                                          ? null
                                          : slug,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (widget.brands.isNotEmpty)
                        _CollectionFilterAccordion(
                          section: _CollectionFilterSection.brand,
                          expanded: _expanded
                              .contains(_CollectionFilterSection.brand),
                          onTap: () =>
                              _toggleExpanded(_CollectionFilterSection.brand),
                          child: Column(
                            children: [
                              for (final brand in widget.brands)
                                _CollectionFilterChoiceRow(
                                  key: Key('collection-filter-brand-$brand'),
                                  label: brandLabel(brand),
                                  selected: _selection.brand == brand,
                                  radio: true,
                                  onTap: () => setState(
                                    () => _selection = _selection.copyWith(
                                      brand: _selection.brand == brand
                                          ? null
                                          : brand,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      _CollectionFilterAccordion(
                        section: _CollectionFilterSection.availability,
                        expanded: _expanded.contains(
                          _CollectionFilterSection.availability,
                        ),
                        onTap: () => _toggleExpanded(
                          _CollectionFilterSection.availability,
                        ),
                        child: _CollectionFilterChoiceRow(
                          key: const Key('collection-filter-stock'),
                          label: 'En existencia',
                          selected: _selection.inStockOnly,
                          onTap: () => setState(
                            () => _selection = _selection.copyWith(
                              inStockOnly: !_selection.inStockOnly,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.canvas,
                  border: Border(
                    top: BorderSide(color: palette.hairline, width: 0.5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    BoutiqueSpace.gutter,
                    BoutiqueSpace.md,
                    BoutiqueSpace.gutter,
                    BoutiqueSpace.md,
                  ),
                  child: Row(
                    children: [
                      TextButton(
                        key: const Key('collection-filter-clear'),
                        onPressed: _clear,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, BoutiqueSpace.tapTarget),
                          foregroundColor: palette.ink,
                        ),
                        child: Text(
                          'Limpiar',
                          style: boutiqueText(
                            size: 14,
                            weight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(width: BoutiqueSpace.md),
                      Expanded(
                        child: BoutiqueButton(
                          key: const Key('collection-filter-apply'),
                          label: resultCount == 1
                              ? 'Ver 1 pieza'
                              : 'Ver $resultCount piezas',
                          onPressed: () =>
                              Navigator.of(context).pop(_selection),
                        ),
                      ),
                    ],
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

class _CollectionFilterAccordion extends StatelessWidget {
  const _CollectionFilterAccordion({
    required this.section,
    required this.expanded,
    required this.onTap,
    required this.child,
  });

  final _CollectionFilterSection section;
  final bool expanded;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: palette.hairline, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          Semantics(
            button: true,
            expanded: expanded,
            child: InkWell(
              key: Key('collection-filter-${section.name}'),
              onTap: onTap,
              child: SizedBox(
                height: 68,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        section.label,
                        style: boutiqueText(
                          size: 16,
                          weight: FontWeight.w600,
                          color: palette.ink,
                        ),
                      ),
                    ),
                    Icon(
                      expanded ? Icons.remove_rounded : Icons.add_rounded,
                      size: 24,
                      color: palette.ink,
                    ),
                    const SizedBox(width: BoutiqueSpace.sm),
                  ],
                ),
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BoutiqueSpace.sm,
                0,
                BoutiqueSpace.sm,
                BoutiqueSpace.lg,
              ),
              child: child,
            ),
        ],
      ),
    );
  }
}

class _CollectionFilterChoiceRow extends StatelessWidget {
  const _CollectionFilterChoiceRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.radio = false,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool radio;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: BoutiqueSpace.tapTarget,
          child: Row(
            children: [
              _CollectionSelectionMark(selected: selected, radio: radio),
              const SizedBox(width: BoutiqueSpace.md),
              Expanded(
                child: Text(
                  label,
                  style: boutiqueText(
                    size: 15,
                    color: selected ? palette.ink : palette.inkMuted,
                    weight: selected ? FontWeight.w600 : FontWeight.w400,
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

class _CollectionSelectionMark extends StatelessWidget {
  const _CollectionSelectionMark({
    required this.selected,
    required this.radio,
  });

  final bool selected;
  final bool radio;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return AnimatedContainer(
      duration: reduceMotion(context) ? Duration.zero : kSnap,
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? palette.ink : palette.surface,
        shape: radio ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: radio ? null : BorderRadius.circular(4),
        border: Border.all(
          color: selected ? palette.ink : palette.hairline,
          width: 1.5,
        ),
      ),
      child: selected
          ? radio
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.canvas,
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox(width: 9, height: 9),
                )
              : Icon(
                  Icons.check_rounded,
                  size: 17,
                  color: palette.canvas,
                )
          : null,
    );
  }
}

void openCollection(BuildContext context, CollectionScreen screen) {
  final store = StoreScope.of(context);
  Navigator.of(context).push(
    monettaFadeRoute(
      StoreScope(notifier: store, child: screen),
    ),
  );
}
