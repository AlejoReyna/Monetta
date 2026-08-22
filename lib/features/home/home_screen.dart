/// Monetta's shopper storefront. Desire first, then a way to buy.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/catalog_store.dart';
import '../../app/media/monetta_image.dart';
import '../../app/media/monetta_video.dart';
import '../../app/motion.dart';
import '../../app/mixed_feed.dart';
import '../../app/shopper_copy.dart';
import '../../app/theme.dart';
import '../../data/media/media_url.dart';
import '../../domain/campaign.dart';
import '../../domain/editorial_content.dart';
import '../../domain/product.dart';
import '../../main.dart';
import '../../reco/explainer.dart';
import '../account/account_screen.dart';
import '../about/about_monetta_screen.dart';
import '../admin/admin_screen.dart';
import '../catalog/catalog_browse_screen.dart';
import '../catalog/collection_screen.dart';
import '../catalog/product_card.dart';
import '../catalog/search_screen.dart';
import '../catalog/silhouette_cutout.dart';
import '../checkout/checkout_screen.dart';
import '../navigation/monetta_bottom_navigation.dart';
import '../onboarding/onboarding_sheet.dart';
import '../partner/partner_hub_screen.dart';
import 'external_catalog_section.dart';

const int _kNewestCount = 8;
const int _kGridCount = 12;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _scroll = ScrollController();
  double _collapse = 0;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _precacheRail());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active == _foreground) return;
    setState(() => _foreground = active);
  }

  void _onScroll() {
    final next = (_scroll.offset / 80).clamp(0.0, 1.0);
    if ((next - _collapse).abs() < 0.01) return;
    setState(() => _collapse = next);
  }

  void _precacheRail() {
    if (!mounted || inWidgetTest) return;
    final store = StoreScope.of(context);
    for (final item in store.feed().take(8)) {
      final url = item.product.primaryImage;
      if (url == null) continue;
      precacheImage(
        NetworkImage(MediaUrl.sized(url, width: MediaUrl.cardWidth)),
        context,
      );
    }
  }

  void _openOnboarding() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) {
        return StoreScope(
          notifier: StoreScope.of(context),
          child: const OnboardingSheet(),
        );
      },
    ).ignore();
  }

  void _openAccount() {
    final account = AccountScope.of(context);
    final admin = AdminScope.of(context);
    final catalogStore = StoreScope.of(context);
    final externalCatalog = ExternalCatalogScope.maybeOf(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AccountScreen(
          controller: account,
          openHostedLoginOnStart: true,
          canOpenAdmin: () => admin.canAccess(
            signedIn: account.isSignedIn,
            email: account.account?.email,
            authProvider: account.account?.authProvider,
          ),
          onOpenAdmin: externalCatalog == null
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AdminScreen(
                        controller: admin,
                        catalogStore: catalogStore,
                        externalCatalogController: externalCatalog,
                      ),
                    ),
                  ),
          onOpenPartner: _openPartner,
        ),
      ),
    );
  }

  MonettaEditorialContent get _editorialContent =>
      EditorialContentScope.maybeOf(context)?.content ??
      MonettaEditorialContent.fallback;

  void _openAbout() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AboutMonettaScreen(
          content: _editorialContent.about,
          onOpenCatalog: _openFullCatalog,
          onOpenPartner: _openPartner,
        ),
      ),
    );
  }

  void _openPartner() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PartnerHubScreen(
          content: _editorialContent.partner,
        ),
      ),
    );
  }

  void _openWhatsApp(Uri uri) {
    unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
  }

  void _openFullCatalog() {
    final store = StoreScope.of(context);
    final external = ExternalCatalogScope.maybeOf(context)?.items ?? const [];
    openCatalogBrowse(
      context,
      items: fullDeduplicatedCatalog(
        monettaItems: store.catalogItems,
        externalItems: external,
      ),
    );
  }

  void _handleBottomNavigation(MonettaBottomDestination destination) {
    switch (destination) {
      case MonettaBottomDestination.home:
        if (_scroll.hasClients) {
          _scroll.animateTo(
            0,
            duration: reduceMotion(context)
                ? Duration.zero
                : const Duration(milliseconds: 260),
            curve: Curves.easeOut,
          );
        }
      case MonettaBottomDestination.catalog:
        _openFullCatalog();
      case MonettaBottomDestination.bag:
        unawaited(openBag(context));
      case MonettaBottomDestination.account:
        _openAccount();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final feed = store.feed();
    // Read in build (not in a tap callback) so this rebuilds reactively once
    // the background fetch in `ExternalCatalogController.loadAndRefresh`
    // completes — a one-shot read at navigation time could catch it empty.
    final externalCatalog = ExternalCatalogScope.maybeOf(context);
    final externalItems = externalCatalog?.items ?? const [];
    final editorial = _editorialContent;
    final storefront = AdminScope.maybeOf(context)?.storefront;
    final showHero = storefront?.showHero ?? true;
    final showNewest = storefront?.showNewest ?? true;
    final showExternalPicks = storefront?.showExternalPicks ?? true;
    final announcement =
        storefront?.announcement ?? r'ENVÍO GRATIS DESDE $1,499';

    if (feed.isEmpty) {
      return Scaffold(
        appBar: _buildAppBar(24),
        body: Center(child: Text('Sin resultados', style: eyebrow())),
        bottomNavigationBar: MonettaBottomNavigation(
          current: MonettaBottomDestination.home,
          bagCount: store.bagQuantity,
          onSelected: _handleBottomNavigation,
        ),
      );
    }

    final newest = [...store.products]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final fresh = newest.take(_kNewestCount).toList();
    final freshIds = fresh.map((p) => p.id).toSet();
    final rest = feed
        .map((item) => item.product)
        .where((p) => !freshIds.contains(p.id))
        .take(_kGridCount)
        .toList();

    final bolsa = store.firstInStockWhere(
      (p, f) => f?.category?.value == 'bolsa',
    );
    final cartera = store.firstInStockWhere(
      (p, f) => f?.category?.value == 'cartera',
    );
    final reloj = store.firstInStockWhere(
      (p, f) => f?.category?.value == 'reloj',
    );

    final media = MediaQuery.sizeOf(context);
    final announcementH = 32 * (1 - _collapse);
    final barH = 68 - 16 * _collapse;
    final markH = 24 - 6 * _collapse;
    final heroCardWidth = (media.width - 32).clamp(0.0, 600.0);
    final heroMediaH = heroCardWidth / 1.08;
    final heroH = heroMediaH +
        _CampaignHero.copyHeight +
        _CampaignHero.outerVerticalPadding;

    return Scaffold(
      appBar: _buildAppBar(markH, height: barH),
      body: ListView(
        controller: _scroll,
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: announcementH,
            child: ClipRect(
              child: Opacity(
                opacity: 1 - _collapse,
                child: _AnnouncementStrip(text: announcement),
              ),
            ),
          ),
          if (showHero)
            _CampaignHero(
              mediaHeight: heroMediaH,
              playing: _foreground &&
                  (!_scroll.hasClients || _scroll.offset < heroH),
              onOpenCatalog: _openFullCatalog,
            ),
          if (showExternalPicks && externalItems.isNotEmpty)
            ExternalCatalogSection(
              items: externalItems,
              generatedAt: externalCatalog?.generatedAt,
            ),
          if (showNewest) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text('Novedades', style: display(24)),
            ),
            _CatalogGrid(products: fresh),
          ],
          const SizedBox(height: 48),
          _PhotoShopRow(
            tiles: [
              if (bolsa != null)
                _ShopTileData(
                  label: 'Bolsas',
                  imageUrl: bolsa.primaryImage,
                  screen: const CollectionScreen(
                    title: 'Bolsas',
                    filter: CollectionFilter(category: 'bolsa'),
                  ),
                ),
              if (cartera != null)
                _ShopTileData(
                  label: 'Carteras',
                  imageUrl: cartera.primaryImage,
                  screen: const CollectionScreen(
                    title: 'Carteras',
                    filter: CollectionFilter(category: 'cartera'),
                  ),
                ),
              if (reloj != null)
                _ShopTileData(
                  label: 'Relojes',
                  imageUrl: reloj.primaryImage,
                  screen: const CollectionScreen(
                    title: 'Relojes',
                    filter: CollectionFilter(category: 'reloj'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 64),
          _AboutMonettaSection(
            content: editorial.about,
            onOpen: _openAbout,
          ),
          const SizedBox(height: 12),
          _PartnerTeaser(
            content: editorial.partner,
            onOpen: _openPartner,
          ),
          const SizedBox(height: 64),
          _FinishedBrandBlock(store: store),
          const SizedBox(height: 64),
          _FinishedFormaBlock(store: store),
          const SizedBox(height: 48),
          _CatalogGrid(products: rest),
          const SizedBox(height: 20),
          Center(
            child: UnderlineLink(
              label: 'Ver todo',
              onTap: _openFullCatalog,
            ),
          ),
          const SizedBox(height: 52),
          _QuietFooter(
            onChooseBrands: _openOnboarding,
            onWhatsApp: () => _openWhatsApp(conciergeWhatsAppUri()),
            onWholesale: () => _openWhatsApp(wholesaleWhatsAppUri()),
          ),
        ],
      ),
      bottomNavigationBar: MonettaBottomNavigation(
        current: MonettaBottomDestination.home,
        bagCount: store.bagQuantity,
        onSelected: _handleBottomNavigation,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(double markHeight, {double height = 68}) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: height,
      centerTitle: false,
      titleSpacing: 20,
      title: Align(
        alignment: Alignment.centerLeft,
        child: MonettaWordmark(height: markHeight),
      ),
      actions: [
        IconButton(
          tooltip: 'Buscar',
          onPressed: () => openSearch(context),
          icon: const Icon(Icons.search, size: 24),
        ),
        const SizedBox(width: 4),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(0.5),
        child: Divider(height: 0.5),
      ),
    );
  }
}

class _AnnouncementStrip extends StatelessWidget {
  const _AnnouncementStrip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      color: kInk,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        text.isEmpty ? 'MONETTA' : text.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: eyebrow(size: 9, color: Colors.white, weight: FontWeight.w500),
      ),
    );
  }
}

