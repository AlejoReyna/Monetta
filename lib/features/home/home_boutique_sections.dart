/// Screen 03 — the boutique modules of the home.
///
/// Split out of `home_screen.dart` (already 1.7k lines) so the redesign is
/// reviewable on its own. Everything here is presentation: navigation,
/// controllers and catalog access stay in [HomeScreen].
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/campaign.dart';
import '../../domain/product.dart';
import '../boutique/boutique_tokens.dart';
import '../boutique/guide_art.dart';
import '../catalog/product_card.dart';

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
/// dots. It advances one slide every 4 s and loops after the last one. It
/// waits while a finger is on it, while [playing] is false (the app is in the
/// background or the carousel scrolled away), while the route is covered
/// (`TickerMode`) and when the OS asks to reduce motion
/// (`MediaQuery.disableAnimations`); a swipe restarts the count.
class HomeEditorialBanner extends StatefulWidget {
  const HomeEditorialBanner({
    required this.playing,
    required this.onOpenProducts,
    required this.onOpenBrands,
    required this.onOpenCategories,
    super.key,
  });

  /// Whether the carousel is on screen and the app in the foreground; the
  /// home drives it from the scroll offset and the app lifecycle.
  final bool playing;

  /// B01 — all products.
  final VoidCallback onOpenProducts;

  /// B02 — all brands.
  final VoidCallback onOpenBrands;

  /// B03 — categories.
  final VoidCallback onOpenCategories;

  /// Number of slides, one dot each.
  static const int slideCount = 3;

  /// Banner height: the home banner's viewport share, capped near the
  /// photographs' own proportions so a tall phone does not crop them hard.
  static double heightFor(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return math.min(homeBannerHeight(context), width / 2.4 + 24);
  }

  @override
  State<HomeEditorialBanner> createState() => _HomeEditorialBannerState();
}

class _HomeEditorialBannerState extends State<HomeEditorialBanner> {
  /// One slide every 4 s.
  static const Duration autoplayDelay = Duration(seconds: 4);
  static const Duration _slideDuration = Duration(milliseconds: 450);

  final PageController _controller = PageController();
  final Set<int> _pointers = <int>{};
  Timer? _autoplayTimer;
  int _page = 0;
  bool _reducedMotion = false;
  bool _tickersEnabled = true;

