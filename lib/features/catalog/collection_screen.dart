/// A real destination: one category, brand, silhouette or Shopify collection.
///
/// The editorial banner gives the destination its identity; everything below
/// it is the shared catalog grid and the same filter vocabulary the product
/// list uses. There is deliberately no second catalog implementation here —
/// scoping is the only thing this screen adds.
library;

import '../navigation/adaptive_storefront_scaffold.dart';
import '../navigation/duo_workspace.dart';
import 'browse_detail_layout.dart';
import '../../platform/system_layout_context.dart';
import '../navigation/storefront_pane_scope.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/catalog_store.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../app/motion.dart';
import '../../app/shopper_copy.dart';
import '../../app/theme.dart';
import '../../domain/product.dart';
import '../../main.dart';
import '../../reco/explainer.dart';
import '../account/account_screen.dart';
import '../boutique/boutique_tokens.dart';
import '../boutique/client_guide_components.dart';
import '../boutique/guide_art.dart';
import '../checkout/checkout_screen.dart';
import '../navigation/guide_chrome.dart';
import '../navigation/guide_drawer.dart';
import '../navigation/monetta_bottom_navigation.dart';
import 'search_screen.dart';
import 'categories_screen.dart';
import 'catalog_controls.dart';
import 'catalog_query.dart';
import 'product_card.dart';
import 'search_history.dart';

enum CatalogInitialPanel { filters, sort }

enum _Sort { newest, oldest, priceAsc, priceDesc }

