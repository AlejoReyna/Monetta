/// The one product presentation every Monetta catalog surface renders.
///
/// Search, the product list, collections, the brand page and Home's rails all
/// draw the same anatomy: a complete photograph on a neutral ground, an
/// optional data-backed badge, an optional favourite, then brand, name and
/// price. The screens differ in *what they scope*, never in how a piece looks.
///
/// ## Why a presentation widget and not one model
///
/// [Product] (Shopify, MXN, Monetta checkout) and [CatalogItem] (source
/// independent, possibly USD, possibly an external merchant) are genuinely
/// different domain objects — collapsing them would lose currency, identity,
/// origin and purchase destination. So the *view data* is shared and the two
/// models keep their own small adapters:
/// [ProductTileData.fromProduct] and [ProductTileData.fromCatalogItem].
library;

import 'package:flutter/material.dart';

import '../../app/card_lift.dart';
import '../../app/media/monetta_image.dart';
import '../../app/shopper_copy.dart';
import '../../app/theme.dart';
import '../../data/media/media_url.dart';
import '../../data/normalize/facets.dart';
import '../../domain/catalog_item.dart';
import '../../domain/product.dart';
import '../../reco/explainer.dart';
import '../boutique/boutique_tokens.dart';

/// How much room a tile has. Only the image proportion and the type scale
/// change — the anatomy is identical, so a shopper recognises the same card
/// in a Home rail and in a two-column grid.
enum ProductTileDensity {
  /// Two-column grids: search results, the product list, collections, brand.
  /// Image is 4:5, matching the proportion shipped before this redesign, so
  /// existing rail height arithmetic keeps working.
  grid,

  /// Home rails and any narrow carousel. Square image, one-line name.
  compact,
}

extension ProductTileMetrics on ProductTileDensity {
  /// width / height of the image area.
  double get imageAspectRatio => this == ProductTileDensity.compact ? 1 : 4 / 5;

  /// height / width — what a grid delegate needs to reserve.
  double get imageHeightFactor => 1 / imageAspectRatio;

  int get nameMaxLines => this == ProductTileDensity.compact ? 1 : 2;

  double get brandSize => this == ProductTileDensity.compact ? 12 : 13;
  double get nameSize => this == ProductTileDensity.compact ? 13 : 14;
  double get priceSize => this == ProductTileDensity.compact ? 14 : 16;

  /// Unscaled height of the caption under the image, used to size grid rows
  /// and rails without pinning the text itself to a fixed box. Includes the
  /// 12pt gap between photo and caption plus brand, name and price.
  ///
  /// Measured against bundled catalog data (fallback type, scale 1): a grid
  /// caption peaks near 100pt with a wrapped compare-at price (was 98pt and
  /// overflowed by 9pt); a compact caption peaks near 82pt when the price
  /// wraps under a narrow card (was 74pt and overflowed by up to 25pt).
  double get captionHeight => this == ProductTileDensity.compact ? 88 : 112;
}

/// Why a badge is showing. Never decorative: each tone has one data source.
enum ProductBadgeTone {
  /// A real discount read off `compare_at`.
  sale,

  /// [CanonicalFacets.newArrival] — the rules file's own window, not a guess.
  fresh,
}

@immutable
class ProductTileBadge {
  const ProductTileBadge({required this.label, required this.tone});

  final String label;
  final ProductBadgeTone tone;
}

/// Everything the shared tile draws, already resolved to shopper-facing text.
@immutable
class ProductTileData {
  const ProductTileData({
    required this.title,
    required this.priceLabel,
    required this.imageUrls,
    this.brand,
    this.compareAtLabel,
    this.badge,
    this.inStock = true,
    this.imageCacheWidth = MediaUrl.cardWidth,
  });

  /// Brand line. Null hides the line rather than printing a placeholder.
  final String? brand;
  final String title;
  final String priceLabel;

  /// Struck-through original price. Only set when the data carries one.
  final String? compareAtLabel;
  final ProductTileBadge? badge;
  final List<String> imageUrls;
  final bool inStock;
  final int imageCacheWidth;

