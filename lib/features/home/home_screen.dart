/// Monetta's shopper storefront. Desire first, then a way to buy.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/catalog_store.dart';
import '../../app/home_content_controller.dart';
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
import '../settings/appearance_sheet.dart';
import '../partner/partner_hub_screen.dart';
import 'customer_experiences_section.dart';
import 'customer_experiences_screen.dart';
import 'external_catalog_section.dart';
import 'home_account_invitation.dart';

const int _kNewestCount = 8;

Duration _homeSectionDelay(int index) =>
    Duration(milliseconds: (index * 70).clamp(0, 350));

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _scroll = ScrollController();
  // Keep scroll-driven state out of the (image-heavy) home body. The app bar
  // and hero playback each listen to only the value they need.
  final ValueNotifier<double> _collapse = ValueNotifier<double>(0);
  final ValueNotifier<bool> _heroPlaying = ValueNotifier<bool>(true);
  double _heroHeight = double.infinity;
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
    _collapse.dispose();
    _heroPlaying.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active == _foreground) return;
    setState(() => _foreground = active);
    _syncHeroPlayback();
  }

  void _onScroll() {
    final next = (_scroll.offset / 120).clamp(0.0, 1.0);
    if ((next - _collapse.value).abs() >= 0.01) {
      _collapse.value = next;
    }
    _syncHeroPlayback();
  }

  void _syncHeroPlayback() {
    final shouldPlay =
        _foreground && (!_scroll.hasClients || _scroll.offset < _heroHeight);
    if (_heroPlaying.value == shouldPlay) return;
    _heroPlaying.value = shouldPlay;
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

  void _openCustomerExperiences(HomeContent content) {
    final homeController = HomeContentScope.maybeOf(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomerExperiencesScreen(
          repository: homeController?.reviewsRepository,
          fallbackReviews: content.testimonials,
          average: content.reviewAverage,
          count: content.reviewCount,
        ),
      ),
    );
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
    final homeScope = HomeContentScope.maybeOf(context);
    final homeContent = homeScope?.content ?? HomeContent.fallback;
    final reviewsStatus =
        homeScope?.reviewsStatus ?? HomeReviewsStatus.fallback;
    final storefront = AdminScope.maybeOf(context)?.storefront;
    final showHero = storefront?.showHero ?? true;
    final showNewest = storefront?.showNewest ?? true;
    final showExternalPicks = storefront?.showExternalPicks ?? true;

    if (feed.isEmpty) {
      return Scaffold(
        extendBody: true,
        drawer: _buildSideMenu(store),
        drawerScrimColor: context.monettaColors.scrim,
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
    final drawer = _buildSideMenu(store);
    final bottomNavigation = MonettaBottomNavigation(
      current: MonettaBottomDestination.home,
      bagCount: store.bagQuantity,
      onSelected: _handleBottomNavigation,
    );
    final body = LayoutBuilder(
      builder: (context, constraints) {
        _heroHeight = _HomeDiscoveryHeader.estimatedHeight;
        return ListView(
          controller: _scroll,
          padding: EdgeInsets.zero,
          children: [
            if (showHero)
              KeyedSubtree(
                key: const ValueKey('home-reveal-hero'),
                child: ValueListenableBuilder<bool>(
                  valueListenable: _heroPlaying,
                  builder: (context, playing, child) => _HomeDiscoveryHeader(
                    collapse: _collapse,
                    playing: playing,
                    onSearch: () => openSearch(context),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 28),
              child: _HomeCollectionsSection(cards: homeContent.collections),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 72),
              child: RevealOnScroll(
                key: const ValueKey('home-reveal-offers'),
                scrollController: _scroll,
                offset: 0,
                child: _HomeOffersSection(onOpenCatalog: _openFullCatalog),
              ),
            ),
            if (showExternalPicks && externalItems.isNotEmpty)
              RevealOnScroll(
                key: const ValueKey('home-reveal-external-picks'),
                scrollController: _scroll,
                delay: const Duration(milliseconds: 80),
                offset: 0,
                child: ExternalCatalogSection(
                  items: externalItems,
                  generatedAt: externalCatalog?.generatedAt,
                ),
              ),
            for (var index = 0;
                index < homeContent.sectionOrder.length;
                index++)
              if (homeContent.sectionOrder[index] !=
                      HomeSectionId.collections &&
                  (showNewest ||
                      homeContent.sectionOrder[index] !=
                          HomeSectionId.newProducts))
                _buildHomeSection(
                  homeContent.sectionOrder[index],
                  index: index,
                  store: store,
                  content: homeContent,
                  editorial: editorial,
                  fresh: fresh,
                  reviewsStatus: reviewsStatus,
                ),
            Padding(
              padding: const EdgeInsets.only(top: 72),
              child: RevealOnScroll(
                key: const ValueKey('home-reveal-account-invitation'),
                scrollController: _scroll,
                delay: const Duration(milliseconds: 280),
                offset: 0,
                child: HomeAccountInvitation(
                  isSignedIn:
                      AccountScope.maybeOf(context)?.isSignedIn ?? false,
                  onRegister: _openAccount,
                ),
              ),
            ),
            const SizedBox(height: 72),
          ],
        );
      },
    );

    return ValueListenableBuilder<double>(
      valueListenable: _collapse,
      // This child is retained while the app bar collapses. A scroll tick
      // therefore does not rebuild or relayout the full home content tree.
      child: body,
      builder: (context, collapse, child) {
        final searchCollapse = showHero ? collapse : 1.0;
        return Scaffold(
          extendBody: true,
          extendBodyBehindAppBar: showHero,
          drawer: drawer,
          drawerScrimColor: context.monettaColors.scrim,
          appBar: _buildAppBar(
            height: 68 - 16 * collapse,
            searchCollapse: searchCollapse,
            surfaceCollapse: showHero ? collapse : 1,
          ),
          body: child,
          bottomNavigationBar: bottomNavigation,
        );
      },
    );
  }

  Widget _buildHomeSection(
    HomeSectionId section, {
    required int index,
    required CatalogStore store,
    required HomeContent content,
    required MonettaEditorialContent editorial,
    required List<Product> fresh,
    required HomeReviewsStatus reviewsStatus,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 72),
      child: RevealOnScroll(
        key: ValueKey('home-reveal-${section.name}'),
        scrollController: _scroll,
        delay: _homeSectionDelay(index),
        // Keep layout-driven scrolling exact for buttons inside the section;
        // the section's appearance is carried by opacity rather than a
        // translated render box.
        offset: 0,
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
              brands: content.brands,
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
          HomeSectionId.testimonials => CustomerExperiencesSection(
              testimonials: content.testimonials,
              average: content.reviewAverage,
              count: content.reviewCount,
              status: reviewsStatus,
              onSeeMore: () => _openCustomerExperiences(content),
            ),
        },
      ),
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
      onAppearance: () => unawaited(openAppearanceSettings(context)),
      onAbout: _openAbout,
      onPartner: _openPartner,
      onSupport: () => _openWhatsApp(conciergeWhatsAppUri()),
    );
  }

  PreferredSizeWidget _buildAppBar({
    double height = 68,
    double searchCollapse = 1,
    double surfaceCollapse = 1,
  }) {
    final colors = context.monettaColors;
    final searchProgress = Curves.easeOutCubic.transform(
      ((searchCollapse - .34) / .66).clamp(0.0, 1.0),
    );
    final surfaceProgress = Curves.easeOutCubic.transform(
      ((surfaceCollapse - .08) / .72).clamp(0.0, 1.0),
    );
    final foreground = Color.lerp(
      Colors.white,
      colors.contentPrimary,
      surfaceProgress,
    )!;
    final collapsedBrightness = Theme.of(context).brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: height,
      backgroundColor: Color.lerp(
        Colors.transparent,
        colors.surface,
        surfaceProgress,
      ),
      foregroundColor: foreground,
      iconTheme: IconThemeData(color: foreground, size: 21),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            surfaceProgress < .55 ? Brightness.light : collapsedBrightness,
        statusBarBrightness: surfaceProgress < .55
            ? Brightness.dark
            : Theme.of(context).brightness,
      ),
      centerTitle: true,
      titleSpacing: 0,
      leadingWidth: 58,
      leading: Builder(
        builder: (scaffoldContext) => Padding(
          padding: const EdgeInsets.all(9),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.lerp(
                Colors.black.withValues(alpha: .42),
                Colors.transparent,
                surfaceProgress,
              ),
              border: Border.all(
                color: Color.lerp(
                  Colors.white.withValues(alpha: .48),
                  Colors.transparent,
                  surfaceProgress,
                )!,
                width: .5,
              ),
            ),
            child: IconButton(
              key: const Key('home-menu-button'),
              tooltip: 'Abrir menú',
              padding: EdgeInsets.zero,
              onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
              icon: const Icon(Icons.menu_rounded, size: 21),
            ),
          ),
        ),
      ),
      title: const MonettaWordmark.appBar(),
      actions: [
        IgnorePointer(
          ignoring: searchProgress < .7,
          child: ExcludeSemantics(
            excluding: searchProgress < .7,
            child: Opacity(
              key: const ValueKey('home-appbar-search-transition'),
              opacity: searchProgress,
              child: Transform.scale(
                scale: .76 + .24 * searchProgress,
                child: IconButton(
                  key: const ValueKey('home-appbar-search-button'),
                  tooltip: 'Buscar',
                  onPressed: () => openSearch(context),
                  icon: const Icon(Icons.search, size: 24),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Divider(
          height: 0.5,
          color: colors.divider.withValues(alpha: surfaceProgress),
        ),
      ),
    );
  }
}

class _HomeDiscoveryHeader extends StatelessWidget {
  const _HomeDiscoveryHeader({
    required this.collapse,
    required this.playing,
    required this.onSearch,
  });

  static const double estimatedHeight = 280;

  final ValueListenable<double> collapse;
  final bool playing;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Reveal(
      offset: 8,
      child: Column(
        key: const ValueKey('home-discovery-header'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            key: const ValueKey('home-compact-hero'),
            height: 280,
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MonettaVideo(
                    campaign: CampaignMedia.monettaHome,
                    playing: playing,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x24000000),
                          Color(0x08000000),
                          Color(0xA3000000),
                        ],
                        stops: [0, .48, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 18,
                    child: ValueListenableBuilder<double>(
                      valueListenable: collapse,
                      builder: (context, value, child) {
                        final visibility = 1 -
                            Curves.easeInCubic.transform(
                              ((value - .08) / .78).clamp(0.0, 1.0),
                            );
                        return IgnorePointer(
                          ignoring: visibility < .25,
                          child: ExcludeSemantics(
                            excluding: visibility < .25,
                            child: Opacity(
                              key: const ValueKey(
                                'home-search-bar-transition',
                              ),
                              opacity: visibility,
                              child: Transform.translate(
                                offset: Offset(0, -8 * (1 - visibility)),
                                child: Transform.scale(
                                  alignment: Alignment.centerRight,
                                  scale: .94 + .06 * visibility,
                                  child: child,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      child: _HomeSearchBar(onTap: onSearch),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeSearchBar extends StatelessWidget {
  const _HomeSearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.monettaColors;
    return Semantics(
      button: true,
      label: 'Buscar productos',
      child: GestureDetector(
        key: const ValueKey('home-search-bar'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 17),
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: colors.divider, width: .5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .12),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 20, color: colors.contentPrimary),
              const SizedBox(width: 11),
              Text(
                '¿Buscas algo?',
                style: sans(size: 12.5, color: colors.contentMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeOffersSection extends StatelessWidget {
  const _HomeOffersSection({required this.onOpenCatalog});

  static const _offers = <_OfferData>[
    _OfferData(
      imageAsset: 'assets/images/campaign_olive.jpg',
      promotion: '20% en bolsos seleccionados',
      description: 'Encuentra una pieza para todos los días.',
    ),
    _OfferData(
      imageAsset: 'assets/images/campaign_coral.jpg',
      promotion: 'Nuevos favoritos de temporada',
      description: 'Color y siluetas que renuevan tu colección.',
    ),
    _OfferData(
      imageAsset: 'assets/images/campaign_terracotta.jpg',
      promotion: 'Envío gratis en tu primer pedido',
      description: 'Regístrate y descubre todo lo nuevo.',
    ),
  ];

  final VoidCallback onOpenCatalog;

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = (viewportWidth * .84).clamp(304.0, 420.0);
    return Column(
      key: const ValueKey('home-section-offers'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text('Ofertas de hoy', style: editorial(25)),
              ),
              Text(
                'DESLIZA',
                style: eyebrow(
                  size: 8,
                  color: context.monettaColors.contentMuted,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          key: const ValueKey('home-offers-rail'),
          height: 500,
          child: ListView.separated(
            key: const PageStorageKey<String>('home-offers-scroll'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: _offers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => SizedBox(
              width: cardWidth,
              child: _OfferCard(
                key: ValueKey('home-offer-card-$index'),
                data: _offers[index],
                onTap: onOpenCatalog,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OfferData {
  const _OfferData({
    required this.imageAsset,
    required this.promotion,
    required this.description,
  });

  final String imageAsset;
  final String promotion;
  final String description;
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.data, required this.onTap, super.key});

  final _OfferData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.monettaColors;
    return Semantics(
      button: true,
      label: '${data.promotion}. ${data.description}. Comprar ahora',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceRaised,
              border: Border.all(color: colors.divider, width: .8),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Column(
              children: [
                Expanded(
                  flex: 51,
                  child: SizedBox.expand(
                    child: Image.asset(
                      data.imageAsset,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
                  ),
                ),
                Expanded(
                  flex: 40,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          data.promotion,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: sans(
                            size: 16,
                            color: colors.contentPrimary,
                            weight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          data.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: sans(
                            size: 12,
                            color: colors.contentMuted,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          height: 43,
                          constraints: const BoxConstraints(minWidth: 178),
                          padding: const EdgeInsets.symmetric(horizontal: 30),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colors.inverseSurface,
                            borderRadius: BorderRadius.circular(23),
                          ),
                          child: Text(
                            'Comprar ahora',
                            style: sans(
                              size: 12.5,
                              color: colors.onInverseSurface,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  height: 45,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  color: colors.surfaceMuted,
                  child: Row(
                    children: [
                      Text(
                        'No requiere código.',
                        style: sans(size: 10, color: colors.contentMuted),
                      ),
                      const Spacer(),
                      Text(
                        'Detalles',
                        style: sans(
                          size: 10,
                          color: colors.contentMuted,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
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

class _HomeCollectionsSection extends StatelessWidget {
  const _HomeCollectionsSection({required this.cards});

  final List<HomeCollectionCard> cards;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = (viewportWidth * .73).clamp(280.0, 460.0);
    final cardHeight = cardWidth / .7;
    return Column(
      key: const ValueKey('home-section-collections'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(kicker: 'DESCUBRE', title: 'Colecciones'),
        SizedBox(
          height: cardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) => SizedBox(
              width: cardWidth,
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
        key: ValueKey('home-collection-card-${card.handle}'),
        onTap: () => _openHomeCollection(context, card),
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              _HomeImage(
                imageUrl: card.imageUrl,
                fallbackAsset: card.fallbackAsset,
              ),
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x00000000),
                        Color(0x08000000),
                        Color(0xB8000000),
                      ],
                      stops: [.46, .64, 1],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 16,
                bottom: 18,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        card.title,
                        style: display(24, color: Colors.white),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward,
                      size: 21,
                      color: Colors.white,
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
                decoration: BoxDecoration(
                  border: Border.all(color: context.monettaColors.divider),
                ),
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

  final List<HomeBrandCard> brands;

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
              label: 'Ver ${brand.title}',
              child: Material(
                key: ValueKey('home-brand-${brand.handle}'),
                color: Colors.white,
                elevation: 2,
                shadowColor: Colors.black.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(28),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => openCollection(
                    context,
                    CollectionScreen(
                      title: brand.title,
                      filter: CollectionFilter(brand: brand.brand),
                    ),
                  ),
                  child: _HomeImage(
                    imageUrl: brand.imageUrl,
                    fallbackAsset: brand.fallbackAsset,
                    fit: BoxFit.cover,
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
          key: const ValueKey('home-about-card'),
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: context.monettaColors.divider),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              final image = SizedBox(
                key: const ValueKey('home-about-image'),
                height: 360,
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
                      style: display(
                        wide ? 31 : 27,
                        color: context.monettaColors.accent,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(content.headline, style: display(wide ? 27 : 23)),
                    const SizedBox(height: 14),
                    Text(
                      content.body,
                      style: sans(
                        size: 13,
                        color: context.monettaColors.contentMuted,
                        height: 1.55,
                      ),
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
            decoration: BoxDecoration(
              border: Border.all(color: context.monettaColors.divider),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _socialIcon(link.id),
                  color: context.monettaColors.accent,
                  size: 28,
                ),
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
    final sizedUrl = MediaUrl.sized(url, width: MediaUrl.cardWidth);
    return Image.network(
      sizedUrl,
      width: double.infinity,
      height: double.infinity,
      fit: fit,
      filterQuality: FilterQuality.medium,
      // Home artwork is displayed in rails/cards, not full-screen. Keep
      // oversized Shopify originals from being decoded on the UI thread.
      cacheWidth: MediaUrl.cardWidth,
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
