/// Monetta's shopper storefront. Desire first, then a way to buy.
library;

import '../navigation/adaptive_storefront_scaffold.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart' show ListEquality;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/card_lift.dart';
import '../../app/catalog_store.dart';
import '../../app/home_content_controller.dart';
import '../../app/motion.dart';
import '../boutique/client_guide_sections.dart';
import '../boutique/guide_art.dart';
import '../boutique/guide_brand_tile.dart';
import '../wholesale/wholesale_screen.dart';
import '../contact/contact_screen.dart';
import '../../app/mixed_feed.dart';
import '../../app/monetta_tokens.g.dart';
import '../../app/shopper_copy.dart';
import '../../app/theme.dart';
import '../../app/theme_controller.dart';
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
import '../catalog/categories_screen.dart';
import '../catalog/collection_screen.dart';
import '../catalog/product_card.dart';
import '../catalog/search_screen.dart';
import '../checkout/checkout_screen.dart';
import '../boutique/boutique_tokens.dart';
import '../notifications/notifications_screen.dart';
import '../navigation/monetta_bottom_navigation.dart';
import '../navigation/monetta_side_menu.dart';
import '../partner/partner_hub_screen.dart';
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
  HomeSectionId.bagTypes,
  HomeSectionId.collections,
  HomeSectionId.brands,
  HomeSectionId.newProducts,
  HomeSectionId.social,
  HomeSectionId.testimonials,
];

const Set<HomeSectionId> _kGuideOpeningSections = <HomeSectionId>{
  HomeSectionId.bagTypes,
  HomeSectionId.collections,
  HomeSectionId.brands,
  HomeSectionId.newProducts,
};

