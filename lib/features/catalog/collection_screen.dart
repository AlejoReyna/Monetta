/// A real destination: one category, brand, or silhouette. Filters work.
library;

import 'dart:async';

import 'package:flutter/material.dart';

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
import 'silhouette_cutout.dart';

enum _Sort { newest, priceAsc, priceDesc }

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
  String? _brand;
  String? _silhouette;
  bool _inStockOnly = false;
  _Sort _sort = _Sort.newest;

  @override
  void initState() {
    super.initState();
    _brand = widget.filter.brand;
    _silhouette = widget.filter.silhouette;
  }

  String get _sortLabel => switch (_sort) {
        _Sort.newest => 'Más nuevas',
        _Sort.priceAsc => 'Menor precio',
        _Sort.priceDesc => 'Mayor precio',
      };

  List<Product> _items() {
    final store = StoreScope.of(context);
    final queryTerms = <String>{
      if (widget.filter.query?.trim().toLowerCase() case final query?
          when query.isNotEmpty)
        query,
      for (final term in widget.filter.queryTerms)
        if (term.trim().isNotEmpty) term.trim().toLowerCase(),
    };
    final items = store.products.where((product) {
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
      if (_brand != null && facets?.brand?.value != _brand) return false;
      if (_silhouette != null && facets?.silhouette?.value != _silhouette) {
        return false;
      }
      if (_inStockOnly && !product.isInStock) return false;
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
    }).toList();

    items.sort((a, b) {
      switch (_sort) {
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
    setState(() {
      _inStockOnly = false;
      _sort = _Sort.newest;
      _brand = widget.filter.brand;
      _silhouette = widget.filter.silhouette;
    });
  }

  Future<void> _openFilterSheet() async {
    final store = StoreScope.of(context);
    final brands = store.availableBrands;
    final silhouettes = {
      for (final product in store.products)
        if (store.facetsFor(product.id)?.silhouette?.value case final value?)
          value,
    }.toList()
      ..sort();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StoreScope(
          notifier: store,
          child: _FilterSheet(
            sort: _sort,
            inStockOnly: _inStockOnly,
            brand: _brand,
            silhouette: _silhouette,
            brands: brands,
            silhouettes:
                widget.filter.category == 'bolsa' ? silhouettes : const [],
            countOf: _items,
            onChanged: (sort, inStock, brand, silhouette) {
              setState(() {
                _sort = sort;
                _inStockOnly = inStock;
                _brand = brand;
                _silhouette = silhouette;
              });
            },
            onReset: () {
              _clearFilters();
              Navigator.of(sheetContext).pop();
            },
            onApply: () => Navigator.of(sheetContext).pop(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final items = _items();
    final silhouettes = {
      for (final product in store.products)
        if (store.facetsFor(product.id)?.silhouette?.value case final value?)
          value,
    }.toList()
      ..sort();

    final applied = <(String, VoidCallback)>[
      if (_inStockOnly)
        ('En stock', () => setState(() => _inStockOnly = false)),
      if (_brand != null)
        (
          brandLabel(_brand!),
          () => setState(() => _brand = null),
        ),
      if (_silhouette != null && widget.filter.category == 'bolsa')
        (
          silhouetteLabel(_silhouette!),
          () => setState(() => _silhouette = null),
        ),
    ];

    final countLabel = items.length == 1
        ? '1 pieza ordenada por '
        : '${items.length} piezas ordenadas por ';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: display(16, weight: FontWeight.w500)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Divider(height: 0.5),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.filter.category == 'bolsa' && silhouettes.isNotEmpty)
            _SilhouetteSiblingRail(
              slugs: silhouettes,
              selected: _silhouette,
              onSelected: (slug) => setState(() {
                _silhouette = _silhouette == slug ? null : slug;
              }),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(countLabel, style: sans(size: 12.5, color: kInkMuted)),
                UnderlineLink(
                  label: _sortLabel,
                  onTap: _openFilterSheet,
                  size: 12,
                ),
              ],
            ),
          ),
          if (applied.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                itemCount: applied.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final chip = applied[index];
                  return GestureDetector(
                    onTap: chip.$2,
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: kLine, width: 0.5),
                      ),
                      child: Text(
                        '${chip.$1}  ×',
                        style: sans(size: 12),
                      ),
                    ),
                  );
                },
              ),
            ),
          const Divider(height: 0.5),
          Expanded(
            child: items.isEmpty
                ? _EmptyFilter(
                    onClear: _clearFilters,
                    suggestions: store.products.take(4).toList(),
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
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        itemCount: slugs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final slug = slugs[index];
          final kind = silhouetteCutoutFor(slug);
          final on = slug == selected;
          return GestureDetector(
            onTap: () => onSelected(slug),
            child: SizedBox(
              width: 68,
              child: Column(
                children: [
                  if (kind != null)
                    SilhouetteCutout(
                      kind: kind,
                      size: 32,
                      color: on ? kInk : kInkMuted,
                    )
                  else
                    const SizedBox(height: 32),
                  const SizedBox(height: 4),
                  Text(
                    silhouetteLabel(slug).toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: eyebrow(size: 8, color: on ? kInk : kInkMuted),
                  ),
                ],
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
          style: sans(size: 13, color: kInkMuted),
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

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.sort,
    required this.inStockOnly,
    required this.brand,
    required this.silhouette,
    required this.brands,
    required this.silhouettes,
    required this.countOf,
    required this.onChanged,
    required this.onReset,
    required this.onApply,
  });

  final _Sort sort;
  final bool inStockOnly;
  final String? brand;
  final String? silhouette;
  final List<String> brands;
  final List<String> silhouettes;
  final List<Product> Function() countOf;
  final void Function(
    _Sort sort,
    bool inStock,
    String? brand,
    String? silhouette,
  ) onChanged;
  final VoidCallback onReset;
  final VoidCallback onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late _Sort _sort = widget.sort;
  late bool _inStockOnly = widget.inStockOnly;
  late String? _brand = widget.brand;
  late String? _silhouette = widget.silhouette;

  void _push() {
    widget.onChanged(_sort, _inStockOnly, _brand, _silhouette);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 36, height: 2, color: kLine),
            ),
            const SizedBox(height: 18),
            Text('Ordenar'.toUpperCase(), style: eyebrow()),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in _Sort.values)
                  _SheetChip(
                    label: switch (option) {
                      _Sort.newest => 'Más nuevas',
                      _Sort.priceAsc => 'Menor precio',
                      _Sort.priceDesc => 'Mayor precio',
                    },
                    selected: _sort == option,
                    onTap: () {
                      setState(() => _sort = option);
                      _push();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Filtrar'.toUpperCase(), style: eyebrow()),
            const SizedBox(height: 12),
            _SheetChip(
              label: 'En stock',
              selected: _inStockOnly,
              onTap: () {
                setState(() => _inStockOnly = !_inStockOnly);
                _push();
              },
            ),
            if (widget.brands.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final brand in widget.brands.take(8))
                    _SheetChip(
                      label: brandLabel(brand),
                      selected: _brand == brand,
                      onTap: () {
                        setState(
                          () => _brand = _brand == brand ? null : brand,
                        );
                        _push();
                      },
                    ),
                ],
              ),
            ],
            if (widget.silhouettes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final slug in widget.silhouettes)
                    _SheetChip(
                      label: silhouetteLabel(slug),
                      selected: _silhouette == slug,
                      onTap: () {
                        setState(
                          () => _silhouette = _silhouette == slug ? null : slug,
                        );
                        _push();
                      },
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                TextButton(
                  onPressed: widget.onReset,
                  child: Text('Limpiar', style: sans(size: 13)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: widget.onApply,
                    child: Text(
                      'Ver ${widget.countOf().length} piezas'.toUpperCase(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetChip extends StatelessWidget {
  const _SheetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: reduceMotion(context) ? Duration.zero : kSnap,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? kInk : Colors.white,
          border: Border.all(color: selected ? kInk : kLine, width: 0.5),
        ),
        child: Text(
          label.toUpperCase(),
          style: eyebrow(
            size: 8.5,
            color: selected ? Colors.white : kInk,
          ),
        ),
      ),
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
