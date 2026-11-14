/// v4.1 «Nueva colección»: featured product, thumbnail rail, PDP on featured tap.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/catalog_store.dart';
import '../../app/media/monetta_image.dart';
import '../../app/shopper_copy.dart';
import '../../app/theme.dart' show formatShopperPrice;
import '../../reco/explainer.dart' show brandLabel;
import '../../domain/product.dart';
import '../../main.dart';
import '../boutique/boutique_tokens.dart';
import '../boutique/client_guide_components.dart';
import '../catalog/product_card.dart';
import '../catalog/product_tile.dart';
import '../product/product_selection.dart';
import 'home_v41_catalog.dart';

class HomeNewCollectionSection extends StatefulWidget {
  const HomeNewCollectionSection({
    required this.products,
    required this.onOpenAll,
    super.key,
  });

  final List<Product> products;
  final VoidCallback onOpenAll;

  @override
  State<HomeNewCollectionSection> createState() =>
      _HomeNewCollectionSectionState();
}

class _HomeNewCollectionSectionState extends State<HomeNewCollectionSection> {
  int _selectedIndex = 0;
  int _variantIndex = 0;

  Product? get _selected =>
      widget.products.isEmpty ? null : widget.products[_selectedIndex];

  void _selectProduct(int index) {
    setState(() {
      _selectedIndex = index;
      _variantIndex = 0;
    });
  }

  void _stepFeatured(int delta) {
    if (widget.products.isEmpty) return;
    final next = (_selectedIndex + delta) % widget.products.length;
    _selectProduct(next);
  }

