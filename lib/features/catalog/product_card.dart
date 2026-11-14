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
/// to the bag happens in the quick view. On a two-sided window
/// ([DuoWorkspace]) both open on the right side, and a long press lifts the
/// card so it can be dropped on the bag there.
///
/// Every parameter except [product] is optional.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/media/monetta_image.dart';
import '../../app/motion.dart';
import '../../data/media/media_url.dart';
import '../../domain/product.dart';
import '../../main.dart';
import '../../reco/events.dart';
import '../boutique/boutique_tokens.dart';
import '../checkout/mini_cart.dart';
import '../navigation/duo_workspace.dart';
import '../product/product_screen.dart';
import '../product/product_selection.dart';
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

class ProductCard extends StatefulWidget {
  const ProductCard({
    required this.product,
    this.urgency,
    this.wide = false,
    this.density = ProductTileDensity.grid,
    this.showWishlist = true,
    this.showQuickAdd = false,
    this.showViewProduct = false,
    this.onQuickView,
    this.onTap,
    this.initialVariantId,
    this.onVariantChanged,
    this.openDirectly = false,
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
  /// quick view carries «Agregar al carrito». The value is ignored.
  final bool showQuickAdd;

  /// Draws a «VER PRODUCTO» pill under the price. Off by default: the UI v4.1
  /// card is photo, brand, name and price, and the quick view carries «Ver
  /// producto». A grid that turns it on passes [kTileFooterExtent] as its
  /// footer reserve.
  final bool showViewProduct;

  /// Overrides what a long press does. By default a long press opens the
  /// quick view, like a tap (a tap always opens it unless [onTap] is given).
  final VoidCallback? onQuickView;

  /// Overrides the default tap, which opens the quick view (or selects the
  /// product in a tablet detail pane).
  final VoidCallback? onTap;
  final String? initialVariantId;
  final ValueChanged<String?>? onVariantChanged;
  final bool openDirectly;

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  late String? _selectedId =
      widget.initialVariantId ?? selectedVariant(widget.product, 0)?.id;
  Product get product => widget.product;
  ProductTileDensity get density => widget.density;
  VoidCallback? get onQuickView => widget.onQuickView;
  VoidCallback? get onTap => widget.onTap;
  bool get showWishlist => widget.showWishlist;
  bool get showViewProduct => widget.showViewProduct;
  String? get urgency => widget.urgency;

  @override
  void didUpdateWidget(covariant ProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != product.id ||
        oldWidget.initialVariantId != widget.initialVariantId) {
      _selectedId = widget.initialVariantId ?? selectedVariant(product, 0)?.id;
    }
  }

  void _openPdp(BuildContext context) => openProduct(
        context,
        product,
        initialVariantId: _selectedId,
        initialVariantIndex: _selectedId == null ? -1 : 0,
      );

  Widget? _options() {
    final choices = selectableVariants(product);
    if (choices.length < 2) return null;
    final selected = selectedVariant(
      product,
      variantIndexForId(product, _selectedId, fallback: -1),
    );
    return PopupMenuButton<String>(
      tooltip: 'Elegir opción',
      initialValue: _selectedId,
      onSelected: (id) {
        setState(() => _selectedId = id);
        widget.onVariantChanged?.call(id);
      },
      itemBuilder: (_) => [
        for (final variant in choices)
          PopupMenuItem(
            value: variant.id,
            child: Text(
              '${variant.title}${variant.available ? '' : ' · Agotado'}',
            ),
          ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selected?.title ?? 'Elegir opción',
                softWrap: true,
                style: boutiqueText(size: 12, height: 1.3),
              ),
            ),
            const Icon(Icons.expand_more, size: 18),
          ],
        ),
      ),
    );
  }

  void _openQuickView(BuildContext context) => unawaited(
        showProductQuickView(
          context,
          product,
          initialVariantId: _selectedId,
          initialVariantIndex: _selectedId == null ? -1 : 0,
          onVariantChanged: (id) {
            if (mounted) setState(() => _selectedId = id);
            widget.onVariantChanged?.call(id);
          },
        ),
      );

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
    if (widget.openDirectly) {
      _openPdp(context);
      return;
    }
    // A tablet detail pane keeps selecting the product beside the list.
    if (BrowseDetailScope.maybeOf(context) != null &&
        context.findAncestorWidgetOfExactType<ProductScreen>() == null) {
      _openPdp(context);
      return;
    }
    _openQuickView(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final facets = store.facetsFor(product.id);
    final wishlisted = store.wishlist.contains(product.id);
    final data = ProductTileData.fromProduct(
      product,
      facets: facets,
      variant: selectedVariant(
        product,
        variantIndexForId(product, _selectedId, fallback: -1),
      ),
      selectDefaultVariant: false,
    );
    // Beside the bag a long press lifts the card instead of opening the card.
    final lifts = DuoWorkspace.isDual(context, listen: true) &&
        DuoWorkspace.regionOf(context) == DuoRegion.browse;

    return DuoBagDragSource(
      drag: productBagDrag(product),
      child: ProductResultAnchor(
        productId: product.id,
        child: MonettaProductTile(
          data: data,
          density: density,
          eyebrow: urgency,
          optionControl: _options(),
          wishlisted: wishlisted,
          onToggleWishlist:
              showWishlist ? () => store.toggleWishlist(product.id) : null,
          onQuickView: lifts ? null : () => _longPress(context),
          footer: showViewProduct
              ? TileViewProductButton(
                  key: Key('view-product-${product.id}'),
                  onPressed: () => _openPdp(context),
                )
              : null,
          semanticHint:
              widget.openDirectly ? 'Abre el producto' : 'Abre la vista previa',
          onTap: () => _tap(context),
        ),
      ),
    );
  }
}