  bool get _autoplayAllowed =>
      widget.playing && _tickersEnabled && !_reducedMotion && _pointers.isEmpty;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `disableAnimationsOf`, not the app's `reduceMotion`: that one is always
    // true under `flutter_test`, and the web gates autoplay on the same media
    // query (`prefers-reduced-motion`).
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    _tickersEnabled = TickerMode.valuesOf(context).enabled;
    _restartAutoplay();
  }

  @override
  void didUpdateWidget(covariant HomeEditorialBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing != widget.playing) _restartAutoplay();
  }

  @override
  void dispose() {
    _autoplayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Cancels any pending advance and, when allowed, waits a full delay again.
  void _restartAutoplay() {
    _autoplayTimer?.cancel();
    _autoplayTimer = null;
    if (!_autoplayAllowed) return;
    _autoplayTimer = Timer(autoplayDelay, _advance);
  }

  void _advance() {
    _autoplayTimer = null;
    if (!mounted || !_controller.hasClients) return;
    final next = (_page + 1) % HomeEditorialBanner.slideCount;
    // The page change callback re-arms the timer once the slide has moved.
    unawaited(
      _controller.animateToPage(
        next,
        duration: _slideDuration,
        curve: Curves.easeOut,
      ),
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers.add(event.pointer);
    _restartAutoplay();
  }

  void _onPointerEnd(PointerEvent event) {
    if (!_pointers.remove(event.pointer)) return;
    // A swipe (or a tap) restarts the 4 s count.
    _restartAutoplay();
  }

  @override
  Widget build(BuildContext context) {
    // v4.1 B01–B03 delivered banners; manual swipe with optional autoplay.
    return SizedBox(
      key: const ValueKey('home-compact-hero'),
      height: HomeEditorialBanner.heightFor(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _onPointerDown,
            onPointerUp: _onPointerEnd,
            onPointerCancel: _onPointerEnd,
            child: PageView(
              controller: _controller,
              onPageChanged: (page) {
                setState(() => _page = page);
                _restartAutoplay();
              },
              children: [
                GuideBanner(
                  key: const ValueKey('home-banner-slide-products'),
                  id: 'B01',
                  onTap: widget.onOpenProducts,
                ),
                GuideBanner(
                  key: const ValueKey('home-banner-slide-brands'),
                  id: 'B02',
                  onTap: widget.onOpenBrands,
                ),
                GuideBanner(
                  key: const ValueKey('home-banner-slide-categories'),
                  id: 'B03',
                  onTap: widget.onOpenCategories,
                ),
              ],
            ),
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
                  priceLines: tilePriceLinesFor(shown),
                ),
                itemCount: shown.length,
                itemBuilder: (context, index) {
                  final product = shown[index];
                  return ProductCard(product: product);
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
    final railHeight = productTileExtent(
      tileWidth: cardWidth,
      textScaler: MediaQuery.textScalerOf(context),
      density: _density,
      priceLines: tilePriceLinesFor(products),
    );

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

/// One entry of «Compra por estilo»: a square photo, its label and the catalog
/// destination it opens.
@immutable
class HomeStyleEntry {
  const HomeStyleEntry({
    required this.id,
    required this.label,
    required this.collectionTitle,
    required this.photoAsset,
    this.category,
    this.silhouette,
  });

  /// Stable id, used for the widget key (`home-style-<id>`).
  final String id;
  final String label;

  /// Title of the collection the entry opens.
  final String collectionTitle;

  /// Square photograph of the tile (the live web's own file).
  final String photoAsset;
  final String? category;
  final String? silhouette;
}

/// The five styles of monetta.mx's «Compra por estilo», in order. Silhouettes
/// are the catalog's own facet values (`hobo` is one of them, see
/// `lib/data/normalize/facets.dart`).
const List<HomeStyleEntry> kHomeStyleEntries = <HomeStyleEntry>[
  HomeStyleEntry(
    id: 'crossbody',
    label: 'Crossbody',
    collectionTitle: 'Crossbody',
    photoAsset: kGuideStyleCrossbody,
    category: 'bolsa',
    silhouette: 'crossbody',
  ),
  HomeStyleEntry(
    id: 'tote',
    label: 'Tote',
    collectionTitle: 'Totes',
    photoAsset: kGuideStyleTote,
    category: 'bolsa',
    silhouette: 'tote',
  ),
  HomeStyleEntry(
    id: 'shoulder',
    label: 'Shoulder',
    collectionTitle: 'Shoulder',
    photoAsset: kGuideStyleShoulder,
    category: 'bolsa',
    silhouette: 'shoulder',
  ),
  HomeStyleEntry(
    id: 'satchel',
    label: 'Satchel',
    collectionTitle: 'Satchel',
    photoAsset: kGuideStyleSatchel,
    category: 'bolsa',
    silhouette: 'satchel',
  ),
  HomeStyleEntry(
    id: 'hobo',
    label: 'Hobo',
    collectionTitle: 'Hobo',
    photoAsset: kGuideStyleHobo,
    category: 'bolsa',
    silhouette: 'hobo',
  ),
];

/// Width from which the web's wide layout applies (iPad, unfolded Duo).
const double kHomeWideBreakpoint = 768;

/// «Compra por estilo»: five square photo tiles across (web
/// `.guia-styles__list`), 4 px apart on a phone.
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
    final wide = MediaQuery.sizeOf(context).width >= kHomeWideBreakpoint;
    // Web: gap 4 on a phone, 16 from 768; the list is at most 1000 wide.
    final gap = wide ? BoutiqueSpace.lg : BoutiqueSpace.xs;
    return Column(
      key: const ValueKey('home-section-bag-types'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BoutiqueSectionHeader(
          title: 'Compra por estilo',
          actionLabel: onSeeAll == null ? null : 'Ver todo',
          onAction: onSeeAll,
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BoutiqueSpace.gutter,
              ),
              child: Row(
                key: const ValueKey('home-style-rail'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < entries.length; i++) ...[
                    if (i > 0) SizedBox(width: gap),
                    Expanded(
                      child: _StyleTile(
                        key: ValueKey('home-style-${entries[i].id}'),
                        entry: entries[i],
                        labelSize: wide ? 15 : 12,
                        onTap: () => onOpen(entries[i]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Web `.guia-styles__tile`: a cream tile with a square photo and a one-line
/// serif label under it. The whole tile is the tap target.
class _StyleTile extends StatelessWidget {
  const _StyleTile({
    required this.entry,
    required this.labelSize,
    required this.onTap,
    super.key,
  });

  final HomeStyleEntry entry;
  final double labelSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Semantics(
      button: true,
      label: 'Ver ${entry.label}',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BoutiqueSpace.tapTarget),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.monettaColors.surfaceTile,
              borderRadius: BoutiqueRadius.tile,
            ),
            child: ClipRRect(
              borderRadius: BoutiqueRadius.tile,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: Image.asset(
                      entry.photoAsset,
                      fit: BoxFit.cover,
                      // The files are 720 px; the tiles are ~70 logical px.
                      cacheWidth: 360,
                      excludeFromSemantics: true,
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
                      style: TextStyle(
                        fontFamily: kBoutiqueSerifFamily,
                        fontFamilyFallback: kBoutiqueSerifFallback,
                        fontSize: labelSize,
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
