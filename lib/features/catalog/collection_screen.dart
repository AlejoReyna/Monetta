/// A real destination: one category, brand, or silhouette. Filters work.
library;

import 'package:flutter/material.dart';

import '../../app/motion.dart';
import '../../app/shopper_copy.dart';
import '../../app/theme.dart';
import '../../domain/product.dart';
import '../../main.dart';
import '../../reco/explainer.dart';
import '../account/account_screen.dart';
import '../checkout/checkout_screen.dart';
import '../navigation/monetta_bottom_navigation.dart';
import 'product_card.dart';

enum _Sort { newest, priceAsc, priceDesc }

class CollectionFilter {
  const CollectionFilter({
    this.category,
    this.brand,
    this.silhouette,
    this.query,
  });

  final String? category;
  final String? brand;
  final String? silhouette;
  final String? query;
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

  List<Product> _items() {
    final store = StoreScope.of(context);
    final query = widget.filter.query?.trim().toLowerCase() ?? '';
    final items = store.products.where((product) {
      final facets = store.facetsFor(product.id);
      if (widget.filter.category != null &&
          facets?.category?.value != widget.filter.category) {
        return false;
      }
      if (_brand != null && facets?.brand?.value != _brand) return false;
      if (_silhouette != null && facets?.silhouette?.value != _silhouette) {
        return false;
      }
      if (_inStockOnly && !product.isInStock) return false;
      if (query.isEmpty) return true;
      final brand = facets?.brand?.value == null
          ? ''
          : brandLabel(facets!.brand!.value).toLowerCase();
      return product.title.toLowerCase().contains(query) ||
          brand.contains(query);
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

  void _handleBottomNavigation(MonettaBottomDestination destination) {
    switch (destination) {
      case MonettaBottomDestination.home:
        Navigator.of(context).popUntil((route) => route.isFirst);
      case MonettaBottomDestination.shuffle:
        setState(() {
          _inStockOnly = false;
          _sort = _Sort.newest;
          _brand = widget.filter.brand;
          _silhouette = widget.filter.silhouette;
        });
      case MonettaBottomDestination.menu:
        _openMenu();
      case MonettaBottomDestination.bag:
        openBag(context);
      case MonettaBottomDestination.account:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AccountScreen(
              controller: AccountScope.of(context),
            ),
          ),
        );
    }
  }

  void _openMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(width: 36, height: 2, color: kLine),
              ),
              const SizedBox(height: 18),
              Text('Menú', style: display(24)),
              const SizedBox(height: 8),
              _SheetLink(
                label: 'Inicio',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
              _SheetLink(
                label: 'Ver todo el catálogo',
                onTap: () => Navigator.of(sheetContext).pop(),
              ),
              _SheetLink(
                label: 'Mi cuenta',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _handleBottomNavigation(MonettaBottomDestination.account);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final items = _items();
    final brands = store.availableBrands;
    final silhouettes = {
      for (final product in store.products)
        if (store.facetsFor(product.id)?.silhouette?.value case final value?)
          value,
    }.toList()
      ..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: display(16, weight: FontWeight.w500)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Divider(height: 0.5),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              children: [
                _FilterChip(
                  label: _inStockOnly ? 'En stock' : 'Todo',
                  selected: _inStockOnly,
                  onTap: () => setState(() => _inStockOnly = !_inStockOnly),
                ),
                const SizedBox(width: 8),
                for (final brand in brands.take(8)) ...[
                  _FilterChip(
                    label: brandLabel(brand),
                    selected: _brand == brand,
                    onTap: () => setState(
                      () => _brand =
                          _brand == brand ? widget.filter.brand : brand,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (widget.filter.category == 'bolsa')
                  for (final silhouette in silhouettes) ...[
                    _FilterChip(
                      label: silhouetteLabel(silhouette),
                      selected: _silhouette == silhouette,
                      onTap: () => setState(
                        () => _silhouette = _silhouette == silhouette
                            ? widget.filter.silhouette
                            : silhouette,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                _FilterChip(
                  label: switch (_sort) {
                    _Sort.newest => 'Más nuevas',
                    _Sort.priceAsc => 'Precio ↑',
                    _Sort.priceDesc => 'Precio ↓',
                  },
                  selected: _sort != _Sort.newest,
                  onTap: () => setState(() {
                    _sort = switch (_sort) {
                      _Sort.newest => _Sort.priceAsc,
                      _Sort.priceAsc => _Sort.priceDesc,
                      _Sort.priceDesc => _Sort.newest,
                    };
                  }),
                ),
              ],
            ),
          ),
          const Divider(height: 0.5),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      'No hay piezas con ese filtro.',
                      style: sans(color: kInkMuted),
                    ),
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
        current: MonettaBottomDestination.menu,
        bagCount: store.bagQuantity,
        onSelected: _handleBottomNavigation,
      ),
    );
  }
}

class _SheetLink extends StatelessWidget {
  const _SheetLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Text(label, style: sans(size: 16)),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
