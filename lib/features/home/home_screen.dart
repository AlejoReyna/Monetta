/// Monetta's shopper storefront. Desire first, then a way to buy.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/catalog_store.dart';
import '../../app/media/monetta_image.dart';
import '../../app/media/monetta_video.dart';
import '../../app/motion.dart';
import '../../app/shopper_copy.dart';
import '../../app/theme.dart';
import '../../data/media/media_url.dart';
import '../../domain/campaign.dart';
import '../../domain/product.dart';
import '../../main.dart';
import '../../reco/explainer.dart';
import '../catalog/collection_screen.dart';
import '../catalog/product_card.dart';
import '../checkout/checkout_screen.dart';
import '../onboarding/onboarding_sheet.dart';

const int _kNewestCount = 8;
const int _kGridCount = 12;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
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

  void _openWhatsApp(Uri uri) {
    unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final feed = store.feed();

    if (feed.isEmpty) {
      return Scaffold(
        key: _scaffoldKey,
        appBar: _buildAppBar(24),
        body: Center(child: Text('Sin resultados', style: eyebrow())),
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
    final heroH = (media.height * 0.42).clamp(240.0, 360.0);

    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(markH, height: barH),
      drawer: _MainDrawer(
        onChooseBrands: _openOnboardingFromDrawer,
        onWhatsApp: () => _openWhatsApp(conciergeWhatsAppUri()),
        onWholesale: () => _openWhatsApp(wholesaleWhatsAppUri()),
      ),
      body: ListView(
        controller: _scroll,
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: announcementH,
            child: ClipRect(
              child: Opacity(
                opacity: 1 - _collapse,
                child: const _AnnouncementStrip(),
              ),
            ),
          ),
          _CampaignHero(
            height: heroH,
            playing: _foreground &&
                (!_scroll.hasClients || _scroll.offset < heroH),
            onOpenCatalog: () => openCollection(
              context,
              const CollectionScreen(title: 'El catálogo'),
            ),
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text('Novedades', style: display(24)),
          ),
          _CatalogGrid(products: fresh),
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
          const SizedBox(height: 48),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Text('Marcas', style: display(24)),
          ),
          _BrandRail(brands: store.availableBrands.take(8).toList()),
          const SizedBox(height: 48),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Text('Formas', style: display(24)),
          ),
          _SilhouetteRail(store: store),
          const SizedBox(height: 48),
          _CatalogGrid(products: rest),
          const SizedBox(height: 20),
          Center(
            child: UnderlineLink(
              label: 'Ver todo',
              onTap: () => openCollection(
                context,
                const CollectionScreen(title: 'El catálogo'),
              ),
            ),
          ),
          const SizedBox(height: 52),
          const _QuietFooter(),
        ],
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
        'ENVÍO GRATIS DESDE \$1,499',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: eyebrow(size: 9, color: Colors.white, weight: FontWeight.w500),
      ),
    );
  }
}

class _CampaignHero extends StatelessWidget {
  const _CampaignHero({
    required this.height,
    required this.playing,
    required this.onOpenCatalog,
  });

  final double height;
  final bool playing;
  final VoidCallback onOpenCatalog;

