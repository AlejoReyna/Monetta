/// Full-catalog browsing for Monetta's bags and accessories.
///
/// Photography owns the screen. Filtering is handled by a single expandable
/// sheet with category and bag-specific facets; the header's filter button is
/// the only entry to it.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/motion.dart';
import '../../app/shopper_copy.dart';
import '../../app/theme.dart';
import '../../data/normalize/facets.dart';
import '../../domain/product.dart';
import '../../main.dart';
import '../account/account_screen.dart';
import '../boutique/boutique_tokens.dart';
import '../checkout/checkout_screen.dart';
import '../navigation/monetta_bottom_navigation.dart';
import '../product/product_screen.dart';
import 'catalog_controls.dart';
import 'product_tile.dart';
import 'quick_add_button.dart';
import 'search_screen.dart';

enum _CatalogSort { featured, newest, priceAsc, priceDesc }

extension on _CatalogSort {
  String get label => switch (this) {
        _CatalogSort.featured => 'Destacados',
        _CatalogSort.newest => 'Más recientes',
        _CatalogSort.priceAsc => 'Precio: de menor a mayor',
        _CatalogSort.priceDesc => 'Precio: de mayor a menor',
      };
}

enum _FilterSection { sort, category, type, brand, price, color, availability }

extension on _FilterSection {
  String get label => switch (this) {
        _FilterSection.sort => 'Ordenar por',
        _FilterSection.category => 'Categoría',
        _FilterSection.type => 'Tipo de bolsa',
        _FilterSection.brand => 'Marca',
        _FilterSection.price => 'Precio',
        _FilterSection.color => 'Color',
        _FilterSection.availability => 'Disponibilidad',
      };
}

class _CatalogFilters {
  const _CatalogFilters({
    this.sort = _CatalogSort.featured,
    this.categories = const <String>{},
    this.types = const <String>{},
    this.brands = const <String>{},
    this.priceBands = const <String>{},
    this.colors = const <String>{},
    this.inStockOnly = false,
  });

  final _CatalogSort sort;

  /// Canonical category keys as produced by [_categoryFor].
  final Set<String> categories;
  final Set<String> types;
  final Set<String> brands;
  final Set<String> priceBands;
  final Set<String> colors;
  final bool inStockOnly;

  int get activeCount =>
      categories.length +
      types.length +
      brands.length +
      priceBands.length +
      colors.length +
      (inStockOnly ? 1 : 0);
}

/// Gap at each end of the header, outside the 48pt button slots.
const double _kHeaderEdgeInset = 4;

/// Width reserved on both sides of the title: the two end buttons' slots plus
/// the edge gap. The leading side reserves the same, empty or not.
const double _kHeaderSlotWidth =
    _kHeaderEdgeInset + BoutiqueSpace.tapTarget * 2;

const Map<String, List<String>> _bagTypeTerms = {
  'Crossbody': ['crossbody', 'bandolera', 'messenger'],
  'Tote': ['tote'],
  'Bolsa de hombro': ['shoulder', 'hombro'],
  'Satchel': ['satchel'],
  'Bolsa de mano': ['handbag', 'top handle', 'bolsa de mano'],
  'Mochila': ['backpack', 'mochila'],
  'Clutch': ['clutch'],
  'Cangurera': ['belt bag', 'waist bag', 'cangurera'],
  'Bolsa cubeta': ['bucket', 'cubeta'],
  'Cartera': ['wallet', 'cartera'],
  'Tarjetero': ['card holder', 'cardholder', 'tarjetero'],
};

const Map<String, List<String>> _colorTerms = {
  'Negro': ['negro', 'negra', 'black'],
  'Café': ['cafe', 'café', 'brown', 'cognac'],
  'Beige': ['beige', 'arena', 'sand', 'camel', 'nude'],
  'Blanco': ['blanco', 'blanca', 'white', 'ivory', 'hueso'],
  'Gris': ['gris', 'gray', 'grey'],
  'Azul': ['azul', 'blue', 'navy', 'marino', 'mezclilla'],
  'Rosa': ['rosa', 'pink', 'blush'],
  'Rojo': ['rojo', 'roja', 'red'],
  'Vino': ['vino', 'burgundy', 'bordo'],
  'Verde': ['verde', 'green', 'olive', 'oliva'],
  'Morado': ['morado', 'morada', 'purple', 'lila'],
  'Amarillo': ['amarillo', 'amarilla', 'yellow'],
  'Naranja': ['naranja', 'orange'],
  'Dorado': ['dorado', 'gold'],
  'Plateado': ['plateado', 'silver'],
};

