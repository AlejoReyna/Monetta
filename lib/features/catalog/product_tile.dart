/// The one product presentation every Monetta catalog surface renders.
///
/// Search, the product list, collections, the brand page and Home's rails all
/// draw the same anatomy: a complete photograph on a neutral ground, an
/// optional data-backed badge, an optional favourite, then brand, name and
/// price. The screens differ in *what they scope*, never in how a piece looks.
///
/// Every surface draws [ProductTileVariant.card]: ONE rounded warm card that
/// holds the photograph, the favourite, brand, name, price and the brown
/// «VER PRODUCTO» pill. [ProductTileVariant.edgeToEdge] stays in the API for
/// the continuous photographic grid, but no screen uses it any more.
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

import 'dart:math' as math;
import '../../app/storefront_layout.dart';
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
import 'product_controls.dart';

/// How much room a tile has. Only the type scale and the inner padding
/// change — the anatomy is identical, so a shopper recognises the same card
/// in a Home rail and in a two-column grid.
enum ProductTileDensity {
  /// Two-column grids: search results, the product list, collections, brand.
  grid,

  /// Home rails and any narrow carousel. Tighter padding, one-line name.
  compact,

  /// Four across a phone (the related pieces of the product page): a square
  /// photograph, a 40pt heart, one-line brand and name, a 12pt price and no
  /// «VER PRODUCTO» pill. Tapping it opens the preview like any other card.
  mini,
}

extension ProductTileMetrics on ProductTileDensity {
  /// width / height of the photo area of the edge-to-edge variant. The card
  /// variant always draws a square photograph (see
  /// [ProductTileVariantMetrics.photoAspectRatio]).
  double get imageAspectRatio => this == ProductTileDensity.grid ? 4 / 5 : 1;

  /// height / width of the edge-to-edge photo area.
  double get imageHeightFactor => 1 / imageAspectRatio;

  int get nameMaxLines => this == ProductTileDensity.grid ? 2 : 1;

  /// Type sizes of the edge-to-edge variant (sans).
  double get brandSize => switch (this) {
        ProductTileDensity.grid => 13,
        ProductTileDensity.compact => 12,
        ProductTileDensity.mini => 11,
      };
  double get nameSize => switch (this) {
        ProductTileDensity.grid => 14,
        ProductTileDensity.compact => 13,
        ProductTileDensity.mini => 11,
      };
  double get priceSize => switch (this) {
        ProductTileDensity.grid => 16,
        ProductTileDensity.compact => 14,
        ProductTileDensity.mini => 12,
      };

  /// Type sizes of the card (serif). None goes below 12 before the shopper's
  /// own text scale.
  double get cardBrandSize => switch (this) {
        ProductTileDensity.grid => 15,
        ProductTileDensity.compact => 13,
        ProductTileDensity.mini => 12,
      };
  double get cardNameSize => switch (this) {
        ProductTileDensity.grid => 14,
        ProductTileDensity.compact => 13,
        ProductTileDensity.mini => 12,
      };
  double get cardPriceSize => switch (this) {
        ProductTileDensity.grid => 15,
        ProductTileDensity.compact => 14,
        ProductTileDensity.mini => 12,
      };

  /// Air between the card edge and its content.
  double get cardPadding => switch (this) {
        ProductTileDensity.grid => 12,
        ProductTileDensity.compact => 8,
        ProductTileDensity.mini => 6,
      };

  /// Unscaled height of the caption under the photograph of a card (gap,
  /// brand, name and one price line; no footer, no padding). The grid and the
  /// rails reserve the exact scaled value through [productTileExtent].
  double get captionHeight =>
      _cardCaptionExtent(this, TextScaler.noScaling, priceLines: 1);
}

/// Which presentation a [MonettaProductTile] takes. The data and the anatomy
/// (photo, brand, name, price) are the same; only the framing differs.
enum ProductTileVariant {
  /// A standalone card: one rounded warm ground holds the photograph, the
  /// caption and the «VER PRODUCTO» pill, and the whole tile lifts when
  /// pressed. Used by every product surface, and the default.
  card,

  /// A continuous photographic grid. Photos run to the edges and meet 4pt
  /// apart, with no frame, radius, inset or lift; only the caption is inset.
  /// No screen uses it at present.
  edgeToEdge,
}