extension on _Sort {
  String get label => switch (this) {
        _Sort.newest => 'Más nuevos',
        _Sort.oldest => 'Más antiguos',
        _Sort.priceAsc => 'Precio: menor a mayor',
        _Sort.priceDesc => 'Precio: mayor a menor',
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
    this.query = '',
    this.sort = _Sort.newest,
    this.inStockOnly = false,
    this.offersOnly = false,
    this.newOnly = false,
    this.color,
    this.priceBand,
    this.brand,
    this.silhouette,
    this.category,
  });

  final String query;
  final _Sort sort;
  final bool inStockOnly;
  final bool offersOnly;
  final bool newOnly;
  final String? color;
  final String? priceBand;
  final String? brand;
  final String? silhouette;

  /// Category facet chosen with the pills under the banner. Null = all.
  final String? category;

  _CollectionFilters copyWith({
    String? query,
    _Sort? sort,
    bool? inStockOnly,
    bool? offersOnly,
    bool? newOnly,
    Object? color = _unchanged,
    Object? priceBand = _unchanged,
    Object? brand = _unchanged,
    Object? silhouette = _unchanged,
    Object? category = _unchanged,
  }) {
    return _CollectionFilters(
      query: query ?? this.query,
      sort: sort ?? this.sort,
      inStockOnly: inStockOnly ?? this.inStockOnly,
      offersOnly: offersOnly ?? this.offersOnly,
      newOnly: newOnly ?? this.newOnly,
      color: identical(color, _unchanged) ? this.color : color as String?,
      priceBand: identical(priceBand, _unchanged)
          ? this.priceBand
          : priceBand as String?,
      brand: identical(brand, _unchanged) ? this.brand : brand as String?,
      silhouette: identical(silhouette, _unchanged)
          ? this.silhouette
          : silhouette as String?,
      category:
          identical(category, _unchanged) ? this.category : category as String?,
    );
  }

  /// Mirrors the catalog's badge convention: ordering is not a filter, while
  /// availability, brand, and bag type are.
  int activeCountComparedTo(_CollectionFilters baseline) =>
      (inStockOnly ? 1 : 0) +
      (offersOnly ? 1 : 0) +
      (newOnly ? 1 : 0) +
      (color != null ? 1 : 0) +
      (priceBand != null ? 1 : 0) +
      (brand != baseline.brand ? 1 : 0) +
      (silhouette != baseline.silhouette ? 1 : 0) +
      (category != baseline.category ? 1 : 0);
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
    this.story,
    this.approvedNewArrival,
    this.initialPanel,
    super.key,
  });

  final String title;
  final CatalogInitialPanel? initialPanel;
  final String? story;
  final bool Function(Product)? approvedNewArrival;
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
  String get _localQuery => _filters.query;
  final _queryController = TextEditingController();
  int _visibleLimit = 40;
  bool _retrying = false;
  String? _refreshError;
  final ScrollController _scroll = ScrollController();

  void _apply(_CollectionFilters filters) {
    if (_queryController.text != filters.query) {
      _queryController.text = filters.query;
    }
    setState(() {
      _filters = filters;
      _visibleLimit = 40;
    });
  }

  bool get _hasHero =>
      widget.heroImageUrl != null || widget.heroImageAsset != null;

  String? get _bannerId {
    if (_hasHero) return null;
    final brand = widget.filter.brand;
    if (brand != null) {
      return const {
        'guess': 'B24',
        'tory_burch': 'B25',
        'marc_jacobs': 'B26',
        'kate_spade': 'B27',
        'coach': 'B28',
        'michael_kors': 'B29',
        'steve_madden': 'B30',
      }[brand];
    }
    final silhouette = widget.filter.silhouette;
    if (silhouette != null) {
      return const {
        'crossbody': 'B18',
        'tote': 'B19',
        'shoulder': 'B20',
        'satchel': 'B22',
        'wristlet': 'B10',
      }[silhouette];
    }
    return const {
      'bolsa': 'B08',
      'cartera': 'B21',
      'perfume': 'B16',
      'reloj': 'B11',
      'accesorio': 'B17',
      'tarjetero': 'B15',
    }[widget.filter.category];
  }

  _CollectionFilters get _initialFilters => _CollectionFilters(
        brand: widget.filter.brand,
        silhouette: widget.filter.silhouette,
        category: widget.filter.category,
      );

  @override
  void initState() {
    super.initState();
    _filters = _initialFilters;
    if (widget.initialPanel != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.initialPanel == CatalogInitialPanel.filters) {
          unawaited(_openFilterSheet());
        } else {
          unawaited(_openSort());
        }
      });
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    if (_retrying) return;
    final store = StoreScope.of(context);
    setState(() {
      _retrying = true;
      _refreshError = null;
    });
    try {
      final result = await store.syncWithShopify();
      if (!mounted) return;
      setState(() {
        if (result.outcome == CatalogSyncOutcome.failed) {
          _refreshError = 'No pudimos actualizar el catálogo.';
        }
        if (result.outcome == CatalogSyncOutcome.skippedNotConfigured) {
          _refreshError = 'La actualización del catálogo no está disponible.';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _refreshError = 'No pudimos actualizar el catálogo.');
      }
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
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
  List<Product> _scopedItems(String? category, [CatalogStore? source]) {
    final store = source ?? StoreScope.of(context);
    final query = normalizeSearchText(widget.filter.query ?? '');
    final queryTerms = <String>[
      for (final term in widget.filter.queryTerms)
        if (term.trim().isNotEmpty) term.trim(),
    ];
    return store.products.where((product) {
      final facets = store.facetsFor(product.id);
      if (widget.filter.category != null &&
          facets?.category?.value != widget.filter.category) {
        return false;
      }
      if (widget.filter.brand != null &&
          facets?.brand?.value != widget.filter.brand) {
        return false;
      }
      if (widget.filter.silhouette != null &&
          facets?.silhouette?.value != widget.filter.silhouette) {
        return false;
      }
      if (category != null && facets?.category?.value != category) {
        return false;
      }
      if (widget.filter.collectionHandle != null &&
          !product.collectionHandles.contains(
            widget.filter.collectionHandle,
          )) {
        return false;
      }
      // Same matcher the search screen counts with, so "Ver todo" lands on
      // the same number of pieces the shopper was just looking at.
      if (query.isNotEmpty &&
          !productMatchesNormalizedQuery(store, product, query)) {
        return false;
      }
      if (queryTerms.isNotEmpty &&
          !productMatchesAnyTerm(store, product, queryTerms)) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  List<Product> _items([_CollectionFilters? filters, CatalogStore? source]) {
    final selection = filters ?? _filters;
    final store = source ?? StoreScope.of(context);
    final items = _scopedItems(selection.category, store).where((product) {
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

    return selectCatalogProducts(
      store,
      items,
      query: selection.query,
      color: selection.color,
      priceBand: selection.priceBand,
      offersOnly: selection.offersOnly,
      newOnly: selection.newOnly,
      approvedNewArrival: widget.approvedNewArrival,
      availableOnly: selection.inStockOnly,
      order: CatalogOrder.values.byName(selection.sort.name),
    );
  }

  Future<void> _openSort() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final selected = await showCatalogOrder<_Sort>(
      context,
      selected: _filters.sort,
      options: _Sort.values,
      label: (sort) => sort.label,
      keyPrefix: 'collection',
    );
    if (selected != null && mounted) _apply(_filters.copyWith(sort: selected));
  }

  void _openFullCatalog() =>
      openCollection(context, const CollectionScreen(title: 'Catálogo'));

  void _handleBottomNavigation(MonettaBottomDestination destination) {
    switch (destination) {
      case MonettaBottomDestination.home:
        DuoWorkspace.navigatorFor(context).popUntil((route) => route.isFirst);
      case MonettaBottomDestination.catalog:
        unawaited(openCategories(context));
      case MonettaBottomDestination.bag:
        unawaited(openBag(context));
      case MonettaBottomDestination.account:
        unawaited(openAccount(context, controller: AccountScope.of(context)));
    }
  }

  void _clearFilters() {
    _apply(_initialFilters.copyWith(sort: _filters.sort));
  }

  List<String> _brandsFor(Iterable<Product> products, CatalogStore store) {
    final brands = <String>{
      for (final product in products)
        if (store.facetsFor(product.id)?.brand?.value case final value?) value,
    }.toList();
    brands.sort(
      (a, b) =>
          brandLabel(a).toLowerCase().compareTo(brandLabel(b).toLowerCase()),
    );
    return brands;
  }

  List<String> _silhouettesFor(Iterable<Product> products, CatalogStore store) {
    final silhouettes = <String>{
      for (final product in products)
        if (store.facetsFor(product.id)?.silhouette?.value case final value?)
          value,
    }.toList();
    silhouettes.sort(
      (a, b) => silhouetteLabel(
        a,
      ).toLowerCase().compareTo(silhouetteLabel(b).toLowerCase()),
    );
    return silhouettes;
  }

  Future<void> _openFilterSheet() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final store = StoreScope.of(context);
    final scopedItems = _scopedItems(widget.filter.category);
    final result = await showModalBottomSheet<_CollectionFilters>(
      context: context,
      anchorPoint: presentationAnchor(context),
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: context.monettaColors.scrim,
      builder: (_) => StoreScope(
        notifier: store,
        child: _CollectionFilterSheet(
          allowNew: widget.approvedNewArrival != null,
          initial: _filters,
          reset: _initialFilters,
          brands: _brandsFor(scopedItems, store),
          silhouettes: _silhouettesFor(scopedItems, store),
          resultCount: (selection) => _items(selection, store).length,
          title: widget.title,
          categories: {
            for (final p in scopedItems)
              if (store.facetsFor(p.id)?.category?.value case final value?)
                value,
          }.toList(),
          priceBands: {
            for (final p in scopedItems)
              for (final v in p.variants) store.rules.priceBandFor(v.price),
          }.toList(),
          colors: {
            for (final p in scopedItems)
              for (final variant in p.variants)
                ...catalogVariantColors(store, p, variant),
          }.toList()
            ..sort(),
        ),
      ),
    );
    // A dismissed sheet returns null and the applied filters stand.
    if (result != null && mounted) _apply(result);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final store = StoreScope.of(context);
    final items = _items();
    final activeCount = _filters.activeCountComparedTo(_initialFilters);

    return AdaptiveStorefrontScaffold(
      avoidReservedRegions: true,
      onSearch: () => unawaited(openSearch(context)),
      backgroundColor: palette.canvas,
      drawer: guideDrawer(context),
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          if (SystemLayoutScope.of(context).barEdge == SystemBarEdge.none ||
              !StorefrontPaneScope.ownsNavigationOf(context))
            _CollectionAppBar(onSearch: () => unawaited(openSearch(context))),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(widget.title, style: boutiqueText(size: 15)),
            ),
          ),
          if (_bannerId case final id?)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x0D242622),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: GuideBanner(id: id),
                ),
              ),
            )
          else if (_hasHero)
            SliverToBoxAdapter(
              child: CatalogEditorialBanner(
                title: widget.title,
                description: widget.description,
                imageUrl: widget.heroImageUrl,
                imageAsset: widget.heroImageAsset,
                onAction: _scrollToGrid,
                actionLabel: widget.ctaLabel,
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _queryController,
                    key: const Key('collection-local-search'),
                    decoration: InputDecoration(
                      labelText: 'Buscar producto',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon:
                          MediaQuery.textScalerOf(context).scale(1) > 1.3
                              ? null
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      key: const Key(
                                        'collection-sort-button',
                                      ),
                                      tooltip: 'Ordenar',
                                      onPressed: _openSort,
                                      icon: const GuideSemanticImage(
                                        id: 'icon:ordenar',
                                        width: 24,
                                        height: 24,
                                      ),
                                    ),
                                    _CollectionFilterIconButton(
                                      activeCount: activeCount,
                                      onPressed: _openFilterSheet,
                                    ),
                                  ],
                                ),
                    ),
                    onChanged: (value) =>
                        _apply(_filters.copyWith(query: value)),
                  ),
                  if (MediaQuery.textScalerOf(context).scale(1) > 1.3)
                    Wrap(
                      spacing: 16,
                      children: [
                        TextButton(
                          style: catalogTextButtonStyle(context),
                          key: const Key('collection-sort-button'),
                          onPressed: _openSort,
                          child: const Text('Ordenar'),
                        ),
                        _CollectionFilterIconButton(
                          activeCount: activeCount,
                          onPressed: _openFilterSheet,
                        ),
                      ],
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (_filters.priceBand != null)
                        InputChip(
                          labelStyle: boutiqueText(
                            size: 14,
                            color: context.boutique.ink,
                          ),
                          label: Text(
                            _priceBandCopy(
                              StoreScope.of(context),
                              _filters.priceBand!,
                            ),
                          ),
                          onDeleted: () =>
                              _apply(_filters.copyWith(priceBand: null)),
                        ),
                      if (_filters.newOnly)
                        InputChip(
                          labelStyle: boutiqueText(
                            size: 14,
                            color: context.boutique.ink,
                          ),
                          label: const Text('Nuevo'),
                          onDeleted: () =>
                              _apply(_filters.copyWith(newOnly: false)),
                        ),
                      if (_filters.category != _initialFilters.category &&
                          _filters.category != null)
                        InputChip(
                          labelStyle: boutiqueText(
                            size: 14,
                            color: context.boutique.ink,
                          ),
                          label: Text(categoryPlural(_filters.category!)),
                          onDeleted: () => _apply(
                            _filters.copyWith(
                              category: _initialFilters.category,
                            ),
                          ),
                        ),
                      if (_filters.offersOnly)
                        InputChip(
                          labelStyle: boutiqueText(
                            size: 14,
                            color: context.boutique.ink,
                          ),
                          label: const Text('Ofertas'),
                          onDeleted: () =>
                              _apply(_filters.copyWith(offersOnly: false)),
                        ),
                      if (_filters.color != null)
                        InputChip(
                          labelStyle: boutiqueText(
                            size: 14,
                            color: context.boutique.ink,
                          ),
                          label: Text(colorLabel(_filters.color!)),
                          onDeleted: () =>
                              _apply(_filters.copyWith(color: null)),
                        ),
                      if (_filters.inStockOnly)
                        InputChip(
                          labelStyle: boutiqueText(
                            size: 14,
                            color: context.boutique.ink,
                          ),
                          label: const Text('Disponibles'),
                          onDeleted: () =>
                              _apply(_filters.copyWith(inStockOnly: false)),
                        ),
                      if (_filters.brand != _initialFilters.brand &&
                          _filters.brand != null)
                        InputChip(
                          labelStyle: boutiqueText(
                            size: 14,
                            color: context.boutique.ink,
                          ),
                          label: Text(brandLabel(_filters.brand!)),
                          onDeleted: () => _apply(
                            _filters.copyWith(
                              brand: _initialFilters.brand,
                            ),
                          ),
                        ),
                      if (_filters.silhouette != _initialFilters.silhouette &&
                          _filters.silhouette != null)
                        InputChip(
                          labelStyle: boutiqueText(
                            size: 14,
                            color: context.boutique.ink,
                          ),
                          label: Text(silhouetteLabel(_filters.silhouette!)),
                          onDeleted: () => _apply(
                            _filters.copyWith(
                              silhouette: _initialFilters.silhouette,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      '${items.length} resultados',
                      key: const Key('collection-count'),
                      style: boutiqueText(
                        size: 13,
                        color: palette.inkMuted,
                      ),
                    ),
                  ),
                  if (activeCount > 0)
                    TextButton(
                      style: catalogTextButtonStyle(context),
                      key: const Key('collection-clear-inline'),
                      onPressed: _clearFilters,
                      child: const Text('Limpiar filtros'),
                    ),
                ],
              ),
            ),
          ),
          if (!store.ready)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_refreshError != null ||
              store.realtimeStatus == CatalogRealtimeStatus.invalid ||
              store.realtimeStatus == CatalogRealtimeStatus.reconnecting)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      _refreshError ??
                          'No pudimos actualizar el catálogo. Conservamos las piezas cargadas.',
                    ),
                    TextButton(
                      style: catalogTextButtonStyle(context),
                      onPressed: _retrying ? null : _retry,
                      child: Text(_retrying ? 'Actualizando…' : 'Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          if (store.ready &&
              items.isEmpty &&
              _refreshError == null &&
              store.realtimeStatus != CatalogRealtimeStatus.invalid &&
              store.realtimeStatus != CatalogRealtimeStatus.reconnecting)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyFilter(
                onClear: _clearFilters,
                onBrowseAll: _openFullCatalog,
                hasActiveFilter: activeCount > 0 || _localQuery.isNotEmpty,
                onClearQuery: _localQuery.isEmpty
                    ? null
                    : () => setState(() {
                          _queryController.clear();
                          _filters = _filters.copyWith(query: '');
                          _visibleLimit = 40;
                        }),
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
              sliver: _ProductSliverGrid(
                products: items.take(_visibleLimit).toList(),
                color: _filters.color,
                priceBand: _filters.priceBand,
                offersOnly: _filters.offersOnly,
                availableOnly: _filters.inStockOnly,
              ),
            ),
          if (items.length > _visibleLimit)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  style: catalogTextButtonStyle(context),
                  key: const Key('collection-load-more'),
                  onPressed: () => setState(() => _visibleLimit += 40),
                  child: const Text('Cargar más'),
                ),
              ),
            ),
          if (widget.story?.trim().isNotEmpty ?? false)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  key: const ValueKey('brand-story'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sobre la marca',
                      style: boutiqueSectionHeading(
                        context: context,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(widget.story!, style: boutiqueText(size: 14)),
                  ],
                ),
              ),
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
  const _ProductSliverGrid({
    required this.products,
    this.color,
    this.priceBand,
    this.offersOnly = false,
    this.availableOnly = false,
  });
  final String? color, priceBand;
  final bool offersOnly, availableOnly;

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) => SliverGrid(
        gridDelegate: productGridDelegate(
          context,
          availableWidth: constraints.crossAxisExtent,
          priceLines: tilePriceLinesFor(products),
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final product = products[index];
            final matching = matchingCatalogVariants(
              StoreScope.of(context),
              product,
              color: color,
              priceBand: priceBand,
              offersOnly: offersOnly,
              availableOnly: availableOnly,
            );
            return ProductCard(
              key: ValueKey('product-card-${product.id}'),
              product: product,
              initialVariantId: color != null ||
                      priceBand != null ||
                      offersOnly ||
                      availableOnly
                  ? matching.firstOrNull?.id
                  : null,
            );
          },
          childCount: products.length,
        ),
      ),
    );
  }
}

