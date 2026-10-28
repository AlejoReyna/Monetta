/// Monetta's shopper storefront. Desire first, then a way to buy.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart' show ListEquality;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/card_lift.dart';
import '../../app/catalog_store.dart';
import '../../app/home_content_controller.dart';
import '../../app/motion.dart';
import '../../app/shopper_copy.dart';
import '../../app/theme.dart';
import '../../data/media/media_url.dart';
import '../../domain/admin_control.dart';
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
import '../product/quick_view.dart';
import '../boutique/boutique_tokens.dart';
import '../navigation/monetta_floating_bottom_navigation.dart';
import '../navigation/monetta_side_menu.dart';
import '../partner/partner_hub_screen.dart';
import '../settings/settings_sheet.dart';
import '../welcome/welcome_gate.dart';
import 'customer_experiences_section.dart';
import 'customer_experiences_screen.dart';
import 'home_account_invitation.dart';
import 'home_boutique_sections.dart';

const int _kNewestCount = 8;

/// The redesign's opening rhythm: what is new, then how to shop it, then the
/// editorial tail. Applied only when the storefront still carries the bundled
/// default order — see `_resolveSectionOrder`.
const List<HomeSectionId> _kBoutiqueSectionOrder = <HomeSectionId>[
  HomeSectionId.newProducts,
  HomeSectionId.bagTypes,
  HomeSectionId.collections,
  HomeSectionId.todaysPicks,
  HomeSectionId.brands,
  HomeSectionId.about,
  HomeSectionId.social,
  HomeSectionId.testimonials,
];