// Caption typography shared by the tile and by the grid's height reserve, so
// both read one source of truth.
const double _brandLineHeight = 1.25;
const double _nameLineHeight = 1.3;
const double _priceLineHeight = 1.2;
const double _brandGap = 2;
const double _priceGap = BoutiqueSpace.xs;
const double _footerGap = BoutiqueSpace.sm;
const double _priceRunGap = 2;

/// Spare points added to the caption reserve of a card. Whatever is spare
/// ends up between the price and the pill, so it is kept to half a point
/// (the proportional allowance below does the real protecting).
const double _cardRoundingAllowance = 0.5;

/// Gap between the photograph and the caption of a card.
const double _cardPhotoGap = BoutiqueSpace.sm;

/// Corner radius of the card.
const BorderRadius kProductCardRadius = BorderRadius.all(Radius.circular(6));

/// Height a grid reserves under a tile that carries a footer control.
const double kTileFooterExtent = _footerGap + 48;

double _tileFooterExtent(TextScaler scaler, double width) {
  final painter = TextPainter(
    text: TextSpan(text: 'VER PRODUCTO', style: boutiqueText(size: 13)),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
  )..layout(maxWidth: math.max(1, width - 16));
  final extent = _footerGap + math.max(48.0, painter.height + 17);
  painter.dispose();
  return extent;
}

/// Unscaled-or-scaled height of the caption block of a card: the gap under the
/// photograph, brand, name and [priceLines] lines of price. Each font size is
/// scaled on its own, so a non-linear scaler (Android 14+) grows the reserve
/// exactly as it grows the text.
double _cardCaptionExtent(
  ProductTileDensity density,
  TextScaler textScaler, {
  required int priceLines,
}) {
  final enlarged = StorefrontLayout.enlargedText(textScaler);
  priceLines = priceLines < 2 ? 2 : priceLines;
  final text = textScaler.scale(density.cardBrandSize) *
          _brandLineHeight *
          (enlarged ? 3 : 1) +
      textScaler.scale(density.cardNameSize) *
          _nameLineHeight *
          (enlarged ? 6 : density.nameMaxLines) +
      textScaler.scale(density.cardPriceSize) * _priceLineHeight * priceLines;
  // The engine rounds each line box, which can add a fraction of a pixel per
  // line (up to about 1% at large sizes). A small proportional allowance plus
  // half a point keeps the reserve from ever being a hair short; it is
  // absorbed by the gap above the pill.
  return _cardPhotoGap +
      _brandGap +
      _priceGap +
      (priceLines - 1) * _priceRunGap +
      text * 1.015 +
      _cardRoundingAllowance;
}

extension ProductTileVariantMetrics on ProductTileVariant {
  bool get _edge => this == ProductTileVariant.edgeToEdge;

  /// Horizontal gap between grid columns.
  double get columnSpacing => _edge ? 4 : BoutiqueSpace.sm;

  /// Vertical gap between grid rows. The edge-to-edge tile carries its own
  /// trailing air instead.
  double get rowSpacing => _edge ? 0 : BoutiqueSpace.sm;

  /// Space between the tile edge and the photograph (the compact card uses
  /// 8, see [ProductTileMetrics.cardPadding]).
  double get photoInset => _edge ? 0 : BoutiqueSpace.md;

  BorderRadius get photoRadius =>
      _edge ? BorderRadius.zero : kProductCardRadius;

  /// width / height of the photograph. A card is always square.
  double photoAspectRatio(ProductTileDensity density) =>
      _edge ? density.imageAspectRatio : 1;

  /// Horizontal inset of the caption text.
  double get captionInset => _edge ? BoutiqueSpace.sm : 0;

  /// Gap between the photograph and the caption.
  double get captionGap => _edge ? 10 : _cardPhotoGap;

  /// Air inside the tile, under the caption (there is no row spacing).
  double get captionTrailing => _edge ? BoutiqueSpace.xl + BoutiqueSpace.xs : 0;

  /// Whether the tile rises when pressed.
  bool get lifts => !_edge;

