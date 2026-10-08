/// One shopper card for a Monetta (Shopify) product.
///
/// This is the widget every package uses — Home's rails (A), the catalog
/// surfaces here (B), the related grid on the product page (C) and Favourites
/// (E). It is a thin, store-aware wrapper: the anatomy, proportions and
/// typography live in [MonettaProductTile] so a [CatalogItem] renders
/// identically without being forced into a [Product].
///
/// ## Contract
///
/// ```dart
/// ProductCard(product: product)                       // two-column grid
/// ProductCard(product: product, density: ProductTileDensity.compact)
/// ProductCard(product: product, showWishlist: false)   // no favourite
/// ProductCard(product: product, onQuickView: () {…})   // long press (C)
/// ```
///
/// Every parameter except [product] is optional and defaults to the behaviour
/// shipped before the redesign, so existing call sites need no edit.
library;

import 'package:flutter/material.dart';

import '../../app/motion.dart';
import '../../domain/product.dart';
import '../../main.dart';
import '../../reco/events.dart';
import '../product/product_screen.dart';
import 'product_tile.dart';
import 'quick_add_button.dart';

export 'product_tile.dart'
    show
        MonettaProductTile,
        ProductTileData,
        ProductTileDensity,
        ProductTileMetrics,
        ProductTileVariant,
        ProductTileVariantMetrics,
        productGridColumns,
        productGridDelegate;

class ProductCard extends StatelessWidget {
  const ProductCard({
    required this.product,
    this.urgency,
    this.wide = false,
    this.density = ProductTileDensity.grid,
    this.showWishlist = true,
    this.showQuickAdd = true,
    this.onQuickView,
    this.onTap,
    super.key,
  });

  final Product product;

  /// Restock or a real discount only. Never a "porque te gustan" line.
  final String? urgency;

  /// Retained for source compatibility with callers that still pass it. It
  /// has never changed this card's layout and still does not; density is the
  /// supported control.
  final bool wide;

  /// [ProductTileDensity.grid] (4:5 image, two-line name) is the default and
  /// matches the card shipped before the redesign. [ProductTileDensity.compact]
  /// squares the image and keeps the name to one line, for narrow rails.
  final ProductTileDensity density;

  /// Set false where a favourite would be meaningless or unsupported.
  final bool showWishlist;

  /// Whether a buyable card draws the "+" quick-add control. The bag turns it
  /// off for its own recommendations.
  final bool showQuickAdd;

  /// Reserved for package C. When given, a long press opens the quick view;
  /// no button is added and tapping still opens the full product page.
  final VoidCallback? onQuickView;

  /// Overrides the default "open this product" navigation.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final facets = store.facetsFor(product.id);
    final wishlisted = store.wishlist.contains(product.id);
    final data = ProductTileData.fromProduct(product, facets: facets);
    // Only a piece with something to buy gets the "+"; a sold-out one keeps
    // the eye (when the surface wires it).
    final canQuickAdd = showQuickAdd && product.isInStock;

    return MonettaProductTile(
      data: data,
      density: density,
      eyebrow: urgency,
      wishlisted: wishlisted,
      onToggleWishlist:
          showWishlist ? () => store.toggleWishlist(product.id) : null,
      onQuickView: onQuickView,
      quickAction: canQuickAdd
          ? ProductQuickAddButton(
              key: Key('quick-add-${product.id}'),
              product: product,
              productName: data.title,
            )
          : null,
      onTap: onTap ?? () => openProduct(context, product),
    );
  }
}

void openProduct(
  BuildContext context,
  Product product, {
  int initialVariantIndex = 0,
}) {
  final store = StoreScope.of(context);
  store.record(EventType.productView, productId: product.id);
  Navigator.of(context).push(
    monettaFadeRoute(
      StoreScope(
        notifier: store,
        child: ProductScreen(
          productId: product.id,
          initialVariantIndex: initialVariantIndex,
        ),
      ),
    ),
  );
}

/// The shared grid used by search results, the product list, collections and
/// the brand page. Kept here so every consumer gets the same columns, spacing
/// and text-scale behaviour from one import.
class ProductCardGrid extends StatelessWidget {
  const ProductCardGrid({
    required this.products,
    this.padding = EdgeInsets.zero,
    this.density = ProductTileDensity.grid,
    this.shrinkWrap = false,
    this.physics,
    this.controller,
    this.onQuickView,
    super.key,
  });

  final List<Product> products;
  final EdgeInsets padding;
  final ProductTileDensity density;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final ScrollController? controller;
  final void Function(Product product)? onQuickView;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - padding.left - padding.right;
        return GridView.builder(
          padding: padding,
          controller: controller,
          shrinkWrap: shrinkWrap,
          physics: physics,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          gridDelegate: productGridDelegate(
            context,
            availableWidth: available,
            density: density,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return ProductCard(
              key: ValueKey('product-card-${product.id}'),
              product: product,
              density: density,
              onQuickView:
                  onQuickView == null ? null : () => onQuickView!(product),
            );
          },
        );
      },
    );
  }
}
