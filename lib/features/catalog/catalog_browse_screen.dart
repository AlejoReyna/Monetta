/// Full-catalog browsing for Monetta's bags and accessories.
///
/// Photography owns the screen. Filtering is handled by a single expandable
/// sheet with bag-specific facets, search, and horizontal category pills.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/motion.dart';
import '../../app/shopper_copy.dart';
import '../../app/theme.dart';
import '../../domain/catalog_item.dart';
import '../../main.dart';
import '../../reco/external_facets.dart';
import '../account/account_screen.dart';
import '../boutique/boutique_tokens.dart';
import '../checkout/checkout_screen.dart';
import '../navigation/monetta_bottom_navigation.dart';
import '../product/external_product_screen.dart';
import '../product/product_screen.dart';
import 'catalog_controls.dart';
import 'extracted_badge.dart';
import 'product_tile.dart';
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

enum _FilterSection { sort, type, brand, price, color, availability }

extension on _FilterSection {
  String get label => switch (this) {
        _FilterSection.sort => 'Ordenar por',
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
    this.types = const <String>{},
    this.brands = const <String>{},
    this.priceBands = const <String>{},
    this.colors = const <String>{},
    this.inStockOnly = false,
  });

  final _CatalogSort sort;
  final Set<String> types;
  final Set<String> brands;
  final Set<String> priceBands;
  final Set<String> colors;
  final bool inStockOnly;

  int get activeCount =>
      types.length +
      brands.length +
      priceBands.length +
      colors.length +
      (inStockOnly ? 1 : 0);
}

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

String _categoryFor(CatalogItem item) {
  final externalCategory =
      item.isExternal ? externalItemFacets(item).category?.value : null;
  final rawCategory = (externalCategory ?? item.category)?.trim().toLowerCase();

  final category = switch (rawCategory) {
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
    _ => null,
  };
  if (category != null) return category;

  if (item.vertical == CatalogVertical.perfumes) return 'perfume';
  if (item.vertical == CatalogVertical.bagsWallets) {
    final terms = item.title.toLowerCase();
    if (RegExp(r'\b(?:wallet|billfold|cartera)\b').hasMatch(terms)) {
      return 'cartera';
    }
    if (RegExp(r'\b(?:card case|card holder|tarjeter[oa])\b').hasMatch(terms)) {
      return 'tarjetero';
    }
    if (RegExp(r'\b(?:monedero|coin purse)\b').hasMatch(terms)) {
      return 'monedero';
    }
    if (RegExp(r'\b(?:cosmetiquera|cosmetic case)\b').hasMatch(terms)) {
      return 'cosmetiquera';
    }
    return 'bolsa';
  }
  return 'otros';
}

class CatalogBrowseScreen extends StatefulWidget {
  const CatalogBrowseScreen({
    required this.items,
    this.openExternalLink = defaultExternalLinkOpener,
    this.bagCount = 0,
    super.key,
  });

  final List<CatalogItem> items;
  final ExternalLinkOpener openExternalLink;
  final int bagCount;

  @override
  State<CatalogBrowseScreen> createState() => _CatalogBrowseScreenState();
}

class _CatalogBrowseScreenState extends State<CatalogBrowseScreen> {
  _CatalogFilters _filters = const _CatalogFilters();
  String? _activeCategory;

  List<String> get _availableCategories {
    final categories = {
      for (final item in widget.items) _categoryFor(item),
    };
    final ordered = [
      for (final category in _catalogCategoryOrder)
        if (categories.remove(category)) category,
      ...categories.toList()
        ..sort(
          (a, b) => _categoryLabel(a).compareTo(_categoryLabel(b)),
        ),
    ];
    return ordered;
  }

  List<CatalogItem> _visibleItems([_CatalogFilters? filters]) {
    final baseFilters = filters ?? _filters;
    var items = _filterCatalog(
      widget.items,
      query: '',
      filters: baseFilters,
    );

    final activeCategory = _activeCategory;
    if (activeCategory != null) {
      items =
          items.where((item) => _categoryFor(item) == activeCategory).toList();
    }
    return items;
  }