  /// Height of the caption under the photograph.
  ///
  /// The edge-to-edge tile reserves exactly brand, a two-line name and one
  /// price line. The card reserves the same block in its serif type, with
  /// [priceLines] lines of price (two when a compare-at price may wrap under
  /// the price); its padding and footer are added by [productTileExtent].
  double captionExtent(
    ProductTileDensity density,
    TextScaler textScaler, {
    int priceLines = 1,
  }) {
    if (!_edge) {
      return _cardCaptionExtent(density, textScaler, priceLines: priceLines);
    }
    return captionGap +
        textScaler.scale(density.brandSize) * _brandLineHeight +
        _brandGap +
        textScaler.scale(density.nameSize) *
            _nameLineHeight *
            density.nameMaxLines +
        _priceGap +
        textScaler.scale(density.priceSize) * _priceLineHeight +
        captionTrailing;
  }
}

/// Total height of one tile [tileWidth] wide.
///
/// A card is its padding, a square photograph, the caption and (when
/// [footerExtent] is not zero) the «VER PRODUCTO» pill. Grids and rails use
/// this instead of repeating the arithmetic.
double productTileExtent({
  required double tileWidth,
  required TextScaler textScaler,
  ProductTileDensity density = ProductTileDensity.grid,
  ProductTileVariant variant = ProductTileVariant.card,
  int priceLines = 1,
  double? footerExtent,
}) {
  final footer = footerExtent ??
      (variant == ProductTileVariant.card
          ? _tileFooterExtent(textScaler, tileWidth - 2 * density.cardPadding)
          : 0);
  if (variant == ProductTileVariant.edgeToEdge) {
    return tileWidth * density.imageHeightFactor +
        variant.captionExtent(density, textScaler) +
        footer;
  }
  final padding = density.cardPadding;
  return padding +
      (tileWidth - 2 * padding) +
      variant.captionExtent(density, textScaler, priceLines: priceLines) +
      48 +
      footer +
      padding;
}