class _CampaignHero extends StatefulWidget {
  const _CampaignHero({
    required this.mediaHeight,
    required this.playing,
    required this.onOpenCatalog,
  });

  static const double copyHeight = 172;
  static const double outerVerticalPadding = 40;

  final double mediaHeight;
  final bool playing;
  final VoidCallback onOpenCatalog;

  @override
  State<_CampaignHero> createState() => _CampaignHeroState();
}

class _CampaignHeroState extends State<_CampaignHero> {
  static const _interval = Duration(milliseconds: 3500);
  static const _initialPage = 3000;
  static const _slides = <_CampaignSlideData>[
    _CampaignSlideData(
      headline: 'Piezas originales, elegidas una por una.',
      ctaLabel: 'Ver el catálogo',
      isVideo: true,
    ),
    _CampaignSlideData(
      headline: 'Nuevas siluetas para todos los días.',
      ctaLabel: 'Explorar bolsas',
      asset: 'assets/images/campaign_olive.jpg',
    ),
    _CampaignSlideData(
      headline: 'Tus marcas favoritas, más cerca de ti.',
      ctaLabel: 'Descubrir novedades',
      asset: 'assets/images/campaign_terracotta.jpg',
    ),
  ];

  final _pageController = PageController(initialPage: _initialPage);
  Timer? _advanceTimer;
  int _page = _initialPage;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleAdvance());
  }

  @override
  void didUpdateWidget(covariant _CampaignHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing == widget.playing) return;
    if (widget.playing) {
      _scheduleAdvance();
    } else {
      _advanceTimer?.cancel();
    }
  }

  void _scheduleAdvance() {
    _advanceTimer?.cancel();
    if (!mounted || !widget.playing) return;
    _advanceTimer = Timer(_interval, _advance);
  }

  void _advance() {
    if (!mounted || !widget.playing || !_pageController.hasClients) return;
    final next = _page + 1;
    if (reduceMotion(context)) {
      _pageController.jumpToPage(next);
    } else {
      unawaited(
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 460),
          curve: Curves.easeInOutCubic,
        ),
      );
    }
  }

  void _onPageChanged(int page) {
    setState(() {
      _page = page;
      _index = page % _slides.length;
    });
    _scheduleAdvance();
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('campaign-hero'),
      height: widget.mediaHeight +
          _CampaignHero.copyHeight +
          _CampaignHero.outerVerticalPadding,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Semantics(
          label: 'Campañas destacadas, 3 tarjetas',
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, page) {
              final index = page % _slides.length;
              return _CampaignSlide(
                index: index,
                data: _slides[index],
                mediaHeight: widget.mediaHeight,
                active: page == _page,
                playing: widget.playing,
                selectedIndex: _index,
                onOpenCatalog: widget.onOpenCatalog,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CampaignSlideData {
  const _CampaignSlideData({
    required this.headline,
    required this.ctaLabel,
    this.asset,
    this.isVideo = false,
  });

  final String headline;
  final String ctaLabel;
  final String? asset;
  final bool isVideo;
}

class _CampaignSlide extends StatelessWidget {
  const _CampaignSlide({
    required this.index,
    required this.data,
    required this.mediaHeight,
    required this.active,
    required this.playing,
    required this.selectedIndex,
    required this.onOpenCatalog,
  });

  final int index;
  final _CampaignSlideData data;
  final double mediaHeight;
  final bool active;
  final bool playing;
  final int selectedIndex;
  final VoidCallback onOpenCatalog;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: kMist),
          child: Column(
            children: [
              GestureDetector(
                key: ValueKey('campaign-slide-media-$index'),
                onTap: onOpenCatalog,
                child: SizedBox(
                  width: double.infinity,
                  height: mediaHeight,
                  child: ClipRect(
                    child: data.isVideo
                        ? MonettaVideo(
                            campaign: CampaignMedia.monettaHome,
                            playing: playing && active,
                          )
                        : Image.asset(
                            data.asset!,
                            width: double.infinity,
                            height: mediaHeight,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium,
                          ),
                  ),
                ),
              ),
              Container(
                key: index == 0
                    ? const Key('editorial-breath')
                    : ValueKey('campaign-slide-copy-$index'),
                width: double.infinity,
                height: _CampaignHero.copyHeight,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Text(
                          data.headline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: display(22, height: 1.28),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    UnderlineLink(
                      label: data.ctaLabel,
                      onTap: onOpenCatalog,
                      size: 14,
                    ),
                    const SizedBox(height: 20),
                    _CampaignIndicators(
                      count: _CampaignHeroState._slides.length,
                      selectedIndex: selectedIndex,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CampaignIndicators extends StatelessWidget {
  const _CampaignIndicators({
    required this.count,
    required this.selectedIndex,
  });

  final int count;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          AnimatedContainer(
            key: ValueKey('campaign-indicator-$i'),
            duration: reduceMotion(context) ? Duration.zero : kSnap,
            width: i == selectedIndex ? 20 : 6,
            height: 3,
            decoration: BoxDecoration(
              color: i == selectedIndex ? kInk : kLine,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ],
    );
  }
}

class _ShopTileData {
  const _ShopTileData({
    required this.label,
    required this.imageUrl,
    required this.screen,
  });

  final String label;
  final String? imageUrl;
  final CollectionScreen screen;
}

class _PhotoShopRow extends StatelessWidget {
  const _PhotoShopRow({required this.tiles});

  final List<_ShopTileData> tiles;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: _PhotoTile(data: tiles[i])),
          ],
        ],
      ),
    );
  }
}

class _PhotoTile extends StatefulWidget {
  const _PhotoTile({required this.data});

  final _ShopTileData data;

  @override
  State<_PhotoTile> createState() => _PhotoTileState();
}

class _PhotoTileState extends State<_PhotoTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () => openCollection(context, widget.data.screen),
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: reduceMotion(context) ? Duration.zero : kSnap,
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 3 / 4,
              child: MonettaImage(
                url: widget.data.imageUrl,
                cacheWidth: MediaUrl.cardWidth,
              ),
            ),
            const SizedBox(height: 10),
            Text(widget.data.label.toUpperCase(), style: eyebrow(size: 9)),
          ],
        ),
      ),
    );
  }
}