const Map<String, String> _catalogCategoryLabels = {
  'bolsa': 'Bolsas',
  'cartera': 'Carteras',
  'monedero': 'Monederos',
  'tarjetero': 'Tarjeteros',
  'reloj': 'Relojes',
  'cosmetiquera': 'Cosmetiqueras',
  'set': 'Sets',
  'accesorio': 'Accesorios',
  'perfume': 'Perfumes',
  'otros': 'Otros',
};

const List<String> _catalogCategoryOrder = [
  'bolsa',
  'cartera',
  'monedero',
  'tarjetero',
  'reloj',
  'cosmetiquera',
  'set',
  'accesorio',
  'perfume',
  'otros',
];

String _categoryLabel(String category) =>
    _catalogCategoryLabels[category] ?? categoryPlural(category);

String _categoryFor(CanonicalFacets? facets) {
  final rawCategory = facets?.category?.value.trim().toLowerCase();

  // A piece without a category facet has no bag/wallet/perfume vertical to
  // fall back on (the vertical was itself derived from the category), so it
  // is simply "otros".
  return switch (rawCategory) {
    'bolsas' || 'handbag' || 'handbags' => 'bolsa',
    'carteras' || 'wallet' || 'wallets' => 'cartera',
    'monederos' => 'monedero',
    'tarjeteros' || 'card case' || 'card cases' => 'tarjetero',
    'relojes' || 'watch' || 'watches' => 'reloj',
    'cosmetiqueras' || 'cosmetic case' || 'cosmetic cases' => 'cosmetiquera',
    'sets' => 'set',
    'accesorios' || 'accessory' || 'accessories' => 'accesorio',
    'perfumes' ||
    'fragancia' ||
    'fragancias' ||
    'fragrance' ||
    'fragrances' =>
      'perfume',
    final value? when value.isNotEmpty => value,
    _ => 'otros',
  };
}

/// Categories present in [products], in the canonical order and then
/// alphabetically by label.
List<String> _availableCategories(
  List<Product> products,
  Map<String, CanonicalFacets> facetsById,
) {
  final categories = {
    for (final product in products) _categoryFor(facetsById[product.id]),
  };
  return [
    for (final category in _catalogCategoryOrder)
      if (categories.remove(category)) category,
    ...categories.toList()
      ..sort((a, b) => _categoryLabel(a).compareTo(_categoryLabel(b))),
  ];
}

/// Identity of the product grid: it changes whenever the applied categories do.
String _sectionKeySuffix(_CatalogFilters filters) {
  if (filters.categories.isEmpty) return 'collection';
  return (filters.categories.toList()..sort()).join('+');
}

class CatalogBrowseScreen extends StatefulWidget {
  const CatalogBrowseScreen({
    required this.products,
    required this.facetsById,
    this.bagCount = 0,
    super.key,
  });

  final List<Product> products;

  /// Canonical facets by product id; a product without an entry simply has no
  /// category or brand facet.
  final Map<String, CanonicalFacets> facetsById;
  final int bagCount;

  @override
  State<CatalogBrowseScreen> createState() => _CatalogBrowseScreenState();
}

class _CatalogBrowseScreenState extends State<CatalogBrowseScreen> {
  _CatalogFilters _filters = const _CatalogFilters();

  List<Product> _visibleProducts([_CatalogFilters? filters]) => _filterCatalog(
        widget.products,
        widget.facetsById,
        query: '',
        filters: filters ?? _filters,
      );