  String get fallbackLabel => brand == null ? title : '$brand · $title';

  String get semanticLabel {
    final parts = <String>[
      if (brand != null) brand!,
      title,
      priceLabel,
      if (compareAtLabel != null) 'antes $compareAtLabel',
      if (!inStock) 'agotado',
    ];
    return parts.join(', ');
  }

  /// Shopify product → tile. [facets] supplies the brand and the new-arrival
  /// window; both are optional and simply drop out when unresolved.
  factory ProductTileData.fromProduct(
    Product product, {
    CanonicalFacets? facets,
    bool allowNewBadge = true,
  }) {
    final brand = facets?.brand?.value;
    final discount = (product.discountFraction * 100).round();
    final badge = product.isOnSale && discount > 0
        ? ProductTileBadge(label: '-$discount%', tone: ProductBadgeTone.sale)
        : allowNewBadge && (facets?.newArrival ?? false)
            ? const ProductTileBadge(
                label: 'NUEVO',
                tone: ProductBadgeTone.fresh,
              )
            : null;

    return ProductTileData(
      brand: brand == null ? null : brandLabel(brand),
      title: cardPieceName(
        title: product.title,
        colorSlug: facets == null || facets.colors.isEmpty
            ? null
            : facets.colors.first.value,
      ),
      priceLabel: kMoney.format(product.price),
      compareAtLabel:
          product.isOnSale ? kMoney.format(product.compareAtPrice) : null,
      badge: badge,
      imageUrls: product.images,
      inStock: product.isInStock,
    );
  }

  /// Source-independent catalog item → tile.
  ///
  /// Currency stays explicit ([formatCatalogMoney] prints `MXN`/`USD`) and an
  /// unknown price is never coerced to `$0`. No badge is derived here: a
  /// [CatalogItem] carries no `compare_at`, and `sourcePrice` is the merchant's
  /// own listing, not a Monetta discount.
  factory ProductTileData.fromCatalogItem(CatalogItem item) {
    return ProductTileData(
      brand: _catalogBrandLabel(item),
      title: item.isExternal
          ? externalProductName(title: item.title, category: item.category)
          : shopperProductName(item.title),
      priceLabel: formatCatalogMoney(item.price),
      imageUrls: [if (item.imageUrl case final url?) url],
      inStock: item.availability != CatalogAvailability.outOfStock,
    );
  }
}

String _catalogBrandLabel(CatalogItem item) {
  final brand = item.brand.trim();
  return humanizeCatalogValue(brand.isEmpty ? item.merchant.trim() : brand);
}

/// The shared card.
///
/// It owns no navigation and reads no store: every screen passes what it
/// already knows. That is what lets the browse screen render it without a
/// [StoreScope] while the product grids render it with favourites wired up.
class MonettaProductTile extends StatelessWidget {
  const MonettaProductTile({
    required this.data,
    required this.onTap,
    this.density = ProductTileDensity.grid,
    this.wishlisted = false,
    this.onToggleWishlist,
    this.onQuickView,
    this.imageOverlay,
    this.eyebrow,
    super.key,
  });

  final ProductTileData data;
  final VoidCallback onTap;
  final ProductTileDensity density;

  /// Favourite state. The heart is only drawn when [onToggleWishlist] is
  /// given, so a surface without wishlist support never shows a dead control.
  final bool wishlisted;
  final VoidCallback? onToggleWishlist;

  /// Package C's quick view. When provided, a long press opens it and a
  /// visible "Vista rápida" action appears on the photo for accessibility;
  /// nothing changes when it is null.
  final VoidCallback? onQuickView;

  /// Extra marker pinned to the top-left of the photograph, e.g. the
  /// external-source badge. Drawn under the discount badge's slot.
  final Widget? imageOverlay;

  /// Optional short line above the brand — a real restock or discount reason,
  /// never a recommender sentence.
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;

