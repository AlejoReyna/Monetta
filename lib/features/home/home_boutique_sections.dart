/// Screen 03 — the boutique modules of the home.
///
/// Split out of `home_screen.dart` (already 1.7k lines) so the redesign is
/// reviewable on its own. Everything here is presentation: navigation,
/// controllers and catalog access stay in [HomeScreen].
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/card_lift.dart';
import '../../app/monetta_tokens.g.dart';
import '../../app/theme.dart';
import '../../domain/campaign.dart';
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

/// Three-slide opening carousel (guide page 3): swipeable, with indicator
/// dots, no autoplay and no timers.
class HomeEditorialBanner extends StatefulWidget {
  const HomeEditorialBanner({
    required this.playing,
    required this.onOpenNew,
    this.onOpenCatalog,
    this.onOpenPerfumes,
    super.key,
  });

  final bool playing;

  /// Slide 2, «Nueva colección».
  final VoidCallback onOpenNew;

  /// Slide 1, «Compra fácil desde México»: the full catalog.
  final VoidCallback? onOpenCatalog;

  /// Slide 3, «Perfumes».
  final VoidCallback? onOpenPerfumes;

  /// Number of slides, one dot each.
  static const int slideCount = 3;

  /// Banner height: the home banner's viewport share, capped near the
  /// photographs' own proportions so a tall phone does not crop them hard.
  static double heightFor(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return math.min(homeBannerHeight(context), width / 1.8);
  }

  @override
  State<HomeEditorialBanner> createState() => _HomeEditorialBannerState();
}

