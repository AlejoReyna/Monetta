/// Screen 03 — the boutique modules of the home.
///
/// Split out of `home_screen.dart` (already 1.7k lines) so the redesign is
/// reviewable on its own. Everything here is presentation: navigation,
/// controllers and catalog access stay in [HomeScreen].
library;

import 'package:flutter/material.dart';

import '../../app/card_lift.dart';
import '../../domain/campaign.dart';
import '../../domain/home_content.dart';
import '../../domain/product.dart';
import '../boutique/boutique_tokens.dart';
import '../boutique/guide_art.dart';
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
    return GestureDetector(
      key: const ValueKey('home-banner-action'),
      onTap: onOpenNew,
      child: SizedBox(
        key: const ValueKey('home-compact-hero'),
        height: homeBannerHeight(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const GuideArt(
              asset: kGuideHomeHero,
              alignment: Alignment.centerRight,
            ),
            if (!playing) const SizedBox.shrink(),
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: <Color>[
                      Color(0xF2FBF6EE),
                      Color(0xB3FBF6EE),
                      Color(0x00FBF6EE),
                    ],
                    stops: <double>[0, .46, .82],
                  ),
                ),
              ),
            ),
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
                  Text(
                    'NUEVA',
                    style: boutiqueEyebrow(size: 12, color: palette.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'COLECCIÓN',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: boutiqueDisplay(
                      32,
                      color: palette.ink,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: BoutiqueSpace.sm),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * .58,
                    ),
                    child: Text(
                      'Un paraíso de marcas\npor descubrir.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: boutiqueText(
                        size: 14,
                        height: 1.3,
                        color: palette.ink,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Center(child: _HeroDots(count: 1, active: 0)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroDots extends StatelessWidget {
  const _HeroDots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            width: i == active ? 16 : 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: i == active ? palette.goldText : palette.hairline,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Nueva colección
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
    this.title = 'Nueva colección',
    this.sectionKey = const ValueKey('home-section-new-products'),
    this.railKey = const ValueKey('home-new-products-rail'),
    this.asGrid = false,
    super.key,
  });

  final List<Product> products;
  final String title;
  final VoidCallback onOpenAll;
  final Key sectionKey;
  final Key railKey;

  /// Guide page 3 lays “Nueva colección” as a two-column grid. The follow-up
  /// rail and wholesale keep the horizontal strip.
  final bool asGrid;

  static const ProductTileDensity _density = ProductTileDensity.compact;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    if (asGrid) {
      final shown = products.length > 4 ? products.sublist(0, 4) : products;
      return Column(
        key: sectionKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BoutiqueSectionHeader(
            title: title,
            actionLabel: 'Ver todo',
            onAction: onOpenAll,
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              return GridView.builder(
                key: railKey,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: BoutiqueSpace.gutter,
                ),
                gridDelegate: productGridDelegate(
                  context,
                  availableWidth:
                      constraints.maxWidth - BoutiqueSpace.gutter * 2,
                ),
                itemCount: shown.length,
                itemBuilder: (context, index) {
                  final product = shown[index];
                  return ProductCard(
                    product: product,
                    onQuickView: () => showProductQuickView(context, product),
                  );
                },
              );
            },
          ),
        ],
      );
    }
    final width = MediaQuery.sizeOf(context).width;
    // Just under three cards across, so the rail reads as scrollable.
    final cardWidth = (width * .36).clamp(132.0, 190.0);
    final railHeight = cardWidth * _density.imageHeightFactor +
        MediaQuery.textScalerOf(context).scale(_density.captionHeight);

    return Column(
      key: sectionKey,
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
            key: railKey,
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