  void _resetAll() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _filters = const _CatalogFilters();
    });
  }

  Future<void> _openFilters() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await showModalBottomSheet<_CatalogFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: context.monettaColors.scrim,
      builder: (sheetContext) => _CatalogFilterSheet(
        products: widget.products,
        facetsById: widget.facetsById,
        initial: _filters,
        visibleCount: (draft) => _visibleProducts(draft).length,
      ),
    );
    // Dismissing the sheet keeps the filters that were already applied.
    if (result != null && mounted) setState(() => _filters = result);
  }

  @override
  Widget build(BuildContext context) {
    final visibleProducts = _visibleProducts();

    return Scaffold(
      // Never `extendBody`: the last row of products must not sit under the
      // navigation bar, and this screen has no floating bar competing with it.
      extendBody: false,
      backgroundColor: context.boutique.canvas,
      appBar: AppBar(
        toolbarHeight: 76,
        backgroundColor: context.boutique.bar,
        foregroundColor: context.boutique.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        // One button at the start and two at the end: a centred title meets
        // the end buttons first and is pushed off centre. Both sides reserve
        // the same slot, so "Productos" stays on the screen's centre.
        centerTitle: true,
        titleSpacing: BoutiqueSpace.sm,
        leadingWidth: _kHeaderSlotWidth,
        leading: const _HeaderBackSlot(),
        // The FittedBox only shrinks the block when it does not fit between
        // the slots; it never truncates it or runs it under a button.
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Productos',
                textAlign: TextAlign.center,
                style: boutiqueScreenTitle(color: context.boutique.ink),
              ),
              const SizedBox(height: 2),
              // Counted from the very list the grid renders below.
              CatalogResultCount(
                count: visibleProducts.length,
                noun: 'pieza',
                pluralNoun: 'piezas',
              ),
            ],
          ),
        ),
        actions: [
          SizedBox.square(
            dimension: BoutiqueSpace.tapTarget,
            child: Center(
              child: IconButton(
                key: const Key('catalog-search-button'),
                tooltip: 'Buscar productos',
                onPressed: () => openSearch(context),
                icon: const Icon(Icons.search_rounded, size: 27),
              ),
            ),
          ),
          SizedBox.square(
            dimension: BoutiqueSpace.tapTarget,
            child: Center(
              child: _FilterIconButton(
                activeCount: _filters.activeCount,
                onPressed: _openFilters,
              ),
            ),
          ),
          const SizedBox(width: _kHeaderEdgeInset),
        ],
      ),
      body: ClipRect(
        child: AnimatedSwitcher(
          key: const Key('catalog-section-transition'),
          duration: reduceMotion(context) ? Duration.zero : kSwap,
          switchInCurve: kMotionCurve,
          switchOutCurve: kMotionCurve,
          // The default layout stacks outgoing and incoming grids, which made
          // the previous category remain visible beneath the new products.
          layoutBuilder: (currentChild, previousChildren) =>
              currentChild ?? const SizedBox.shrink(),
          transitionBuilder: (child, animation) => FadeTransition(
            // Start mostly visible: the new category is immediate, while the
            // final 22% of opacity gives the change a quiet sense of motion.
            opacity: Tween<double>(begin: 0.78, end: 1).animate(animation),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.012),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: CustomScrollView(
            key: ValueKey('catalog-section-${_sectionKeySuffix(_filters)}'),
            primary: false,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              if (visibleProducts.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyCatalogState(
                    hasActiveFilter: _filters.activeCount > 0,
                    onReset: _resetAll,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(top: BoutiqueSpace.md),
                  // Photos run to the screen edges, so there is no horizontal
                  // or bottom padding (each tile carries its own trailing
                  // air). The safe area still applies sideways, for a notch
                  // in landscape.
                  sliver: SliverSafeArea(
                    top: false,
                    bottom: false,
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) => SliverGrid(
                        gridDelegate: productGridDelegate(
                          context,
                          availableWidth: constraints.crossAxisExtent,
                          variant: ProductTileVariant.edgeToEdge,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final product = visibleProducts[index];
                            return _BrowseTile(
                              key: ValueKey('monetta:${product.id}'),
                              product: product,
                              facets: widget.facetsById[product.id],
                            );
                          },
                          childCount: visibleProducts.length,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: MonettaBottomNavigation(
        current: MonettaBottomDestination.catalog,
        bagCount: widget.bagCount,
        onSelected: (destination) {
          switch (destination) {
            case MonettaBottomDestination.home:
              Navigator.of(context).popUntil((route) => route.isFirst);
            case MonettaBottomDestination.catalog:
              break;
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
        },
      ),
    );
  }
}

void openCatalogBrowse(
  BuildContext context, {
  required List<Product> products,
  required Map<String, CanonicalFacets> facetsById,
}) {
  final store = StoreScope.of(context);
  Navigator.of(context).push(
    monettaFadeRoute(
      StoreScope(
        notifier: store,
        child: CatalogBrowseScreen(
          products: products,
          facetsById: facetsById,
          bagCount: store.bagQuantity,
        ),
      ),
    ),
  );
}

class _HeaderBackSlot extends StatelessWidget {
  const _HeaderBackSlot();

  @override
  Widget build(BuildContext context) {
    final canLeave = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: canLeave
          ? const Padding(
              padding: EdgeInsetsDirectional.only(start: _kHeaderEdgeInset),
              child: BackButton(),
            )
          : null,
    );
  }
}

class _FilterIconButton extends StatelessWidget {
  const _FilterIconButton({
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
          key: const Key('catalog-filter-button'),
          tooltip: 'Filtrar y ordenar',
          onPressed: onPressed,
          icon: const AdjustmentsIcon(size: 25),
        ),
        if (activeCount > 0)
          Positioned(
            right: 3,
            top: 5,
            child: IgnorePointer(
              child: Container(
                key: const Key('catalog-filter-count'),
                constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: context.monettaColors.contentPrimary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$activeCount',
                  style: boutiqueText(
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

class _CatalogFilterSheet extends StatefulWidget {
  const _CatalogFilterSheet({
    required this.products,
    required this.facetsById,
    required this.initial,
    required this.visibleCount,
  });

  final List<Product> products;
  final Map<String, CanonicalFacets> facetsById;
  final _CatalogFilters initial;

  final int Function(_CatalogFilters filters) visibleCount;

  @override
  State<_CatalogFilterSheet> createState() => _CatalogFilterSheetState();
}

class _CatalogFilterSheetState extends State<_CatalogFilterSheet> {
  late _CatalogSort _sort;
  late Set<String> _categories;
  late Set<String> _types;
  late Set<String> _brands;
  late Set<String> _priceBands;
  late Set<String> _colors;
  late bool _inStockOnly;

  late final Set<_FilterSection> _expanded = {_FilterSection.sort};

  @override
  void initState() {
    super.initState();
    _load(widget.initial);
  }

  void _load(_CatalogFilters filters) {
    _sort = filters.sort;
    _categories = {...filters.categories};
    _types = {...filters.types};
    _brands = {...filters.brands};
    _priceBands = {...filters.priceBands};
    _colors = {...filters.colors};
    _inStockOnly = filters.inStockOnly;
  }

  _CatalogFilters get _selection => _CatalogFilters(
        sort: _sort,
        categories: _categories,
        types: _types,
        brands: _brands,
        priceBands: _priceBands,
        colors: _colors,
        inStockOnly: _inStockOnly,
      );

  List<String> get _typeOptions => _optionsWithMatches(
        _bagTypeTerms.keys,
        (product, facets, value) => _bagTypeFor(product, facets) == value,
      );

  List<String> get _brandOptions {
    final values = {
      for (final product in widget.products)
        if (_brandFor(product, widget.facetsById[product.id]).isNotEmpty)
          _brandFor(product, widget.facetsById[product.id]),
    }.toList();
    values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  List<String> get _priceOptions => _optionsWithMatches(
        const [
          'mxn-under-1000',
          'mxn-1000-2499',
          'mxn-2500-4999',
          'mxn-5000-plus',
        ],
        (product, facets, value) => _priceBandFor(product) == value,
      );

  List<String> get _colorOptions => _optionsWithMatches(
        _colorTerms.keys,
        (product, facets, value) => _colorsFor(product, facets).contains(value),
      );

  List<String> _optionsWithMatches(
    Iterable<String> candidates,
    bool Function(Product product, CanonicalFacets? facets, String value)
        matches,
  ) =>
      candidates
          .where(
            (value) => widget.products.any(
              (product) =>
                  matches(product, widget.facetsById[product.id], value),
            ),
          )
          .toList(growable: false);

  void _toggleExpanded(_FilterSection section) {
    setState(() {
      _expanded.contains(section)
          ? _expanded.remove(section)
          : _expanded.add(section);
    });
  }

  void _toggle(Set<String> values, String value) {
    setState(
      () => values.contains(value) ? values.remove(value) : values.add(value),
    );
  }

  void _clear() {
    setState(() => _load(const _CatalogFilters()));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.monettaColors;
    final categoryOptions =
        _availableCategories(widget.products, widget.facetsById);
    final typeOptions = _typeOptions;
    final brandOptions = _brandOptions;
    final priceOptions = _priceOptions;
    final colorOptions = _colorOptions;
    final resultCount = widget.visibleCount(_selection);

    return FractionallySizedBox(
      heightFactor: 0.94,
      child: Material(
        color: context.boutique.canvas,
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
                      style:
                          boutiqueTitle(size: 20, color: context.boutique.ink),
                    ),
                    Positioned(
                      right: 12,
                      child: IconButton(
                        key: const Key('catalog-filter-close'),
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
                      _FilterAccordion(
                        section: _FilterSection.sort,
                        expanded: _expanded.contains(_FilterSection.sort),
                        onTap: () => _toggleExpanded(_FilterSection.sort),
                        child: Column(
                          children: [
                            for (final option in _CatalogSort.values)
                              _FilterChoiceRow(
                                label: option.label,
                                selected: _sort == option,
                                radio: true,
                                onTap: () => setState(() => _sort = option),
                              ),
                          ],
                        ),
                      ),
                      if (categoryOptions.isNotEmpty)
                        _FilterAccordion(
                          section: _FilterSection.category,
                          expanded: _expanded.contains(_FilterSection.category),
                          onTap: () => _toggleExpanded(_FilterSection.category),
                          child: Column(
                            children: [
                              for (final option in categoryOptions)
                                _FilterChoiceRow(
                                  key: Key('catalog-filter-category-$option'),
                                  label: _categoryLabel(option),
                                  selected: _categories.contains(option),
                                  onTap: () => _toggle(_categories, option),
                                ),
                            ],
                          ),
                        ),
                      if (typeOptions.isNotEmpty)
                        _FilterAccordion(
                          section: _FilterSection.type,
                          expanded: _expanded.contains(_FilterSection.type),
                          onTap: () => _toggleExpanded(_FilterSection.type),
                          child: Column(
                            children: [
                              for (final option in typeOptions)
                                _FilterChoiceRow(
                                  label: option,
                                  selected: _types.contains(option),
                                  onTap: () => _toggle(_types, option),
                                ),
                            ],
                          ),
                        ),
                      if (brandOptions.isNotEmpty)
                        _FilterAccordion(
                          section: _FilterSection.brand,
                          expanded: _expanded.contains(_FilterSection.brand),
                          onTap: () => _toggleExpanded(_FilterSection.brand),
                          child: Column(
                            children: [
                              for (final option in brandOptions)
                                _FilterChoiceRow(
                                  label: option,
                                  selected: _brands.contains(option),
                                  onTap: () => _toggle(_brands, option),
                                ),
                            ],
                          ),
                        ),
                      if (priceOptions.isNotEmpty)
                        _FilterAccordion(
                          section: _FilterSection.price,
                          expanded: _expanded.contains(_FilterSection.price),
                          onTap: () => _toggleExpanded(_FilterSection.price),
                          child: Column(
                            children: [
                              for (final option in priceOptions)
                                _FilterChoiceRow(
                                  label: _priceBandLabel(option),
                                  selected: _priceBands.contains(option),
                                  onTap: () => _toggle(_priceBands, option),
                                ),
                            ],
                          ),
                        ),
                      if (colorOptions.isNotEmpty)
                        _FilterAccordion(
                          section: _FilterSection.color,
                          expanded: _expanded.contains(_FilterSection.color),
                          onTap: () => _toggleExpanded(_FilterSection.color),
                          child: Column(
                            children: [
                              for (final option in colorOptions)
                                _FilterChoiceRow(
                                  label: option,
                                  selected: _colors.contains(option),
                                  swatch: _colorSwatch(option),
                                  onTap: () => _toggle(_colors, option),
                                ),
                            ],
                          ),
                        ),
                      _FilterAccordion(
                        section: _FilterSection.availability,
                        expanded:
                            _expanded.contains(_FilterSection.availability),
                        onTap: () =>
                            _toggleExpanded(_FilterSection.availability),
                        child: _FilterChoiceRow(
                          label: 'En existencia',
                          selected: _inStockOnly,
                          onTap: () =>
                              setState(() => _inStockOnly = !_inStockOnly),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: context.boutique.canvas,
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
                        key: const Key('catalog-filter-clear'),
                        onPressed: _clear,
                        style: TextButton.styleFrom(
                          foregroundColor: context.monettaColors.contentPrimary,
                        ),
                        child: Text(
                          'Limpiar',
                          style: boutiqueText(
                            size: 13,
                            weight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          key: const Key('catalog-filter-apply'),
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
                            style: boutiqueText(
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

class _FilterAccordion extends StatelessWidget {
  const _FilterAccordion({
    required this.section,
    required this.expanded,
    required this.onTap,
    required this.child,
  });

  final _FilterSection section;
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
              key: section == _FilterSection.category
                  ? const Key('catalog-filter-section-category')
                  : Key('catalog-filter-${section.name}'),
              onTap: onTap,
              child: SizedBox(
                height: 78,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        section.label,
                        style: boutiqueText(
                          size: 17,
                          weight: FontWeight.w600,
                        ),
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

class _FilterChoiceRow extends StatelessWidget {
  const _FilterChoiceRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.radio = false,
    this.swatch,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool radio;
  final Color? swatch;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            _SelectionMark(selected: selected, radio: radio),
            if (swatch != null) ...[
              const SizedBox(width: 12),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: swatch,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.monettaColors.divider),
                ),
              ),
            ],
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: boutiqueText(
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
    );
  }
}

class _SelectionMark extends StatelessWidget {
  const _SelectionMark({required this.selected, required this.radio});

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
                  child: SizedBox(width: 9, height: 9),
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

class _EmptyCatalogState extends StatelessWidget {
  const _EmptyCatalogState({
    required this.hasActiveFilter,
    required this.onReset,
  });

  final bool hasActiveFilter;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 64, 32, 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 30,
            color: context.monettaColors.contentMuted,
          ),
          const SizedBox(height: 18),
          Text(
            'Sin resultados',
            style: boutiqueScreenTitle(color: context.boutique.ink),
          ),
          const SizedBox(height: 8),
          Text(
            hasActiveFilter
                ? 'Intenta usar otros filtros o quita los actuales.'
                : 'Muy pronto encontrarás nuevas piezas aquí.',
            textAlign: TextAlign.center,
            style: boutiqueText(
              size: 13,
              color: context.monettaColors.contentMuted,
              height: 1.5,
            ),
          ),
          if (hasActiveFilter) ...[
            const SizedBox(height: 22),
            TextButton(
              onPressed: onReset,
              child: Text(
                'Limpiar filtros',
                style: boutiqueText(
                  size: 13,
                  weight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BrowseTile extends StatelessWidget {
  const _BrowseTile({
    required this.product,
    required this.facets,
    super.key,
  });

  final Product product;
  final CanonicalFacets? facets;

  void _tap(BuildContext context) {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StoreScope(
            notifier: StoreScope.of(context),
            child: ProductScreen(productId: product.id),
          ),
        ),
      ),
    );
  }

  /// The store's current copy of this product when it can be bought from here.
  ///
  /// Reads the store without subscribing to it and degrades to null when the
  /// screen is mounted without a [StoreScope]; unknown and sold-out pieces
  /// have nothing to add.
  Product? _buyableProduct(BuildContext context) {
    final store = context.getInheritedWidgetOfExactType<StoreScope>()?.notifier;
    if (store == null) return null;
    for (final candidate in store.products) {
      if (candidate.id == product.id) {
        return candidate.isInStock ? candidate : null;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // The same presentation the product grids use; only its view data is
    // adapted, with the browser's plain-price rules.
    final data = ProductTileData.forCatalogBrowse(product, facets: facets);
    final buyable = _buyableProduct(context);
    return MonettaProductTile(
      data: data,
      onTap: () => _tap(context),
      variant: ProductTileVariant.edgeToEdge,
      quickAction: buyable == null
          ? null
          : ProductQuickAddButton(
              key: Key('quick-add-${buyable.id}'),
              product: buyable,
              productName: data.title,
            ),
      // No favourite here: this screen renders without a wishlist-bearing
      // store.
    );
  }
}

List<Product> _filterCatalog(
  List<Product> products,
  Map<String, CanonicalFacets> facetsById, {
  required String query,
  required _CatalogFilters filters,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  final result = products.where((product) {
    final facets = facetsById[product.id];
    if (normalizedQuery.isNotEmpty) {
      final searchable = [
        product.title,
        facets?.brand?.value ?? product.vendor,
        'Monetta',
        facets?.category?.value ?? '',
      ].join(' ').toLowerCase();
      if (!searchable.contains(normalizedQuery)) return false;
    }

    if (filters.categories.isNotEmpty &&
        !filters.categories.contains(_categoryFor(facets))) {
      return false;
    }
    if (filters.types.isNotEmpty &&
        !filters.types.contains(_bagTypeFor(product, facets))) {
      return false;
    }
    if (filters.brands.isNotEmpty &&
        !filters.brands.contains(_brandFor(product, facets))) {
      return false;
    }
    if (filters.priceBands.isNotEmpty &&
        !filters.priceBands.contains(_priceBandFor(product))) {
      return false;
    }
    if (filters.colors.isNotEmpty &&
        filters.colors.intersection(_colorsFor(product, facets)).isEmpty) {
      return false;
    }
    if (filters.inStockOnly && !product.isInStock) return false;
    return true;
  }).toList(growable: false);

  switch (filters.sort) {
    case _CatalogSort.featured:
      break;
    case _CatalogSort.newest:
      result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    case _CatalogSort.priceAsc:
      result.sort(_comparePriceAsc);
    case _CatalogSort.priceDesc:
      result.sort((a, b) => _comparePriceAsc(b, a));
  }
  return result;
}

int _comparePriceAsc(Product a, Product b) => a.price.compareTo(b.price);

String _brandFor(Product product, CanonicalFacets? facets) =>
    catalogBrowseBrand(product, facets);

String? _bagTypeFor(Product product, CanonicalFacets? facets) {
  final terms =
      '${facets?.category?.value ?? ''} ${product.title}'.toLowerCase();
  for (final entry in _bagTypeTerms.entries) {
    if (entry.value.any(terms.contains)) return entry.key;
  }
  return null;
}

Set<String> _colorsFor(Product product, CanonicalFacets? facets) {
  final terms = [
    product.title,
    facets?.category?.value ?? '',
  ].join(' ').toLowerCase();
  return {
    for (final entry in _colorTerms.entries)
      if (entry.value.any(terms.contains)) entry.key,
  };
}

String _priceBandFor(Product product) {
  final amount = product.price;
  if (amount < 1000) return 'mxn-under-1000';
  if (amount < 2500) return 'mxn-1000-2499';
  if (amount < 5000) return 'mxn-2500-4999';
  return 'mxn-5000-plus';
}

String _priceBandLabel(String value) => switch (value) {
      'mxn-under-1000' => 'Menos de \$1,000 MXN',
      'mxn-1000-2499' => '\$1,000 – \$2,499 MXN',
      'mxn-2500-4999' => '\$2,500 – \$4,999 MXN',
      'mxn-5000-plus' => '\$5,000 MXN o más',
      _ => value,
    };

Color _colorSwatch(String value) => switch (value) {
      'Negro' => const Color(0xFF161616),
      'Café' => const Color(0xFF76513B),
      'Beige' => const Color(0xFFD7C4A3),
      'Blanco' => const Color(0xFFF7F5EF),
      'Gris' => const Color(0xFF999999),
      'Azul' => const Color(0xFF355C86),
      'Rosa' => const Color(0xFFD99AAA),
      'Rojo' => const Color(0xFFA83232),
      'Vino' => const Color(0xFF682D3D),
      'Verde' => const Color(0xFF5E7251),
      'Morado' => const Color(0xFF725A82),
      'Amarillo' => const Color(0xFFE2C452),
      'Naranja' => const Color(0xFFD67B3B),
      'Dorado' => const Color(0xFFB9904F),
      'Plateado' => const Color(0xFFB8B8B8),
      _ => const Color(0xFF999999),
    };
