/// «Lo más buscado» horizontal rail (distinct from Nueva colección source).
library;

import 'package:flutter/material.dart';

import '../../domain/product.dart';
import '../boutique/boutique_tokens.dart';
import '../catalog/product_card.dart';
import '../catalog/product_tile.dart';

class HomeMostWantedSection extends StatelessWidget {
  const HomeMostWantedSection({
    required this.products,
    required this.onOpenAll,
    super.key,
  });

  final List<Product> products;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    final width = MediaQuery.sizeOf(context).width;
    final cardWidth = (width * .36).clamp(132.0, 190.0);
    final railHeight = productTileExtent(
      tileWidth: cardWidth,
      textScaler: MediaQuery.textScalerOf(context),
      density: ProductTileDensity.compact,
      priceLines: tilePriceLinesFor(products),
    );

    return Column(
      key: const ValueKey('home-section-most-wanted'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BoutiqueSectionHeader(
          title: 'Lo más buscado',
          actionLabel: 'Ver todo',
          onAction: onOpenAll,
        ),
        SizedBox(
          height: railHeight,
          child: ListView.separated(
            key: const ValueKey('home-most-wanted-rail'),
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: BoutiqueSpace.gutter),
            itemCount: products.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: BoutiqueSpace.md),
            itemBuilder: (context, index) => SizedBox(
              width: cardWidth,
              child: ProductCard(
                product: products[index],
                density: ProductTileDensity.compact,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