class _AboutMonettaSection extends StatelessWidget {
  const _AboutMonettaSection({required this.content, required this.onOpen});

  final AboutMonettaContent content;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('home-about-monetta'),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(border: Border.all(color: kLine)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          final image = Image.asset(
            content.heroAsset,
            height: wide ? 330 : 250,
            width: double.infinity,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          );
          final copy = Padding(
            padding: EdgeInsets.all(wide ? 36 : 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(content.eyebrow, style: eyebrow(color: kGold)),
                const SizedBox(height: 13),
                Text(content.headline, style: display(wide ? 30 : 25)),
                const SizedBox(height: 14),
                Text(
                  content.body,
                  maxLines: wide ? 5 : 4,
                  overflow: TextOverflow.ellipsis,
                  style: sans(size: 13, color: kInkMuted, height: 1.55),
                ),
                const SizedBox(height: 22),
                UnderlineLink(
                  label: 'Conoce nuestra historia',
                  onTap: onOpen,
                ),
              ],
            ),
          );
          if (!wide) return Column(children: [image, copy]);
          return SizedBox(
            height: 330,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: image),
                Expanded(child: copy),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PartnerTeaser extends StatelessWidget {
  const _PartnerTeaser({required this.content, required this.onOpen});

  final PartnerProgramContent content;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('home-partner-teaser'),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: kInk,
      padding: const EdgeInsets.fromLTRB(24, 38, 24, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(content.eyebrow, style: eyebrow(color: kGold)),
          const SizedBox(height: 14),
          Text(
            content.headline,
            style: display(27, color: Colors.white, height: 1.22),
          ),
          const SizedBox(height: 14),
          Text(
            content.body,
            style: sans(
              size: 13,
              color: const Color(0xFFD3D3D3),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey('home-open-partner'),
            onPressed: onOpen,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: kInk,
            ),
            child: const Text('VER CÓMO FUNCIONA'),
          ),
        ],
      ),
    );
  }
}

