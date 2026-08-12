/// Monetta's responsive storefront.
///
/// The page borrows the useful retail rhythms of a global accessories shop:
/// a compact announcement, wordmark-led navigation, a prominent search field,
/// campaign photography, category shortcuts, and a clean product grid. The
/// campaign artwork is original placeholder material generated for Monetta;
/// catalog, recommendation, wishlist, and external-research behavior remains
/// driven by the existing application services.
library;

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/catalog_store.dart';
import '../../app/mixed_feed.dart';
import '../../app/theme.dart';
import '../../domain/catalog_item.dart';
import '../../domain/product.dart';
import '../../main.dart';
import '../../reco/events.dart';
import '../../reco/explainer.dart';
import '../catalog/catalog_browse_screen.dart';
import '../checkout/checkout_screen.dart';
import '../onboarding/onboarding_sheet.dart';
import '../product/product_screen.dart';
import 'external_catalog_section.dart';

const int _kEditorialCount = 6;

const _campaigns = <_CampaignData>[
  _CampaignData(
    asset: 'assets/images/campaign_terracotta.jpg',
    kicker: 'Edición solar',
    title: 'Nueva luz, nuevas formas',
    cta: 'Descubrir la colección',
    searchQuery: 'bolsa',
  ),
  _CampaignData(
    asset: 'assets/images/campaign_olive.jpg',
    kicker: 'Texturas de temporada',
    title: 'El nuevo verde',
    cta: 'Ver bolsos de hombro',
    searchQuery: 'hombro',
  ),
  _CampaignData(
    asset: 'assets/images/campaign_coral.jpg',
    kicker: 'Color en escena',
    title: 'Pequeños, inolvidables',
    cta: 'Ver bolsos mini',
    searchQuery: 'mini',
  ),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _campaignController = PageController();
  bool _askedOnboarding = false;
  int _campaignIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_askedOnboarding) return;
    _askedOnboarding = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _openOnboarding());
  }

  @override
  void dispose() {
    _campaignController.dispose();
    super.dispose();
  }

  void _openOnboarding() {
    if (!mounted) return;
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

  void _openOnboardingFromDrawer() {
    _scaffoldKey.currentState?.closeDrawer();
    Future<void>.delayed(const Duration(milliseconds: 360), () {
      if (mounted) _openOnboarding();
    });
  }

  void _openSearch({String initialQuery = ''}) {
    final store = StoreScope.of(context);
    showSearch<void>(
      context: context,
      query: initialQuery,
      delegate: _CatalogSearchDelegate(store),
    );
  }

  void _openCatalogBrowse({required bool closeDrawer}) {
    final store = StoreScope.of(context);
    final externalCatalog = ExternalCatalogScope.of(context);
    if (closeDrawer) Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoreScope(
          notifier: store,
          child: ExternalCatalogScope(
            notifier: externalCatalog,
            child: CatalogBrowseScreen(
              items: fullDeduplicatedCatalog(
                monettaItems: store.catalogItems,
                externalItems: externalCatalog.items,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final feed = store.feed();

    if (feed.isEmpty) {
      return Scaffold(
        key: _scaffoldKey,
        appBar: _buildAppBar(),
        body: Center(child: Text('Sin resultados', style: eyebrow())),
      );
    }

    final topBrands = store.profile.topOf('brand');
    final editorial = feed.take(_kEditorialCount).toList();
    final externalCatalog = ExternalCatalogScope.of(context);
    final featuredIds = editorial.map((item) => item.product.id).toSet();
    // Home is an edited storefront, not the infinite catalog. Keeping the
    // first 12 ranked candidates makes initial layout/image work bounded;
    // every item remains reachable through “Ver todo el catálogo”.
    final restMixed = store
        .mixedFeed(external: externalCatalog.items, limit: 12)
        .where((item) => !featuredIds.contains(item.product?.id))
        .toList();

    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(),
      drawer: _MainDrawer(
        onAdjustTaste: _openOnboardingFromDrawer,
        onBrowseCatalog: () => _openCatalogBrowse(closeDrawer: true),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const _AnnouncementStrip(),
          _SearchField(onTap: _openSearch),
          _CampaignShowcase(
            controller: _campaignController,
            selectedIndex: _campaignIndex,
            onPageChanged: (index) => setState(() => _campaignIndex = index),
            onTap: (campaign) =>
                _openSearch(initialQuery: campaign.searchQuery),
          ),
          const SizedBox(height: 44),
          const _EditorialIntro(),
          _CategoryRail(
            onSelected: (query) => _openSearch(initialQuery: query),
          ),
          const SizedBox(height: 44),
          SectionHeading(
            kicker: topBrands.isEmpty ? 'Novedades' : 'Seleccionado para ti',
            title: topBrands.isEmpty ? 'Lo más reciente' : 'Tu selección',
            trailing: UnderlineLink(
              label: topBrands.isEmpty ? 'Personalizar' : 'Ajustar',
              onTap: _openOnboarding,
              size: 11,
            ),
          ),
          _EditorialRail(items: editorial),
          const SizedBox(height: 52),
          const _ExternalCatalogRailBuilder(),
          _CatalogHeader(
            count: restMixed.length,
            onViewAll: () => _openCatalogBrowse(closeDrawer: false),
          ),
          _CatalogGrid(items: restMixed),
          const SizedBox(height: 52),
          _ProfileFootnote(
            topBrands: topBrands,
            eventCount: store.eventCount,
            productCount: store.products.length,
            onAdjust: _openOnboarding,
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 68,
      centerTitle: false,
      titleSpacing: 20,
      title: const Align(
        alignment: Alignment.centerLeft,
        child: MonettaWordmark(height: 24),
      ),
      actions: [
        IconButton(
          tooltip: 'Buscar',
          onPressed: _openSearch,
          icon: const Icon(Icons.search, size: 23),
        ),
        const BagAction(),
        IconButton(
          tooltip: 'Menú',
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          icon: const Icon(Icons.menu, size: 25),
        ),
        const SizedBox(width: 8),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(0.5),
        child: Divider(height: 0.5),
      ),
    );
  }
}

class _AnnouncementStrip extends StatelessWidget {
  const _AnnouncementStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      color: kInk,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        'ENVÍO GRATIS EN COMPRAS DE \$1,499 · VER NOVEDADES',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: eyebrow(size: 9, color: Colors.white, weight: FontWeight.w500),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Semantics(
        button: true,
        label: 'Buscar en Monetta',
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: kSearchFill,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Buscar bolsas, carteras y relojes',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: sans(size: 15, color: kInkMuted),
                  ),
                ),
                const Icon(Icons.search, size: 24, color: kInkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CampaignData {
  const _CampaignData({
    required this.asset,
    required this.kicker,
    required this.title,
    required this.cta,
    required this.searchQuery,
  });

  final String asset;
  final String kicker;
  final String title;
  final String cta;
  final String searchQuery;
}

class _CampaignShowcase extends StatelessWidget {
  const _CampaignShowcase({
    required this.controller,
    required this.selectedIndex,
    required this.onPageChanged,
    required this.onTap,
  });

  final PageController controller;
  final int selectedIndex;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<_CampaignData> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 760) {
          final tileWidth = (constraints.maxWidth - 72) / 3;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              height: (tileWidth / .8).clamp(360, 590),
              child: Row(
                children: [
                  for (var i = 0; i < _campaigns.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      child: _CampaignTile(
                        data: _campaigns[i],
                        onTap: () => onTap(_campaigns[i]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        final height = (constraints.maxWidth - 32) / .8;
        return Column(
          children: [
            SizedBox(
              height: height,
              child: PageView.builder(
                controller: controller,
                onPageChanged: onPageChanged,
                itemCount: _campaigns.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _CampaignTile(
                    data: _campaigns[index],
                    onTap: () => onTap(_campaigns[index]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _campaigns.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: i == selectedIndex ? 22 : 6,
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    color: i == selectedIndex ? kInk : kLine,
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _CampaignTile extends StatelessWidget {
  const _CampaignTile({required this.data, required this.onTap});

  final _CampaignData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(data.asset, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Color(0x0A000000),
                  Color(0xB8000000),
                ],
                stops: [0, .55, 1],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    data.kicker.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: eyebrow(size: 9.5, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data.title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: display(
                      25,
                      color: Colors.white,
                      weight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    data.cta.toUpperCase(),
                    style: sans(
                      size: 10.5,
                      color: Colors.white,
                      weight: FontWeight.w600,
                    ).copyWith(letterSpacing: 1.25),
                  ),
                  const SizedBox(height: 5),
                  Container(height: 1, width: 86, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorialIntro extends StatelessWidget {
  const _EditorialIntro();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          Text(
            'Conoce los accesorios que definen la temporada',
            textAlign: TextAlign.center,
            style: display(27, weight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          Text(
            'Siluetas versátiles, texturas irresistibles y piezas originales para todos los días.',
            textAlign: TextAlign.center,
            style: sans(size: 13, color: kInkMuted),
          ),
        ],
      ),
    );
  }
}

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    const entries = [
      ('Bolsas', 'bolsa'),
      ('Carteras', 'cartera'),
      ('Relojes', 'reloj'),
      ('Crossbody', 'crossbody'),
    ];
    return SizedBox(
      height: 74,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return OutlinedButton(
            onPressed: () => onSelected(entry.$2),
            style: OutlinedButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              foregroundColor: kInk,
              side: kHairline,
              shape: const StadiumBorder(),
            ),
            child: Text(entry.$1.toUpperCase()),
          );
        },
      ),
    );
  }
}

class _MainDrawer extends StatelessWidget {
  const _MainDrawer({
    required this.onAdjustTaste,
    required this.onBrowseCatalog,
  });

  final VoidCallback onAdjustTaste;
  final VoidCallback onBrowseCatalog;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Drawer(
      width: width < 400 ? width * .88 : 360,
      backgroundColor: Colors.white,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: kSquare),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 22),
              child: Row(
                children: [
                  const Expanded(child: MonettaWordmark(height: 22)),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 22),
                  ),
                ],
              ),
            ),
            const Divider(height: .5),
            _DrawerLink(
              label: 'Inicio',
              current: true,
              onTap: () => Navigator.of(context).pop(),
            ),
            _DrawerLink(
              label: 'Bolsas',
              onTap: () {
                Navigator.of(context).pop();
                showSearch<void>(
                  context: context,
                  query: 'bolsa',
                  delegate: _CatalogSearchDelegate(StoreScope.of(context)),
                );
              },
            ),
            _DrawerLink(label: 'Ver todo el catálogo', onTap: onBrowseCatalog),
            _DrawerLink(
              label: 'Ajustar mis gustos',
              onTap: onAdjustTaste,
            ),
            const Spacer(),
            const Divider(height: .5),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 26),
              child:
                  Text('Originales importados'.toUpperCase(), style: eyebrow()),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerLink extends StatelessWidget {
  const _DrawerLink({
    required this.label,
    required this.onTap,
    this.current = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Text(
          label,
          style: sans(
            size: 17,
            color: current ? kInkMuted : kInk,
            weight: current ? FontWeight.w400 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _EditorialRail extends StatelessWidget {
  const _EditorialRail({required this.items});

  final List<Recommendation> items;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final width = screenWidth >= 760 ? 280.0 : screenWidth * .62;
    return SizedBox(
      height: width / .82 + 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => SizedBox(
          width: width,
          child: _ProductTile(item: items[index]),
        ),
      ),
    );
  }
}

class _CatalogHeader extends StatelessWidget {
  const _CatalogHeader({required this.count, required this.onViewAll});

  final int count;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('EL CATÁLOGO', style: eyebrow()),
                    const SizedBox(height: 7),
                    Text(
                      'Descubre más',
                      style: display(25, weight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Text('$count PIEZAS', style: eyebrow(size: 9)),
            ],
          ),
          const SizedBox(height: 18),
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: kHairline, bottom: kHairline),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: onViewAll,
                    icon: const Icon(Icons.tune, size: 17),
                    label: const Text('FILTRAR'),
                  ),
                ),
                const SizedBox(height: 44, child: VerticalDivider(width: .5)),
                Expanded(
                  child: TextButton.icon(
                    onPressed: onViewAll,
                    icon: const Icon(Icons.swap_vert, size: 18),
                    label: const Text('ORDENAR'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogGrid extends StatelessWidget {
  const _CatalogGrid({required this.items});

  final List<MixedRecommendation> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
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
            childAspectRatio: .49,
            crossAxisSpacing: 8,
            mainAxisSpacing: 32,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => _MixedTile(rec: items[index]),
        );
      },
    );
  }
}

class _MixedTile extends StatelessWidget {
  const _MixedTile({required this.rec});

  final MixedRecommendation rec;

  @override
  Widget build(BuildContext context) {
    return rec.isExternal
        ? _ExternalMixedTile(rec: rec)
        : _MonettaMixedTile(rec: rec);
  }
}

class _MonettaMixedTile extends StatelessWidget {
  const _MonettaMixedTile({required this.rec});

  final MixedRecommendation rec;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final product = rec.product!;
    final facets = store.facetsFor(product.id);
    return _RetailProductCard(
      imageUrl: product.primaryImage,
      brand: facets?.brand?.value == null
          ? null
          : brandLabel(facets!.brand!.value),
      title: product.title,
      price: kMoney.format(product.price),
      compareAtPrice:
          product.isOnSale ? kMoney.format(product.compareAtPrice) : null,
      inStock: product.isInStock,
      reason: rec.reason,
      wishlisted: store.wishlist.contains(product.id),
      onWishlist: () => store.toggleWishlist(product.id),
      onTap: () => _openProduct(context, store, product),
    );
  }
}

class _ExternalMixedTile extends StatelessWidget {
  const _ExternalMixedTile({required this.rec});

  final MixedRecommendation rec;

  Future<void> _open(BuildContext context) async {
    final item = rec.item;
    if (!isValidExternalDetailUrl(item)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enlace no válido para ${item.merchant}')),
      );
      return;
    }
    final launched = await defaultExternalLinkOpener(Uri.parse(item.detailUrl));
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir ${item.merchant}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = rec.item;
    return _RetailProductCard(
      imageUrl: item.imageUrl,
      brand: item.brand,
      title: item.title,
      price: formatCatalogMoney(item.price),
      inStock: item.availability != CatalogAvailability.outOfStock,
      reason: rec.reason,
      source: externalSourceBadge(item.source),
      onTap: () => unawaited(_open(context)),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.item});

  final Recommendation item;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final product = item.product;
    final facets = store.facetsFor(product.id);
    return _RetailProductCard(
      imageUrl: product.primaryImage,
      brand: facets?.brand?.value == null
          ? null
          : brandLabel(facets!.brand!.value),
      title: product.title,
      price: kMoney.format(product.price),
      compareAtPrice:
          product.isOnSale ? kMoney.format(product.compareAtPrice) : null,
      inStock: product.isInStock,
      reason: item.reason,
      wishlisted: store.wishlist.contains(product.id),
      onWishlist: () => store.toggleWishlist(product.id),
      onTap: () => _openProduct(context, store, product),
    );
  }
}

void _openProduct(BuildContext context, CatalogStore store, Product product) {
  store.record(EventType.productView, productId: product.id);
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => StoreScope(
        notifier: store,
        child: ProductScreen(productId: product.id),
      ),
    ),
  );
}

class _RetailProductCard extends StatelessWidget {
  const _RetailProductCard({
    required this.imageUrl,
    required this.brand,
    required this.title,
    required this.price,
    required this.inStock,
    required this.reason,
    required this.onTap,
    this.compareAtPrice,
    this.wishlisted = false,
    this.onWishlist,
    this.source,
  });

  final String? imageUrl;
  final String? brand;
  final String title;
  final String price;
  final String? compareAtPrice;
  final bool inStock;
  final RecoReason reason;
  final bool wishlisted;
  final VoidCallback? onWishlist;
  final VoidCallback onTap;
  final String? source;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: .82,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _ProductImage(url: imageUrl),
                if (!inStock)
                  ColoredBox(
                    color: Colors.white.withValues(alpha: .68),
                    child: Center(child: Text('AGOTADO', style: eyebrow())),
                  ),
                if (onWishlist != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      onPressed: onWishlist,
                      constraints:
                          const BoxConstraints.tightFor(width: 34, height: 34),
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        wishlisted ? Icons.favorite : Icons.favorite_border,
                        size: 19,
                        color: wishlisted ? kGold : kInk,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 11),
          Text(
            reason.text.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: eyebrow(
              size: 8.5,
              color: reason.kind == ReasonKind.priceDrop ? kSale : kInkMuted,
            ),
          ),
          const SizedBox(height: 6),
          if (brand != null) ...[
            Text(
              brand!.toUpperCase(),
              style: sans(size: 10.5, weight: FontWeight.w600),
            ),
            const SizedBox(height: 3),
          ],
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: sans(size: 12.5, height: 1.35),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 7,
            runSpacing: 2,
            children: [
              Text(price, style: sans(size: 12, weight: FontWeight.w600)),
              if (compareAtPrice != null)
                Text(
                  compareAtPrice!,
                  style: sans(
                    size: 11,
                    color: kInkMuted,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
            ],
          ),
          if (source != null) ...[
            const SizedBox(height: 4),
            Text(source!, style: sans(size: 9.5, color: kInkMuted)),
          ],
        ],
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kMist,
      child: url == null
          ? const Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                size: 20,
                color: kInkMuted,
              ),
            )
          : CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 220),
              placeholder: (_, __) => const ColoredBox(color: kMist),
              errorWidget: (_, __, ___) => const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 20,
                  color: kInkMuted,
                ),
              ),
            ),
    );
  }
}