/// How many price lines a tile for [products] can need. Always one: the price
/// and the struck-through compare-at price share ONE line and shrink to fit it
/// (see [_PriceLine]), so a sale piece never makes the whole grid reserve a
/// second line. Kept so existing grids keep compiling.
int tilePriceLinesFor(Iterable<Product> products) => 1;

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
    this.variantLabel,
    this.compareAtLabel,
    this.badge,
    this.inStock = true,
    this.imageCacheWidth = MediaUrl.cardWidth,
  });

  /// Brand line. Null hides the line rather than printing a placeholder.
  final String? brand;
  final String? variantLabel;
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
      if (variantLabel != null) variantLabel!,
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
    ProductVariant? variant,
    bool selectDefaultVariant = true,
  }) {
    if (selectDefaultVariant) {
      variant ??= product.variants.isEmpty ? null : product.variants.first;
    }
    final price = variant?.price ?? product.price;
    final compare = variant?.compareAtPrice;
    final onSale = compare != null && compare > price;
    final brand = facets?.brand?.value;
    final discount = onSale ? ((compare - price) / compare * 100).round() : 0;
    final badge = onSale && discount > 0
        ? ProductTileBadge(label: '-$discount%', tone: ProductBadgeTone.sale)
        : allowNewBadge && (facets?.newArrival ?? false)
            ? const ProductTileBadge(
                label: 'NUEVO',
                tone: ProductBadgeTone.fresh,
              )
            : null;

    return ProductTileData(
      brand: brand == null ? null : brandLabel(brand),
      title: shopperProductName(product.title),
      variantLabel: variant?.isDefault == false ? variant!.title : null,
      priceLabel: formatShopperPrice(price),
      compareAtLabel: onSale ? formatShopperPrice(compare) : null,
      badge: badge,
      imageUrls: imagesForVariant(product, variant),
      inStock: variant?.available ?? false,
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

/// The brown «VER PRODUCTO» pill at the foot of every card.
class TileViewProductButton extends StatelessWidget {
  const TileViewProductButton({required this.onPressed, super.key});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          foregroundColor: context.boutique.ink,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
        child: Text(
          'VER PRODUCTO',
          textAlign: TextAlign.center,
          style: boutiqueText(size: 13, color: context.boutique.ink),
        ),
      );
}

// Serif caption of the card. The family is bundled; the fallback list keeps a
// platform serif until it is registered.
TextStyle _tileSerif({
  required double size,
  required FontWeight weight,
  required Color color,
  required double height,
  TextDecoration? decoration,
}) =>
    TextStyle(
      fontFamily: kBoutiqueSansFamily,
      fontFamilyFallback: kBoutiqueSansFallback,
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: color,
      decoration: decoration,
    );

/// Brightens a photograph 3 % so the #F9F9F9 ground the store's real photos
/// carry becomes pure white before it is multiplied onto a surface.
const ColorFilter kPackshotLiftFilter = ColorFilter.matrix(<double>[
  1.03, 0, 0, 0, 0, //
  0, 1.03, 0, 0, 0, //
  0, 0, 1.03, 0, 0, //
  0, 0, 0, 1, 0, //
]);

/// Lets a catalog photograph rest directly on the surface [ground] behind it.
///
/// The photo is lifted 3 % (so its near-white ground is exactly white and no
/// slightly darker box remains) and then multiplied with [ground]: white
/// becomes the surface, the piece keeps its own colours. Light theme only; in
/// the dark theme the photograph stays as shot. The card, the preview, the
/// thumbnails and the product gallery all use it.
class PackshotBlend extends StatelessWidget {
  const PackshotBlend({required this.ground, required this.child, super.key});

  /// The colour behind the photograph (the surface it should rest on).
  final Color ground;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).brightness != Brightness.light) return child;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(ground, BlendMode.multiply),
      child: ColorFiltered(colorFilter: kPackshotLiftFilter, child: child),
    );
  }
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
    this.variant = ProductTileVariant.card,
    this.wishlisted = false,
    this.onToggleWishlist,
    this.onQuickView,
    this.quickAction,
    this.imageOverlay,
    this.eyebrow,
    this.footer,
    this.optionControl,
    this.semanticHint,
    super.key,
  });

  final ProductTileData data;
  final VoidCallback onTap;
  final ProductTileDensity density;

  /// See [ProductTileVariant]; the card by default.
  final ProductTileVariant variant;

  /// Favourite state. The heart is only drawn when [onToggleWishlist] is
  /// given, so a surface without wishlist support never shows a dead control.
  final bool wishlisted;
  final VoidCallback? onToggleWishlist;

  /// Package C's quick view. When provided, a long press opens it. The
  /// edge-to-edge variant also draws a visible "Vista rápida" action on the
  /// photo; the card does not, because tapping the card is the way in.
  final VoidCallback? onQuickView;

  /// Purchase control pinned to the lower right corner of the photograph.
  /// No Monetta card passes one any more (the quick view carries «AGREGAR A
  /// BOLSA»); the slot stays for callers outside the catalog.
  final Widget? quickAction;

  /// Extra marker pinned to the bottom-left of the photograph, e.g. the
  /// external-source badge.
  final Widget? imageOverlay;

  /// Optional short line above the brand — a real restock or discount reason,
  /// never a recommender sentence.
  final String? eyebrow;

  /// A full-width control under the price (the «VER PRODUCTO» pill). A grid
  /// that shows it reserves [kTileFooterExtent] more height per row through
  /// [productGridDelegate], which does so by default for the card.
  final Widget? footer;
  final Widget? optionControl;

  /// Screen-reader hint for the tap, e.g. «Abre la vista previa».
  final String? semanticHint;

  @override
  Widget build(BuildContext context) {
    final edge = variant == ProductTileVariant.edgeToEdge;
    final body = edge ? _buildEdge(context) : _buildCard(context);
    return Semantics(
      button: true,
      label: data.semanticLabel,
      hint: semanticHint,
      child: variant.lifts
          ? MonettaCardLift(borderRadius: kProductCardRadius, child: body)
          : body,
    );
  }

  Widget _caption(BuildContext context) {
    final palette = context.boutique;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
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
            maxLines:
                StorefrontLayout.enlargedText(MediaQuery.textScalerOf(context))
                    ? null
                    : 1,
            overflow: TextOverflow.clip,
            style: variant == ProductTileVariant.edgeToEdge
                ? boutiqueText(
                    size: density.brandSize,
                    weight: FontWeight.w600,
                    color: palette.ink,
                    height: _brandLineHeight,
                  )
                : _tileSerif(
                    size: density.cardBrandSize,
                    weight: FontWeight.w700,
                    color: palette.ink,
                    height: _brandLineHeight,
                  ),
          ),
          const SizedBox(height: _brandGap),
        ],
        Text(
          data.title,
          maxLines:
              StorefrontLayout.enlargedText(MediaQuery.textScalerOf(context))
                  ? null
                  : density.nameMaxLines,
          overflow:
              StorefrontLayout.enlargedText(MediaQuery.textScalerOf(context))
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
          style: variant == ProductTileVariant.edgeToEdge
              ? boutiqueText(
                  size: density.nameSize,
                  color: palette.inkMuted,
                  height: _nameLineHeight,
                )
              : _tileSerif(
                  size: density.cardNameSize,
                  weight: FontWeight.w400,
                  color: palette.ink,
                  height: _nameLineHeight,
                ),
        ),
        const SizedBox(height: _priceGap),
        _PriceLine(data: data, density: density, variant: variant),
      ],
    );
  }

  double _measuredCaptionExtent(BuildContext context, double width) {
    final scaler = MediaQuery.textScalerOf(context);
    final enlarged = StorefrontLayout.enlargedText(scaler);
    Size measure(
      String value,
      double size,
      double height,
      FontWeight weight, {
      int? lines,
      double? maxWidth,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: _tileSerif(
            size: size,
            weight: weight,
            color: context.boutique.ink,
            height: height,
          ),
        ),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: lines,
      )..layout(maxWidth: maxWidth ?? width);
      final measured = painter.size;
      painter.dispose();
      return measured;
    }

    final price = measure(
      data.priceLabel,
      density.cardPriceSize,
      _priceLineHeight,
      FontWeight.w700,
      maxWidth: double.infinity,
    );
    final compare =
        data.compareAtLabel == null || density == ProductTileDensity.mini
            ? Size.zero
            : measure(
                data.compareAtLabel!,
                density.cardPriceSize - 2,
                _priceLineHeight,
                FontWeight.w400,
                maxWidth: double.infinity,
              );
    final priceHeight = compare == Size.zero
        ? price.height
        : price.width + 8 + compare.width <= width
            ? math.max(price.height, compare.height)
            : price.height + 2 + compare.height;
    return variant.captionGap +
        _priceGap +
        priceHeight +
        // Paragraph and button line boxes round independently in Flutter.
        8 +
        measure(
          data.title,
          density.cardNameSize,
          _nameLineHeight,
          FontWeight.w400,
          lines: enlarged ? null : density.nameMaxLines,
        ).height +
        (data.brand == null
            ? 0
            : _brandGap +
                measure(
                  data.brand!,
                  density.cardBrandSize,
                  _brandLineHeight,
                  FontWeight.w700,
                  lines: enlarged ? null : 1,
                ).height) +
        (eyebrow == null
            ? 0
            : measure(
                  eyebrow!.toUpperCase(),
                  11,
                  1.45,
                  FontWeight.w400,
                  lines: 1,
                ).height +
                BoutiqueSpace.xs);
  }

  /// The card: one rounded warm ground with the photograph, the favourite,
  /// the caption and the pill inside it.
  Widget _buildCard(BuildContext context) {
    final palette = context.boutique;
    final padding = density.cardPadding;
    final badge = data.badge;

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceDeep,
        borderRadius: kProductCardRadius,
      ),
      child: Stack(
        // Pass the grid's tight height down to the layout below.
        fit: StackFit.passthrough,
        children: [
          Padding(
            padding: EdgeInsets.all(padding),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Inside a grid or a rail the cell height is fixed: the pill
                // is pinned to the foot so every card of a row lines up. On
                // its own the card is as tall as its content.
                final fill = constraints.hasTightHeight;
                final optionText = TextPainter(
                  text: TextSpan(
                    text: data.variantLabel ?? 'Elegir opción',
                    style: boutiqueText(size: 12, height: 1.3),
                  ),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout(maxWidth: math.max(1, constraints.maxWidth - 22));
                final optionHeight = math.max(48.0, optionText.height + 16);
                optionText.dispose();
                final caption =
                    _measuredCaptionExtent(context, constraints.maxWidth);
                final footerHeight = footer == null
                    ? 0
                    : _tileFooterExtent(
                        MediaQuery.textScalerOf(context),
                        constraints.maxWidth,
                      );
                final photoHeight = fill
                    ? math.max(
                        0.0,
                        math.min(
                          constraints.maxWidth,
                          constraints.maxHeight -
                              caption -
                              optionHeight -
                              footerHeight,
                        ),
                      )
                    : constraints.maxWidth;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: photoHeight,
                      width: double.infinity,
                      child: _TileImage(
                        data: data,
                        variant: variant,
                        quickAction: quickAction,
                        overlay: imageOverlay,
                      ),
                    ),
                    SizedBox(height: variant.captionGap),
                    SizedBox(height: optionHeight, child: optionControl),
                    _caption(context),
                    if (footer case final control?) ...[
                      const SizedBox(height: _footerGap),
                      if (fill) const Spacer(),
                      control,
                    ],
                  ],
                );
              },
            ),
          ),
          if (badge != null && density != ProductTileDensity.mini)
            Positioned(
              top: padding,
              left: padding,
              child: _Badge(badge: badge),
            ),
          if (onToggleWishlist case final toggle?)
            Positioned(
              top: 0,
              right: 0,
              child: _WishlistButton(
                wishlisted: wishlisted,
                onPressed: toggle,
                cornerIcon: true,
                mini: density == ProductTileDensity.mini,
              ),
            ),
        ],
      ),
    );

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        onLongPress: onQuickView,
        child: card,
      ),
    );
  }

  /// The continuous photographic tile (no screen uses it at present).
  Widget _buildEdge(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onQuickView,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: variant.photoAspectRatio(density),
            child: _TileImage(
              data: data,
              variant: variant,
              wishlisted: wishlisted,
              onToggleWishlist: onToggleWishlist,
              onQuickView: onQuickView,
              quickAction: quickAction,
              overlay: imageOverlay,
            ),
          ),
          SizedBox(height: variant.captionGap),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: variant.captionInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _caption(context),
                if (footer case final control?) ...[
                  const SizedBox(height: _footerGap),
                  control,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({
    required this.data,
    required this.density,
    required this.variant,
  });

  final ProductTileData data;
  final ProductTileDensity density;
  final ProductTileVariant variant;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final card = variant == ProductTileVariant.card;
    final mini = density == ProductTileDensity.mini;
    // The price and the struck-through compare-at price share ONE line and
    // shrink together to fit the column: a cut-off price is never acceptable,
    // and a second line would leave a gap above the pill on every card of a
    // grid that holds a sale piece. The mini card has no room for the
    // compare-at price at all.
    return Wrap(
      spacing: 8,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          data.priceLabel,
          maxLines: 1,
          softWrap: false,
          style: card
              ? _tileSerif(
                  size: density.cardPriceSize,
                  weight: FontWeight.w700,
                  color: palette.ink,
                  height: _priceLineHeight,
                )
              : boutiqueText(
                  size: density.priceSize,
                  weight: FontWeight.w700,
                  color: palette.ink,
                  height: _priceLineHeight,
                ),
        ),
        if (!mini)
          if (data.compareAtLabel case final before?) ...[
            Text(
              before,
              maxLines: 1,
              softWrap: false,
              style: card
                  ? _tileSerif(
                      size: density.cardPriceSize - 2,
                      weight: FontWeight.w400,
                      color: palette.inkMuted,
                      height: _priceLineHeight,
                      decoration: TextDecoration.lineThrough,
                    )
                  : boutiqueText(
                      size: density.priceSize - 3,
                      color: palette.inkMuted,
                      height: _priceLineHeight,
                      decoration: TextDecoration.lineThrough,
                    ),
            ),
          ],
      ],
    );
  }
}