/// How a card for [product] is dragged to a two-sided window's bag.
DuoBagDrag productBagDrag(Product product) => DuoBagDrag(
      feedback: _BagDragFeedback(product: product),
      onDrop: (paneContext) => _dropInBag(paneContext, product),
    );

/// Dropped on the bag: one buyable variant goes in and is confirmed there;
/// several open the card on that side to choose one, so a variant is never
/// picked on the shopper's behalf. The same rule as the card's "+".
Future<void> _dropInBag(BuildContext paneContext, Product product) async {
  if (selectableVariants(product).length > 1) {
    DuoWorkspace.showBag(paneContext);
    await showProductQuickView(paneContext, product, requireChoice: true);
    return;
  }
  final result = await tryAddSelectionToBag(paneContext, product, 0);
  if (!paneContext.mounted) return;
  final message = switch (result.status) {
    BagAddStatus.added => null,
    BagAddStatus.soldOut => 'Esta opción está agotada.',
    BagAddStatus.unavailable => 'Esta pieza no está disponible por ahora.',
    BagAddStatus.failed => 'No pudimos agregar la pieza. Intenta de nuevo.',
  };
  if (message != null) {
    ScaffoldMessenger.maybeOf(paneContext)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
    return;
  }
  NotificationScope.maybeOf(paneContext)?.recordPushOutcome('add_to_cart');
  DuoWorkspace.showBag(paneContext);
  await showMiniCart(paneContext);
}

/// The photograph that follows the finger while a card is dragged to the bag.
class _BagDragFeedback extends StatelessWidget {
  const _BagDragFeedback({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Material(
      key: const Key('duo-drag-feedback'),
      color: palette.canvas,
      elevation: 4,
      shadowColor: const Color(0x29000000),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: palette.hairline),
      ),
      child: SizedBox(
        width: 96,
        height: 112,
        child: Padding(
          padding: const EdgeInsets.all(BoutiqueSpace.sm),
          child: PackshotBlend(
            ground: palette.canvas,
            child: MonettaImage(
              url: product.primaryImage,
              fit: BoxFit.contain,
              cacheWidth: MediaUrl.thumbWidth,
              fallbackLabel: product.title,
            ),
          ),
        ),
      ),
    );
  }
}

void openProduct(
  BuildContext context,
  Product product, {
  int initialVariantIndex = 0,
  String? initialVariantId,
}) {
  final store = StoreScope.of(context);
  initialVariantIndex = variantIndexForId(
    product,
    initialVariantId,
    fallback: initialVariantIndex,
  );
  // One key wherever the page is drawn: a window that opens moves it to its
  // right side with its state.
  final key = GlobalKey(debugLabel: 'product ${product.id}');
  Widget page(BuildContext _) => StoreScope(
        notifier: store,
        child: ProductScreen(
          key: key,
          productId: product.id,
          initialVariantIndex: initialVariantIndex,
          initialVariantId: initialVariantId,
        ),
      );
  final beside = DuoPanePage(
    kind: DuoPaneKind.product,
    productId: product.id,
    builder: page,
  );
  // A two-sided window opens the product on its right side, beside the list.
  if (DuoWorkspace.showPane(context, beside)) {
    store.record(EventType.productView, productId: product.id);
    return;
  }
  final browse = BrowseDetailScope.maybeOf(context);
  if (browse != null &&
      context.findAncestorWidgetOfExactType<ProductScreen>() == null) {
    browse.select(product, initialVariantIndex);
    return;
  }
  store.record(EventType.productView, productId: product.id);
  Navigator.of(context).push(
    monettaFadeRoute(
      Builder(builder: page),
      settings: RouteSettings(
        name: DuoWorkspace.productRoute,
        arguments: beside,
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