  @override
  Widget build(BuildContext context) {
    const campaign = CampaignMedia.monettaHome;
    return SizedBox(
      height: height,
      child: GestureDetector(
        onTap: onOpenCatalog,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MonettaVideo(campaign: campaign, playing: playing),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0x66000000),
                  ],
                  stops: [0.55, 1],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
                child: Reveal(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        campaign.ctaLabel.toUpperCase(),
                        style: sans(
                          size: 11,
                          color: Colors.white,
                          weight: FontWeight.w600,
                        ).copyWith(letterSpacing: 1.4),
                      ),
                      const SizedBox(height: 6),
                      Container(height: 1, width: 92, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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

class _BrandRail extends StatelessWidget {
  const _BrandRail({required this.brands});

  final List<String> brands;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: brands.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final brand = brands[index];
          return GestureDetector(
            onTap: () => openCollection(
              context,
              CollectionScreen(
                title: brandLabel(brand),
                filter: CollectionFilter(brand: brand),
              ),
            ),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(border: Border.all(color: kLine, width: 0.5)),
              child: Text(
                brandLabel(brand).toUpperCase(),
                style: eyebrow(size: 9, color: kInk),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SilhouetteRail extends StatelessWidget {
  const _SilhouetteRail({required this.store});

  final CatalogStore store;

  @override
  Widget build(BuildContext context) {
    const shapes = <(String, String)>[
      ('tote', 'Totes'),
      ('crossbody', 'Crossbody'),
      ('shoulder', 'De hombro'),
    ];
    final tiles = <_ShopTileData>[
      for (final shape in shapes)
        if (store.firstInStockWhere((p, f) => f?.silhouette?.value == shape.$1)
            case final product?)
          _ShopTileData(
            label: shape.$2,
            imageUrl: product.primaryImage,
            screen: CollectionScreen(
              title: shape.$2,
              filter: CollectionFilter(category: 'bolsa', silhouette: shape.$1),
            ),
          ),
    ];
    if (tiles.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tiles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final tile = tiles[index];
          return SizedBox(
            width: 148,
            child: _PhotoTile(data: tile),
          );
        },
      ),
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
  const _QuietFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: kMist,
      padding: const EdgeInsets.fromLTRB(20, 34, 20, 38),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Originales importados de Estados Unidos', style: sans(size: 13)),
          const SizedBox(height: 8),
          Text(
            'Envío a todo México · 3 a 5 días · WhatsApp $kWhatsAppNumberDisplay',
            style: sans(size: 12.5, color: kInkMuted),
          ),
        ],
      ),
    );
  }
}

class _MainDrawer extends StatelessWidget {
  const _MainDrawer({
    required this.onChooseBrands,
    required this.onWhatsApp,
    required this.onWholesale,
  });

  final VoidCallback onChooseBrands;
  final VoidCallback onWhatsApp;
  final VoidCallback onWholesale;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Drawer(
      width: width < 400 ? width * 0.88 : 360,
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
            const Divider(height: 0.5),
            _DrawerLink(
              label: 'Inicio',
              current: true,
              onTap: () => Navigator.of(context).pop(),
            ),
            _DrawerLink(
              label: 'Bolsas',
              onTap: () {
                Navigator.of(context).pop();
                openCollection(
                  context,
                  const CollectionScreen(
                    title: 'Bolsas',
                    filter: CollectionFilter(category: 'bolsa'),
                  ),
                );
              },
            ),
            _DrawerLink(
              label: 'Carteras',
              onTap: () {
                Navigator.of(context).pop();
                openCollection(
                  context,
                  const CollectionScreen(
                    title: 'Carteras',
                    filter: CollectionFilter(category: 'cartera'),
                  ),
                );
              },
            ),
            _DrawerLink(
              label: 'Relojes',
              onTap: () {
                Navigator.of(context).pop();
                openCollection(
                  context,
                  const CollectionScreen(
                    title: 'Relojes',
                    filter: CollectionFilter(category: 'reloj'),
                  ),
                );
              },
            ),
            _DrawerLink(
              label: 'Ver todo',
              onTap: () {
                Navigator.of(context).pop();
                openCollection(
                  context,
                  const CollectionScreen(title: 'El catálogo'),
                );
              },
            ),
            _DrawerLink(label: 'Elige marcas', onTap: onChooseBrands),
            const Spacer(),
            const Divider(height: 0.5),
            _DrawerLink(label: 'WhatsApp', onTap: onWhatsApp),
            _DrawerLink(label: 'Mayoreo', onTap: onWholesale),
            const SizedBox(height: 12),
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
          'No hay piezas para “$query”.',
          style: sans(color: kInkMuted),
        ),
      );
    }

    return StoreScope(
      notifier: store,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.52,
          crossAxisSpacing: 8,
          mainAxisSpacing: 28,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) => ProductCard(product: products[index]),
      ),
    );
  }
}