/// The photograph: product shown whole, sold-out stamp and, on the
/// edge-to-edge variant, badge, favourite and quick-view eye (the card draws
/// those itself, on its own ground).
class _TileImage extends StatefulWidget {
  const _TileImage({
    required this.data,
    required this.variant,
    required this.overlay,
    this.wishlisted = false,
    this.onToggleWishlist,
    this.onQuickView,
    this.quickAction,
  });

  final ProductTileData data;
  final ProductTileVariant variant;
  final bool wishlisted;
  final VoidCallback? onToggleWishlist;
  final VoidCallback? onQuickView;
  final Widget? quickAction;
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

    final edge = widget.variant == ProductTileVariant.edgeToEdge;

    Widget photo = MonettaImage(
      key: ValueKey(url ?? 'fallback'),
      url: url,
      fit: BoxFit.contain,
      // The photo's own white margin stays. `cover` is chosen only when it
      // crops less than that margin; otherwise the photo is contained whole,
      // so handles and straps are never cut.
      maxCoverTrim: 0,
      cacheWidth: widget.data.imageCacheWidth,
      fallbackLabel: widget.data.fallbackLabel,
      onFailed: _advance,
    );
    if (!edge) {
      // The catalog photographs sit on (near) white. Blending them into the
      // card's own colour makes that white become the card, so the bag
      // appears to rest directly on it.
      photo = PackshotBlend(ground: palette.surfaceDeep, child: photo);
    }