  void _resetAll() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _filters = const _CatalogFilters();
      _activeCategory = null;
    });
  }

  Future<void> _openFilters([_FilterSection? section]) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await showModalBottomSheet<_CatalogFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: context.monettaColors.scrim,
      builder: (sheetContext) => _CatalogFilterSheet(
        items: widget.items,
        initial: _filters,
        initialSection: section ?? _FilterSection.sort,
        visibleCount: (draft) => _visibleItems(draft).length,
      ),
    );
    // Dismissing the sheet keeps the filters that were already applied.
    if (result != null && mounted) setState(() => _filters = result);
  }

  Widget _buildCategoryPill({
    required String title,
    required String keyName,
    required String? category,
  }) {
    final isSelected = _activeCategory == category;
    final colors = context.monettaColors;
    final animationsDisabled = reduceMotion(context);
    final labelColor =
        isSelected ? colors.accentContent : colors.contentPrimary;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AnimatedScale(
        key: Key('$keyName-motion'),
        scale: isSelected ? 1.025 : 1,
        duration: animationsDisabled ? Duration.zero : kSnap,
        curve: kMotionCurve,
        child: ChoiceChip(
          key: Key(keyName),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: boutiqueText(
                  size: 13,
                  weight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: labelColor,
                ),
              ),
            ],
          ),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) setState(() => _activeCategory = category);
          },
          color: WidgetStateProperty.resolveWith<Color>((states) {
            return states.contains(WidgetState.selected)
                ? colors.navigationSelection
                : Colors.transparent;
          }),
          backgroundColor: Colors.transparent,
          selectedColor: colors.navigationSelection,
          surfaceTintColor: Colors.transparent,
          side: BorderSide(
            color: isSelected
                ? colors.accent.withValues(alpha: 0.48)
                : colors.divider,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _visibleItems();

    return Scaffold(
      // Never `extendBody`: the last row of products must not sit under the
      // navigation bar, and this screen has no floating bar competing with it.
      extendBody: false,
      backgroundColor: context.boutique.canvas,
      appBar: AppBar(
        toolbarHeight: 76,
        backgroundColor: context.boutique.canvas,
        foregroundColor: context.boutique.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: BoutiqueSpace.gutter,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Productos',
              style: boutiqueDisplay(24, color: context.boutique.ink),
            ),
            const SizedBox(height: 2),
            // Counted from the very list the grid renders below.
            CatalogResultCount(
              count: visibleItems.length,
              noun: 'pieza',
              pluralNoun: 'piezas',
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('catalog-search-button'),
            tooltip: 'Buscar productos',
            onPressed: () => openSearch(context),
            icon: const Icon(Icons.search_rounded, size: 27),
          ),
          _FilterIconButton(
            activeCount: _filters.activeCount,
            onPressed: _openFilters,
          ),
          const SizedBox(width: 6),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            key: const Key('catalog-category-rail'),
            color: context.boutique.canvas,
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: [
                _buildCategoryPill(
                  title: 'Colección',
                  keyName: 'catalog-category-collection',
                  category: null,
                ),
                for (final category in _availableCategories)
                  _buildCategoryPill(
                    title: _categoryLabel(category),
                    keyName: 'catalog-category-$category',
                    category: category,
                  ),
              ],
            ),
          ),
        ),
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
            key: ValueKey('catalog-section-${_activeCategory ?? 'collection'}'),
            primary: false,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: _QuickFilterRail(
                  items: widget.items,
                  filters: _filters,
                  onOpen: _openFilters,
                ),
              ),
              if (visibleItems.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyCatalogState(
                    hasActiveFilter: _filters.activeCount > 0,
                    onReset: _resetAll,
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
                  sliver: SliverGrid(
                    gridDelegate: productGridDelegate(
                      context,
                      availableWidth: MediaQuery.sizeOf(context).width -
                          BoutiqueSpace.gutter * 2,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _BrowseTile(
                        key: ValueKey(visibleItems[index].sourceScopedId),
                        item: visibleItems[index],
                        openExternalLink: widget.openExternalLink,
                      ),
                      childCount: visibleItems.length,
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
        surfaceColor: context.monettaColors.navigationSurface,
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
  required List<CatalogItem> items,
}) {
  final store = StoreScope.of(context);
  Navigator.of(context).push(
    monettaFadeRoute(
      StoreScope(
        notifier: store,
        child: CatalogBrowseScreen(
          items: items,
          bagCount: store.bagQuantity,
        ),
      ),
    ),
  );
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
          icon: const Icon(Icons.tune_rounded, size: 27),
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
    required this.items,
    required this.initial,
    required this.visibleCount,
    this.initialSection = _FilterSection.sort,
  });

  final List<CatalogItem> items;
  final _CatalogFilters initial;

  /// The section a quick-filter chip asked for, already open.
  final _FilterSection initialSection;
  final int Function(_CatalogFilters filters) visibleCount;

  @override
  State<_CatalogFilterSheet> createState() => _CatalogFilterSheetState();
}

class _CatalogFilterSheetState extends State<_CatalogFilterSheet> {
  late _CatalogSort _sort;
  late Set<String> _types;
  late Set<String> _brands;
  late Set<String> _priceBands;
  late Set<String> _colors;
  late bool _inStockOnly;