Duration _homeSectionDelay(int index) =>
    Duration(milliseconds: (index * 70).clamp(0, 350));

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _scroll = ScrollController();
  // Keep scroll-driven state out of the (image-heavy) home body: only the
  // app bar and the search handover listen to it.
  final ValueNotifier<double> _collapse = ValueNotifier<double>(0);
  Timer? _featuredRefreshTimer;
  bool _foreground = true;
  bool _firstRunPrepared = false;
  late String _searchPrompt;

  @override
  void initState() {
    super.initState();
    _searchPrompt = nextSearchPrompt();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheRail();
      unawaited(FeaturedCatalogScope.maybeOf(context)?.refresh());
      _featuredRefreshTimer = Timer.periodic(
        const Duration(seconds: 60),
        (_) => unawaited(
          FeaturedCatalogScope.maybeOf(context)?.refreshIfStale(),
        ),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybePrepareFirstRunExperience();
  }

  /// Notification permission is asked for once, on the home, and deliberately
  /// **not** from the onboarding panel: a personalisation tap must never turn
  /// into a system prompt. It also waits for the first-visit welcome to close
  /// (`features/welcome/welcome_gate.dart`), so the OS dialog never lands on
  /// top of the brand's first screen.
  void _maybePrepareFirstRunExperience() {
    if (_firstRunPrepared || WelcomeScope.isVisible(context)) return;
    _firstRunPrepared = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(NotificationScope.maybeOf(context)?.requestSystemPermission());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _collapse.dispose();
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

  /// The search field with its scroll-driven handover to the app-bar icon.
  /// Shared by the hero overlay and the in-page fallback used when
  /// the owner hides the hero.
  Widget _buildSearchFieldTransition({bool inHero = false}) {
    return ValueListenableBuilder<double>(
      valueListenable: _collapse,
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
              key: const ValueKey('home-search-bar-transition'),
              opacity: visibility,
              child: child,
            ),
          ),
        );
      },
      child: HomeSearchField(
        onTap: _openSearch,
        prompt: _searchPrompt,
        padding: inHero
            ? EdgeInsets.zero
            : const EdgeInsets.fromLTRB(
                BoutiqueSpace.gutter,
                BoutiqueSpace.md,
                BoutiqueSpace.gutter,
                BoutiqueSpace.lg,
              ),
      ),
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
      products: store.products,
      facetsById: store.facetsById,
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

    if (feed.isEmpty) {
      return Scaffold(
        extendBody: true,
        backgroundColor: context.boutique.canvas,
        drawer: _buildSideMenu(store),
        drawerScrimColor: context.monettaColors.scrim,
        appBar: _buildAppBar(),
        body: Center(child: Text('Sin resultados', style: eyebrow())),
        bottomNavigationBar: MonettaFloatingBottomNavigation(
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
    final bottomNavigation = MonettaFloatingBottomNavigation(
      current: MonettaBottomDestination.home,
      bagCount: store.bagQuantity,
      onSelected: _handleBottomNavigation,
    );
    final sections = _resolveSectionOrder(homeContent, storefront);
    final body = LayoutBuilder(
      builder: (context, constraints) {
        return ListView(
          controller: _scroll,
          padding: EdgeInsets.zero,
          children: [
            Column(
              key: const ValueKey('home-discovery-header'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showHero)
                  HomeEditorialBanner(
                    searchField: _buildSearchFieldTransition(inHero: true),
                  )
                else
                  _buildSearchFieldTransition(),
              ],
            ),
            for (var index = 0; index < sections.length; index++)
              _buildHomeSection(
                sections[index],
                index: index,
                store: store,
                content: homeContent,
                editorial: editorial,
                fresh: fresh,
                featuredProducts: featured?.products ?? const [],
                reviewsStatus: reviewsStatus,
              ),
            Padding(
              padding: const EdgeInsets.only(top: BoutiqueSpace.xxl),
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
            Padding(
              padding: const EdgeInsets.only(top: BoutiqueSpace.xxl),
              child: HomeAccountInvitation(
                key: const ValueKey('home-reveal-account-invitation'),
                scrollController: _scroll,
                isSignedIn: AccountScope.maybeOf(context)?.isSignedIn ?? false,
                onRegister: _openAccount,
              ),
            ),
            // The home body extends beneath the persistent navigation. Keep
            // that trailing scroll clearance in the invitation's surface so
            // its background reaches the navigation divider instead of
            // revealing the scaffold's canvas. With `extendBody` the scaffold
            // reports the bar's full height, safe area included, to this body
            // as its bottom padding.
            ColoredBox(
              key: const ValueKey('home-account-invitation-bottom-bleed'),
              color: homeAccountInvitationBackground(context),
              child: SizedBox(height: MediaQuery.paddingOf(context).bottom),
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
        return Scaffold(
          extendBody: true,
          backgroundColor: context.boutique.canvas,
          drawer: drawer,
          drawerScrimColor: context.monettaColors.scrim,
          appBar: _buildAppBar(
            searchCollapse: showHero ? collapse : 1,
            dividerCollapse: showHero ? collapse : 1,
          ),
          body: child,
          bottomNavigationBar: bottomNavigation,
        );
      },
    );
  }

  /// The configured order wins whenever an owner has actually set one.
  ///
  /// `HomeContent.sectionOrder` arrives from Shopify; until someone edits it,
  /// every install carries the bundled default. The redesign needs a different
  /// opening rhythm — new arrivals and silhouettes before the editorial tail —
  /// so the bundled default (and only the bundled default) is remapped. A
  /// storefront that has published its own order is left exactly as configured.
  List<HomeSectionId> _resolveSectionOrder(
    HomeContent content,
    AdminStorefrontSettings storefront,
  ) {
    final configured = content.sectionOrder;
    final isBundledDefault = const ListEquality<HomeSectionId>().equals(
      configured,
      HomeContent.fallback.sectionOrder,
    );
    final order = isBundledDefault ? _kBoutiqueSectionOrder : configured;
    return <HomeSectionId>[
      for (final section in order)
        if (_isSectionEnabled(section, storefront)) section,
    ];
  }

  bool _isSectionEnabled(
    HomeSectionId section,
    AdminStorefrontSettings storefront,
  ) {
    return switch (section) {
      HomeSectionId.newProducts => storefront.showNewest,
      HomeSectionId.todaysPicks => storefront.showTodaysPicks,
      _ => true,
    };
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
    // 24–32px between modules instead of the old 64–72: the page reads as one
    // boutique rather than a stack of separate posters, and a shopper reaches
    // the next thing to buy without a screen of empty canvas in between.
    return Padding(
      padding: const EdgeInsets.only(top: BoutiqueSpace.xxl),
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
          HomeSectionId.newProducts => HomeNewArrivalsRail(
              products: fresh,
              onOpenAll: _openFullCatalog,
            ),
          HomeSectionId.bagTypes => HomeShopByStyle(
              cards: content.bagTypes,
              onOpen: (card) => _openHomeCollection(context, card),
              onSeeAll: () =>
                  _openCatalogSection(title: 'Bolsas', category: 'bolsa'),
            ),
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
    final accountState = AccountScope.maybeOf(context);
    final localAccount = accountState?.account;
    return MonettaSideMenu(
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
      isSignedIn: accountState?.isSignedIn ?? false,
      accountName: localAccount?.displayName,
      accountEmail: localAccount?.email,
      onAccount: _openAccount,
      onSettings: () => unawaited(openAppSettings(context)),
      onAbout: _openAbout,
      onPartner: _openPartner,
      onSupport: () => _openWhatsApp(conciergeWhatsAppUri()),
    );
  }

  /// Solid canvas header (white in light mode) so it runs straight into the
  /// light hero photograph; its hairline only appears once the hero scrolls.
  PreferredSizeWidget _buildAppBar({
    double searchCollapse = 1,
    double dividerCollapse = 1,
  }) {
    final palette = context.boutique;
    final searchProgress = Curves.easeOutCubic.transform(
      ((searchCollapse - .34) / .66).clamp(0.0, 1.0),
    );
    final dividerProgress = Curves.easeOutCubic.transform(
      ((dividerCollapse - .08) / .72).clamp(0.0, 1.0),
    );
    final brightness = Theme.of(context).brightness;
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 60,
      backgroundColor: palette.canvas,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      foregroundColor: palette.ink,
      iconTheme: IconThemeData(color: palette.ink, size: 22),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: brightness,
      ),
      centerTitle: true,
      titleSpacing: 0,
      leadingWidth: 56,
      leading: Builder(
        builder: (scaffoldContext) => Padding(
          padding: const EdgeInsets.all(9),
          child: IconButton(
            key: const Key('home-menu-button'),
            tooltip: 'Abrir menú',
            padding: EdgeInsets.zero,
            onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
            icon: const Icon(Icons.menu_rounded, size: 22),
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
              child: IconButton(
                key: const ValueKey('home-appbar-search-button'),
                tooltip: 'Buscar',
                onPressed: _openSearch,
                icon: const Icon(Icons.search, size: 22),
              ),
            ),
          ),
        ),
        const SizedBox(width: BoutiqueSpace.xs),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Divider(
          height: 0.5,
          color: palette.hairline.withValues(
            alpha: palette.hairline.a * dividerProgress,
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

  /// The card gives its text 10 of 21 flex parts of its height.
  static const double _offerCardHeightPerTextHeight = 21 / 10;

  /// Height of the offer card's text stack for a given size scaling: an 11pt
  /// eyebrow line, a 22pt title (two lines) and a 13pt description (two
  /// lines). Line heights match the styles in [_OfferCard].
  static double _offerTextHeight(double Function(double size) scale) =>
      scale(11) * 1.3 + scale(22) * 1.12 * 2 + scale(13) * 1.35 * 2;

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = (viewportWidth * .84).clamp(304.0, 420.0);
    // The card holds a fixed stack of text (eyebrow, two-line title, two-line
    // description) in the lower 10/21 of its height. Each size is scaled on its
    // own, so the rail grows by exactly what that text grows by, spread over
    // the whole card, and the text never overflows.
    final scaler = MediaQuery.textScalerOf(context);
    final growth = math.max<double>(
          0,
          _offerTextHeight(scaler.scale) - _offerTextHeight((size) => size),
        ) *
        _offerCardHeightPerTextHeight;
    return Column(
      key: const ValueKey('home-section-offers'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BoutiqueSectionHeader(
          kicker: 'Para comprar, estrenar o crecer',
          title: 'Lo mejor de Monetta, hoy',
        ),
        SizedBox(
          key: const ValueKey('home-offers-rail'),
          height: 430 + growth,
          child: ListView.separated(
            key: const PageStorageKey<String>('home-offers-scroll'),
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(
              horizontal: BoutiqueSpace.gutter,
            ),
            itemCount: _offers.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: BoutiqueSpace.md),
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
    final palette = context.boutique;
    return Semantics(
      button: true,
      label: '${data.eyebrow}. ${data.title}. ${data.description}. '
          '${data.actionLabel}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: MonettaCardLift(
          borderRadius: BoutiqueRadius.card,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BoutiqueRadius.card,
              border: Border.all(color: palette.hairline, width: 1),
            ),
            child: Column(
              children: [
                Expanded(
                  flex: 11,
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
                  flex: 10,
                  child: Padding(
                    key: const ValueKey('home-offer-content'),
                    padding: const EdgeInsets.fromLTRB(
                      BoutiqueSpace.lg,
                      BoutiqueSpace.lg,
                      BoutiqueSpace.lg,
                      BoutiqueSpace.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.eyebrow,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: boutiqueEyebrow(
                            size: 11,
                            color: palette.goldText,
                          ),
                        ),
                        const SizedBox(height: BoutiqueSpace.sm),
                        Text(
                          data.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: boutiqueDisplay(22, color: palette.ink),
                        ),
                        const SizedBox(height: BoutiqueSpace.sm),
                        Text(
                          data.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: boutiqueText(
                            size: 13,
                            color: palette.inkMuted,
                            height: 1.35,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          key: ValueKey(
                            'home-offer-action-${data.destination.name}',
                          ),
                          height: BoutiqueSpace.tapTarget,
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: BoutiqueSpace.lg,
                          ),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: palette.ink,
                            borderRadius: BoutiqueRadius.control,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  data.actionLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: boutiqueText(
                                    size: 13,
                                    color: palette.canvas,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: BoutiqueSpace.sm),
                              Icon(
                                Icons.arrow_forward,
                                size: 16,
                                color: palette.canvas,
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
        const BoutiqueSectionHeader(title: 'Colecciones'),
        SizedBox(
          height: cardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(
              horizontal: BoutiqueSpace.gutter,
            ),
            itemCount: cards.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: BoutiqueSpace.md),
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
          borderRadius: BoutiqueRadius.card,
          child: ClipRRect(
            borderRadius: BoutiqueRadius.card,
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
                          style: boutiqueDisplay(
                            24,
                            color: context.boutique.onDark,
                          ),
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

class _TodaysPicksSection extends StatelessWidget {
  const _TodaysPicksSection({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('home-section-todays-picks'),
      children: [
        const BoutiqueSectionHeader(
          kicker: 'Selección Monetta',
          title: 'Catálogo de hoy',
        ),
        _CatalogGrid(products: products.take(4).toList()),
      ],
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
        const BoutiqueSectionHeader(title: 'Marcas'),
        GridView.builder(
          clipBehavior: Clip.none,
          padding: const EdgeInsets.symmetric(
            horizontal: BoutiqueSpace.gutter,
          ),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.45,
            crossAxisSpacing: BoutiqueSpace.md,
            mainAxisSpacing: BoutiqueSpace.md,
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
                child: Material(
                  key: ValueKey('home-brand-${brand.handle}'),
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => openCollection(
                      context,
                      CollectionScreen(
                        title: brand.title,
                        filter: CollectionFilter(brand: brand.brand),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: BoutiqueSpace.md,
                        vertical: BoutiqueSpace.md,
                      ),
                      child: _HomeBrandLogo(brand: brand),
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

/// Bounds of the artwork inside the original 600px square logo assets.
/// Cropping at render time keeps the originals intact and gives each logo
/// the same usable width, rather than fitting its surrounding white space.
const _brandLogoBounds = <String, Rect>{
  'anne_klein': Rect.fromLTRB(68, 269, 546, 320),
  'coach': Rect.fromLTRB(127, 262, 480, 318),
  'dior': Rect.fromLTRB(153, 247, 460, 334),
  'guess': Rect.fromLTRB(127, 254, 486, 330),
  'laneige': Rect.fromLTRB(87, 260, 514, 331),
  'michael_kors': Rect.fromLTRB(75, 272, 532, 322),
  'olaplex': Rect.fromLTRB(88, 262, 525, 338),
  'rhode': Rect.fromLTRB(120, 233, 491, 336),
  'steve_madden': Rect.fromLTRB(84, 259, 533, 334),
  'summer_fridays': Rect.fromLTRB(97, 230, 508, 358),
  'the_ordinary': Rect.fromLTRB(144, 227, 484, 364),
  'tommy_hilfiger': Rect.fromLTRB(118, 232, 494, 352),
};

class _HomeBrandLogo extends StatelessWidget {
  const _HomeBrandLogo({required this.brand});

  final HomeBrandCard brand;

  @override
  Widget build(BuildContext context) {
    final asset = brand.fallbackAsset;
    final assetName = asset.split('/').last.split('.').first;
    final bounds = _brandLogoBounds[assetName];
    Widget fullBleed(double size) => Image.asset(
          asset,
          width: size,
          height: size,
          filterQuality: FilterQuality.high,
        );
    Widget cropped(Widget artwork600) {
      // La imagen es un cuadrado de 600px con el logo al centro: se recorta
      // el whitespace para que el trazo llene la celda sin cambiar su tamaño.
      if (bounds == null) {
        return FittedBox(fit: BoxFit.contain, child: artwork600);
      }
      return FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: bounds.width,
          height: bounds.height,
          child: ClipRect(
            child: Stack(
              children: [
                Positioned(
                  left: -bounds.left,
                  top: -bounds.top,
                  width: 600,
                  height: 600,
                  child: artwork600,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final fallback = cropped(fullBleed(600));
    final url = brand.imageUrl;
    if (url == null || url.isEmpty) return fallback;
    // La imagen de Shopify es el mismo cuadrado con whitespace: se recorta
    // igual que el asset para que el logo se vea del mismo tamaño.
    return cropped(
      Image.network(
        MediaUrl.sized(url, width: MediaUrl.cardWidth),
        width: 600,
        height: 600,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.high,
        cacheWidth: MediaUrl.cardWidth,
        errorBuilder: (_, __, ___) => fullBleed(600),
      ),
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
    final palette = context.boutique;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BoutiqueSectionHeader(title: 'Más sobre Monetta'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: BoutiqueSpace.gutter),
          child: SizedBox(
            key: const ValueKey('home-about-card'),
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 720;
                final portraitWidth = wide
                    ? constraints.maxWidth * .4
                    : constraints.maxWidth * .38;
                final image = SizedBox(
                  key: const ValueKey('home-about-image'),
                  width: portraitWidth,
                  height: portraitWidth * 1.3,
                  child: _HomeImage(
                    imageUrl: imageUrl,
                    fallbackAsset: 'assets/images/home_about.webp',
                    fit: BoxFit.cover,
                  ),
                );
                final heading = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NUESTRA HISTORIA',
                      style: boutiqueEyebrow(size: 10, color: palette.goldText),
                    ),
                    const SizedBox(height: BoutiqueSpace.md),
                    Text(
                      content.headline,
                      style:
                          boutiqueDisplay(wide ? 32 : 24, color: palette.ink),
                    ),
                  ],
                );
                final details = Column(
                  key: const ValueKey('home-about-monetta'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      content.body,
                      style: boutiqueText(
                        size: 14,
                        color: palette.inkMuted,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: BoutiqueSpace.xl),
                    FilledButton(
                      onPressed: onOpen,
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.action,
                        foregroundColor: palette.onAction,
                        shape: const StadiumBorder(),
                        minimumSize:
                            const Size.fromHeight(BoutiqueSpace.control),
                        padding: const EdgeInsets.symmetric(
                          horizontal: BoutiqueSpace.lg,
                          vertical: BoutiqueSpace.md,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Conoce nuestra historia',
                              style: boutiqueText(
                                size: 14,
                                weight: FontWeight.w600,
                                color: palette.canvas,
                              ),
                            ),
                          ),
                          const SizedBox(width: BoutiqueSpace.md),
                          const Icon(Icons.arrow_forward, size: 20),
                        ],
                      ),
                    ),
                    const SizedBox(height: BoutiqueSpace.sm),
                    TextButton(
                      key: const ValueKey('home-open-partner'),
                      onPressed: onOpenPartner,
                      style: TextButton.styleFrom(
                        foregroundColor: palette.ink,
                        minimumSize:
                            const Size.fromHeight(BoutiqueSpace.tapTarget),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Vende con Monetta',
                            style: boutiqueText(size: 13, color: palette.ink),
                          ),
                          const SizedBox(width: BoutiqueSpace.sm),
                          const Icon(Icons.north_east, size: 16),
                        ],
                      ),
                    ),
                  ],
                );
                if (!wide) {
                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          image,
                          const SizedBox(width: BoutiqueSpace.lg),
                          Expanded(child: heading),
                        ],
                      ),
                      const SizedBox(height: BoutiqueSpace.xl),
                      details,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    image,
                    const SizedBox(width: BoutiqueSpace.xxl),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          heading,
                          const SizedBox(height: BoutiqueSpace.xl),
                          details,
                        ],
                      ),
                    ),
                  ],
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
        const BoutiqueSectionHeader(title: 'Nuestras redes'),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BoutiqueSpace.gutter,
          ),
          child: Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < links.length; index++) ...[
                    if (index > 0) const SizedBox(width: BoutiqueSpace.md),
                    Expanded(
                      child: _SocialTile(link: links[index], onOpen: onOpen),
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

class _SocialTile extends StatelessWidget {
  const _SocialTile({required this.link, required this.onOpen});

  final HomeSocialLink link;
  final ValueChanged<Uri> onOpen;

  @override
  Widget build(BuildContext context) {
    final uri = link.uri;
    return Semantics(
      link: uri != null,
      label: 'Abrir ${link.label}',
      excludeSemantics: true,
      onTap: uri == null ? null : () => onOpen(uri),
      child: InkWell(
        key: ValueKey('home-social-${link.id}'),
        onTap: uri == null ? null : () => onOpen(uri),
        child: MonettaCardLift(
          enabled: uri != null,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 180;
              final imageSize = math.min(constraints.maxWidth, 240.0);
              final asset = _socialAsset(link.id);
              return Padding(
                padding: EdgeInsets.symmetric(
                  vertical: wide ? BoutiqueSpace.xl : BoutiqueSpace.sm,
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: imageSize,
                      height: imageSize * 420 / 440,
                      child: asset == null
                          ? Icon(
                              Icons.open_in_new,
                              color: context.monettaColors.accent,
                              size: 28,
                            )
                          : Image.asset(
                              asset,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              excludeFromSemantics: true,
                            ),
                    ),
                    SizedBox(
                      height: wide ? BoutiqueSpace.lg : BoutiqueSpace.sm,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          link.label.toUpperCase(),
                          maxLines: 1,
                          style: boutiqueEyebrow(
                            size: wide ? 12 : 10,
                            color: context.boutique.ink,
                            weight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String? _socialAsset(String id) => switch (id) {
        'instagram' => 'assets/images/home_social_instagram.webp',
        'tiktok' => 'assets/images/home_social_tiktok.webp',
        'facebook' => 'assets/images/home_social_facebook.webp',
        _ => null,
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
  Widget build(BuildContext context) => products.isEmpty
      ? const SizedBox.shrink()
      : ProductCardGrid(
          products: products,
          variant: ProductTileVariant.edgeToEdge,
          showWishlist: false,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          onQuickView: (product) => showProductQuickView(context, product),
        );
}