    final stack = Stack(
      fit: StackFit.expand,
      children: [
        photo,
        if (!widget.data.inStock)
          const Positioned(
            left: 4,
            bottom: 4,
            child: ProductSoldOutBadge(),
          ),
        if (edge && badge != null)
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
        if (edge)
          if (widget.onToggleWishlist case final toggle?)
            Positioned(
              top: 0,
              right: 0,
              child: _WishlistButton(
                wishlisted: widget.wishlisted,
                onPressed: toggle,
              ),
            ),
        if (widget.quickAction case final action?)
          Positioned(
            bottom: BoutiqueSpace.xs,
            right: BoutiqueSpace.xs,
            child: action,
          )
        else if (edge)
          if (widget.onQuickView case final quickView?)
            Positioned(
              bottom: BoutiqueSpace.xs,
              right: BoutiqueSpace.xs,
              child: _QuickViewButton(onPressed: quickView),
            ),
      ],
    );

    if (edge) return stack;
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(4)),
      child: stack,
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
/// mistaken for tapping the card. On the card ([cornerIcon]) the outline heart
/// sits tucked in the top right corner, as drawn in the design; the touch zone
/// still covers 48×48 inside the card.
class _WishlistButton extends StatelessWidget {
  const _WishlistButton({
    required this.wishlisted,
    required this.onPressed,
    this.cornerIcon = false,
    this.mini = false,
  });
  final bool wishlisted;
  final VoidCallback onPressed;
  final bool cornerIcon;
  final bool mini;
  @override
  Widget build(BuildContext context) => ProductFavoriteButton(
        selected: wishlisted,
        onPressed: onPressed,
        onPhoto: true,
      );
}

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
int productGridColumns(double width) =>
    StorefrontLayout.columns(width, TextScaler.noScaling);

