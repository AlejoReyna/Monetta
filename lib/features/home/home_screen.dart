/// Monetta's shopper storefront. Desire first, then a way to buy.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/card_lift.dart';
import '../../app/catalog_store.dart';
import '../../app/home_content_controller.dart';
import '../../app/media/monetta_video.dart';
import '../../app/motion.dart';
import '../../app/mixed_feed.dart';
import '../../app/onboarding_controller.dart';
import '../../app/product_telemetry.dart';
import '../../app/shopper_copy.dart';
import '../../app/theme.dart';
import '../../app/theme_controller.dart';
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
import '../onboarding/onboarding_sheet.dart';
import '../partner/partner_hub_screen.dart';
import 'customer_experiences_section.dart';
import 'customer_experiences_screen.dart';
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
  Timer? _featuredRefreshTimer;
  double _heroHeight = double.infinity;
  bool _foreground = true;
  bool _onboardingRequested = false;
  late String _searchPrompt;

  @override
  void initState() {
    super.initState();
    _searchPrompt = nextSearchPrompt();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheRail();
      unawaited(_prepareFirstRunExperience());
      unawaited(FeaturedCatalogScope.maybeOf(context)?.refresh());
      _featuredRefreshTimer = Timer.periodic(
        const Duration(seconds: 60),
        (_) => unawaited(
          FeaturedCatalogScope.maybeOf(context)?.refreshIfStale(),
        ),
      );
    });
  }

  Future<void> _prepareFirstRunExperience() async {
    // The onboarding panel remains in the code for a future explicit entry
    // point, but it is intentionally not opened automatically on startup.
    await NotificationScope.maybeOf(context)?.requestSystemPermission();
  }

  // Retained so the onboarding experience and its persistence flow remain
  // available if the product decides to expose it explicitly later.
  // ignore: unused_element
  Future<void> _showFirstRunOnboarding() async {
    if (!mounted || _onboardingRequested) return;
    final onboarding = OnboardingScope.maybeOf(context);
    if (onboarding == null || !onboarding.shouldShow) return;
    _onboardingRequested = true;
    final store = StoreScope.of(context);
    final completed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => StoreScope(
        notifier: store,
        child: const OnboardingSheet(),
      ),
    );
    if (!mounted) return;
    if (completed == true) {
      await onboarding.complete();
      if (!mounted) return;
      logProductEvent(context, ProductEvent.onboardingCompleted);
    } else {
      await onboarding.skip();
      if (!mounted) return;
      logProductEvent(context, ProductEvent.onboardingSkipped);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _collapse.dispose();
    _heroPlaying.dispose();
    _featuredRefreshTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active == _foreground) return;
    setState(() {
      _foreground = active;
      if (active) _searchPrompt = nextSearchPrompt();
    });
    _syncHeroPlayback();
    if (active) {
      unawaited(FeaturedCatalogScope.maybeOf(context)?.refresh());
      // General catalog (single-flight inside CatalogStore.syncWithShopify).
      unawaited(StoreScope.maybeOf(context)?.syncWithShopify());
    }
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

  void _openSearch() {
    final prompt = _searchPrompt;
    unawaited(
      openSearch(context, prompt: prompt).whenComplete(() {
        if (!mounted) return;
        setState(() => _searchPrompt = nextSearchPrompt());
      }),
    );
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
    unawaited(
      openAccount(
        context,
        controller: account,
        canOpenAdmin: () => admin.canAccess(
          signedIn: account.isSignedIn,
          email: account.account?.email,
          authProvider: account.account?.authProvider,
        ),
        onOpenAdmin: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AdminScreen(
              controller: admin,
              notificationController: AdminNotificationScope.maybeOf(context),
              catalogStore: catalogStore,
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
    openCatalogBrowse(
      context,
      items: fullDeduplicatedCatalog(
        monettaItems: store.catalogItems,
        externalItems: const [],
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
    final editorial = _editorialContent;
    final homeScope = HomeContentScope.maybeOf(context);
    final homeContent = homeScope?.content ?? HomeContent.fallback;
    final featured = FeaturedCatalogScope.maybeOf(context);
    final reviewsStatus =
        homeScope?.reviewsStatus ?? HomeReviewsStatus.fallback;
    // HomeContent is the normal shopper source. The AdminScope fallback keeps
    // small preview/widget harnesses compatible without making production
    // rendering depend on an owner opening the admin panel.
    final storefront = homeScope == null
        ? AdminScope.maybeOf(context)?.storefront ?? homeContent.storefront
        : homeContent.storefront;
    final showHero = storefront.showHero;
    final showNewest = storefront.showNewest;
    final showTodaysPicks = storefront.showTodaysPicks;

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
                    onSearch: _openSearch,
                    searchPrompt: _searchPrompt,
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
                child: _HomeOffersSection(
                  onOpenCatalog: _openFullCatalog,
                  onOpenPartner: _openPartner,
                ),
              ),
            ),
            for (var index = 0;
                index < homeContent.sectionOrder.length;
                index++)
              if (homeContent.sectionOrder[index] !=
                      HomeSectionId.collections &&
                  (showNewest ||
                      homeContent.sectionOrder[index] !=
                          HomeSectionId.newProducts) &&
                  (showTodaysPicks ||
                      homeContent.sectionOrder[index] !=
                          HomeSectionId.todaysPicks))
                _buildHomeSection(
                  homeContent.sectionOrder[index],
                  index: index,
                  store: store,
                  content: homeContent,
                  editorial: editorial,
                  fresh: fresh,
                  featuredProducts: featured?.products ?? const [],
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
            // The home body extends beneath the persistent navigation. Keep
            // that trailing scroll clearance in the invitation's surface so
            // its background reaches the navigation divider instead of
            // revealing the scaffold's white canvas.
            ColoredBox(
              key: const ValueKey('home-account-invitation-bottom-bleed'),
              color: context.monettaColors.surfaceMuted,
              child: const SizedBox(height: 72),
            ),
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
    required List<Product> featuredProducts,
    required HomeReviewsStatus reviewsStatus,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 72),
      child: RevealOnScroll(
        key: ValueKey('home-reveal-${section.name}'),
        scrollController: _scroll,
        delay: _homeSectionDelay(index),
        // Keep layout-driven scrolling exact for buttons inside the section;
        // sections do not move vertically. Brands also skip the group fade so
        // their own horizontal entrance is the only card motion applied.
        offset: 0,
        fade: section != HomeSectionId.brands,
        child: switch (section) {
          HomeSectionId.collections => _HomeCollectionsSection(
              cards: content.collections,
            ),
          HomeSectionId.todaysPicks => _TodaysPicksSection(
              products: featuredProducts,
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
    return MonettaSideMenu(
      onSearch: _openSearch,
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
      onToggleTheme: _toggleTheme,
      onAbout: _openAbout,
      onPartner: _openPartner,
      onSupport: () => _openWhatsApp(conciergeWhatsAppUri()),
    );
  }

  void _toggleTheme() {
    final nextMode = Theme.of(context).brightness == Brightness.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    unawaited(ThemeScope.of(context).setMode(nextMode));
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
                  onPressed: _openSearch,
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
    required this.searchPrompt,
  });

  static const double estimatedHeight = 280;

  final ValueListenable<double> collapse;
  final bool playing;
  final VoidCallback onSearch;
  final String searchPrompt;

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
                      child: _HomeSearchBar(
                        onTap: onSearch,
                        prompt: searchPrompt,
                      ),
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
  const _HomeSearchBar({required this.onTap, required this.prompt});

  final VoidCallback onTap;
  final String prompt;

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
              Expanded(
                child: Text(
                  prompt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: sans(size: 12.5, color: colors.contentMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeOffersSection extends StatelessWidget {
  const _HomeOffersSection({
    required this.onOpenCatalog,
    required this.onOpenPartner,
  });

  static const _offers = <_OfferData>[
    _OfferData(
      imageAsset: 'assets/images/campaign_olive.jpg',
      eyebrow: 'OFERTA MONETTA',
      title: '20% en bolsos seleccionados',
      description: 'Una selección especial para encontrar tu próxima pieza.',
      actionLabel: 'Ver la selección',
      destination: _OfferDestination.catalog,
    ),
    _OfferData(
      imageAsset: 'assets/images/campaign_coral.jpg',
      eyebrow: 'NUEVO EN MONETTA',
      title: 'Piezas que acaban de llegar',
      description: 'Color, formas y favoritos para estrenar esta temporada.',
      actionLabel: 'Descubrir novedades',
      destination: _OfferDestination.catalog,
    ),
    _OfferData(
      imageAsset: 'assets/images/campaign_terracotta.jpg',
      eyebrow: 'VENDE CON MONETTA',
      title: 'Haz crecer tu negocio con mayoreo',
      description:
          'Precios desde tres modelos y catálogos listos para compartir.',
      actionLabel: 'Conocer mayoreo',
      destination: _OfferDestination.partner,
    ),
  ];

  final VoidCallback onOpenCatalog;
  final VoidCallback onOpenPartner;

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PARA COMPRAR, ESTRENAR O CRECER',
                      style: eyebrow(
                        size: 8.5,
                        color: context.monettaColors.accentContent,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text('Lo mejor de Monetta, hoy', style: editorial(25)),
                  ],
                ),
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
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: _offers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => SizedBox(
              width: cardWidth,
              child: _OfferCard(
                key: ValueKey('home-offer-card-$index'),
                data: _offers[index],
                onTap: _offers[index].destination == _OfferDestination.partner
                    ? onOpenPartner
                    : onOpenCatalog,
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
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.destination,
  });

  final String imageAsset;
  final String eyebrow;
  final String title;
  final String description;
  final String actionLabel;
  final _OfferDestination destination;
}

enum _OfferDestination { catalog, partner }

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.data, required this.onTap, super.key});

  final _OfferData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.monettaColors;
    return Semantics(
      button: true,
      label: '${data.eyebrow}. ${data.title}. ${data.description}. '
          '${data.actionLabel}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: MonettaCardLift(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceRaised,
              border: Border.all(color: colors.divider, width: .8),
            ),
            child: Column(
              children: [
                Expanded(
                  child: SizedBox.expand(
                    key: const ValueKey('home-offer-media'),
                    child: Image.asset(
                      data.imageAsset,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    key: const ValueKey('home-offer-content'),
                    padding: const EdgeInsets.fromLTRB(22, 21, 22, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.eyebrow,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: eyebrow(
                            size: 8.5,
                            color: colors.accentContent,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          data.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: editorial(
                            22,
                            color: colors.contentPrimary,
                            height: 1.08,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: sans(
                            size: 11.5,
                            color: colors.contentMuted,
                            height: 1.35,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          key: ValueKey(
                            'home-offer-action-${data.destination.name}',
                          ),
                          height: 44,
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          alignment: Alignment.center,
                          color: colors.inverseSurface,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  data.actionLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: sans(
                                    size: 12,
                                    color: colors.onInverseSurface,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 9),
                              Icon(
                                Icons.arrow_forward,
                                size: 15,
                                color: colors.onInverseSurface,
                              ),
                            ],
                          ),
                        ),
                      ],
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
        const SectionHeading(
          kicker: 'DESCUBRE',
          title: 'Colecciones',
          animateKickerColor: true,
        ),
        SizedBox(
          height: cardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
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
        child: MonettaCardLift(
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
          animateKickerColor: true,
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

class _TodaysPicksSection extends StatelessWidget {
  const _TodaysPicksSection({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('home-section-todays-picks'),
      children: [
        const SectionHeading(
          kicker: 'SELECCIÓN MONETTA',
          title: 'Catálogo de hoy',
          animateKickerColor: true,
        ),
        _CatalogGrid(products: products.take(4).toList()),
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
        const SectionHeading(
          kicker: 'ELIGE TU FORMA',
          title: 'Tipo de bolsas',
          animateKickerColor: true,
        ),
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
        child: MonettaCardLift(
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
      ),
    );
  }
}

class _BrandsSection extends StatefulWidget {
  const _BrandsSection({required this.brands});

  final List<HomeBrandCard> brands;

  @override
  State<_BrandsSection> createState() => _BrandsSectionState();
}

Duration _brandEntranceDuration(int brandCount) {
  final lastRow = brandCount <= 1 ? 0 : (brandCount - 1) ~/ 2;
  return kEnter + Duration(milliseconds: lastRow * 70);
}

class _BrandsSectionState extends State<_BrandsSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _brandEntranceDuration(widget.brands.length),
  );
  ScrollPosition? _scrollPosition;
  bool _checkScheduled = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextPosition = Scrollable.maybeOf(context)?.position;
    if (nextPosition != _scrollPosition) {
      _scrollPosition?.removeListener(_scheduleVisibilityCheck);
      _scrollPosition = nextPosition;
      _scrollPosition?.addListener(_scheduleVisibilityCheck);
    }
    if (reduceMotion(context)) {
      _started = true;
      _controller.value = 1;
    } else {
      _scheduleVisibilityCheck();
    }
  }

  @override
  void didUpdateWidget(covariant _BrandsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_started && oldWidget.brands.length != widget.brands.length) {
      _controller.duration = _brandEntranceDuration(widget.brands.length);
    }
  }

  void _scheduleVisibilityCheck() {
    if (_started || _checkScheduled || !mounted) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (!mounted || _started) return;
      final renderObject = context.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) return;
      final top = renderObject.localToGlobal(Offset.zero).dy;
      final bottom = top + renderObject.size.height;
      final viewportHeight = MediaQuery.sizeOf(context).height;
      if (bottom <= 0 || top >= viewportHeight) return;
      _started = true;
      _controller.forward();
    });
  }

  Animation<Offset> _entranceFor(int index) {
    final totalMilliseconds = _controller.duration!.inMilliseconds;
    final startMilliseconds = (index ~/ 2) * 70;
    final endMilliseconds = startMilliseconds + kEnter.inMilliseconds;
    final begin = (startMilliseconds / totalMilliseconds).clamp(0.0, 1.0);
    final end = (endMilliseconds / totalMilliseconds).clamp(begin, 1.0);
    final direction = index.isEven ? -1.2 : 1.2;
    return Tween<Offset>(
      begin: Offset(direction, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(begin, end, curve: kMotionCurve),
      ),
    );
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_scheduleVisibilityCheck);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.brands.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('home-section-brands'),
      children: [
        const SectionHeading(
          kicker: 'NUESTRA SELECCIÓN',
          title: 'Todas las marcas',
          animateKickerColor: true,
        ),
        GridView.builder(
          clipBehavior: Clip.none,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.45,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: widget.brands.length,
          itemBuilder: (context, index) {
            final brand = widget.brands[index];
            return SlideTransition(
              key: ValueKey('home-brand-entrance-${brand.handle}'),
              position: _entranceFor(index),
              child: Semantics(
                button: true,
                label: 'Ver ${brand.title}',
                child: MonettaCardLift(
                  borderRadius: BorderRadius.circular(28),
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
          animateKickerColor: true,
        ),
        MonettaCardLift(
          mouseCursor: MouseCursor.defer,
          child: Container(
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
        const SectionHeading(
          kicker: 'SÍGUENOS',
          title: 'Nuestras redes',
          animateKickerColor: true,
        ),
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
        child: MonettaCardLift(
          enabled: uri != null,
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
          clipBehavior: Clip.none,
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