  String? _featuredImage(Product product, int variantIndex) {
    final variant = selectedVariant(product, variantIndex);
    final fromVariant = variant?.imageUrls;
    if (fromVariant != null && fromVariant.isNotEmpty) return fromVariant.first;
    return product.primaryImage;
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.products;
    if (products.isEmpty) return const SizedBox.shrink();
    final product = _selected!;
    final store = StoreScope.of(context);
    final facets = store.facetsFor(product.id);
    final brand = facets?.brand?.value;
    final palette = context.boutique;
    final price = selectionPrice(product, _variantIndex);
    final compare = selectionCompareAt(product, _variantIndex);
    final onSale = selectionOnSale(product, _variantIndex);
    final discount = selectionDiscountPercent(product, _variantIndex);
    final inStock = selectionInStock(product, _variantIndex);
    final wishlisted = store.wishlist.contains(product.id);

    return Column(
      key: const ValueKey('home-section-new-products'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BoutiqueSectionHeader(
          title: 'Nueva colección',
          actionLabel: 'Ver todo',
          onAction: widget.onOpenAll,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: BoutiqueSpace.gutter),
          child: Stack(
            children: [
              Semantics(
                button: true,
                label: 'Abrir ficha de ${product.title}',
                child: GestureDetector(
                  key: const ValueKey('home-new-collection-featured'),
                  onTap: () => openProduct(
                    context,
                    product,
                    initialVariantId:
                        selectedVariant(product, _variantIndex)?.id,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.surfaceDeep,
                      borderRadius: BoutiqueRadius.tile,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AspectRatio(
                          aspectRatio: 4 / 5,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (_featuredImage(product, _variantIndex)
                                  case final url?)
                                MonettaImage(url: url, fit: BoxFit.contain),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: _HomeWishlistControl(
                                  wishlisted: wishlisted,
                                  onPressed: () =>
                                      unawaited(store.toggleWishlist(product.id)),
                                ),
                              ),
                              if (products.length > 1) ...[
                                Positioned(
                                  left: 4,
                                  top: 0,
                                  bottom: 0,
                                  child: Center(
                                    child: GuideGlassIconButton(
                                      tooltip: 'Anterior',
                                      icon: const Icon(Icons.chevron_left),
                                      onPressed: () => _stepFeatured(-1),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 4,
                                  top: 0,
                                  bottom: 0,
                                  child: Center(
                                    child: GuideGlassIconButton(
                                      tooltip: 'Siguiente',
                                      icon: const Icon(Icons.chevron_right),
                                      onPressed: () => _stepFeatured(1),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(BoutiqueSpace.lg),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (brand != null)
                                      Text(
                                        brandLabel(brand),
                                        style: boutiqueText(
                                          size: 14,
                                          weight: FontWeight.w600,
                                          color: palette.ink,
                                        ),
                                      ),
                                    Text(
                                      cardPieceName(
                                        title: product.title,
                                        colorSlug: facets?.colors.isEmpty ?? true
                                            ? null
                                            : facets!.colors.first.value,
                                      ),
                                      style: boutiqueTitle(
                                        size: 18,
                                        color: palette.ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    formatShopperPrice(price),
                                    style: boutiqueText(
                                      size: 16,
                                      weight: FontWeight.w600,
                                      color: palette.ink,
                                    ),
                                  ),
                                  if (onSale && compare != null) ...[
                                    Text(
                                      formatShopperPrice(compare),
                                      style: boutiqueText(
                                        size: 13,
                                        color: palette.inkMuted,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                    Text(
                                      '-$discount%',
                                      style: boutiqueText(
                                        size: 13,
                                        color: palette.sale,
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  if (!inStock)
                                    Text(
                                      'Agotado',
                                      style: boutiqueEyebrow(
                                        size: 11,
                                        color: palette.inkMuted,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            BoutiqueSpace.lg,
                            0,
                            BoutiqueSpace.lg,
                            BoutiqueSpace.md,
                          ),
                          child: ProductOptionSelector(
                            product: product,
                            selectedIndex: _variantIndex,
                            onSelect: (index) =>
                                setState(() => _variantIndex = index),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: BoutiqueSpace.lg),
        SizedBox(
          height: productTileExtent(
            tileWidth: 112,
            textScaler: MediaQuery.textScalerOf(context),
            density: ProductTileDensity.compact,
            priceLines: 1,
          ),
          child: ListView.separated(
            key: const ValueKey('home-new-products-rail'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: BoutiqueSpace.gutter),
            itemCount: products.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: BoutiqueSpace.md),
            itemBuilder: (context, index) {
              final item = products[index];
              final selected = index == _selectedIndex;
              return SizedBox(
                width: 112,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BoutiqueRadius.tile,
                    border: selected
                        ? Border.all(color: palette.goldText, width: 1.5)
                        : null,
                  ),
                  child: ProductCard(
                    product: item,
                    density: ProductTileDensity.compact,
                    showViewProduct: false,
                    onTap: () => _selectProduct(index),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            BoutiqueSpace.gutter,
            BoutiqueSpace.md,
            BoutiqueSpace.gutter,
            0,
          ),
          child: Column(
            children: [
              GuideGlassIconButton(
                tooltip: 'Ver Nueva colección',
                icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                onPressed: widget.onOpenAll,
              ),
              const SizedBox(height: BoutiqueSpace.sm),
              TextButton(
                key: const ValueKey('home-new-collection-see-all'),
                onPressed: widget.onOpenAll,
                child: const Text('Ver Nueva colección'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeWishlistControl extends StatelessWidget {
  const _HomeWishlistControl({
    required this.wishlisted,
    required this.onPressed,
  });

  final bool wishlisted;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Semantics(
      button: true,
      toggled: wishlisted,
      label: wishlisted ? 'Quitar de favoritos' : 'Guardar en favoritos',
      child: SizedBox(
        width: BoutiqueSpace.tapTarget,
        height: BoutiqueSpace.tapTarget,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(
            wishlisted ? Icons.favorite : Icons.favorite_border,
            color: wishlisted ? palette.goldText : palette.ink,
            size: 22,
          ),
        ),
      ),
    );
  }
}