class _ExternalCatalogRailBuilder extends StatelessWidget {
  const _ExternalCatalogRailBuilder();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final externalCatalog = ExternalCatalogScope.of(context);
    return ListenableBuilder(
      listenable: externalCatalog,
      builder: (context, _) {
        if (!externalCatalog.enabled) return const SizedBox.shrink();
        return ExternalCatalogSection(
          items: dedupeExternalAgainstMonetta(
            external: externalCatalog.items,
            monettaItems: store.catalogItems,
          ),
          generatedAt: externalCatalog.generatedAt,
        );
      },
    );
  }
}

class _ProfileFootnote extends StatelessWidget {
  const _ProfileFootnote({
    required this.topBrands,
    required this.eventCount,
    required this.productCount,
    required this.onAdjust,
  });

  final List<String> topBrands;
  final int eventCount;
  final int productCount;
  final VoidCallback onAdjust;

  @override
  Widget build(BuildContext context) {
    final hasTaste = topBrands.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 34, 20, 38),
      color: kMist,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TU EXPERIENCIA MONETTA', style: eyebrow()),
          const SizedBox(height: 11),
          Text(
            hasTaste
                ? 'Priorizamos ${topBrands.map(brandLabel).join(' · ')} a partir de $eventCount interacciones en este dispositivo.'
                : '$productCount piezas originales listas para descubrir. Elige tus gustos para personalizar esta selección.',
            style: sans(size: 12.5, color: kInkMuted),
          ),
          const SizedBox(height: 18),
          UnderlineLink(
            label: hasTaste ? 'Ajustar mis gustos' : 'Elegir mis gustos',
            onTap: onAdjust,
            size: 11.5,
          ),
        ],
      ),
    );
  }
}