class _CollectionAppBar extends StatelessWidget {
  const _CollectionAppBar({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final bar = guideAppBar(context, onSearch: onSearch);
    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: palette.bar,
      surfaceTintColor: Colors.transparent,
      foregroundColor: palette.ink,
      centerTitle: true,
      titleSpacing: 0,
      leadingWidth: 56,
      leading: bar.leading,
      title: bar.title,
      actions: bar.actions,
    );
  }
}

class _EmptyFilter extends StatelessWidget {
  const _EmptyFilter({
    required this.onClear,
    required this.onBrowseAll,
    this.onClearQuery,
    required this.hasActiveFilter,
  });

  final VoidCallback onClear;
  final VoidCallback onBrowseAll;
  final bool hasActiveFilter;
  final VoidCallback? onClearQuery;

  @override
  Widget build(BuildContext context) {
    return CatalogEmptyState(
      title: 'Sin resultados',
      body: hasActiveFilter
          ? 'No hay piezas con ese filtro. Quita un filtro para volver a '
              'la colección completa.'
          : 'Muy pronto encontrarás nuevas piezas aquí.',
      actionLabel: onClearQuery != null
          ? 'Limpiar búsqueda'
          : hasActiveFilter
              ? 'Limpiar filtros'
              : null,
      onAction: onClearQuery ?? (hasActiveFilter ? onClear : null),
    );
  }
}