    return Semantics(
      button: true,
      label: data.semanticLabel,
      child: MonettaCardLift(
        borderRadius: BoutiqueRadius.tile,
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onQuickView,
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: density.imageAspectRatio,
                child: _TileImage(
                  data: data,
                  wishlisted: wishlisted,
                  onToggleWishlist: onToggleWishlist,
                  onQuickView: onQuickView,
                  overlay: imageOverlay,
                ),
              ),
              const SizedBox(height: BoutiqueSpace.md),
              if (eyebrow case final line? when line.trim().isNotEmpty) ...[
                Text(
                  line.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: boutiqueEyebrow(size: 11, color: palette.sale),
                ),
                const SizedBox(height: BoutiqueSpace.xs),
              ],
              if (data.brand case final brand?) ...[
                Text(
                  brand,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: boutiqueText(
                    size: density.brandSize,
                    weight: FontWeight.w600,
                    color: palette.ink,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Text(
                data.title,
                maxLines: density.nameMaxLines,
                overflow: TextOverflow.ellipsis,
                style: boutiqueText(
                  size: density.nameSize,
                  color: palette.inkMuted,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: BoutiqueSpace.xs),
              _PriceLine(data: data, density: density),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.data, required this.density});

  final ProductTileData data;
  final ProductTileDensity density;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    // Prices wrap as whole units: `softWrap: false` stops "$ 1,299.00" from
    // breaking after the currency mark into a third run on narrow cards. The
    // Wrap still moves the compare-at price to its own run when the pair does
    // not fit — that two-run peak is what `captionHeight` reserves.
    return Wrap(
      spacing: BoutiqueSpace.sm,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          data.priceLabel,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: boutiqueText(
            size: density.priceSize,
            weight: FontWeight.w700,
            color: palette.ink,
            height: 1.2,
          ),
        ),
        if (data.compareAtLabel case final before?)
          Text(
            before,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: boutiqueText(
              size: density.priceSize - 3,
              color: palette.inkMuted,
              height: 1.2,
              decoration: TextDecoration.lineThrough,
            ),
          ),
      ],
    );
  }
}

/// The photograph: neutral ground, product shown whole, badge, favourite.
class _TileImage extends StatefulWidget {
  const _TileImage({
    required this.data,
    required this.wishlisted,
    required this.onToggleWishlist,
    required this.overlay,
    this.onQuickView,
  });

  final ProductTileData data;
  final bool wishlisted;
  final VoidCallback? onToggleWishlist;
  final VoidCallback? onQuickView;
  final Widget? overlay;

  @override
  State<_TileImage> createState() => _TileImageState();
}

class _TileImageState extends State<_TileImage> {
  int _activeIndex = 0;

  List<String> get _candidates => [
        for (final url in widget.data.imageUrls)
          if (url.trim().isNotEmpty) url,
      ];

  void _advance() {
    if (_activeIndex + 1 >= _candidates.length || !mounted) return;
    setState(() => _activeIndex += 1);
  }

  @override
  void didUpdateWidget(covariant _TileImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.imageUrls != widget.data.imageUrls) _activeIndex = 0;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final candidates = _candidates;
    final url = candidates.isEmpty ? null : candidates[_activeIndex];
    final badge = widget.data.badge;