class _CatalogSearchDelegate extends SearchDelegate<void> {
  _CatalogSearchDelegate(this.store)
      : super(
          searchFieldLabel: 'Buscar en Monetta',
          searchFieldStyle: sans(size: 15),
          keyboardType: TextInputType.text,
        );

  final CatalogStore store;

  @override
  ThemeData appBarTheme(BuildContext context) => Theme.of(context).copyWith(
        appBarTheme: Theme.of(context).appBarTheme.copyWith(centerTitle: false),
        inputDecorationTheme:
            const InputDecorationTheme(border: InputBorder.none),
      );

  @override
  List<Widget>? buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            tooltip: 'Borrar',
            onPressed: () => query = '',
            icon: const Icon(Icons.close),
          ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        tooltip: 'Volver',
        onPressed: () => close(context, null),
        icon: const Icon(Icons.arrow_back),
      );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final normalized = query.trim().toLowerCase();
    final products = store.products.where((product) {
      if (normalized.isEmpty) return true;
      final facets = store.facetsFor(product.id);
      final brand = facets?.brand?.value == null
          ? ''
          : brandLabel(facets!.brand!.value).toLowerCase();
      return product.title.toLowerCase().contains(normalized) ||
          brand.contains(normalized) ||
          product.productType.toLowerCase().contains(normalized);
    }).toList();

    if (products.isEmpty) {
      return Center(
        child: Text(
          'No encontramos resultados para “$query”.',
          style: sans(color: kInkMuted),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: .55,
        crossAxisSpacing: 8,
        mainAxisSpacing: 28,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final facets = store.facetsFor(product.id);
        return GestureDetector(
          onTap: () => _openProduct(context, store, product),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: .82,
                child: _ProductImage(url: product.primaryImage),
              ),
              const SizedBox(height: 10),
              if (facets?.brand?.value != null) ...[
                Text(
                  brandLabel(facets!.brand!.value).toUpperCase(),
                  style: sans(size: 10, weight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
              ],
              Text(
                product.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: sans(size: 12.5, height: 1.35),
              ),
              const SizedBox(height: 5),
              Text(
                kMoney.format(product.price),
                style: sans(size: 12, weight: FontWeight.w600),
              ),
            ],
          ),
        );
      },
    );
  }
}