class _HomeEditorialBannerState extends State<HomeEditorialBanner> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final width = MediaQuery.sizeOf(context).width;
    final gutter = MonettaTokens.gutterFor(width);
    final serif = MonettaTokens.campaign.sizeFor(width) * 1.05;
    // Full bleed, square to the edges — figure 03 runs the photograph from
    // rail to rail under the header, not as an inset card.
    return SizedBox(
      key: const ValueKey('home-compact-hero'),
      height: HomeEditorialBanner.heightFor(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView(
            controller: _controller,
            onPageChanged: (page) => setState(() => _page = page),
            children: [
              _BannerSlide(
                key: const ValueKey('home-banner-slide-easy'),
                photo: const GuidePhoto(
                  kGuideHomeBannerEasy,
                  GuideTextSide.right,
                ),
                focus: const Alignment(-.6, 0),
                gutter: gutter,
                onTap: widget.onOpenCatalog,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Compra ',
                          style: guideSerifItalicStyle(
                            context,
                            size: serif,
                            color: palette.ink,
                          ),
                        ),
                        TextSpan(
                          text: 'fácil',
                          style: guideAccentStyle(
                            context,
                            size: serif * 1.7,
                            color: palette.ink,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.end,
                  ),
                  Text(
                    'desde México',
                    textAlign: TextAlign.end,
                    style: guideSerifItalicStyle(
                      context,
                      size: serif,
                      color: palette.ink,
                    ),
                  ),
                ],
              ),
              _BannerSlide(
                photo: const GuidePhoto(
                  kGuideHomeBannerNew,
                  GuideTextSide.left,
                ),
                focus: const Alignment(.4, 0),
                gutter: gutter,
                actionKey: const ValueKey('home-banner-action'),
                onTap: widget.onOpenNew,
                children: [
                  Text(
                    'NUEVA',
                    style: guideSerifStyle(
                      context,
                      size: serif * 0.6,
                      color: palette.ink,
                      weight: FontWeight.w500,
                      letterSpacing: serif * 0.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'COLECCIÓN',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: guideSerifStyle(
                      context,
                      size: serif * 1.15,
                      color: palette.ink,
                      height: 1.05,
                      letterSpacing: serif * 0.04,
                    ),
                  ),
                  const SizedBox(height: BoutiqueSpace.sm),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: width * .58),
                    child: Text(
                      'Un paraíso de marcas\npor descubrir.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: guideSerifItalicStyle(
                        context,
                        size: serif * 0.62,
                        color: palette.ink,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              _BannerSlide(
                key: const ValueKey('home-banner-slide-perfumes'),
                photo: const GuidePhoto(
                  kGuideHomeBannerPerfumes,
                  GuideTextSide.right,
                ),
                focus: const Alignment(-.3, 0),
                gutter: gutter,
                onTap: widget.onOpenPerfumes,
                children: [
                  Text(
                    'PERFUMES',
                    textAlign: TextAlign.end,
                    style: guideSerifStyle(
                      context,
                      size: serif * 1.15,
                      color: palette.ink,
                      height: 1.05,
                      letterSpacing: serif * 0.04,
                    ),
                  ),
                  const SizedBox(height: BoutiqueSpace.sm),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: width * .5),
                    child: Text(
                      'Descubre nuestra selección de fragancias originales',
                      textAlign: TextAlign.end,
                      style: guideSerifItalicStyle(
                        context,
                        size: serif * 0.62,
                        color: palette.ink,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: BoutiqueSpace.md,
            child: IgnorePointer(
              child: Center(
                key: const ValueKey('home-banner-dots'),
                child: _HeroDots(
                  count: HomeEditorialBanner.slideCount,
                  active: _page,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One carousel slide: a guide still, a cream wash on the text side and the
/// copy aligned to that side. The copy scales down instead of overflowing.
class _BannerSlide extends StatelessWidget {
  const _BannerSlide({
    required this.photo,
    required this.focus,
    required this.gutter,
    required this.children,
    this.onTap,
    this.actionKey,
    super.key,
  });

  final GuidePhoto photo;
  final Alignment focus;
  final double gutter;
  final List<Widget> children;
  final VoidCallback? onTap;
  final Key? actionKey;

  @override
  Widget build(BuildContext context) {
    final onRight = photo.textSide == GuideTextSide.right;
    return GestureDetector(
      key: actionKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GuideArt(asset: photo.asset, alignment: focus),
          GuideScrim(textSide: photo.textSide),
          Padding(
            padding: EdgeInsets.fromLTRB(
              gutter,
              BoutiqueSpace.lg,
              gutter,
              BoutiqueSpace.xl,
            ),
            child: Align(
              alignment: onRight ? Alignment.centerRight : Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment:
                    onRight ? Alignment.centerRight : Alignment.centerLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: onRight
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
          ),
        ],
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
            key: ValueKey('home-banner-dot-$i'),
            width: i == active ? 16 : 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: i == active
                  ? palette.goldText
                  : palette.ink.withValues(alpha: .28),
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

/// One entry of «Compra por estilo»: a studio photo, its label and the catalog
/// destination it opens.
@immutable
class HomeStyleEntry {
  const HomeStyleEntry({
    required this.id,
    required this.label,
    required this.collectionTitle,
    required this.iconAsset,
    this.category,
    this.silhouette,
  });

  /// Stable id, used for the widget key (`home-style-<id>`).
  final String id;
  final String label;

  /// Title of the collection the entry opens.
  final String collectionTitle;
  final String iconAsset;
  final String? category;
  final String? silhouette;
}

/// The guide's five bag styles, in order. Silhouettes are the catalog's own
/// facet values.
const List<HomeStyleEntry> kHomeStyleEntries = <HomeStyleEntry>[
  HomeStyleEntry(
    id: 'crossbody',
    label: 'Crossbody',
    collectionTitle: 'Crossbody',
    iconAsset: kGuidePhotoStyleCrossbody,
    category: 'bolsa',
    silhouette: 'crossbody',
  ),
  HomeStyleEntry(
    id: 'tote',
    label: 'Tote',
    collectionTitle: 'Totes',
    iconAsset: kGuidePhotoStyleTote,
    category: 'bolsa',
    silhouette: 'tote',
  ),
  HomeStyleEntry(
    id: 'shoulder',
    label: 'Shoulder',
    collectionTitle: 'Shoulder',
    iconAsset: kGuidePhotoStyleShoulder,
    category: 'bolsa',
    silhouette: 'shoulder',
  ),
  HomeStyleEntry(
    id: 'satchel',
    label: 'Satchel',
    collectionTitle: 'Satchel',
    iconAsset: kGuidePhotoStyleSatchel,
    category: 'bolsa',
    silhouette: 'satchel',
  ),
  HomeStyleEntry(
    id: 'hobo',
    label: 'Hobo',
    collectionTitle: 'Hobo',
    iconAsset: kGuidePhotoStyleHobo,
    category: 'bolsa',
    silhouette: 'hobo',
  ),
];

/// «Compra por estilo»: five static cream cards across, photo over a serif
/// label. The only motion is the shared [MonettaCardLift].
class HomeShopByStyle extends StatelessWidget {
  const HomeShopByStyle({
    required this.onOpen,
    this.entries = kHomeStyleEntries,
    this.onSeeAll,
    super.key,
  });

  final List<HomeStyleEntry> entries;
  final void Function(HomeStyleEntry entry) onOpen;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Column(
      key: const ValueKey('home-section-bag-types'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BoutiqueSectionHeader(
          title: 'Compra por estilo',
          actionLabel: onSeeAll == null ? null : 'Ver todo',
          onAction: onSeeAll,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: BoutiqueSpace.sm),
          child: large
              ? Wrap(
                  key: const ValueKey('home-style-rail'),
                  alignment: WrapAlignment.center,
                  runSpacing: BoutiqueSpace.md,
                  children: [
                    for (final entry in entries)
                      SizedBox(
                        width: 108,
                        child: _StyleTile(
                          key: ValueKey('home-style-${entry.id}'),
                          entry: entry,
                          onTap: () => onOpen(entry),
                        ),
                      ),
                  ],
                )
              : Row(
                  key: const ValueKey('home-style-rail'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in entries)
                      Expanded(
                        child: _StyleTile(
                          key: ValueKey('home-style-${entry.id}'),
                          entry: entry,
                          onTap: () => onOpen(entry),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _StyleTile extends StatelessWidget {
  const _StyleTile({required this.entry, required this.onTap, super.key});

  final HomeStyleEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Semantics(
      button: true,
      label: 'Ver ${entry.label}',
      excludeSemantics: true,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(BoutiqueSpace.xs / 2),
        child: MonettaCardLift(
          borderRadius: BoutiqueRadius.tile,
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: ClipRRect(
              borderRadius: BoutiqueRadius.tile,
              child: ColoredBox(
                color: context.monettaColors.surfaceTile,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Square photo: the five labels share a baseline.
                    AspectRatio(
                      aspectRatio: 1,
                      child: Image.asset(
                        entry.iconAsset,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        BoutiqueSpace.xs,
                        0,
                        BoutiqueSpace.xs,
                        BoutiqueSpace.sm,
                      ),
                      child: Text(
                        entry.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: boutiqueProductName(
                          size: 13,
                          color: palette.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
