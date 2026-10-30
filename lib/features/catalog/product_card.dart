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
/// ## Interaction
///
/// Tapping the card (photo or text) opens the quick view
/// ([showProductQuickView]); the brown «VER PRODUCTO» pill opens the product
/// page ([openProduct]). Inside a tablet detail pane ([BrowseDetailScope]) a
/// tap selects the product in that pane instead. The card has no "+": adding
/// to the bag happens in the quick view.
///
/// Every parameter except [product] is optional.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/motion.dart';
import '../../domain/product.dart';
import '../../main.dart';
import '../../reco/events.dart';
import '../product/product_screen.dart';
import '../product/quick_view.dart';
import 'product_tile.dart';
import 'browse_detail_layout.dart';

export 'product_tile.dart'
    show
        MonettaProductTile,
        TileViewProductButton,
        ProductTileData,
        ProductTileDensity,
        ProductTileMetrics,
        kTileFooterExtent,
        ProductTileVariant,
        ProductTileVariantMetrics,
        productGridColumns,
        productGridDelegate,
        productTileExtent,
        tilePriceLinesFor;

class ProductCard extends StatelessWidget {
  const ProductCard({
    required this.product,
    this.urgency,
    this.wide = false,
    this.density = ProductTileDensity.grid,
    this.showWishlist = true,
    this.showQuickAdd = false,
    this.showViewProduct = true,
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

  /// [ProductTileDensity.grid] is the default for two-column grids.
  /// [ProductTileDensity.compact] tightens the padding and keeps the name to
  /// one line, for narrow rails.
  final ProductTileDensity density;

  /// Set false where a favourite would be meaningless or unsupported.
  final bool showWishlist;

  /// Retained for source compatibility. The card no longer draws a "+": the
  /// quick view carries «AGREGAR A BOLSA». The value is ignored.
  final bool showQuickAdd;

  /// Draws the brown «VER PRODUCTO» pill under the price. On by default; the
  /// grids reserve [kTileFooterExtent] per row for it.
  final bool showViewProduct;

  /// Overrides what a long press does. By default a long press opens the
  /// quick view, like a tap (a tap always opens it unless [onTap] is given).
  final VoidCallback? onQuickView;

  /// Overrides the default tap, which opens the quick view (or selects the
  /// product in a tablet detail pane).
  final VoidCallback? onTap;

  void _openQuickView(BuildContext context) =>
      unawaited(showProductQuickView(context, product));

  /// A long press: the caller's [onQuickView] when given, the quick view
  /// otherwise.
  void _longPress(BuildContext context) {
    if (onQuickView != null) {
      onQuickView!();
    } else {
      _openQuickView(context);
    }
  }

  void _tap(BuildContext context) {
    if (onTap != null) {
      onTap!();
      return;
    }
    // A tablet detail pane keeps selecting the product beside the list.
    if (BrowseDetailScope.maybeOf(context) != null &&
        context.findAncestorWidgetOfExactType<ProductScreen>() == null) {
      openProduct(context, product);
      return;
    }
    _openQuickView(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final facets = store.facetsFor(product.id);
    final wishlisted = store.wishlist.contains(product.id);
    final data = ProductTileData.fromProduct(product, facets: facets);

    return ProductResultAnchor(
      productId: product.id,
      child: MonettaProductTile(
        data: data,
        density: density,
        eyebrow: urgency,
        wishlisted: wishlisted,
        onToggleWishlist:
            showWishlist ? () => store.toggleWishlist(product.id) : null,
        onQuickView: () => _longPress(context),
        footer: showViewProduct
            ? TileViewProductButton(
                key: Key('view-product-${product.id}'),
                onPressed: () => openProduct(context, product),
              )
            : null,
        semanticHint: 'Abre la vista previa',
        onTap: () => _tap(context),
      ),
    );
  }
}

void openProduct(
  BuildContext context,
  Product product, {
  int initialVariantIndex = 0,
}) {
  final browse = BrowseDetailScope.maybeOf(context);
  if (browse != null &&
      context.findAncestorWidgetOfExactType<ProductScreen>() == null) {
    browse.select(product, initialVariantIndex);
    return;
  }
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
            priceLines: tilePriceLinesFor(products),
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
