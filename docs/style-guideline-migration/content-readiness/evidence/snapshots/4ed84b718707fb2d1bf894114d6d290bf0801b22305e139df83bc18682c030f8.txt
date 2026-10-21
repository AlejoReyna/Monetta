/// Screen 03 — the boutique modules of the home.
///
/// Split out of `home_screen.dart` (already 1.7k lines) so the redesign is
/// reviewable on its own. Everything here is presentation: navigation,
/// controllers and catalog access stay in [HomeScreen].
library;

import 'package:flutter/material.dart';

import '../../app/card_lift.dart';
import '../../app/text_scale_policy.dart';
import '../../domain/home_content.dart';
import '../../domain/product.dart';
import '../boutique/boutique_tokens.dart';
import '../catalog/product_card.dart';
import '../product/quick_view.dart';

const String kHomeBannerAsset = 'assets/images/home_banner.jpg';

/// Compact hero under the app bar: about a third of the viewport.
double homeHeroHeight(BuildContext context) =>
    (MediaQuery.sizeOf(context).height * 0.3).clamp(220.0, 280.0);

// ---------------------------------------------------------------------------
// Search
// ---------------------------------------------------------------------------

/// Search entry, embedded in the hero or shown on its own when it is hidden.
class HomeSearchField extends StatelessWidget {
  const HomeSearchField({
    required this.onTap,
    required this.prompt,
    this.padding = const EdgeInsets.fromLTRB(
      BoutiqueSpace.gutter,
      BoutiqueSpace.md,
      BoutiqueSpace.gutter,
      BoutiqueSpace.lg,
    ),
    super.key,
  });