class _CollectionFilterIconButton extends StatelessWidget {
  const _CollectionFilterIconButton({
    required this.activeCount,
    required this.onPressed,
  });

  final int activeCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Semantics(
            button: true,
            label: 'Filtros',
            excludeSemantics: true,
            onTap: onPressed,
            child: Material(
              color: palette.surfaceDeep,
              shape: const CircleBorder(),
              child: InkWell(
                key: const Key('collection-filter-button'),
                customBorder: const CircleBorder(),
                onTap: onPressed,
                child: Tooltip(
                  message: 'Filtros',
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: AdjustmentsIcon(size: 22, color: palette.ink),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (activeCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: IgnorePointer(
                child: Container(
                  key: const Key('collection-filter-count'),
                  constraints: const BoxConstraints(
                    minWidth: 17,
                    minHeight: 17,
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: palette.ink,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$activeCount',
                    style: boutiqueEyebrow(size: 9, color: palette.canvas),
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
// Filter sheet
// ---------------------------------------------------------------------------

class _CollectionFilterSheet extends StatefulWidget {
  const _CollectionFilterSheet({
    required this.initial,
    required this.reset,
    required this.brands,
    required this.silhouettes,
    required this.resultCount,
    required this.title,
    this.categories = const [],
    this.colors = const [],
    this.priceBands = const [],
    this.allowNew = false,
  });
  final _CollectionFilters initial, reset;
  final List<String> brands, silhouettes, categories, colors, priceBands;
  final String title;
  final int Function(_CollectionFilters) resultCount;
  final bool allowNew;
  @override
  State<_CollectionFilterSheet> createState() => _CollectionFilterSheetState();
}

class _CollectionFilterSheetState extends State<_CollectionFilterSheet> {
  late _CollectionFilters _selection = widget.initial;
  late final _name = TextEditingController(text: widget.initial.query);
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _select(_CollectionFilters value) => setState(() => _selection = value);
  void _clear() {
    _name.clear();
    _select(widget.reset.copyWith(sort: _selection.sort));
  }

  Widget _section(String label, List<Widget> choices) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: boutiqueText(size: 17, weight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 12, children: choices),
          ],
        ),
      );
  @override
  Widget build(BuildContext context) {
    final count = widget.resultCount(_selection);
    final store = StoreScope.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: .94,
        child: Material(
          color: context.boutique.canvas,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Filtros',
                          style: boutiqueScreenTitle(
                            context: context,
                            size: 28,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('collection-filter-close'),
                        tooltip: 'Cerrar filtros',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: boutiqueText(size: 15)),
                        const SizedBox(height: 16),
                        TextField(
                          key: const Key('collection-filter-query'),
                          controller: _name,
                          decoration: const InputDecoration(
                            labelText: 'Nombre',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (value) => _select(
                            _selection.copyWith(query: value),
                          ),
                        ),
                        if (widget.categories.length > 1 &&
                            widget.reset.category == null)
                          _section('Categoría', [
                            for (final category in widget.categories)
                              FilterChip(
                                backgroundColor: context.boutique.canvas,
                                selectedColor: context.boutique.canvas,
                                elevation: 1,
                                shadowColor: const Color(0x0D242622),
                                shape: const StadiumBorder(),
                                labelStyle: boutiqueText(
                                  size: 14,
                                  color: context.boutique.ink,
                                ),
                                key: Key(
                                  'collection-filter-category-$category',
                                ),
                                label: Text(categoryPlural(category)),
                                selected: _selection.category == category,
                                side: BorderSide(
                                  color: _selection.category == category
                                      ? context.boutique.goldText
                                      : context.boutique.hairline,
                                ),
                                onSelected: (value) => _select(
                                  _selection.copyWith(
                                    category: value ? category : null,
                                  ),
                                ),
                              ),
                          ]),
                        if (widget.brands.isNotEmpty &&
                            widget.reset.brand == null)
                          _section('Marca', [
                            for (final brand in widget.brands)
                              FilterChip(
                                backgroundColor: context.boutique.canvas,
                                selectedColor: context.boutique.canvas,
                                elevation: 1,
                                shadowColor: const Color(0x0D242622),
                                shape: const StadiumBorder(),
                                labelStyle: boutiqueText(
                                  size: 14,
                                  color: context.boutique.ink,
                                ),
                                key: Key(
                                  'collection-filter-brand-$brand',
                                ),
                                label: Text(brandLabel(brand)),
                                selected: _selection.brand == brand,
                                side: BorderSide(
                                  color: _selection.brand == brand
                                      ? context.boutique.goldText
                                      : context.boutique.hairline,
                                ),
                                onSelected: (value) => _select(
                                  _selection.copyWith(
                                    brand: value ? brand : null,
                                  ),
                                ),
                              ),
                          ]),
                        if (widget.silhouettes.isNotEmpty &&
                            widget.reset.silhouette == null)
                          _section('Estilo', [
                            for (final style in widget.silhouettes)
                              FilterChip(
                                backgroundColor: context.boutique.canvas,
                                selectedColor: context.boutique.canvas,
                                elevation: 1,
                                shadowColor: const Color(0x0D242622),
                                shape: const StadiumBorder(),
                                labelStyle: boutiqueText(
                                  size: 14,
                                  color: context.boutique.ink,
                                ),
                                key: Key(
                                  'collection-filter-silhouette-$style',
                                ),
                                label: Text(silhouetteLabel(style)),
                                selected: _selection.silhouette == style,
                                side: BorderSide(
                                  color: _selection.silhouette == style
                                      ? context.boutique.goldText
                                      : context.boutique.hairline,
                                ),
                                onSelected: (value) => _select(
                                  _selection.copyWith(
                                    silhouette: value ? style : null,
                                  ),
                                ),
                              ),
                          ]),
                        if (widget.colors.isNotEmpty)
                          _section('Color', [
                            for (final color in widget.colors)
                              FilterChip(
                                backgroundColor: context.boutique.canvas,
                                selectedColor: context.boutique.canvas,
                                elevation: 1,
                                shadowColor: const Color(0x0D242622),
                                shape: const StadiumBorder(),
                                labelStyle: boutiqueText(
                                  size: 14,
                                  color: context.boutique.ink,
                                ),
                                key: Key(
                                  'collection-filter-color-$color',
                                ),
                                avatar: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: catalogColorSwatch(color),
                                    border: Border.all(
                                      color: context.boutique.hairline,
                                    ),
                                  ),
                                ),
                                label: Text(colorLabel(color)),
                                selected: _selection.color == color,
                                side: BorderSide(
                                  color: _selection.color == color
                                      ? context.boutique.goldText
                                      : context.boutique.hairline,
                                ),
                                onSelected: (value) => _select(
                                  _selection.copyWith(
                                    color: value ? color : null,
                                  ),
                                ),
                              ),
                          ]),
                        if (widget.priceBands.isNotEmpty)
                          _section('Precio', [
                            for (final band in widget.priceBands)
                              FilterChip(
                                backgroundColor: context.boutique.canvas,
                                selectedColor: context.boutique.canvas,
                                elevation: 1,
                                shadowColor: const Color(0x0D242622),
                                shape: const StadiumBorder(),
                                labelStyle: boutiqueText(
                                  size: 14,
                                  color: context.boutique.ink,
                                ),
                                key: Key(
                                  'collection-filter-price-$band',
                                ),
                                label: Text(_priceBandCopy(store, band)),
                                selected: _selection.priceBand == band,
                                side: BorderSide(
                                  color: _selection.priceBand == band
                                      ? context.boutique.goldText
                                      : context.boutique.hairline,
                                ),
                                onSelected: (value) => _select(
                                  _selection.copyWith(
                                    priceBand: value ? band : null,
                                  ),
                                ),
                              ),
                          ]),
                        if (widget.allowNew)
                          CheckboxListTile(
                            key: const Key('collection-filter-new'),
                            title: const Text('Nuevo'),
                            value: _selection.newOnly,
                            onChanged: (value) => _select(
                              _selection.copyWith(newOnly: value),
                            ),
                          ),
                        CheckboxListTile(
                          key: const Key('collection-filter-offers'),
                          title: const Text('Ofertas'),
                          value: _selection.offersOnly,
                          onChanged: (value) => _select(
                            _selection.copyWith(offersOnly: value),
                          ),
                        ),
                        CheckboxListTile(
                          key: const Key('collection-filter-stock'),
                          title: const Text('Disponibles'),
                          value: _selection.inStockOnly,
                          onChanged: (value) => _select(
                            _selection.copyWith(inStockOnly: value),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          TextButton(
                            style: catalogTextButtonStyle(context),
                            key: const Key('collection-filter-clear'),
                            onPressed: _clear,
                            child: const Text('Limpiar filtros'),
                          ),
                          TextButton(
                            style: catalogTextButtonStyle(context),
                            key: const Key('collection-filter-cancel'),
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancelar'),
                          ),
                        ],
                      ),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          '$count resultados',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      GuideGlassSurface(
                        halo: true,
                        child: BoutiqueButton(
                          key: const Key('collection-filter-apply'),
                          label: 'Aplicar filtros',
                          onPressed: () => Navigator.pop(context, _selection),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void openCollection(BuildContext context, CollectionScreen screen) {
  final store = StoreScope.of(context);
  final account = AccountScope.maybeOf(context);
  final content = HomeContentScope.maybeOf(context);
  Widget child =
      StoreScope(notifier: store, child: BrowseDetailLayout(child: screen));
  if (account != null) child = AccountScope(notifier: account, child: child);
  if (content != null) {
    child = HomeContentScope(notifier: content, child: child);
  }
  DuoWorkspace.navigatorFor(context).push(monettaFadeRoute(child));
}

String _priceBandCopy(CatalogStore store, String band) {
  double lower = 0;
  for (final entry in store.rules.priceBands) {
    final upper = entry.maxExclusive;
    if (entry.id == band) {
      if (upper == null) return '${formatShopperPrice(lower)} o más';
      if (lower == 0) return 'Menos de ${formatShopperPrice(upper)}';
      return '${formatShopperPrice(lower)} a menos de ${formatShopperPrice(upper)}';
    }
    if (upper != null) lower = upper;
  }
  return 'Precio';
}
