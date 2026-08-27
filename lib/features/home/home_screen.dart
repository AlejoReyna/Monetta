/// Monetta's shopper storefront. Desire first, then a way to buy.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/catalog_store.dart';
import '../../app/media/monetta_video.dart';
import '../../app/motion.dart';
import '../../app/mixed_feed.dart';
import '../../app/shopper_copy.dart';
import '../../app/theme.dart';
import '../../data/media/media_url.dart';
import '../../domain/campaign.dart';
import '../../domain/editorial_content.dart';
import '../../domain/home_content.dart';
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
import '../checkout/checkout_screen.dart';
import '../navigation/monetta_bottom_navigation.dart';
import '../navigation/monetta_side_menu.dart';
import '../notifications/notification_settings_sheet.dart';
import '../partner/partner_hub_screen.dart';
import 'external_catalog_section.dart';

const int _kNewestCount = 8;

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

  void _openAccount() {
    final account = AccountScope.of(context);
    final admin = AdminScope.of(context);
    final catalogStore = StoreScope.of(context);
    final externalCatalog = ExternalCatalogScope.maybeOf(context);
    unawaited(
      openAccount(
        context,
        controller: account,
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
                      notificationController:
                          AdminNotificationScope.maybeOf(context),
                      catalogStore: catalogStore,
                      externalCatalogController: externalCatalog,
                    ),
                  ),
                ),
        onOpenPartner: _openPartner,
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

  void _openExternal(Uri uri) {
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

  void _openCatalogSection({
    required String title,
    String? category,
    List<String> queryTerms = const [],
  }) {
    openCollection(
      context,
      CollectionScreen(
        title: title,
        filter: CollectionFilter(
          category: category,
          queryTerms: queryTerms,
        ),
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
    final homeContent =
        HomeContentScope.maybeOf(context)?.content ?? HomeContent.fallback;
    final storefront = AdminScope.maybeOf(context)?.storefront;
    final showHero = storefront?.showHero ?? true;
    final showNewest = storefront?.showNewest ?? true;
    final showExternalPicks = storefront?.showExternalPicks ?? true;

    if (feed.isEmpty) {
      return Scaffold(
        drawer: _buildSideMenu(store),
        drawerScrimColor: Colors.black.withValues(alpha: 0.32),
        appBar: _buildAppBar(),
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
    final barH = 68 - 16 * _collapse;

    return Scaffold(
      drawer: _buildSideMenu(store),
      drawerScrimColor: Colors.black.withValues(alpha: 0.32),
      appBar: _buildAppBar(height: barH),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Fill the first body viewport (plus a small scroll lead) so the
          // next section cannot peek above the bottom navigation on load.
          final heroH = constraints.maxHeight + 12;
          final heroMediaH = heroH - _CampaignHero.outerVerticalPadding;
          return ListView(
            controller: _scroll,
            padding: EdgeInsets.zero,
            children: [
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
              for (final section in homeContent.sectionOrder)
                if (showNewest || section != HomeSectionId.newProducts)
                  _buildHomeSection(
                    section,
                    store: store,
                    content: homeContent,
                    editorial: editorial,
                    fresh: fresh,
                  ),
              const SizedBox(height: 72),
            ],
          );
        },
      ),
      bottomNavigationBar: MonettaBottomNavigation(
        current: MonettaBottomDestination.home,
        bagCount: store.bagQuantity,
        onSelected: _handleBottomNavigation,
      ),
    );
  }

  Widget _buildHomeSection(
    HomeSectionId section, {
    required CatalogStore store,
    required HomeContent content,
    required MonettaEditorialContent editorial,
    required List<Product> fresh,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 72),
      child: switch (section) {
        HomeSectionId.collections => _HomeCollectionsSection(
            cards: content.collections,
          ),
        HomeSectionId.newProducts => _NewestProductsSection(
            products: fresh,
            onOpenAll: _openFullCatalog,
          ),
        HomeSectionId.bagTypes => _BagTypesSection(cards: content.bagTypes),
        HomeSectionId.brands => _BrandsSection(
            brands: store.availableBrands,
          ),
        HomeSectionId.about => _AboutMonettaSection(
            content: editorial.about,
            imageUrl: content.aboutImageUrl,
            onOpen: _openAbout,
            onOpenPartner: _openPartner,
          ),
        HomeSectionId.social => _SocialSection(
            links: content.socialLinks,
            onOpen: _openExternal,
          ),
        HomeSectionId.testimonials => _TestimonialsSection(
            testimonials: content.testimonials,
            average: content.reviewAverage,
            count: content.reviewCount,
          ),
      },
    );
  }

  Widget _buildSideMenu(CatalogStore store) {
    final notifications = NotificationScope.maybeOf(context);
    return MonettaSideMenu(
      onSearch: () => openSearch(context),
      onCatalog: _openFullCatalog,
      onBags: () => _openCatalogSection(title: 'Bolsas', category: 'bolsa'),
      onWallets: () =>
          _openCatalogSection(title: 'Carteras', category: 'cartera'),
      onWatches: () => _openCatalogSection(title: 'Relojes', category: 'reloj'),
      onPerfumes: () => _openCatalogSection(
        title: 'Perfumes',
        queryTerms: const ['perfume', 'fragancia'],
      ),
      onBeauty: () => _openCatalogSection(
        title: 'Maquillaje y skincare',
        queryTerms: const ['maquillaje', 'skincare'],
      ),
      onNotifications: notifications == null
          ? null
          : () => unawaited(
                openNotificationSettings(
                  context,
                  controller: notifications,
                ),
              ),
      onAbout: _openAbout,
      onPartner: _openPartner,
      onSupport: () => _openWhatsApp(conciergeWhatsAppUri()),
    );
  }

  PreferredSizeWidget _buildAppBar({double height = 68}) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: height,
      centerTitle: true,
      titleSpacing: 0,
      leadingWidth: 58,
      leading: Builder(
        builder: (scaffoldContext) => IconButton(
          key: const Key('home-menu-button'),
          tooltip: 'Abrir menú',
          onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
          icon: const Icon(Icons.menu_rounded, size: 23),
        ),
      ),
      title: const MonettaWordmark.appBar(),
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

class _CampaignHero extends StatefulWidget {
  const _CampaignHero({
    required this.mediaHeight,
    required this.playing,
    required this.onOpenCatalog,
  });

  static const double outerVerticalPadding = 24;

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
    _CampaignSlideData(isVideo: true),
    _CampaignSlideData(
      asset: 'assets/images/campaign_welcome.png',
      fit: BoxFit.contain,
    ),
    _CampaignSlideData(
      asset: 'assets/images/campaign_olive.jpg',
    ),
    _CampaignSlideData(
      asset: 'assets/images/campaign_terracotta.jpg',
    ),
  ];

  final _pageController = PageController(initialPage: _initialPage);
  Timer? _advanceTimer;
  int _page = _initialPage;

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
    setState(() => _page = page);
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
      height: widget.mediaHeight + _CampaignHero.outerVerticalPadding,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
    this.asset,
    this.isVideo = false,
    this.fit,
  });

  final String? asset;
  final bool isVideo;
  final BoxFit? fit;
}