/// A grid delegate sized from the real tile width and the shopper's own text
/// scale, so large type produces taller rows instead of clipped captions.
///
/// [spacing] and [rowSpacing] default to the [variant]'s own gaps. A card
/// reserves its «VER PRODUCTO» pill by default ([footerExtent] null); pass 0
/// only for a grid whose cards show none. [priceLines] is 2 when any product
/// of the grid carries a compare-at price (see [tilePriceLinesFor]).
SliverGridDelegate productGridDelegate(
  BuildContext context, {
  required double availableWidth,
  ProductTileDensity density = ProductTileDensity.grid,
  ProductTileVariant variant = ProductTileVariant.card,
  double? spacing,
  double? rowSpacing,
  double? footerExtent,
  int priceLines = 1,
}) {
  final textScaler = MediaQuery.textScalerOf(context);
  final columns = StorefrontLayout.columns(availableWidth, textScaler);
  final columnSpacing = spacing ?? variant.columnSpacing;
  final tileWidth = (availableWidth - columnSpacing * (columns - 1)) / columns;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    crossAxisSpacing: columnSpacing,
    mainAxisSpacing: rowSpacing ?? variant.rowSpacing,
    mainAxisExtent: productTileExtent(
      tileWidth: tileWidth,
      textScaler: textScaler,
      density: density,
      variant: variant,
      priceLines: priceLines,
      footerExtent: footerExtent,
    ),
  );
}