  late final Set<_FilterSection> _expanded = {widget.initialSection};

  @override
  void initState() {
    super.initState();
    _load(widget.initial);
  }

  void _load(_CatalogFilters filters) {
    _sort = filters.sort;
    _types = {...filters.types};
    _brands = {...filters.brands};
    _priceBands = {...filters.priceBands};
    _colors = {...filters.colors};
    _inStockOnly = filters.inStockOnly;
  }

  _CatalogFilters get _selection => _CatalogFilters(
        sort: _sort,
        types: _types,
        brands: _brands,
        priceBands: _priceBands,
        colors: _colors,
        inStockOnly: _inStockOnly,
      );

  List<String> get _typeOptions => _optionsWithMatches(
        _bagTypeTerms.keys,
        (item, value) => _bagTypeFor(item) == value,
      );

  List<String> get _brandOptions {
    final values = {
      for (final item in widget.items)
        if (_brandFor(item).isNotEmpty) _brandFor(item),
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
          'usd-under-100',
          'usd-100-249',
          'usd-250-499',
          'usd-500-plus',
        ],
        (item, value) => _priceBandFor(item) == value,
      );

  List<String> get _colorOptions => _optionsWithMatches(
        _colorTerms.keys,
        (item, value) => _colorsFor(item).contains(value),
      );

  List<String> _optionsWithMatches(
    Iterable<String> candidates,
    bool Function(CatalogItem item, String value) matches,
  ) =>
      candidates
          .where((value) => widget.items.any((item) => matches(item, value)))
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
                      style: boutiqueDisplay(20, weight: FontWeight.w600),
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
              key: Key('catalog-filter-${section.name}'),
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
            style: boutiqueDisplay(24, weight: FontWeight.w600),
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
    required this.item,
    required this.openExternalLink,
    super.key,
  });

  final CatalogItem item;
  final ExternalLinkOpener openExternalLink;

  void _tap(BuildContext context) {
    if (!item.isExternal) {
      final productId = item.shopifyProductId;
      if (productId == null) return;
      unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => StoreScope(
              notifier: StoreScope.of(context),
              child: ProductScreen(productId: productId),
            ),
          ),
        ),
      );
      return;
    }

    unawaited(
      showExternalProductDetail(
        context,
        item: item,
        openLink: openExternalLink,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The same presentation the product grids use. A [CatalogItem] is not
    // turned into a [Product] — currency, origin and purchase destination
    // would be lost — only its view data is adapted.
    return MonettaProductTile(
      data: ProductTileData.fromCatalogItem(item),
      onTap: () => _tap(context),
      // No favourite here: an external listing has no Monetta product id to
      // save, and this screen renders without a wishlist-bearing store.
      imageOverlay: item.isExternal ? const ExtractedBadge() : null,
    );
  }
}

/// Fig. 05's quick filters. Each chip opens the sheet on its own section, so
/// there is exactly one place where a filter is applied or cancelled.
///
/// A chip only appears when the visible catalog actually offers that facet,
/// and ordering is a chip but never counts as an active filter — the same
/// convention the badge on the filter icon uses.
class _QuickFilterRail extends StatelessWidget {
  const _QuickFilterRail({
    required this.items,
    required this.filters,
    required this.onOpen,
  });

  final List<CatalogItem> items;
  final _CatalogFilters filters;
  final ValueChanged<_FilterSection> onOpen;

  bool _hasBrands() => items.any((item) => _brandFor(item).isNotEmpty);

  bool _hasPrices() => items.any((item) => _priceBandFor(item) != null);

  bool _hasColors() => items.any((item) => _colorsFor(item).isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (_hasBrands())
        MonettaCapsuleChip(
          key: const Key('catalog-quick-brand'),
          label: 'Marca',
          showCaret: true,
          selected: filters.brands.isNotEmpty,
          badgeCount: filters.brands.length,
          onTap: () => onOpen(_FilterSection.brand),
        ),
      if (_hasPrices())
        MonettaCapsuleChip(
          key: const Key('catalog-quick-price'),
          label: 'Precio',
          showCaret: true,
          selected: filters.priceBands.isNotEmpty,
          badgeCount: filters.priceBands.length,
          onTap: () => onOpen(_FilterSection.price),
        ),
      if (_hasColors())
        MonettaCapsuleChip(
          key: const Key('catalog-quick-color'),
          label: 'Color',
          showCaret: true,
          selected: filters.colors.isNotEmpty,
          badgeCount: filters.colors.length,
          onTap: () => onOpen(_FilterSection.color),
        ),
      MonettaCapsuleChip(
        key: const Key('catalog-quick-sort'),
        label: 'Ordenar',
        showCaret: true,
        onTap: () => onOpen(_FilterSection.sort),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: BoutiqueSpace.sm),
      child: MonettaChipRail(children: chips),
    );
  }
}