class _CampaignSlide extends StatelessWidget {
  const _CampaignSlide({
    required this.index,
    required this.data,
    required this.mediaHeight,
    required this.active,
    required this.playing,
    required this.onOpenCatalog,
  });

  final int index;
  final _CampaignSlideData data;
  final double mediaHeight;
  final bool active;
  final bool playing;
  final VoidCallback onOpenCatalog;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: GestureDetector(
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
                      fit: data.fit ?? BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeCollectionsSection extends StatelessWidget {
  const _HomeCollectionsSection({required this.cards});

  final List<HomeCollectionCard> cards;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('home-section-collections'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(kicker: 'DESCUBRE', title: 'Colecciones'),
        SizedBox(
          height: 414,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) => SizedBox(
              width: MediaQuery.sizeOf(context).width.clamp(280, 440) * .78,
              child: _CollectionEditorialCard(card: cards[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _CollectionEditorialCard extends StatelessWidget {
  const _CollectionEditorialCard({required this.card});

  final HomeCollectionCard card;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ver colección ${card.title}',
      child: GestureDetector(
        onTap: () => _openHomeCollection(context, card),
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: kLine)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _HomeImage(
                  imageUrl: card.imageUrl,
                  fallbackAsset: card.fallbackAsset,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                child: Row(
                  children: [
                    Expanded(child: Text(card.title, style: display(23))),
                    const Icon(Icons.arrow_forward, size: 18),
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

class _NewestProductsSection extends StatelessWidget {
  const _NewestProductsSection({
    required this.products,
    required this.onOpenAll,
  });

  final List<Product> products;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('home-section-new-products'),
      children: [
        SectionHeading(
          kicker: 'Novedades',
          title: 'Nuevos productos',
          trailing: UnderlineLink(label: 'Ver todos', onTap: onOpenAll),
        ),
        _CatalogGrid(products: products.take(4).toList()),
        const SizedBox(height: 26),
        Center(
          child: UnderlineLink(
            label: 'Todos los productos',
            onTap: onOpenAll,
          ),
        ),
      ],
    );
  }
}

class _BagTypesSection extends StatelessWidget {
  const _BagTypesSection({required this.cards});

  final List<HomeCollectionCard> cards;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('home-section-bag-types'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(kicker: 'ELIGE TU FORMA', title: 'Tipo de bolsas'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < cards.length; index++) ...[
                if (index > 0) const SizedBox(width: 8),
                Expanded(child: _BagTypeTile(card: cards[index])),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BagTypeTile extends StatelessWidget {
  const _BagTypeTile({required this.card});

  final HomeCollectionCard card;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ver ${card.title}',
      child: GestureDetector(
        onTap: () => _openHomeCollection(context, card),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(border: Border.all(color: kLine)),
                padding: const EdgeInsets.all(8),
                child: _HomeImage(
                  imageUrl: card.imageUrl,
                  fallbackAsset: card.fallbackAsset,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              card.title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: eyebrow(size: 8.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandsSection extends StatelessWidget {
  const _BrandsSection({required this.brands});

  final List<String> brands;

  @override
  Widget build(BuildContext context) {
    if (brands.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('home-section-brands'),
      children: [
        const SectionHeading(
          kicker: 'NUESTRA SELECCIÓN',
          title: 'Todas las marcas',
        ),
        GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.45,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: brands.length,
          itemBuilder: (context, index) {
            final brand = brands[index];
            return Semantics(
              button: true,
              label: 'Ver ${brandLabel(brand)}',
              child: GestureDetector(
                onTap: () => openCollection(
                  context,
                  CollectionScreen(
                    title: brandLabel(brand),
                    filter: CollectionFilter(brand: brand),
                  ),
                ),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(border: Border.all(color: kLine)),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    brandLabel(brand).toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: eyebrow(size: 8.5),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AboutMonettaSection extends StatelessWidget {
  const _AboutMonettaSection({
    required this.content,
    required this.imageUrl,
    required this.onOpen,
    required this.onOpenPartner,
  });

  final AboutMonettaContent content;
  final String? imageUrl;
  final VoidCallback onOpen;
  final VoidCallback onOpenPartner;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(
          kicker: 'NUESTRA HISTORIA',
          title: 'Más sobre Monetta',
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(border: Border.all(color: kLine)),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              final image = SizedBox(
                height: wide ? 360 : 310,
                width: double.infinity,
                child: _HomeImage(
                  imageUrl: imageUrl,
                  fallbackAsset: 'assets/images/home_about.webp',
                  fit: BoxFit.cover,
                ),
              );
              final copy = Padding(
                key: const ValueKey('home-about-monetta'),
                padding: EdgeInsets.all(wide ? 36 : 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BIENVENID@',
                      style: display(wide ? 31 : 27, color: kGold),
                    ),
                    const SizedBox(height: 14),
                    Text(content.headline, style: display(wide ? 27 : 23)),
                    const SizedBox(height: 14),
                    Text(
                      content.body,
                      style: sans(size: 13, color: kInkMuted, height: 1.55),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 26,
                      runSpacing: 18,
                      children: [
                        UnderlineLink(
                          label: 'Conoce nuestra historia',
                          onTap: onOpen,
                        ),
                        UnderlineLink(
                          key: const ValueKey('home-open-partner'),
                          label: 'Vende con Monetta',
                          onTap: onOpenPartner,
                        ),
                      ],
                    ),
                  ],
                ),
              );
              if (!wide) return Column(children: [image, copy]);
              return SizedBox(
                height: 360,
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
        ),
      ],
    );
  }
}

class _SocialSection extends StatelessWidget {
  const _SocialSection({required this.links, required this.onOpen});

  final List<HomeSocialLink> links;
  final ValueChanged<Uri> onOpen;

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('home-section-social'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(kicker: 'SÍGUENOS', title: 'Nuestras redes'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (var index = 0; index < links.length; index++) ...[
                if (index > 0) const SizedBox(width: 8),
                Expanded(
                  child: _SocialTile(link: links[index], onOpen: onOpen),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SocialTile extends StatelessWidget {
  const _SocialTile({required this.link, required this.onOpen});

  final HomeSocialLink link;
  final ValueChanged<Uri> onOpen;

  @override
  Widget build(BuildContext context) {
    final uri = link.uri;
    return Semantics(
      button: uri != null,
      label: 'Abrir ${link.label}',
      child: GestureDetector(
        onTap: uri == null ? null : () => onOpen(uri),
        child: AspectRatio(
          aspectRatio: .82,
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: kLine)),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_socialIcon(link.id), color: kGold, size: 28),
                const SizedBox(height: 18),
                Text(
                  link.label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: eyebrow(size: 8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _socialIcon(String id) => switch (id) {
        'instagram' => Icons.camera_alt_outlined,
        'facebook' => Icons.facebook,
        'tiktok' => Icons.music_note,
        _ => Icons.open_in_new,
      };
}

class _TestimonialsSection extends StatelessWidget {
  const _TestimonialsSection({
    required this.testimonials,
    required this.average,
    required this.count,
  });

  final List<HomeTestimonial> testimonials;
  final double? average;
  final int? count;

  @override
  Widget build(BuildContext context) {
    if (testimonials.isEmpty) return const SizedBox.shrink();
    final summary = [
      if (average != null) average!.toStringAsFixed(1),
      if (count != null) '$count reseñas',
    ].join(' · ');
    return Column(
      key: const ValueKey('home-section-testimonials'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          kicker: summary.isEmpty ? 'COMUNIDAD MONETTA' : summary,
          title: 'Experiencias de clientes',
        ),
        SizedBox(
          height: 520,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: testimonials.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) => SizedBox(
              width: MediaQuery.sizeOf(context).width.clamp(280, 440) * .82,
              child: _TestimonialCard(testimonial: testimonials[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  const _TestimonialCard({required this.testimonial});

  final HomeTestimonial testimonial;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: kLine)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _HomeImage(
              imageUrl: testimonial.imageUrl,
              fallbackAsset: testimonial.fallbackAsset,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (var i = 0; i < testimonial.rating; i++)
                      const Icon(Icons.star, color: kGold, size: 16),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '“${testimonial.body}”',
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: display(18, height: 1.36),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      testimonial.reviewer.toUpperCase(),
                      style: eyebrow(size: 9),
                    ),
                    if (testimonial.verified) ...[
                      const SizedBox(width: 7),
                      const Icon(
                        Icons.verified_outlined,
                        size: 14,
                        color: kGold,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeImage extends StatelessWidget {
  const _HomeImage({
    required this.imageUrl,
    required this.fallbackAsset,
    this.fit = BoxFit.cover,
  });

  final String? imageUrl;
  final String fallbackAsset;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final fallback = Image.asset(
      fallbackAsset,
      width: double.infinity,
      height: double.infinity,
      fit: fit,
      filterQuality: FilterQuality.medium,
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

void _openHomeCollection(BuildContext context, HomeCollectionCard card) {
  openCollection(
    context,
    CollectionScreen(
      title: card.title,
      filter: CollectionFilter(
        collectionHandle: card.handle,
        category: card.category,
        silhouette: card.silhouette,
      ),
    ),
  );
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