List<Product> _inStockFor(
  CatalogStore store, {
  String? brand,
  String? silhouette,
  int limit = 4,
}) {
  final out = <Product>[];
  for (final product in store.products) {
    if (!product.isInStock) continue;
    final facets = store.facetsFor(product.id);
    if (brand != null && facets?.brand?.value != brand) continue;
    if (silhouette != null && facets?.silhouette?.value != silhouette) {
      continue;
    }
    out.add(product);
    if (out.length >= limit) break;
  }
  return out;
}

class _FinishedBrandBlock extends StatefulWidget {
  const _FinishedBrandBlock({required this.store});

  final CatalogStore store;

  @override
  State<_FinishedBrandBlock> createState() => _FinishedBrandBlockState();
}

class _FinishedBrandBlockState extends State<_FinishedBrandBlock> {
  String? _brand;

  List<String> get _brands {
    return [
      for (final brand in widget.store.availableBrands)
        if (_inStockFor(widget.store, brand: brand, limit: 1).isNotEmpty) brand,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final brands = _brands;
    if (brands.isEmpty) return const SizedBox.shrink();
    final brand = brands.contains(_brand) ? _brand! : brands.first;
    final pieces = _inStockFor(widget.store, brand: brand);
    if (pieces.isEmpty) return const SizedBox.shrink();
    final still = pieces.first.primaryImage;
    final label = brandLabel(brand);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (still != null)
          AspectRatio(
            aspectRatio: 16 / 10,
            child: MonettaImage(url: still, cacheWidth: MediaUrl.heroWidth),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
          child: Text('Marcas'.toUpperCase(), style: eyebrow()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Text('Las casas que traemos', style: display(24)),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: brands.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final slug = brands[index];
              final selected = slug == brand;
              return GestureDetector(
                onTap: () => setState(() => _brand = slug),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selected ? kInk : kLine,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    brandLabel(slug).toUpperCase(),
                    style: eyebrow(
                      size: 9,
                      color: selected ? kInk : kInkMuted,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        _CatalogGrid(products: pieces),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: FilledButton(
            onPressed: () => openCollection(
              context,
              CollectionScreen(
                title: label,
                filter: CollectionFilter(brand: brand),
              ),
            ),
            child: Text('Ver $label'.toUpperCase()),
          ),
        ),
      ],
    );
  }
}

class _FinishedFormaBlock extends StatefulWidget {
  const _FinishedFormaBlock({required this.store});

  final CatalogStore store;

  @override
  State<_FinishedFormaBlock> createState() => _FinishedFormaBlockState();
}

class _FinishedFormaBlockState extends State<_FinishedFormaBlock> {
  static const _shapes = <(String, String, SilhouetteCutoutKind)>[
    ('tote', 'Totes', SilhouetteCutoutKind.tote),
    ('crossbody', 'Crossbody', SilhouetteCutoutKind.crossbody),
    ('shoulder', 'De hombro', SilhouetteCutoutKind.shoulder),
  ];

  String? _silhouette;

  List<(String, String, SilhouetteCutoutKind)> get _available {
    return [
      for (final shape in _shapes)
        if (_inStockFor(widget.store, silhouette: shape.$1, limit: 1)
            .isNotEmpty)
          shape,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final shapes = _available;
    if (shapes.isEmpty) return const SizedBox.shrink();
    final selected = shapes.firstWhere(
      (s) => s.$1 == _silhouette,
      orElse: () => shapes.first,
    );
    final pieces = _inStockFor(widget.store, silhouette: selected.$1);
    if (pieces.isEmpty) return const SizedBox.shrink();
    final still = pieces.first.primaryImage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (still != null)
          AspectRatio(
            aspectRatio: 16 / 10,
            child: MonettaImage(url: still, cacheWidth: MediaUrl.heroWidth),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
          child: Text('Formas'.toUpperCase(), style: eyebrow()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Text('Cómo se lleva', style: display(24)),
        ),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: shapes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 18),
            itemBuilder: (context, index) {
              final shape = shapes[index];
              final on = shape.$1 == selected.$1;
              return GestureDetector(
                onTap: () => setState(() => _silhouette = shape.$1),
                child: SizedBox(
                  width: 64,
                  child: Column(
                    children: [
                      SilhouetteCutout(
                        kind: shape.$3,
                        color: on ? kInk : kInkMuted,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        shape.$2.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: eyebrow(
                          size: 8,
                          color: on ? kInk : kInkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _CatalogGrid(products: pieces),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: FilledButton(
            onPressed: () => openCollection(
              context,
              CollectionScreen(
                title: selected.$2,
                filter: CollectionFilter(
                  category: 'bolsa',
                  silhouette: selected.$1,
                ),
              ),
            ),
            child: Text('Ver ${selected.$2}'.toUpperCase()),
          ),
        ),
      ],
    );
  }
}

class _CatalogGrid extends StatelessWidget {
  const _CatalogGrid({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1060
            ? 4
            : constraints.maxWidth >= 720
                ? 3
                : 2;
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: 0.52,
            crossAxisSpacing: 8,
            mainAxisSpacing: 32,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) =>
              ProductCard(product: products[index]),
        );
      },
    );
  }
}

class _QuietFooter extends StatelessWidget {
  const _QuietFooter({
    required this.onChooseBrands,
    required this.onWhatsApp,
    required this.onWholesale,
  });

  final VoidCallback onChooseBrands;
  final VoidCallback onWhatsApp;
  final VoidCallback onWholesale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: kMist,
      padding: const EdgeInsets.fromLTRB(20, 34, 20, 38),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MonettaTrustRows(),
          const SizedBox(height: 28),
          UnderlineLink(label: 'Elige marcas', onTap: onChooseBrands),
          const SizedBox(height: 16),
          UnderlineLink(label: 'WhatsApp', onTap: onWhatsApp),
          const SizedBox(height: 16),
          UnderlineLink(label: 'Mayoreo', onTap: onWholesale),
          const SizedBox(height: 22),
          Text(
            'MONETTA · MÉXICO',
            style: eyebrow(size: 9, color: kInkMuted),
          ),
        ],
      ),
    );
  }
}