Duration _homeSectionDelay(int index) =>
    Duration(milliseconds: (index * 70).clamp(0, 350));

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _scroll = ScrollController();
  final ValueNotifier<bool> _heroPlaying = ValueNotifier<bool>(true);
  Timer? _featuredRefreshTimer;
  double _heroHeight = double.infinity;
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
        (_) =>
            unawaited(FeaturedCatalogScope.maybeOf(context)?.refreshIfStale()),
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
        builder: (_) => PartnerHubScreen(content: _editorialContent.partner),
      ),
    );
  }

  void _openWholesale() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const WholesaleScreen()));
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
        filter: CollectionFilter(category: category, queryTerms: queryTerms),
      ),
    );
  }

  /// A «Compra por estilo» entry opens its silhouette (or the perfumes
  /// category) through the same collection route as the other home links.
  void _openStyle(HomeStyleEntry entry) {
    openCollection(
      context,
      CollectionScreen(
        title: entry.collectionTitle,
        filter: CollectionFilter(
          category: entry.category,
          silhouette: entry.silhouette,
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
        unawaited(openCategories(context));
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
      return AdaptiveStorefrontScaffold(
        avoidReservedRegions: true,
        extendBody: true,
        backgroundColor: context.boutique.canvas,
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
    final sections = _resolveSectionOrder(homeContent, storefront);
    final bundled = const ListEquality<HomeSectionId>().equals(
      homeContent.sectionOrder,
      HomeContent.fallback.sectionOrder,
    );
    final opening = bundled
        ? <HomeSectionId>[
            for (final section in sections)
              if (_kGuideOpeningSections.contains(section)) section,
          ]
        : sections;
    final tail = bundled
        ? <HomeSectionId>[
            for (final section in sections)
              if (!_kGuideOpeningSections.contains(section)) section,
          ]
        : const <HomeSectionId>[];
    final body = LayoutBuilder(
      builder: (context, constraints) {
        _heroHeight = homeBannerHeight(context);
        return ListView(
          controller: _scroll,
          padding: EdgeInsets.zero,
          children: [
            Column(
              key: const ValueKey('home-discovery-header'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showHero)
                  ValueListenableBuilder<bool>(
                    valueListenable: _heroPlaying,
                    builder: (context, playing, _) => HomeEditorialBanner(
                      playing: playing,
                      onOpenNew: _openFullCatalog,
                      onOpenCatalog: _openFullCatalog,
                      onOpenPerfumes: () => _openCatalogSection(
                        title: 'Perfumes',
                        category: 'perfume',
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 1),
              ],
            ),
            for (var index = 0; index < opening.length; index++)
              _buildHomeSection(
                opening[index],
                index: index,
                store: store,
                content: homeContent,
                editorial: editorial,
                fresh: fresh,
                featuredProducts: featured?.products ?? const [],
                reviewsStatus: reviewsStatus,
              ),
            if (bundled) ...[
              if (fresh.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: BoutiqueSpace.xxl),
                  child: HomeNewArrivalsRail(
                    products: fresh,
                    title: 'Lo más buscado',
                    sectionKey: const ValueKey('home-section-most-wanted'),
                    railKey: const ValueKey('home-most-wanted-rail'),
                    onOpenAll: _openFullCatalog,
                  ),
                ),
            ],
            Padding(
              padding: const EdgeInsets.only(top: BoutiqueSpace.xxl),
              child: RevealOnScroll(
                key: const ValueKey('home-reveal-offers'),
                scrollController: _scroll,
                offset: 0,
                child: _HomeOffersSection(onOpenPartner: _openWholesale),
              ),
            ),
            const ClientGuideServices(),
            Padding(
              padding: const EdgeInsets.only(top: BoutiqueSpace.xxl),
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
            ClientGuideFooter(
              onContact: () => unawaited(
                openContact(context, socialLinks: homeContent.socialLinks),
              ),
              onAbout: _openAbout,
            ),
            for (var index = 0; index < tail.length; index++)
              _buildHomeSection(
                tail[index],
                index: opening.length + index,
                store: store,
                content: homeContent,
                editorial: editorial,
                fresh: fresh,
                featuredProducts: featured?.products ?? const [],
                reviewsStatus: reviewsStatus,
              ),
            // The home body extends beneath the persistent navigation. Keep
            // that trailing scroll clearance in the invitation's surface so
            // its background reaches the navigation divider instead of
            // revealing the scaffold's canvas. With `extendBody` the scaffold
            // reports the bar's full height, safe area included, to this body
            // as its bottom padding.
            ColoredBox(
              key: const ValueKey('home-account-invitation-bottom-bleed'),
              color: context.monettaColors.surfaceMuted,
              child: SizedBox(height: MediaQuery.paddingOf(context).bottom),
            ),
          ],
        );
      },
    );

    return AdaptiveStorefrontScaffold(
      avoidReservedRegions: true,
      extendBody: true,
      backgroundColor: context.boutique.canvas,
      drawer: drawer,
      drawerScrimColor: context.monettaColors.scrim,
      appBar: _buildAppBar(),
      body: body,
      bottomNavigationBar: bottomNavigation,
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
        // «Más sobre Monetta» no longer lives on Inicio (the theme dropped
        // it); the story stays reachable from the footer's «Nuestra historia».
        if (section != HomeSectionId.about &&
            _isSectionEnabled(section, storefront))
          section,
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
              asGrid: true,
            ),
          HomeSectionId.bagTypes => HomeShopByStyle(
              onOpen: _openStyle,
              onSeeAll: () =>
                  _openCatalogSection(title: 'Bolsas', category: 'bolsa'),
            ),
          HomeSectionId.brands => _BrandsSection(
              brands: guideBrandsFor(content.brands),
              onSeeAll: () => unawaited(openCategories(context)),
            ),
          // Filtered out by `_resolveSectionOrder`; never built on Inicio.
          HomeSectionId.about => const SizedBox.shrink(),
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
    final account = AccountScope.maybeOf(context)?.account;
    final display = account?.displayName?.trim();
    final email = account?.email?.trim();
    final name = (display != null && display.isNotEmpty) ? display : email;
    final content = HomeContentScope.maybeOf(context)?.content;
    return MonettaSideMenu(
      onSearch: _openSearch,
      onCatalog: _openFullCatalog,
      onCategories: () => unawaited(openCategories(context)),
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
      onPartner: _openWholesale,
      onSupport: () =>
          unawaited(openContact(context, socialLinks: content?.socialLinks)),
      identityName: name,
      identityDetail:
          email != null && email.isNotEmpty && email != name ? email : null,
      onNotifications: () {
        unawaited(
          openNotifications(
            context,
            inbox: sharedAccountNotificationInbox,
            ownerId: account?.localAccountId ?? '',
            accountController: AccountScope.maybeOf(context),
          ),
        );
      },
      onShare: () {
        unawaited(Share.share('Únete al mundo de Monetta'));
      },
      onWhatsApp: () => _openExternal(conciergeWhatsAppUri()),
      socialLinks: content?.socialLinks ?? HomeContent.fallback.socialLinks,
      onOpenSocial: _openExternal,
    );
  }

  void _toggleTheme() {
    final nextMode = Theme.of(context).brightness == Brightness.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    unawaited(ThemeScope.of(context).setMode(nextMode));
  }

  /// Compact header: menu, wordmark, and the search icon. The guide has no
  /// in-page search field above the hero.
  PreferredSizeWidget _buildAppBar() {
    final palette = context.boutique;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 60,
      backgroundColor: palette.bar,
      surfaceTintColor: Colors.transparent,
      foregroundColor: palette.ink,
      iconTheme: IconThemeData(color: palette.ink, size: 22),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      ),
      centerTitle: true,
      titleSpacing: 0,
      leadingWidth: 56,
      leading: Builder(
        builder: (scaffoldContext) => IconButton(
          key: const Key('home-menu-button'),
          tooltip: 'Abrir menú',
          onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
          icon: const Icon(Icons.menu_rounded, size: 22),
        ),
      ),
      title: const MonettaWordmark.appBar(),
      actions: [
        IconButton(
          key: const ValueKey('home-appbar-search-button'),
          tooltip: 'Buscar',
          onPressed: _openSearch,
          icon: const Icon(Icons.search, size: 22),
        ),
        const SizedBox(width: BoutiqueSpace.xs),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Divider(height: 0.5, color: palette.hairline),
      ),
    );
  }
}

class _HomeOffersSection extends StatelessWidget {
  const _HomeOffersSection({required this.onOpenPartner});
  final VoidCallback onOpenPartner;

  @override
  Widget build(BuildContext context) => ClientGuideEditorial(
        key: const ValueKey('home-section-offers'),
        title: 'PRECIOS DE',
        titleAccent: 'mayoreo',
        subtitle: 'A partir de 3 piezas',
        imageAsset: kGuideHomeWholesale,
        overlaySide: GuideTextSide.right,
        action: GuidePillButton(
          key: const ValueKey('home-wholesale-button'),
          label: 'CONOCE MÁS',
          onPressed: onOpenPartner,
        ),
      );
}

/// «Colecciones», between «Compra por estilo» and «Tus marcas favoritas»: the
/// three photo cards of monetta.mx's home (`.guia-collections__track`).
///
/// On a phone it is a snap scroller whose cards are `min(56% of the viewport,
/// 270)` wide, 12 apart, with side room so the first and the last can sit
/// centred. It always opens on the FIRST card; the centred card is drawn full
/// size and the others at 0.9 (web `guia-collection-focus`). From 768 px the
/// cards sit in a row. On first appearance the cards rise 24 px and fade in
/// one after the other, once, unless animations are disabled.
class _HomeCollectionsSection extends StatefulWidget {
  const _HomeCollectionsSection({required this.cards});

  final List<HomeCollectionCard> cards;

  @override
  State<_HomeCollectionsSection> createState() =>
      _HomeCollectionsSectionState();
}

/// Phone card width: `min(56vw, 270px)`.
const double _kCollectionCardMaxWidth = 270;
const double _kCollectionCardShare = .56;

/// Space between cards (`--space-3`).
const double _kCollectionGap = 12;

/// Wide layout (web `@media (min-width: 768px)`): gap `--space-5`, at most 960
/// wide, each card 30% of what is left after the gaps.
const double _kCollectionWideGap = 24;
const double _kCollectionWideMaxWidth = 960;
const double _kCollectionWideShare = .3;

/// Height over width of the collection photographs (800 x 930).
const double _kCollectionPhotoRatio = 930 / 800;

/// Reveal (web `monetta-guia.js` `initCollectionsReveal`): each card rises 24
/// px and fades in over 420 ms, 120 ms after the previous one.
const double _kCollectionRiseOffset = 24;
const Duration _kCollectionRevealDuration = Duration(milliseconds: 420);
const Duration _kCollectionRevealStagger = Duration(milliseconds: 120);
const Cubic _kCollectionRevealCurve = Cubic(0.22, 1, 0.36, 1);

/// Card typography (web `.guia-collection-card__title` / `__button`).
const double _kCollectionTitleSize = 28;
const double _kCollectionTitleLineHeight = 1.1;
const double _kCollectionPillTextSize = 12;
const double _kCollectionPillLineHeight = 1.2;
const double _kCollectionPillMinHeight = 40;

/// Whether the section's motion (reveal, focus scale) is off: the web's
/// `prefers-reduced-motion`. Read from the media query rather than from the
/// app's `reduceMotion`, which is always true under `flutter_test`.
bool _collectionsMotionOff(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ||
    MediaQuery.accessibleNavigationOf(context);

/// Room for the font's own rounding of the title's line box.
const double _kCollectionHeightSlack = 2;

/// Natural height of a collection card of [width]: photo, 12, title, 12, pill,
/// 24 — grown with the shopper's text scale.
double _collectionCardHeight(BuildContext context, double width) {
  final scaler = MediaQuery.textScalerOf(context);
  final title =
      scaler.scale(_kCollectionTitleSize) * _kCollectionTitleLineHeight;
  final pill = math.max(
    _kCollectionPillMinHeight,
    scaler.scale(_kCollectionPillTextSize) * _kCollectionPillLineHeight,
  );
  return width * _kCollectionPhotoRatio +
      _kCollectionGap +
      title +
      _kCollectionGap +
      pill +
      BoutiqueSpace.xl +
      _kCollectionHeightSlack;
}

class _HomeCollectionsSectionState extends State<_HomeCollectionsSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: _revealDuration(widget.cards.length),
  );
  PageController? _controller;
  double? _fraction;
  ScrollPosition? _scrollPosition;
  bool _checkScheduled = false;
  bool _started = false;

  static Duration _revealDuration(int count) =>
      _kCollectionRevealDuration +
      _kCollectionRevealStagger * (count <= 1 ? 0 : count - 1);

  /// The page controller for a viewport fraction. Rebuilt when the fraction
  /// changes (rotation, window resize) on the card the shopper was looking at;
  /// a fresh one starts on the first card.
  PageController _controllerFor(double fraction) {
    final current = _controller;
    if (current != null && _fraction == fraction) return current;
    final page =
        current != null && current.hasClients ? (current.page ?? 0).round() : 0;
    current?.dispose();
    _fraction = fraction;
    return _controller =
        PageController(viewportFraction: fraction, initialPage: page);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Scrollable.maybeOf(context)?.position;
    if (next != _scrollPosition) {
      _scrollPosition?.removeListener(_scheduleVisibilityCheck);
      _scrollPosition = next;
      _scrollPosition?.addListener(_scheduleVisibilityCheck);
    }
    if (_collectionsMotionOff(context)) {
      // Nothing to wait for: the cards are simply there.
      _started = true;
      _reveal.value = 1;
    } else {
      _scheduleVisibilityCheck();
    }
  }

  @override
  void didUpdateWidget(covariant _HomeCollectionsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_started && oldWidget.cards.length != widget.cards.length) {
      _reveal.duration = _revealDuration(widget.cards.length);
    }
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_scheduleVisibilityCheck);
    _reveal.dispose();
    _controller?.dispose();
    super.dispose();
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
      if (bottom <= 0 || top >= MediaQuery.sizeOf(context).height) return;
      _started = true;
      unawaited(_reveal.forward());
    });
  }

  /// Progress of card [index]: 0 until its turn, then eased to 1.
  Animation<double> _progress(int index) {
    final total = _reveal.duration!.inMilliseconds;
    final start = _kCollectionRevealStagger.inMilliseconds * index;
    final end = start + _kCollectionRevealDuration.inMilliseconds;
    return _reveal.drive(
      CurveTween(
        curve: Interval(
          (start / total).clamp(0.0, 1.0),
          (end / total).clamp(0.0, 1.0),
          curve: _kCollectionRevealCurve,
        ),
      ),
    );
  }

  Widget _revealed(int index, Widget child) {
    final progress = _progress(index);
    return AnimatedBuilder(
      animation: progress,
      child: child,
      builder: (context, child) => Opacity(
        opacity: progress.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, _kCollectionRiseOffset * (1 - progress.value)),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.cards;
    if (cards.isEmpty) return const SizedBox.shrink();
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final header = const BoutiqueSectionHeader(title: 'Colecciones');
    if (viewportWidth >= kHomeWideBreakpoint) {
      final container = math.min(viewportWidth, _kCollectionWideMaxWidth) -
          BoutiqueSpace.gutter * 2;
      final cardWidth =
          (container - _kCollectionWideGap * 2) * _kCollectionWideShare;
      return Column(
        key: const ValueKey('home-section-collections'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          Center(
            child: Wrap(
              key: const ValueKey('home-collections-row'),
              alignment: WrapAlignment.center,
              spacing: _kCollectionWideGap,
              runSpacing: _kCollectionWideGap,
              children: [
                for (var i = 0; i < cards.length; i++)
                  _revealed(
                    i,
                    SizedBox(
                      width: cardWidth,
                      child: _CollectionPhotoCard(card: cards[i]),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    final cardWidth = math.min(
      viewportWidth * _kCollectionCardShare,
      _kCollectionCardMaxWidth,
    );
    final controller = _controllerFor(
      ((cardWidth + _kCollectionGap) / viewportWidth).clamp(.1, 1.0),
    );
    final motionOff = _collectionsMotionOff(context);
    return Column(
      key: const ValueKey('home-section-collections'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        SizedBox(
          height: _collectionCardHeight(context, cardWidth),
          child: PageView.builder(
            key: const ValueKey('home-collections-track'),
            controller: controller,
            // The cards' shadow reaches past the track.
            clipBehavior: Clip.none,
            padEnds: true,
            itemCount: cards.length,
            itemBuilder: (context, index) => _revealed(
              index,
              AnimatedBuilder(
                animation: controller,
                builder: (context, child) {
                  final page = controller.hasClients &&
                          controller.position.haveDimensions
                      ? controller.page ?? controller.initialPage.toDouble()
                      : controller.initialPage.toDouble();
                  final distance = (page - index).abs().clamp(0.0, 1.0);
                  return Transform.scale(
                    scale: motionOff ? 1 : 1 - .1 * distance,
                    child: child,
                  );
                },
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: cardWidth,
                    child: _CollectionPhotoCard(card: cards[index]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Web `.guia-collection-card`: white card, photo, serif title and the
/// «VER COLECCIÓN» pill. The whole card is the tap target.
class _CollectionPhotoCard extends StatelessWidget {
  const _CollectionPhotoCard({required this.card});

  final HomeCollectionCard card;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Semantics(
      button: true,
      label: 'Ver colección ${card.title}',
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('home-collection-card-${card.handle}'),
        onTap: () => _openHomeCollection(context, card),
        child: MonettaCardLift(
          borderRadius: BoutiqueRadius.card,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.monettaColors.surfaceRaised,
              borderRadius: BoutiqueRadius.card,
              // --shadow-card: 0 4px 14px rgba(61, 43, 28, 0.059)
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F3D2B1C),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BoutiqueRadius.card,
              child: Padding(
                padding: const EdgeInsets.only(bottom: BoutiqueSpace.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AspectRatio(
                      aspectRatio: 1 / _kCollectionPhotoRatio,
                      child: _HomeImage(
                        imageUrl: card.imageUrl,
                        fallbackAsset: card.fallbackAsset,
                      ),
                    ),
                    const SizedBox(height: _kCollectionGap),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: BoutiqueSpace.md,
                      ),
                      child: Text(
                        card.title,
                        key: ValueKey('home-collection-title-${card.handle}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: guideSerifStyle(
                          context,
                          size: _kCollectionTitleSize,
                          height: _kCollectionTitleLineHeight,
                          color: palette.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: _kCollectionGap),
                    Container(
                      key: ValueKey('home-collection-pill-${card.handle}'),
                      constraints: const BoxConstraints(
                        minHeight: _kCollectionPillMinHeight,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: BoutiqueSpace.xl,
                      ),
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFFECECEC),
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                      // At large text scales the label shrinks rather than
                      // wrapping or overflowing the card.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'VER COLECCIÓN',
                          maxLines: 1,
                          style: boutiqueText(
                            size: _kCollectionPillTextSize,
                            weight: FontWeight.w600,
                            height: _kCollectionPillLineHeight,
                            // The pill is a light grey on both themes: dark
                            // ink, whatever the palette.
                            color: MonettaTokens.ink,
                          ).copyWith(
                            letterSpacing: _kCollectionPillTextSize * .12,
                          ),
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
          title: 'Lo más buscado',
        ),
        _CatalogGrid(products: products.take(4).toList()),
      ],
    );
  }
}

class _BrandsSection extends StatefulWidget {
  const _BrandsSection({required this.brands, this.onSeeAll});

  final List<HomeBrandCard> brands;
  final VoidCallback? onSeeAll;

  @override
  State<_BrandsSection> createState() => _BrandsSectionState();
}

/// The guide's own brands, first in the grid and in this order.
const List<String> _kGuideBrandOrder = <String>[
  'coach',
  'guess',
  'michael_kors',
  'steve_madden',
  'tommy_hilfiger',
];

String _brandSlug(String brand) =>
    brand.trim().toLowerCase().replaceAll(RegExp(r'[\s\-]+'), '_');

/// The brands the grid shows: every configured brand (they all come with
/// bundled artwork), the guide's own five first. A brand the catalog does not
/// carry yet still has its tile; it opens its (empty) listing.
@visibleForTesting
List<HomeBrandCard> guideBrandsFor(List<HomeBrandCard> configured) {
  int rank(HomeBrandCard brand) {
    final index = _kGuideBrandOrder.indexOf(_brandSlug(brand.brand));
    return index < 0 ? _kGuideBrandOrder.length : index;
  }

  final ordered = [...configured];
  // List.sort is not stable: tie-break on the configured position.
  final position = <HomeBrandCard, int>{
    for (var i = 0; i < ordered.length; i++) ordered[i]: i,
  };
  ordered.sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    return byRank != 0 ? byRank : position[a]!.compareTo(position[b]!);
  });
  return ordered;
}

Duration _brandEntranceDuration(int brandCount) {
  final lastRow = brandCount <= 1 ? 0 : (brandCount - 1) ~/ 4;
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
    final startMilliseconds = (index ~/ 4) * 70;
    final endMilliseconds = startMilliseconds + kEnter.inMilliseconds;
    final begin = (startMilliseconds / totalMilliseconds).clamp(0.0, 1.0);
    final end = (endMilliseconds / totalMilliseconds).clamp(begin, 1.0);
    final direction = index.isEven ? -1.2 : 1.2;
    return Tween<Offset>(begin: Offset(direction, 0), end: Offset.zero).animate(
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
        BoutiqueSectionHeader(
          title: 'Tus marcas favoritas',
          actionLabel: widget.onSeeAll == null ? null : 'Ver todas',
          onAction: widget.onSeeAll,
        ),
        GridView.builder(
          clipBehavior: Clip.none,
          padding: const EdgeInsets.symmetric(horizontal: BoutiqueSpace.gutter),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          // Four tiles across, as in the guide. Official wordmarks sit in the
          // vertical middle of a square file: a wide cell plus fitWidth shows
          // that band edge to edge instead of a speck inside an empty square.
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 1.7,
            crossAxisSpacing: BoutiqueSpace.sm,
            mainAxisSpacing: BoutiqueSpace.sm,
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
                  borderRadius: BoutiqueRadius.tile,
                  // The shared guide tile: the wordmark large on a tinted
                  // rectangle, no hairline and no drop shadow.
                  child: GuideBrandTile(
                    key: ValueKey('home-brand-${brand.handle}'),
                    asset: brand.fallbackAsset,
                    imageUrl: brand.imageUrl,
                    label: brand.title,
                    aspectRatio: 1.7,
                    onTap: () => openCollection(
                      context,
                      CollectionScreen(
                        title: brand.title,
                        filter: CollectionFilter(brand: brand.brand),
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
          padding: const EdgeInsets.symmetric(horizontal: BoutiqueSpace.gutter),
          child: Row(
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
  });

  final String? imageUrl;
  final String fallbackAsset;

  @override
  Widget build(BuildContext context) {
    final fallback = Image.asset(
      fallbackAsset,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
    );
    final url = imageUrl;
    if (url == null || url.isEmpty) return fallback;
    final sizedUrl = MediaUrl.sized(url, width: MediaUrl.cardWidth);
    return Image.network(
      sizedUrl,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
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
        return GridView.builder(
          clipBehavior: Clip.none,
          padding: const EdgeInsets.symmetric(horizontal: BoutiqueSpace.gutter),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: productGridDelegate(
            context,
            availableWidth: constraints.maxWidth - BoutiqueSpace.gutter * 2,
            priceLines: tilePriceLinesFor(products),
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return ProductCard(product: product);
          },
        );
      },
    );
  }
}
