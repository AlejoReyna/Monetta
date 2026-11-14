/// v4.1 «Para ti» accordion-style horizontal product feed.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/media/monetta_image.dart';
import '../../app/shopper_copy.dart';
import '../../app/theme.dart' show formatShopperPrice;
import '../../reco/explainer.dart' show brandLabel;
import '../../domain/product.dart';
import '../../main.dart';
import '../../app/motion.dart';
import '../boutique/boutique_tokens.dart';
import '../boutique/client_guide_components.dart';
import '../checkout/checkout_screen.dart' show openBag;
import '../product/product_selection.dart';
import '../product/quick_view.dart' show showProductQuickView;
import 'home_v41_catalog.dart';

class HomeForYouSection extends StatefulWidget {
  const HomeForYouSection({super.key});

  @override
  State<HomeForYouSection> createState() => _HomeForYouSectionState();
}

class _HomeForYouSectionState extends State<HomeForYouSection> {
  final Map<String, int> _variantIndexByProduct = {};
  int? _expandedIndex;

  int _variantIndexFor(Product product) =>
      _variantIndexByProduct[product.id] ?? 0;

  void _setVariantIndex(Product product, int index) {
    setState(() => _variantIndexByProduct[product.id] = index);
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
              final facets = store.facetsFor(product.id);
              final brand = facets?.brand?.value;
              final wishlisted = store.wishlist.contains(product.id);
              final price = selectionPrice(product, variantIndex);
              final inStock = selectionInStock(product, variantIndex);
              final adding = ValueNotifier<bool>(false);

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
                              GestureDetector(
                                onTap: () => setState(
                                  () =>
                                      _expandedIndex = expanded ? null : index,
                                ),
                                child: Builder(
                                  builder: (context) {
                                    final url =
                                        _panelImage(product, variantIndex);
                                    if (url == null)
                                      return const SizedBox.shrink();
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
                              Positioned(
                                right: 4,
                                bottom: 4,
                                child: _FeedAddControl(
                                  enabled: inStock,
                                  adding: adding,
                                  onAdd: () async {
                                    if (selectableVariants(product).length >
                                            1 &&
                                        !hasReliableColorOptions(product)) {
                                      if (!context.mounted) return;
                                      await showProductQuickView(
                                        context,
                                        product,
                                        requireChoice: true,
                                        initialVariantIndex: variantIndex,
                                      );
                                      return;
                                    }
                                    adding.value = true;
                                    final result = await tryAddSelectionToBag(
                                      context,
                                      product,
                                      variantIndex,
                                    );
                                    adding.value = false;
                                    if (!context.mounted) return;
                                    if (result.status == BagAddStatus.added) {
                                      ScaffoldMessenger.maybeOf(context)
                                          ?.showSnackBar(
                                        const SnackBar(
                                          content: Text('Agregado a la bolsa'),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
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
                              Text(
                                formatShopperPrice(price),
                                style: boutiqueText(
                                  size: 15,
                                  weight: FontWeight.w600,
                                  color: palette.ink,
                                ),
                              ),
                              if (expanded &&
                                  selectableVariants(product).isNotEmpty) ...[
                                const SizedBox(height: BoutiqueSpace.sm),
                                ProductOptionSelector(
                                  product: product,
                                  selectedIndex: variantIndex,
                                  showSelectedName: false,
                                  colorHeading: 'Colores',
                                  onSelect: (i) => _setVariantIndex(product, i),
                                ),
                                const SizedBox(height: BoutiqueSpace.sm),
                                ClientGuideButton(
                                  label: 'Comprar ahora',
                                  onPressed: inStock
                                      ? () async {
                                          final result =
                                              await tryAddSelectionToBag(
                                            context,
                                            product,
                                            variantIndex,
                                          );
                                          if (!context.mounted) return;
                                          if (result.status ==
                                              BagAddStatus.added) {
                                            await openBag(context);
                                          }
                                        }
                                      : null,
                                ),
                              ],
                            ],
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

class _FeedAddControl extends StatelessWidget {
  const _FeedAddControl({
    required this.enabled,
    required this.adding,
    required this.onAdd,
  });

  final bool enabled;
  final ValueNotifier<bool> adding;
  final Future<void> Function() onAdd;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: adding,
      builder: (context, busy, _) {
        return GuideGlassIconButton(
          tooltip: 'Agregar a la bolsa',
          onPressed: !enabled || busy ? null : () => unawaited(onAdd()),
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_rounded, size: 20),
        );
      },
    );
  }
}