  final VoidCallback onTap;
  final String prompt;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Padding(
      padding: padding,
      child: Semantics(
        button: true,
        label: 'Buscar productos',
        excludeSemantics: true,
        onTap: onTap,
        child: GestureDetector(
          key: const ValueKey('home-search-bar'),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: BoutiqueSpace.control,
            padding: const EdgeInsets.symmetric(horizontal: BoutiqueSpace.lg),
            decoration: BoxDecoration(
              color: palette.surfaceDeep,
              borderRadius: BoutiqueRadius.capsule,
              border: Border.all(color: palette.hairline, width: .5),
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 20, color: palette.ink),
                const SizedBox(width: BoutiqueSpace.md),
                Expanded(
                  child: Text(
                    prompt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: boutiqueText(size: 14, color: palette.inkMuted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Editorial banner
// ---------------------------------------------------------------------------

/// The home photograph under the white app bar, with the search field
/// resting on its lower edge. No copy and no scrims: the photograph is light,
/// so the bar and the search pill read directly over it.
class HomeEditorialBanner extends StatelessWidget {
  const HomeEditorialBanner({
    required this.searchField,
    super.key,
  });

  final Widget searchField;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('home-compact-hero'),
      height: homeHeroHeight(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            kHomeBannerAsset,
            fit: BoxFit.cover,
            // Keeps the hand and the bag's hardware in frame on wide crops.
            alignment: const Alignment(0, .45),
            excludeFromSemantics: true,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BoutiqueSpace.gutter,
              BoutiqueSpace.sm,
              BoutiqueSpace.gutter,
              BoutiqueSpace.md,
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: searchField,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Novedades
// ---------------------------------------------------------------------------

/// New arrivals as a horizontal rail.
///
/// Uses the shared [ProductCard] at [ProductTileDensity.compact] — the density
/// package B publishes for exactly this ("Home rails and any narrow carousel")
/// — so the rail is the catalog's own card, not a home-only lookalike, and the
/// rail's height comes from the tile's own metrics rather than from arithmetic
/// this file would have to keep in sync.
class HomeNewArrivalsRail extends StatelessWidget {
  const HomeNewArrivalsRail({
    required this.products,
    required this.onOpenAll,
    super.key,
  });

  final List<Product> products;
  final VoidCallback onOpenAll;

  static const ProductTileDensity _density = ProductTileDensity.compact;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    final width = MediaQuery.sizeOf(context).width;
    // Just under three cards across, so the rail reads as scrollable.
    final cardWidth = (width * .36).clamp(132.0, 190.0);
    final textScaler = MediaQuery.textScalerOf(context);
    final railHeight = cardWidth * _density.imageHeightFactor +
        _density.captionHeight *
            textScaleFactorFor(textScaler, _density.nameSize);

    return Column(
      key: const ValueKey('home-section-new-products'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BoutiqueSectionHeader(
          title: 'Novedades',
          actionLabel: 'Ver todo',
          onAction: onOpenAll,
        ),
        SizedBox(
          height: railHeight,
          child: ListView.separated(
            key: const ValueKey('home-new-products-rail'),
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(
              horizontal: BoutiqueSpace.gutter,
            ),
            itemCount: products.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: BoutiqueSpace.md),
            itemBuilder: (context, index) {
              final product = products[index];
              return SizedBox(
                width: cardWidth,
                child: ProductCard(
                  product: product,
                  density: _density,
                  showSaleBadge: false,
                  onQuickView: () => showProductQuickView(context, product),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Compra por estilo
// ---------------------------------------------------------------------------

/// Silhouettes — crossbody, tote, shoulder and whatever else the owner has
/// configured. The bundled artwork is a consistent set shot at one scale on
/// white, so it is laid out `contain` on a neutral ground rather than cropped.
class HomeShopByStyle extends StatelessWidget {
  const HomeShopByStyle({
    required this.cards,
    required this.onOpen,
    this.onSeeAll,
    super.key,
  });

  final List<HomeCollectionCard> cards;
  final void Function(HomeCollectionCard card) onOpen;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    final width = MediaQuery.sizeOf(context).width;
    // Iconos más grandes: cada tile muestra un tercio del ancho para que
    // cinco estilos siempre desborden y el rail se lea como scrolleable.
    final tileWidth = (width * .32).clamp(112.0, 172.0);
    // Imagen cuadrada + banda de etiqueta centrada de una línea.
    final labelBand =
        34 * textScaleFactorFor(MediaQuery.textScalerOf(context), 13);
    final tileHeight = tileWidth + 8 + labelBand;

    return Column(
      key: const ValueKey('home-section-bag-types'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BoutiqueSectionHeader(
          title: 'Compra por estilo',
          actionLabel: onSeeAll == null ? null : 'Ver todo',
          onAction: onSeeAll,
        ),
        SizedBox(
          height: tileHeight,
          child: ListView.separated(
            key: const ValueKey('home-style-rail'),
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(
              horizontal: BoutiqueSpace.gutter,
            ),
            itemCount: cards.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: BoutiqueSpace.md),
            itemBuilder: (context, index) => SizedBox(
              width: tileWidth,
              child: _StyleTile(
                key: ValueKey('home-style-${cards[index].handle}'),
                card: cards[index],
                onTap: () => onOpen(cards[index]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StyleTile extends StatelessWidget {
  const _StyleTile({required this.card, required this.onTap, super.key});

  final HomeCollectionCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Semantics(
      button: true,
      label: 'Ver ${card.title}',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: MonettaCardLift(
          borderRadius: BorderRadius.zero,
          child: ColoredBox(
            color: Colors.transparent,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icono sin borde ni fondo: la silueta va directa sobre el
                // lienzo, contenida y centrada, nunca recortada.
                Expanded(
                  child: Center(
                    child: HomeAssetImage(
                      imageUrl: card.imageUrl,
                      fallbackAsset: card.fallbackAsset,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  card.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: boutiqueText(
                    size: 13,
                    height: 1.2,
                    color: palette.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Owner artwork with a bundled fallback. A failed network image drops to the
/// asset; a failed asset drops to the neutral ground rather than a broken box.
class HomeAssetImage extends StatelessWidget {
  const HomeAssetImage({
    required this.imageUrl,
    required this.fallbackAsset,
    this.fit = BoxFit.cover,
    super.key,
  });

  final String? imageUrl;
  final String fallbackAsset;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(color: context.boutique.surfaceDeep);
    final fallback = Image.asset(
      fallbackAsset,
      width: double.infinity,
      height: double.infinity,
      fit: fit,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => placeholder,
    );
    final url = imageUrl;
    if (url == null || url.isEmpty) return fallback;
    return Image.network(
      url,
      width: double.infinity,
      height: double.infinity,
      fit: fit,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}
