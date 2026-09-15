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
import '../../app/mixed_feed.dart';
import '../../app/motion.dart';
import '../../app/shopper_copy.dart';
import '../../app/theme.dart';
import '../../domain/product.dart';
import '../../main.dart';
import '../../reco/explainer.dart';
import '../account/account_screen.dart';
import '../boutique/boutique_tokens.dart';
import '../checkout/checkout_screen.dart';
import '../navigation/monetta_bottom_navigation.dart';
import 'brand_screen.dart';
import 'catalog_browse_screen.dart';
import 'catalog_controls.dart';
import 'catalog_query.dart';
import 'product_card.dart';
import '../product/quick_view.dart';

enum _Sort { newest, priceAsc, priceDesc }

extension on _Sort {
  String get label => switch (this) {
        _Sort.newest => 'Más nuevas',
        _Sort.priceAsc => 'Menor precio',
        _Sort.priceDesc => 'Mayor precio',
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

/// The choices a shopper can make without changing the collection route.
///
/// A [CollectionFilter] describes the destination that was opened (for
/// example, Bolsas or a specific brand). This value describes only the
/// temporary controls in the filter sheet, so cancelling the sheet never
/// changes the product grid, and "Limpiar" returns to the destination rather
/// than to the whole catalog.
class _CollectionFilters {
  const _CollectionFilters({
    this.sort = _Sort.newest,
    this.inStockOnly = false,
    this.brand,
    this.silhouette,
  });

  final _Sort sort;
  final bool inStockOnly;
  final String? brand;
  final String? silhouette;

  _CollectionFilters copyWith({
    _Sort? sort,
    bool? inStockOnly,
    Object? brand = _unchanged,
    Object? silhouette = _unchanged,
  }) {
    return _CollectionFilters(
      sort: sort ?? this.sort,
      inStockOnly: inStockOnly ?? this.inStockOnly,
      brand: identical(brand, _unchanged) ? this.brand : brand as String?,
      silhouette: identical(silhouette, _unchanged)
          ? this.silhouette
          : silhouette as String?,
    );
  }

  /// Mirrors the catalog's badge convention: ordering is not a filter, while
  /// availability, brand, and bag type are.
  int activeCountComparedTo(_CollectionFilters baseline) =>
      (inStockOnly ? 1 : 0) +
      (brand != baseline.brand ? 1 : 0) +
      (silhouette != baseline.silhouette ? 1 : 0);
}

const Object _unchanged = Object();

class CollectionFilter {
  const CollectionFilter({
    this.category,
    this.brand,
    this.silhouette,
    this.query,
    this.queryTerms = const [],
    this.collectionHandle,
  });

  final String? category;
  final String? brand;
  final String? silhouette;
  final String? query;
  final List<String> queryTerms;
  final String? collectionHandle;
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
  late _CollectionFilters _filters;
  final ScrollController _scroll = ScrollController();
  bool _titleInBar = false;

  bool get _hasHero =>
      widget.heroImageUrl != null || widget.heroImageAsset != null;

  _CollectionFilters get _initialFilters => _CollectionFilters(
        brand: widget.filter.brand,
        silhouette: widget.filter.silhouette,
      );

  @override
  void initState() {
    super.initState();
    _filters = _initialFilters;
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
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

  /// Everything the destination contains, before the sheet's own choices.
  List<Product> _scopedItems() {
    final store = StoreScope.of(context);
    final queryTerms = <String>{
      if (widget.filter.query?.trim() case final query? when query.isNotEmpty)
        query,
      for (final term in widget.filter.queryTerms)
        if (term.trim().isNotEmpty) term.trim(),
    };
    return store.products.where((product) {
      final facets = store.facetsFor(product.id);
      if (widget.filter.category != null &&
          facets?.category?.value != widget.filter.category) {
        return false;
      }
      if (widget.filter.collectionHandle != null &&
          product.collectionHandles.isNotEmpty &&
          !product.collectionHandles.contains(widget.filter.collectionHandle)) {
        return false;
      }
      // Same matcher the search screen counts with, so "Ver todo" lands on
      // the same number of pieces the shopper was just looking at.
      return productMatchesAnyTerm(store, product, queryTerms);
    }).toList(growable: false);
  }

  List<Product> _items([_CollectionFilters? filters]) {
    final selection = filters ?? _filters;
    final store = StoreScope.of(context);
    final items = _scopedItems().where((product) {
      final facets = store.facetsFor(product.id);
      if (selection.brand != null && facets?.brand?.value != selection.brand) {
        return false;
      }
      if (selection.silhouette != null &&
          facets?.silhouette?.value != selection.silhouette) {
        return false;
      }
      return !selection.inStockOnly || product.isInStock;
    }).toList();

    items.sort((a, b) {
      switch (selection.sort) {
        case _Sort.priceAsc:
          return a.price.compareTo(b.price);
        case _Sort.priceDesc:
          return b.price.compareTo(a.price);
        case _Sort.newest:
          return b.createdAt.compareTo(a.createdAt);
      }
    });
    return items;
  }

  void _openFullCatalog() {
    final store = StoreScope.of(context);
    openCatalogBrowse(
      context,
      items: fullDeduplicatedCatalog(
        monettaItems: store.catalogItems,
        externalItems: const [],
      ),
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

  void _clearFilters() {
    setState(() => _filters = _initialFilters);
  }

  List<String> _brandsFor(Iterable<Product> products, CatalogStore store) {
    final brands = <String>{
      for (final product in products)
        if (store.facetsFor(product.id)?.brand?.value case final value?) value,
    }.toList();
    brands.sort(
      (a, b) => brandLabel(a).toLowerCase().compareTo(
            brandLabel(b).toLowerCase(),
          ),
    );
    return brands;
  }

  List<String> _silhouettesFor(
    Iterable<Product> products,
    CatalogStore store,
  ) {
    final silhouettes = <String>{
      for (final product in products)
        if (store.facetsFor(product.id)?.silhouette?.value case final value?)
          value,
    }.toList();
    silhouettes.sort(
      (a, b) => silhouetteLabel(a).toLowerCase().compareTo(
            silhouetteLabel(b).toLowerCase(),
          ),
    );
    return silhouettes;
  }

  Future<void> _openFilterSheet() async {
    final store = StoreScope.of(context);
    final scopedItems = _scopedItems();
    final result = await showModalBottomSheet<_CollectionFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: context.monettaColors.scrim,
      builder: (_) => StoreScope(
        notifier: store,
        child: _CollectionFilterSheet(
          initial: _filters,
          reset: _initialFilters,
          brands: _brandsFor(scopedItems, store),
          silhouettes: _silhouettesFor(scopedItems, store),
          resultCount: (selection) => _items(selection).length,
        ),
      ),
    );
    // A dismissed sheet returns null and the applied filters stand.
    if (result != null && mounted) setState(() => _filters = result);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final store = StoreScope.of(context);
    final items = _items();
    final scopedItems = _scopedItems();
    final silhouettes = _silhouettesFor(scopedItems, store);
    final activeCount = _filters.activeCountComparedTo(_initialFilters);

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
          if (silhouettes.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: BoutiqueSpace.lg),
                child: MonettaChipRail(
                  children: [
                    for (final slug in silhouettes)
                      MonettaCapsuleChip(
                        key: Key('collection-silhouette-$slug'),
                        label: silhouetteLabel(slug),
                        selected: _filters.silhouette == slug,
                        onTap: () => setState(() {
                          _filters = _filters.copyWith(
                            silhouette:
                                _filters.silhouette == slug ? null : slug,
                          );
                        }),
                      ),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: _CollectionToolbar(
              count: items.length,
              activeCount: activeCount,
              onFilters: _openFilterSheet,
              onClear: activeCount == 0 ? null : _clearFilters,
              // Only when the destination really is one brand; a mixed
              // collection has no single marca to open.
              brandSlug: _filters.brand,
              onOpenBrand: _filters.brand == null
                  ? null
                  : () => unawaited(
                        openBrand(context, brandSlug: _filters.brand!),
                      ),
            ),
          ),
          if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyFilter(
                onClear: _clearFilters,
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
        bagCount: store.bagQuantity,
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
      backgroundColor:
          onPhoto && !showTitle ? Colors.transparent : palette.canvas,
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
              style: boutiqueDisplay(19, color: palette.ink),
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

/// Count, ordering and the way back to the unfiltered destination.
class _CollectionToolbar extends StatelessWidget {
  const _CollectionToolbar({
    required this.count,
    required this.activeCount,
    required this.onFilters,
    required this.onClear,
    required this.brandSlug,
    required this.onOpenBrand,
  });

  final int count;
  final int activeCount;
  final VoidCallback onFilters;
  final VoidCallback? onClear;
  final String? brandSlug;
  final VoidCallback? onOpenBrand;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BoutiqueSpace.gutter,
        BoutiqueSpace.lg,
        BoutiqueSpace.gutter,
        0,
      ),
      // Wrap instead of Row+Spacer: on a narrow phone the count, the brand
      // link, the clear action and the sort chip can exceed 350pt together.
      // Wrapping flows the actions below instead of overflowing the row.
      child: Wrap(
        spacing: BoutiqueSpace.md,
        runSpacing: BoutiqueSpace.sm,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CatalogResultCount(count: count),
              if (brandSlug case final slug? when onOpenBrand != null) ...[
                const SizedBox(width: BoutiqueSpace.md),
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
                      'Ver ${brandLabel(slug)}',
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
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              const SizedBox(width: BoutiqueSpace.sm),
              // The chip names the control, not the current choice: the sheet
              // is the one place that shows and changes the ordering.
              MonettaCapsuleChip(
                key: const Key('collection-sort-chip'),
                label: 'Ordenar',
                showCaret: true,
                onTap: onFilters,
              ),
            ],
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

  final _CollectionFilters initial;

  /// The destination's own filters. "Limpiar" returns here, never to the
  /// whole catalog.
  final _CollectionFilters reset;
  final List<String> brands;
  final List<String> silhouettes;
  final int Function(_CollectionFilters filters) resultCount;

  @override
  State<_CollectionFilterSheet> createState() => _CollectionFilterSheetState();
}

class _CollectionFilterSheetState extends State<_CollectionFilterSheet> {
  late _CollectionFilters _selection = widget.initial;
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
                      style: boutiqueDisplay(20, color: palette.ink),
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
                            for (final option in _Sort.values)
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
