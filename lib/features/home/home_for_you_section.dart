/// v4.1 «Para ti» accordion-style horizontal product feed.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/media/monetta_image.dart';
import '../../app/shopper_copy.dart';
import '../../reco/explainer.dart' show brandLabel;
import '../../domain/product.dart';
import '../../main.dart';
import '../../app/motion.dart';
import '../boutique/boutique_tokens.dart';
import '../catalog/quick_add_button.dart';
import '../boutique/client_guide_components.dart';
import '../checkout/checkout_screen.dart' show openCheckout;
import '../product/product_selection.dart';
import 'home_v41_catalog.dart';

class HomeForYouSection extends StatefulWidget {
  const HomeForYouSection({super.key});

  @override
  State<HomeForYouSection> createState() => _HomeForYouSectionState();
}

class _HomeForYouSectionState extends State<HomeForYouSection> {
  final Map<String, int> _variantIndexByProduct = {};
  int? _expandedIndex;
  String? _buyingProductId;

  int _variantIndexFor(Product product) =>
      _variantIndexByProduct[product.id] ?? 0;

  void _setVariantIndex(Product product, int index) {
    setState(() => _variantIndexByProduct[product.id] = index);
  }

  Future<void> _buyNow(Product product, int variantIndex) async {
    if (_buyingProductId != null) return;
    setState(() => _buyingProductId = product.id);
    try {
      final result = await tryAddSelectionToBag(context, product, variantIndex);
      if (!mounted) return;
      if (result.status == BagAddStatus.added) {
        await openCheckout(context);
        return;
      }
      final message = switch (result.status) {
        BagAddStatus.soldOut => 'Esta opción está agotada.',
        BagAddStatus.unavailable => 'Esta pieza no está disponible por ahora.',
        _ => 'No pudimos agregar la pieza. Intenta de nuevo.',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _buyingProductId = null);
    }
  }

  String? _panelImage(Product product, int variantIndex) {
    final variant = selectedVariant(product, variantIndex);
    if (variant?.imageUrls.isNotEmpty ?? false) {
      return variant!.imageUrls.first;
    }
    return product.primaryImage;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final editorial = store.profile.isEmpty;
    final products =
        uniqueFeedProducts(store, limit: kHomeNewCollectionProductLimit);
    if (products.isEmpty) return const SizedBox.shrink();
    final palette = context.boutique;
    final panelWidth =
        (MediaQuery.sizeOf(context).width * 0.72).clamp(240.0, 320.0);

    return Column(
      key: const ValueKey('home-section-for-you'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BoutiqueSectionHeader(
          title: 'Para ti',
          kicker: editorial ? 'Selección editorial' : null,
        ),
        SizedBox(
          height: panelWidth * 1.35,
          child: ListView.separated(
            key: const ValueKey('home-for-you-rail'),
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: BoutiqueSpace.gutter),
            itemCount: products.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: BoutiqueSpace.md),
            itemBuilder: (context, index) {
              final product = products[index];
              final variantIndex = _variantIndexFor(product);
              final expanded = _expandedIndex == index;
              final requiresChoice = selectableVariants(product).length > 1;
              final chosenIndex = requiresChoice
                  ? _variantIndexByProduct[product.id]
                  : variantIndex;
              final buying = _buyingProductId == product.id;
              final facets = store.facetsFor(product.id);
              final brand = facets?.brand?.value;
              final wishlisted = store.wishlist.contains(product.id);
              final price = selectionPrice(product, variantIndex);
              final inStock = selectionInStock(product, variantIndex);

              return SizedBox(
                width: expanded ? panelWidth * 1.05 : panelWidth,
                child: Semantics(
                  expanded: expanded,
                  child: AnimatedContainer(
                    duration: reduceMotion(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                    decoration: BoxDecoration(
                      color: palette.surfaceDeep,
                      borderRadius: BoutiqueRadius.tile,
                      border: expanded
                          ? Border.all(color: palette.goldText, width: 1)
                          : Border.all(color: palette.hairline, width: 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              InkWell(
                                key: ValueKey('for-you-options-${product.id}'),
                                onTap: () => setState(
                                  () =>
                                      _expandedIndex = expanded ? null : index,
                                ),
                                child: Builder(
                                  builder: (context) {
                                    final url =
                                        _panelImage(product, variantIndex);
                                    if (url == null) {
                                      return const SizedBox.shrink();
                                    }
                                    return MonettaImage(
                                      url: url,
                                      fit: BoxFit.contain,
                                    );
                                  },
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: _FeedWishlistControl(
                                  wishlisted: wishlisted,
                                  onPressed: () => unawaited(
                                    store.toggleWishlist(product.id),
                                  ),
                                ),
                              ),
                              if (inStock && !buying)
                                Positioned(
                                  right: 4,
                                  bottom: 4,
                                  child: ProductQuickAddButton(
                                    key: ValueKey('for-you-add-${product.id}'),
                                    product: product,
                                    productName: product.title,
                                    selectedVariantId: _variantIndexByProduct
                                            .containsKey(product.id)
                                        ? selectedVariant(product, variantIndex)
                                            ?.id
                                        : null,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: panelWidth),
                          child: SingleChildScrollView(
                            primary: false,
                            padding: const EdgeInsets.all(BoutiqueSpace.md),
                            child: Column(
                              children: [
                                if (brand != null)
                                  Text(
                                    brandLabel(brand),
                                    textAlign: TextAlign.center,
                                    style: boutiqueText(
                                      size: 14,
                                      weight: FontWeight.w600,
                                      color: palette.ink,
                                    ),
                                  ),
                                Text(
                                  cardPieceName(title: product.title),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: boutiqueTitle(
                                    size: 16,
                                    color: palette.ink,
                                  ),
                                ),
                                const SizedBox(height: BoutiqueSpace.xs),
                                SelectionPriceView(
                                  price: price,
                                  compare:
                                      selectedVariant(product, variantIndex)
                                          ?.compareAtPrice,
                                  size: 15,
                                  centered: true,
                                  inStock: inStock,
                                ),
                                if (expanded) ...[
                                  if (requiresChoice) ...[
                                    const SizedBox(height: BoutiqueSpace.sm),
                                    IgnorePointer(
                                      ignoring: buying,
                                      child: ProductOptionSelector(
                                        product: product,
                                        selectedIndex: chosenIndex,
                                        showSelectedName: false,
                                        colorHeading: 'Colores',
                                        onSelect: (i) {
                                          if (!buying) {
                                            _setVariantIndex(product, i);
                                          }
                                        },
                                      ),
                                    ),
                                    if (chosenIndex == null)
                                      const Text(
                                        'Elige una opción para continuar.',
                                      ),
                                  ],
                                  const SizedBox(height: BoutiqueSpace.sm),
                                  ClientGuideButton(
                                    label:
                                        buying ? 'Agregando…' : 'Comprar ahora',
                                    onPressed: inStock &&
                                            chosenIndex != null &&
                                            _buyingProductId == null
                                        ? () => _buyNow(product, chosenIndex)
                                        : null,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FeedWishlistControl extends StatelessWidget {
  const _FeedWishlistControl({
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
          ),
        ),
      ),
    );
  }
}