    return ClipRRect(
      borderRadius: BoutiqueRadius.tile,
      child: ColoredBox(
        color: palette.surfaceDeep,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // `contain` with a small inset: a handbag's handle and straps are
            // the part a shopper recognises, and `cover` crops exactly those.
            Padding(
              padding: const EdgeInsets.all(BoutiqueSpace.sm),
              child: MonettaImage(
                key: ValueKey(url ?? 'fallback'),
                url: url,
                fit: BoxFit.contain,
                cacheWidth: widget.data.imageCacheWidth,
                fallbackLabel: widget.data.fallbackLabel,
                onFailed: _advance,
              ),
            ),
            if (!widget.data.inStock)
              IgnorePointer(
                child: ColoredBox(
                  // Sold out has to read without relying on colour alone, and
                  // it never blocks the tap that opens the piece.
                  color: palette.canvas.withValues(alpha: 0.66),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: BoutiqueSpace.md,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: palette.canvas,
                        borderRadius: BoutiqueRadius.capsule,
                        border: Border.all(color: palette.ink, width: 0.8),
                      ),
                      child: Text(
                        'AGOTADO',
                        style: boutiqueEyebrow(size: 10, color: palette.ink),
                      ),
                    ),
                  ),
                ),
              ),
            if (badge != null)
              Positioned(
                top: BoutiqueSpace.sm,
                left: BoutiqueSpace.sm,
                child: _Badge(badge: badge),
              ),
            if (widget.overlay case final overlay?)
              Positioned(
                bottom: BoutiqueSpace.sm,
                left: BoutiqueSpace.sm,
                child: overlay,
              ),
            if (widget.onToggleWishlist case final toggle?)
              Positioned(
                top: 0,
                right: 0,
                child: _WishlistButton(
                  wishlisted: widget.wishlisted,
                  onPressed: toggle,
                ),
              ),
            if (widget.onQuickView case final quickView?)
              Positioned(
                bottom: BoutiqueSpace.xs,
                right: BoutiqueSpace.xs,
                child: _QuickViewButton(onPressed: quickView),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.badge});

  final ProductTileBadge badge;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    // White on the brand gold measures 2.6:1 — below AA — so the discount
    // badge keeps white on the sale red and the new badge uses ink on gold.
    final background =
        badge.tone == ProductBadgeTone.sale ? palette.sale : palette.gold;
    final foreground = badge.tone == ProductBadgeTone.sale
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF111111);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BoutiqueRadius.capsule,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          badge.label,
          style: boutiqueEyebrow(size: 10, color: foreground),
        ),
      ),
    );
  }
}

/// 48×48 hit area over an 18px heart, so tapping the favourite can never be
/// mistaken for tapping the card.
class _WishlistButton extends StatelessWidget {
  const _WishlistButton({required this.wishlisted, required this.onPressed});

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
          tooltip: wishlisted ? 'Quitar de favoritos' : 'Guardar',
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          icon: Icon(
            wishlisted ? Icons.favorite : Icons.favorite_border,
            size: 19,
            color: wishlisted ? palette.goldText : palette.ink,
          ),
        ),
      ),
    );
  }
}

/// Visible, accessible entry to the quick view. Rendered only when the surface
/// wires [MonettaProductTile.onQuickView]; long-press remains as a shortcut.
class _QuickViewButton extends StatelessWidget {
  const _QuickViewButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Semantics(
      button: true,
      label: 'Vista rápida',
      child: SizedBox(
        width: BoutiqueSpace.tapTarget,
        height: BoutiqueSpace.tapTarget,
        child: Center(
          child: Material(
            color: palette.surface.withValues(alpha: 0.94),
            shape: const CircleBorder(),
            elevation: 0,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Tooltip(
                message: 'Vista rápida',
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(
                    Icons.visibility_outlined,
                    size: 19,
                    color: palette.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grid
// ---------------------------------------------------------------------------

/// Column count for the shared grid.
///
/// Columns drop rather than squeeze: below ~150pt a two-column tile can no
/// longer show a bag and a readable price at the same time.
int productGridColumns(double width) {
  if (width >= 1060) return 4;
  if (width >= 720) return 3;
  if (width < 340) return 1;
  return 2;
}

/// A grid delegate sized from the real tile width and the shopper's own text
/// scale, so large type produces taller rows instead of clipped captions.
SliverGridDelegate productGridDelegate(
  BuildContext context, {
  required double availableWidth,
  ProductTileDensity density = ProductTileDensity.grid,
  double spacing = BoutiqueSpace.md,
  double rowSpacing = BoutiqueSpace.xl,
}) {
  final columns = productGridColumns(availableWidth);
  final tileWidth = (availableWidth - spacing * (columns - 1)) / columns;
  final caption = MediaQuery.textScalerOf(context).scale(
    density.captionHeight,
  );
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    crossAxisSpacing: spacing,
    mainAxisSpacing: rowSpacing,
    mainAxisExtent: tileWidth * density.imageHeightFactor + caption,
  );
}
