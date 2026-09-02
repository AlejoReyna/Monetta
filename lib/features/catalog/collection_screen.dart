/// A real destination: one category, brand, or silhouette. Filters work.
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
import '../checkout/checkout_screen.dart';
import '../navigation/monetta_bottom_navigation.dart';
import 'catalog_browse_screen.dart';
import 'product_card.dart';

enum _Sort { newest, priceAsc, priceDesc }

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
/// changes the product grid.
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
    super.key,
  });

  final String title;
  final CollectionFilter filter;

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  late _CollectionFilters _filters;

  _CollectionFilters get _initialFilters => _CollectionFilters(
        brand: widget.filter.brand,
        silhouette: widget.filter.silhouette,
      );

  @override
  void initState() {
    super.initState();
    _filters = _initialFilters;
  }

  List<Product> _scopedItems() {
    final store = StoreScope.of(context);
    final queryTerms = <String>{
      if (widget.filter.query?.trim().toLowerCase() case final query?
          when query.isNotEmpty)
        query,
      for (final term in widget.filter.queryTerms)
        if (term.trim().isNotEmpty) term.trim().toLowerCase(),
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
      if (queryTerms.isEmpty) return true;
      final brand = facets?.brand?.value == null
          ? ''
          : brandLabel(facets!.brand!.value).toLowerCase();
      final searchable = <String>[
        product.title,
        brand,
        product.productType,
        ...product.tags,
        ...product.collectionHandles,
      ].join(' ').toLowerCase();
      return queryTerms.any(searchable.contains);
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
    final external = ExternalCatalogScope.maybeOf(context)?.items ?? const [];
    openCatalogBrowse(
      context,
      items: fullDeduplicatedCatalog(
        monettaItems: store.catalogItems,
        externalItems: external,
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
        openBag(context);
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
    if (result != null && mounted) setState(() => _filters = result);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final items = _items();
    final scopedItems = _scopedItems();
    final silhouettes = _silhouettesFor(scopedItems, store);

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Text(widget.title, style: display(16, weight: FontWeight.w500)),
        actions: [
          _CollectionFilterIconButton(
            activeCount: _filters.activeCountComparedTo(_initialFilters),
            onPressed: _openFilterSheet,
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Divider(height: 0.5),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (silhouettes.isNotEmpty)
            _SilhouetteSiblingRail(
              slugs: silhouettes,
              selected: _filters.silhouette,
              onSelected: (slug) => setState(() {
                _filters = _filters.copyWith(
                  silhouette: _filters.silhouette == slug ? null : slug,
                );
              }),
            ),
          const Divider(height: 0.5),
          Expanded(
            child: items.isEmpty
                ? _EmptyFilter(
                    onClear: _clearFilters,
                    suggestions: scopedItems.take(4).toList(),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 20, 12, 40),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.52,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 28,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) =>
                        ProductCard(product: items[index]),
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

class _SilhouetteSiblingRail extends StatelessWidget {
  const _SilhouetteSiblingRail({
    required this.slugs,
    required this.selected,
    required this.onSelected,
  });

  final List<String> slugs;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.monettaColors;
    final animationsDisabled = reduceMotion(context);

    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: slugs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final slug = slugs[index];
          final on = slug == selected;
          final labelColor = on ? colors.accentContent : colors.contentPrimary;

          return AnimatedScale(
            key: Key('collection-silhouette-$slug-motion'),
            scale: on ? 1.025 : 1,
            duration: animationsDisabled ? Duration.zero : kSnap,
            curve: kMotionCurve,
            child: ChoiceChip(
              key: Key('collection-silhouette-$slug'),
              label: Text(
                silhouetteLabel(slug),
                style: sans(
                  size: 13,
                  weight: on ? FontWeight.w600 : FontWeight.w400,
                  color: labelColor,
                ),
              ),
              selected: on,
              onSelected: (_) => onSelected(slug),
              color: WidgetStateProperty.resolveWith<Color>((states) {
                return states.contains(WidgetState.selected)
                    ? colors.navigationSelection
                    : Colors.transparent;
              }),
              backgroundColor: Colors.transparent,
              selectedColor: colors.navigationSelection,
              surfaceTintColor: Colors.transparent,
              side: BorderSide(
                color:
                    on ? colors.accent.withValues(alpha: 0.48) : colors.divider,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              chipAnimationStyle: ChipAnimationStyle(
                selectAnimation: animationsDisabled
                    ? AnimationStyle.noAnimation
                    : const AnimationStyle(
                        curve: kMotionCurve,
                        duration: kSwap,
                        reverseCurve: kMotionCurve,
                        reverseDuration: kSnap,
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyFilter extends StatelessWidget {
  const _EmptyFilter({required this.onClear, required this.suggestions});

  final VoidCallback onClear;
  final List<Product> suggestions;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 40),
      children: [
        Text('No hay piezas con ese filtro.', style: display(22)),
        const SizedBox(height: 10),
        Text(
          'Quita un filtro o mira otras piezas de la colección.',
          style: sans(size: 13, color: context.monettaColors.contentMuted),
        ),
        const SizedBox(height: 22),
        Align(
          alignment: Alignment.centerLeft,
          child: UnderlineLink(label: 'Limpiar filtros', onTap: onClear),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 36),
          Text('Otras piezas', style: display(22)),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.52,
              crossAxisSpacing: 8,
              mainAxisSpacing: 28,
            ),
            itemCount: suggestions.length,
            itemBuilder: (context, index) =>
                ProductCard(product: suggestions[index]),
          ),
        ],
      ],
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          key: const Key('collection-filter-button'),
          tooltip: 'Filtrar y ordenar',
          onPressed: onPressed,
          icon: const Icon(Icons.tune_rounded, size: 24),
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
                  color: context.monettaColors.contentPrimary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$activeCount',
                  style: sans(
                    size: 9,
                    color: context.monettaColors.canvas,
                    weight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CollectionFilterSheet extends StatefulWidget {
  const _CollectionFilterSheet({
    required this.initial,
    required this.reset,
    required this.brands,
    required this.silhouettes,
    required this.resultCount,
  });

  final _CollectionFilters initial;
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
    final colors = context.monettaColors;
    final resultCount = widget.resultCount(_selection);
    return FractionallySizedBox(
      heightFactor: 0.94,
      child: Material(
        color: context.monettaColors.surfaceRaised,
        clipBehavior: Clip.antiAlias,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 74,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      'Filtrar y ordenar',
                      style: display(20, weight: FontWeight.w600),
                    ),
                    Positioned(
                      right: 12,
                      child: IconButton(
                        key: const Key('collection-filter-close'),
                        tooltip: 'Cerrar filtros',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, size: 28),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 0.5, color: context.monettaColors.divider),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
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
                                label: switch (option) {
                                  _Sort.newest => 'Más nuevas',
                                  _Sort.priceAsc => 'Menor precio',
                                  _Sort.priceDesc => 'Mayor precio',
                                },
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
                  color: context.monettaColors.surfaceRaised,
                  border: Border(
                    top: BorderSide(
                      color: context.monettaColors.divider,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                  child: Row(
                    children: [
                      TextButton(
                        key: const Key('collection-filter-clear'),
                        onPressed: _clear,
                        style: TextButton.styleFrom(
                          foregroundColor: context.monettaColors.contentPrimary,
                        ),
                        child: Text(
                          'Limpiar',
                          style: sans(
                            size: 13,
                            weight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          key: const Key('collection-filter-apply'),
                          onPressed: () =>
                              Navigator.of(context).pop(_selection),
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.navigationSelection,
                            foregroundColor: colors.accentContent,
                            side: BorderSide(
                              color: colors.accent.withValues(alpha: 0.48),
                            ),
                            minimumSize: const Size.fromHeight(56),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            resultCount == 1
                                ? 'Ver 1 artículo'
                                : 'Ver $resultCount artículos',
                            style: sans(
                              size: 15,
                              color: colors.accentContent,
                              weight: FontWeight.w700,
                            ),
                          ),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.monettaColors.divider, width: 0.5),
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
                height: 78,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        section.label,
                        style: sans(size: 17, weight: FontWeight.w600),
                      ),
                    ),
                    Icon(
                      expanded ? Icons.remove_rounded : Icons.add_rounded,
                      size: 26,
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 8, 20),
              child: child,
            ),
        ],
      ),
    );
  }
}

class _CollectionFilterChoiceRow extends StatelessWidget {
  const _CollectionFilterChoiceRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.radio = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool radio;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              _CollectionSelectionMark(selected: selected, radio: radio),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: sans(
                    size: 15,
                    color: selected
                        ? context.monettaColors.contentPrimary
                        : context.monettaColors.contentMuted,
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
    return AnimatedContainer(
      duration: reduceMotion(context) ? Duration.zero : kSnap,
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected
            ? context.monettaColors.contentPrimary
            : context.monettaColors.surface,
        shape: radio ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: radio ? null : BorderRadius.circular(4),
        border: Border.all(
          color: selected
              ? context.monettaColors.contentPrimary
              : context.monettaColors.divider,
          width: 1.5,
        ),
      ),
      child: selected
          ? radio
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.monettaColors.canvas,
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox(width: 9, height: 9),
                )
              : Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: context.monettaColors.canvas,
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
