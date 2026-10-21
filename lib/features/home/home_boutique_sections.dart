/// Screen 03 — the boutique modules of the home.
///
/// Split out of `home_screen.dart` (already 1.7k lines) so the redesign is
/// reviewable on its own. Everything here is presentation: navigation,
/// controllers and catalog access stay in [HomeScreen].
library;

import 'package:flutter/material.dart';

import '../../app/card_lift.dart';
import '../../app/media/monetta_video.dart';
import '../../domain/campaign.dart';
import '../../domain/home_content.dart';
import '../../domain/product.dart';
import '../boutique/boutique_tokens.dart';
import '../catalog/product_card.dart';
import '../product/quick_view.dart';

/// The home banner's film, with a real editorial poster frame.
///
/// `CampaignMedia.monettaHome` points its poster at `hero_poster.jpg`, which is
/// a blown-out white frame — acceptable behind a full-bleed hero that fills the
/// screen in under a second, wrong for a banner that is the first thing under
/// the search field. The film is unchanged; only the still it rests on is.
final CampaignMedia kHomeBannerCampaign = CampaignMedia(
  videoUrl: CampaignMedia.monettaHome.videoUrl,
  posterAsset: 'assets/images/campaign_olive.jpg',
);

/// Banner height as a share of the viewport.
///
/// The brief's 25–32% starting point, landed at 29% and clamped so a small
/// phone still gets a banner worth looking at and a tall one does not hand the
/// whole first fold to a single image.
double homeBannerHeight(BuildContext context) =>
    (MediaQuery.sizeOf(context).height * 0.29).clamp(200.0, 320.0) *
    MediaQuery.textScalerOf(context).scale(1).clamp(1.0, double.infinity);

// ---------------------------------------------------------------------------
// Search
// ---------------------------------------------------------------------------

/// The search field, in the page rather than floating over the hero: on the
/// reference it is a standing part of the header, visible before any scroll.
class HomeSearchField extends StatelessWidget {
  const HomeSearchField({required this.onTap, required this.prompt, super.key});

  final VoidCallback onTap;
  final String prompt;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BoutiqueSpace.gutter,
        BoutiqueSpace.md,
        BoutiqueSpace.gutter,
        BoutiqueSpace.lg,
      ),
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

class HomeEditorialBanner extends StatelessWidget {
  const HomeEditorialBanner({
    required this.playing,
    required this.onOpenNew,
    super.key,
  });

  final bool playing;
  final VoidCallback onOpenNew;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    // Full bleed, square to the edges — figure 03 runs the photograph from
    // rail to rail under the header, not as an inset card.
    return SizedBox(
      key: const ValueKey('home-compact-hero'),
      height: homeBannerHeight(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          MonettaVideo(campaign: kHomeBannerCampaign, playing: playing),
          // Left-weighted scrim: the asset keeps its subject right of centre,
          // so the copy column stays readable without dimming the piece.
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: <Color>[
                    Color(0xC2000000),
                    Color(0x70000000),
                    Color(0x1A000000),
                  ],
                  stops: <double>[0, .52, 1],
                ),
              ),
            ),
          ),
          // Vertical padding is lg, not xl: copy (3-line 26pt headline) +
          // action (48pt) + 2×24pt padding peaks near 205pt and overflowed
          // the 200pt minimum banner on short viewports by 5pt.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BoutiqueSpace.gutter,
              BoutiqueSpace.lg,
              BoutiqueSpace.gutter,
              BoutiqueSpace.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * .62,
                  ),
                  child: Text(
                    'Estilo que te acompaña en cada momento',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: boutiqueDisplay(
                      26,
                      color: palette.onDark,
                      height: 1.18,
                    ),
                  ),
                ),
                const SizedBox(height: BoutiqueSpace.lg),
                _BannerAction(
                  key: const ValueKey('home-banner-action'),
                  label: 'Ver novedades',
                  onTap: onOpenNew,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A capsule — the brief's geometry for short editorial actions.
class _BannerAction extends StatelessWidget {
  const _BannerAction({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: palette.onDark,
        borderRadius: BoutiqueRadius.capsule,
        child: InkWell(
          onTap: onTap,
          borderRadius: BoutiqueRadius.capsule,
          child: Container(
            height: BoutiqueSpace.tapTarget,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: BoutiqueSpace.xl),
            child: Text(
              label,
              style: boutiqueText(
                size: 14,
                weight: FontWeight.w600,
                color: const Color(0xFF111111),
                height: 1.1,
              ),
            ),
          ),
        ),
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
    this.title = 'Novedades',
    super.key,
  });

  final List<Product> products;
  final String title;
  final VoidCallback onOpenAll;

  static const ProductTileDensity _density = ProductTileDensity.compact;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    final width = MediaQuery.sizeOf(context).width;
    // Just under three cards across, so the rail reads as scrollable.
    final cardWidth = (width * .36).clamp(132.0, 190.0);
    final railHeight = cardWidth * _density.imageHeightFactor +
        MediaQuery.textScalerOf(context).scale(_density.captionHeight);

    return Column(
      key: const ValueKey('home-section-new-products'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BoutiqueSectionHeader(
          title: title,
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
    // Four tiles across a phone, with the fourth cut so the rail reads as
    // scrollable — the proportion figure 03 uses.
    final tileWidth = (width * .27).clamp(96.0, 150.0);
    final tileHeight =
        MediaQuery.textScalerOf(context).scale(38) + tileWidth * 0.86;

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
          borderRadius: BoutiqueRadius.card,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: palette.surfaceDeep,
              borderRadius: BoutiqueRadius.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The bundled silhouettes are one consistent set, shot at one
                // scale on white — contained, never cropped.
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      BoutiqueSpace.sm,
                      BoutiqueSpace.sm,
                      BoutiqueSpace.sm,
                      0,
                    ),
                    child: HomeAssetImage(
                      imageUrl: card.imageUrl,
                      fallbackAsset: card.fallbackAsset,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    BoutiqueSpace.md,
                    BoutiqueSpace.xs,
                    BoutiqueSpace.sm,
                    BoutiqueSpace.md,
                  ),
                  child: Text(
                    card.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: boutiqueText(
                      size: 13,
                      height: 1.2,
                      color: palette.ink,
                    ),
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