List<CatalogItem> _filterCatalog(
  List<CatalogItem> items, {
  required String query,
  required _CatalogFilters filters,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  final result = items.where((item) {
    if (normalizedQuery.isNotEmpty) {
      final searchable = [
        item.title,
        item.brand,
        item.merchant,
        item.category ?? '',
        ...item.variants.map((variant) => variant.displayName),
      ].join(' ').toLowerCase();
      if (!searchable.contains(normalizedQuery)) return false;
    }

    if (filters.types.isNotEmpty &&
        !filters.types.contains(_bagTypeFor(item))) {
      return false;
    }
    if (filters.brands.isNotEmpty &&
        !filters.brands.contains(_brandFor(item))) {
      return false;
    }
    if (filters.priceBands.isNotEmpty &&
        !filters.priceBands.contains(_priceBandFor(item))) {
      return false;
    }
    if (filters.colors.isNotEmpty &&
        filters.colors.intersection(_colorsFor(item)).isEmpty) {
      return false;
    }
    if (filters.inStockOnly &&
        item.availability != CatalogAvailability.inStock) {
      return false;
    }
    return true;
  }).toList(growable: false);

  switch (filters.sort) {
    case _CatalogSort.featured:
      break;
    case _CatalogSort.newest:
      result.sort((a, b) => b.lastObservedAt.compareTo(a.lastObservedAt));
    case _CatalogSort.priceAsc:
      result.sort(_comparePriceAsc);
    case _CatalogSort.priceDesc:
      result.sort((a, b) => _comparePriceAsc(b, a));
  }
  return result;
}

int _comparePriceAsc(CatalogItem a, CatalogItem b) {
  final aPrice = a.price;
  final bPrice = b.price;
  if (aPrice == null && bPrice == null) return 0;
  if (aPrice == null) return 1;
  if (bPrice == null) return -1;
  final currencyOrder = aPrice.currency.index.compareTo(bPrice.currency.index);
  if (currencyOrder != 0) return currencyOrder;
  return aPrice.amount.compareTo(bPrice.amount);
}

String _brandFor(CatalogItem item) {
  final brand = item.brand.trim();
  return humanizeCatalogValue(
    brand.isEmpty ? item.merchant.trim() : brand,
  );
}

String? _bagTypeFor(CatalogItem item) {
  final terms = '${item.category ?? ''} ${item.title}'.toLowerCase();
  for (final entry in _bagTypeTerms.entries) {
    if (entry.value.any(terms.contains)) return entry.key;
  }
  return null;
}

Set<String> _colorsFor(CatalogItem item) {
  // External variant names often append hardware finishes (for example
  // "Café/Dorado"). Those should not make a brown bag appear under a gold
  // body-colour filter, so metallic hardware words are ignored in variants;
  // a genuinely gold or silver bag still matches when its product title says
  // so explicitly.
  final variantColors = item.variants.map(
    (variant) => variant.displayName.toLowerCase().replaceAll(
          RegExp(r'\b(dorado|dorada|plateado|plateada|gold|silver)\b'),
          '',
        ),
  );
  final terms = [
    item.title,
    item.category ?? '',
    ...variantColors,
  ].join(' ').toLowerCase();
  return {
    for (final entry in _colorTerms.entries)
      if (entry.value.any(terms.contains)) entry.key,
  };
}

String? _priceBandFor(CatalogItem item) {
  final price = item.price;
  if (price == null) return null;
  if (price.currency == Currency.mxn) {
    if (price.amount < 1000) return 'mxn-under-1000';
    if (price.amount < 2500) return 'mxn-1000-2499';
    if (price.amount < 5000) return 'mxn-2500-4999';
    return 'mxn-5000-plus';
  }
  if (price.amount < 100) return 'usd-under-100';
  if (price.amount < 250) return 'usd-100-249';
  if (price.amount < 500) return 'usd-250-499';
  return 'usd-500-plus';
}

String _priceBandLabel(String value) => switch (value) {
      'mxn-under-1000' => 'Menos de \$1,000 MXN',
      'mxn-1000-2499' => '\$1,000 – \$2,499 MXN',
      'mxn-2500-4999' => '\$2,500 – \$4,999 MXN',
      'mxn-5000-plus' => '\$5,000 MXN o más',
      'usd-under-100' => 'Menos de \$100 USD',
      'usd-100-249' => '\$100 – \$249 USD',
      'usd-250-499' => '\$250 – \$499 USD',
      'usd-500-plus' => '\$500 USD o más',
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
