/// Monetta's shopper storefront. Desire first, then a way to buy.
library;

import '../navigation/adaptive_storefront_scaffold.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/card_lift.dart';
import '../../app/catalog_store.dart';
import '../../app/motion.dart';
import '../boutique/client_guide_sections.dart';
import '../boutique/guide_brand_tile.dart';
import '../wholesale/wholesale_screen.dart';
import '../contact/contact_screen.dart';
import '../../app/mixed_feed.dart';
import '../../app/shopper_copy.dart';
import '../../app/theme.dart';
import '../../app/theme_controller.dart';
import '../../data/media/media_url.dart';
import '../../domain/editorial_content.dart';
import '../../domain/home_content.dart';
import '../../main.dart';
import '../account/account_screen.dart';
import '../about/about_monetta_screen.dart';
import '../admin/admin_screen.dart';
import '../catalog/catalog_browse_screen.dart';
import '../catalog/brands_screen.dart';
import '../catalog/categories_screen.dart';
import '../catalog/collection_screen.dart';
import '../catalog/search_screen.dart';
import '../checkout/checkout_screen.dart';
import '../boutique/boutique_tokens.dart';
import '../notifications/notifications_screen.dart';
import '../navigation/monetta_bottom_navigation.dart';
import '../navigation/monetta_side_menu.dart';
import '../partner/partner_hub_screen.dart';
import '../welcome/welcome_gate.dart';
import 'home_account_invitation.dart';
import 'home_boutique_sections.dart';
import 'home_category_photo_rail.dart';
import 'home_for_you_section.dart';
import 'home_most_wanted_section.dart';
import 'home_new_collection_section.dart';
import 'home_v41_catalog.dart';
import 'home_wholesale_banner.dart';

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
    final homeScope = HomeContentScope.maybeOf(context);
    final homeContent = homeScope?.content ?? HomeContent.fallback;
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

    final nuevaColeccion = uniqueNewestProducts(store);
    final nuevaIds = nuevaColeccion.map((p) => p.id).toSet();
    final loMasBuscado = uniqueFeedProducts(
      store,
      excludeIds: nuevaIds,
    );
    final drawer = _buildSideMenu(store);
    final bottomNavigation = MonettaBottomNavigation(
      current: MonettaBottomDestination.home,
      bagCount: store.bagQuantity,
      onSelected: _handleBottomNavigation,
    );
    // UI v4.1 fixes one sequence on every width: banners → categorías →
    // marcas → Nueva colección → Lo más buscado → Para ti → Mayoreo →
    // servicios → registro → pie. Shopify still feeds the data (brands, social
    // links), never the order.
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
                      onOpenProducts: _openFullCatalog,
                      onOpenBrands: () => unawaited(openBrands(context)),
                      onOpenCategories: () =>
                          unawaited(openCategories(context)),
                    ),
                  )
                else
                  const SizedBox(height: 1),
              ],
            ),
            ...[
              Padding(
                padding: const EdgeInsets.only(top: BoutiqueSpace.xxl),
                child: HomeCategoryPhotoRail(
                  onOpen: (entry) => openCollection(
                    context,
                    CollectionScreen(
                      title: entry.label,
                      filter: entry.filter,
                    ),
                  ),
                  onSeeAll: () => unawaited(openCategories(context)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: BoutiqueSpace.xxl),
                child: _BrandsSection(
                  brands: guideBrandsFor(homeContent.brands),
                  onSeeAll: () => unawaited(openBrands(context)),
                ),
              ),
              if (nuevaColeccion.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: BoutiqueSpace.xxl),
                  child: HomeNewCollectionSection(
                    products: nuevaColeccion,
                    onOpenAll: _openFullCatalog,
                  ),
                ),
              if (loMasBuscado.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: BoutiqueSpace.xxl),
                  child: HomeMostWantedSection(
                    products: loMasBuscado,
                    onOpenAll: _openFullCatalog,
                  ),
                ),
              const Padding(
                padding: EdgeInsets.only(top: BoutiqueSpace.xxl),
                child: HomeForYouSection(),
              ),
            ],
            Padding(
              padding: const EdgeInsets.only(top: BoutiqueSpace.xxl),
              child: RevealOnScroll(
                key: const ValueKey('home-reveal-offers'),
                scrollController: _scroll,
                offset: 0,
                child: HomeWholesaleBanner(onOpenWholesale: _openWholesale),
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
              onWholesale: _openWholesale,
              socialLinks: homeContent.socialLinks,
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
