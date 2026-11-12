/// Product detail with one stable Shopify variant selection, contained
/// photography, native purchase controls and lazy editorial continuation.
/// Unsupported policy/restock capabilities stay hidden until A00 attaches them.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/media/monetta_image.dart';
import '../../app/motion.dart';
import '../../app/monetta_tokens.g.dart';
import '../../app/storefront_layout.dart';
import '../../app/shopper_copy.dart';
import '../../app/theme.dart';
import '../../data/media/media_url.dart';
import '../../data/shopify/cart_attribution.dart';
import '../../domain/product.dart';
import '../../main.dart';
import '../../reco/events.dart';
import '../../reco/explainer.dart';
import '../account/account_screen.dart';
import '../boutique/boutique_tokens.dart';
import '../catalog/categories_screen.dart';
import '../catalog/product_card.dart';
import '../catalog/product_tile.dart' show PackshotBlend;
import '../catalog/search_screen.dart';
import '../checkout/checkout_screen.dart';
import '../catalog/product_controls.dart';
import 'product_recommendations.dart';
import 'product_zoom.dart';
import '../navigation/guide_chrome.dart';
import '../navigation/guide_drawer.dart';
import '../navigation/monetta_bottom_navigation.dart';
import 'product_selection.dart';
import 'product_adaptive_body.dart';
import '../navigation/adaptive_storefront_scaffold.dart';
import '../navigation/duo_workspace.dart';
import '../../platform/system_layout_context.dart';
import '../../data/shopify/storefront_config.dart';
import 'purchase_dock.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({
    required this.productId,
    this.initialVariantIndex = 0,
    this.initialVariantId,
    this.onRestock,
    this.endSectionsBuilder,
    this.shippingPolicy,
    this.returnsPolicy,
    this.onClose,
    super.key,
  });

  final String productId;

  /// Variante seleccionada en la vista rápida u otra superficie previa.
  /// Se conserva al abrir la ficha para no perder la elección.
  final int initialVariantIndex;
  final String? initialVariantId;
  final ProductRestockAction? onRestock;

  /// A06/A00 attach the shared registration/footer here.
  final WidgetBuilder? endSectionsBuilder;

  /// Only current, approved policy content may enable these accordions.
  final String? shippingPolicy;
  final String? returnsPolicy;
  final VoidCallback? onClose;

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final Stopwatch _dwell = Stopwatch()..start();
  final PageController _gallery = PageController();
  final GlobalKey _shareSource = GlobalKey();
  String? _variantId;
  bool _selectionInitialized = false;
  bool _added = false;
  int _page = 0;
  late int _variantIndex = widget.initialVariantIndex;
  final Set<String> _open = <String>{};

  /// True while an add is in flight; blocks a second tap on any purchase
  /// action so one tap never turns into two units.
  bool _adding = false;

  @override
  void dispose() {
    _dwell.stop();
    _gallery.dispose();
    super.dispose();
  }

  void _recordDwellAndPop() {
    final store = StoreScope.of(context);
    store.record(
      EventType.productView,
      productId: widget.productId,
      dwellMs: _dwell.elapsedMilliseconds,
    );
    NotificationScope.maybeOf(context)?.recordPushOutcome('product_viewed');
    if (widget.onClose case final close?) {
      close();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openApartado(Product product) async {
    final store = StoreScope.of(context);
    store.record(EventType.whatsappApartado, productId: product.id);
    final variant = selectedVariant(product, _variantIndex);
    if (variant == null) return;
    final config = StorefrontConfig.fromEnvironment();
    final message = <String>[
      'Hola MONETTA, quiero solicitar un apartado.',
      product.title,
      if (!variant.isDefault) 'Opción: ${variant.title}',
      'Variante: ${variant.id}',
      'Precio: ${formatShopperPrice(variant.price)}',
      if (config.isUsable && product.handle.isNotEmpty)
        Uri.https(config.shopDomain, '/products/${product.handle}').toString(),
      'Enviar esta solicitud no confirma un apartado ni realiza un cobro.',
      'Código: ${const AttributionCodeGenerator().generate(DateTime.now().microsecondsSinceEpoch)}',
    ].join('\n');
    try {
      final launched = await launchUrl(
        Uri.https(
          'wa.me',
          '/${ApartadoRequest.whatsappNumber}',
          {'text': message},
        ),
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) _showMessage('No se pudo abrir WhatsApp');
    } catch (_) {
      if (mounted) _showMessage('No se pudo abrir WhatsApp');
    }
  }

  Future<void> _share(Product product, double price) async {
    final store = StoreScope.of(context);
    store.record(EventType.galleryInteraction, productId: product.id);
    final box = _shareSource.currentContext?.findRenderObject();
    final anchor = box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : presentationAnchor(context) & const Size(1, 1);
    final config = StorefrontConfig.fromEnvironment();
    final link = config.isUsable && product.handle.isNotEmpty
        ? '\n${Uri.https(config.shopDomain, '/products/${product.handle}')}'
        : '';
    try {
      await Share.share(
        '${shopperProductName(product.title)} · ${kMoney.format(price)} en Monetta$link',
        sharePositionOrigin: anchor,
        subject: shopperProductName(product.title),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo compartir esta pieza')),
      );
    }
  }

  Future<void> _add(Product product) => _purchase(product, buyNow: false);

  Future<void> _buyNow(Product product) => _purchase(product, buyNow: true);

  /// Both purchase actions go through [tryAddSelectionToBag]; they differ only
  /// in what follows a successful add. The selected variant is never changed,
  /// whatever the outcome.
  Future<void> _purchase(Product product, {required bool buyNow}) async {
    if (_adding) return;
    setState(() {
      _adding = true;
      _added = false;
    });
    final result = await tryAddSelectionToBag(context, product, _variantIndex);
    if (!mounted) return;
    // Released before any feedback so the action is usable again as soon as
    // the sheet or the snack bar appears.
    setState(() => _adding = false);
    switch (result.status) {
      case BagAddStatus.added:
        // Keeps the existing confirmation surface — a sheet, never a toast.
        if (buyNow) {
          await openBag(context);
        } else {
          setState(() => _added = true);
        }
      case BagAddStatus.soldOut:
        _showMessage('Esta opción está agotada.');
      case BagAddStatus.unavailable:
        _showMessage('Esta pieza no está disponible por ahora.');
      case BagAddStatus.failed:
        _showMessage('No pudimos agregar la pieza. Intenta de nuevo.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _goToPage(int index) {
    setState(() => _page = index);
    if (reduceMotion(context)) {
      _gallery.jumpToPage(index);
    } else {
      _gallery.animateToPage(index, duration: kSwap, curve: kMotionCurve);
    }
  }

  Widget _recommendationSection(
    BuildContext context,
    String title,
    List<Product> products,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: BoutiqueSpace.gutter),
            child: Text(title, style: boutiqueSectionHeading(context: context)),
          ),
          const SizedBox(height: 16),
          _Rail(key: ValueKey(title), title: title, products: products),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final product =
        store.products.where((p) => p.id == widget.productId).firstOrNull;
    if (product == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Producto no disponible')),
        body: Center(
          child: TextButton(
            onPressed: () => openCategories(context),
            child: Text(
              'Explorar productos',
              style: boutiqueText(color: context.boutique.ink),
            ),
          ),
        ),
      );
    }
    final facets = store.facetsFor(product.id);
    final wishlisted = store.wishlist.contains(product.id);
    final selectable = selectableVariants(product);
    if (!_selectionInitialized) {
      _variantIndex = variantIndexForId(
        product,
        widget.initialVariantId,
        fallback: widget.initialVariantIndex,
      );
      _variantId = widget.initialVariantId ??
          selectedVariant(product, _variantIndex)?.id;
      _selectionInitialized = true;
    }
    final selectedPosition = selectable.indexWhere((v) => v.id == _variantId);
    if (selectedPosition >= 0) _variantIndex = selectedPosition;
    final selectionMissing =
        _variantId != null && !product.variants.any((v) => v.id == _variantId);
    final selected =
        selectionMissing ? null : selectedVariant(product, _variantIndex);
    final price = selected?.price ?? product.price;
    final compare = selected?.compareAtPrice;
    final onSale = selectionOnSale(product, _variantIndex);
    final discount = selectionDiscountPercent(product, _variantIndex);
    final inStock =
        !selectionMissing && selectionInStock(product, _variantIndex);
    final memberImages = imagesForVariant(product, selected);
    final images = memberImages.isEmpty ? <String?>[null] : memberImages;
    if (_page >= images.length) _page = 0;
    final shopifyDescription = shopifyDescriptionText(product.descriptionHtml);
    final description = shopifyDescription;
    final recent = uniqueProductSet(
      store.recentlyViewed(excluding: product.id, limit: 40),
      excluding: product.id,
    );
    final related = relatedProductSet(product, store.products, store.facetsFor);
    final brand = facets?.brand?.value;
    final sameBrand = brand == null
        ? const <Product>[]
        : uniqueProductSet(
            store.moreFromBrand(brand, excluding: product.id, limit: 40),
            excluding: product.id,
          );
    final palette = context.boutique;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _recordDwellAndPop();
      },
      child: AdaptiveStorefrontScaffold(
        backgroundColor: palette.canvas,
        drawer: guideDrawer(context),
        appBar: guideAppBar(
          context,
          onSearch: () => unawaited(openSearch(context)),
          onBack: widget.onClose != null || Navigator.canPop(context)
              ? _recordDwellAndPop
              : null,
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: ProductAdaptiveBody(
            galleryAccessoryHeight: images.length > 1 ? 100 : 0,
            // The gallery is a square as wide as the content: the body always
            // scrolls it (a list, or a scroll view per region), so the height
            // the body suggests is not a cap.
            gallery: (_) => Padding(
              padding: const EdgeInsets.fromLTRB(
                BoutiqueSpace.gutter,
                BoutiqueSpace.sm,
                BoutiqueSpace.gutter,
                0,
              ),
              child: Column(
                children: [
                  _Gallery(
                    product: product,
                    shareKey: _shareSource,
                    images: images,
                    page: _page,
                    controller: _gallery,
                    wishlisted: wishlisted,
                    inStock: inStock,
                    onPageChanged: (i) => setState(() => _page = i),
                    onPrevious: images.length < 2
                        ? null
                        : () => _goToPage(
                              (_page - 1 + images.length) % images.length,
                            ),
                    onNext: images.length < 2
                        ? null
                        : () => _goToPage((_page + 1) % images.length),
                    onToggleWishlist: () => store.toggleWishlist(product.id),
                    onShare: () => _share(product, price),
                    onZoom: memberImages.isEmpty
                        ? null
                        : () async {
                            final next = await showProductZoom(
                              context,
                              images: memberImages,
                              initialPage: _page,
                              title:
                                  '${shopperProductName(product.title)}${selected?.isDefault == false ? ' · ${selected!.title}' : ''}',
                            );
                            if (mounted && next != null) _goToPage(next);
                          },
                  ),
                  if (images.length > 1)
                    _Thumbnails(
                      images: images,
                      active: _page,
                      title: product.title,
                      onSelect: _goToPage,
                    ),
                ],
              ),
            ),
            details: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    BoutiqueSpace.gutter,
                    BoutiqueSpace.xl,
                    BoutiqueSpace.gutter,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (facets?.brand != null) ...[
                        Text(
                          brandLabel(facets!.brand!.value),
                          key: const Key('product-brand'),
                          style: boutiqueText(
                            size: 18,
                            weight: FontWeight.w600,
                            color: palette.ink,
                          ),
                        ),
                        const SizedBox(height: BoutiqueSpace.xs),
                      ],
                      Text(
                        shopperProductName(product.title),
                        style: boutiqueProductName(
                          context: context,
                          color: palette.ink,
                        ),
                      ),
                      const SizedBox(height: BoutiqueSpace.md),
                      Wrap(
                        spacing: BoutiqueSpace.md,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            formatShopperPrice(price),
                            key: const Key('product-price'),
                            style: boutiqueText(
                              size: 22,
                              weight: FontWeight.w600,
                              color: inStock ? palette.ink : palette.inkMuted,
                              height: 1.2,
                            ),
                          ),
                          // Previous price + -% render only off real
                          // `compare_at` data — never otherwise.
                          if (onSale && compare != null) ...[
                            Text(
                              formatShopperPrice(compare),
                              style: boutiqueText(
                                size: 14,
                                color: palette.inkMuted,
                                height: 1.2,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            if (discount > 0)
                              Container(
                                key: const ValueKey('discount-badge'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.saleSurface,
                                  borderRadius: BoutiqueRadius.capsule,
                                ),
                                child: Text(
                                  '-$discount%',
                                  style: boutiqueText(
                                    size: 13,
                                    weight: FontWeight.w500,
                                    color: palette.sale,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                      if (selectable.isNotEmpty) ...[
                        const SizedBox(height: BoutiqueSpace.lg),
                        ProductOptionSelector(
                          product: product,
                          selectedIndex: _variantIndex,
                          onSelect: (i) {
                            if (_adding) return;
                            setState(() {
                              _variantIndex = i;
                              _variantId = i < 0 ? null : selectable[i].id;
                              _page = 0;
                              _added = false;
                              if (_gallery.hasClients) _gallery.jumpToPage(0);
                            });
                          },
                        ),
                      ],
                      if (inStock) ...[
                        PurchaseDockButton(
                          key: const Key('purchase-dock-primary'),
                          label: _adding ? 'AGREGANDO…' : 'AGREGAR A BOLSA',
                          pending: _adding,
                          large: true,
                          onPressed: _adding ? null : () => _add(product),
                        ),
                        const SizedBox(height: BoutiqueSpace.sm),
                        PurchaseOutlineButton(
                          key: const Key('purchase-buy-now'),
                          label: 'COMPRAR AHORA',
                          textColor: palette.ink,
                          onPressed: _adding ? null : () => _buyNow(product),
                        ),
                        const SizedBox(height: BoutiqueSpace.lg),
                      ],
                      _AvailabilityLine(inStock: inStock),
                      if (_added)
                        Semantics(
                          liveRegion: true,
                          child: const Text('Agregado al carrito'),
                        ),
                      const SizedBox(height: BoutiqueSpace.lg),
                      const _TrustRow(),
                      if (!inStock &&
                          selected != null &&
                          widget.onRestock != null)
                        TextButton(
                          key: const ValueKey('create-restock-alert'),
                          onPressed: () => widget.onRestock!(product, selected),
                          child: Text(
                            'Avísame cuando vuelva',
                            style: boutiqueText(color: palette.ink),
                          ),
                        ),
                      const SizedBox(height: BoutiqueSpace.lg),
                      Divider(height: 1, thickness: 1, color: palette.hairline),
                      if (description.isNotEmpty)
                        _BoutiqueAccordion(
                          label: 'Descripción',
                          open: _open.contains('descripcion'),
                          onTap: () => setState(() {
                            _open.contains('descripcion')
                                ? _open.remove('descripcion')
                                : _open.add('descripcion');
                          }),
                          child: Text(
                            description,
                            style: boutiqueText(
                              size: 14,
                              color: palette.ink,
                              height: 1.6,
                            ),
                          ),
                        ),
                      _BoutiqueAccordion(
                        label: 'Otras formas de comprar',
                        open: _open.contains('otras'),
                        onTap: () => setState(
                          () => _open.contains('otras')
                              ? _open.remove('otras')
                              : _open.add('otras'),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Enviar una solicitud no confirma el apartado ni realiza un cobro.',
                            ),
                            if (selected != null)
                              TextButton.icon(
                                key: const Key('purchase-apartar'),
                                onPressed: () => _openApartado(product),
                                style: TextButton.styleFrom(
                                  foregroundColor: palette.ink,
                                ),
                                icon: const Icon(Icons.chat_outlined),
                                label: const Text(
                                  'Solicitar apartado por WhatsApp',
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (widget.shippingPolicy case final policy?
                          when policy.trim().isNotEmpty)
                        _BoutiqueAccordion(
                          label: 'Envíos',
                          open: _open.contains('envios'),
                          onTap: () => setState(
                            () => _open.contains('envios')
                                ? _open.remove('envios')
                                : _open.add('envios'),
                          ),
                          child: Text(policy),
                        ),
                      if (widget.returnsPolicy case final policy?
                          when policy.trim().isNotEmpty)
                        _BoutiqueAccordion(
                          label: 'Cambios y devoluciones',
                          open: _open.contains('cambios'),
                          onTap: () => setState(
                            () => _open.contains('cambios')
                                ? _open.remove('cambios')
                                : _open.add('cambios'),
                          ),
                          child: Text(policy),
                        ),
                    ],
                  ),
                ),
                if (related.isNotEmpty)
                  _recommendationSection(context, 'Relacionados', related),
                if (sameBrand.isNotEmpty)
                  _recommendationSection(context, 'Más de la marca', sameBrand),
                if (recent.isNotEmpty)
                  _recommendationSection(
                    context,
                    'Vistos hace un momento',
                    recent,
                  ),
                if (widget.endSectionsBuilder != null)
                  KeyedSubtree(
                    key: const Key('product-end-sections'),
                    child: widget.endSectionsBuilder!(context),
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
        bottomNavigationBar: MonettaBottomNavigation(
          current:
              widget.onClose != null ? MonettaBottomDestination.catalog : null,
          bagCount: store.bagQuantity,
          onSelected: (destination) {
            switch (destination) {
              case MonettaBottomDestination.home:
                DuoWorkspace.navigatorFor(context)
                    .popUntil((route) => route.isFirst);
              case MonettaBottomDestination.catalog:
                if (widget.onClose != null) {
                  _recordDwellAndPop();
                } else {
                  unawaited(openCategories(context));
                }
              case MonettaBottomDestination.bag:
                unawaited(openBag(context));
              case MonettaBottomDestination.account:
                final account = AccountScope.maybeOf(context);
                if (account != null) {
                  unawaited(openAccount(context, controller: account));
                }
            }
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gallery: contained photo, thumbs, fav + share, sold-out seal
// ---------------------------------------------------------------------------

class _Gallery extends StatelessWidget {
  const _Gallery({
    required this.product,
    required this.images,
    required this.page,
    required this.controller,
    required this.wishlisted,
    required this.inStock,
    required this.onPageChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onToggleWishlist,
    required this.onShare,
    required this.shareKey,
    required this.onZoom,
  });

  final Product product;
  final List<String?> images;
  final int page;
  final PageController controller;
  final bool wishlisted;
  final bool inStock;
  final ValueChanged<int> onPageChanged;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onToggleWishlist;
  final VoidCallback onShare;
  final GlobalKey shareKey;
  final VoidCallback? onZoom;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      child: ColoredBox(
        color: palette.surfaceDeep,
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: controller,
                itemCount: images.length,
                onPageChanged: onPageChanged,
                itemBuilder: (_, i) => Hero(
                  tag: i == 0
                      ? 'product-image-${product.id}'
                      : 'p-${product.id}-$i',
                  // `contain`: handles and straps are the recognisable
                  // part — `cover` crops exactly those.
                  child: InkWell(
                    onTap: onZoom,
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 2.2,
                      child: PackshotBlend(
                        ground: palette.surfaceDeep,
                        child: MonettaImage(
                          url: images[i],
                          fit: BoxFit.contain,
                          cacheWidth: MediaUrl.heroWidth,
                          fallbackLabel:
                              '${shopperProductName(product.title)} · Monetta',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (!inStock)
                const Positioned(
                  left: 8,
                  bottom: 4,
                  child: ProductSoldOutBadge(),
                ),
              if (onPrevious != null)
                Positioned(
                  left: BoutiqueSpace.xs,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _RoundPhotoButton(
                      buttonKey: const Key('product-gallery-prev'),
                      tooltip: 'Foto anterior',
                      icon: Icons.chevron_left,
                      onPressed: onPrevious!,
                    ),
                  ),
                ),
              if (onNext != null)
                Positioned(
                  right: BoutiqueSpace.xs,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _RoundPhotoButton(
                      buttonKey: const Key('product-gallery-next'),
                      tooltip: 'Foto siguiente',
                      icon: Icons.chevron_right,
                      onPressed: onNext!,
                    ),
                  ),
                ),
              // The heart (and the share control under it) sits top right,
              // the zoom bottom right. The heart only toggles the wishlist —
              // it never navigates.
              Positioned(
                top: BoutiqueSpace.xs,
                right: BoutiqueSpace.xs,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ProductFavoriteButton(
                      key: const Key('product-header-favorite'),
                      selected: wishlisted,
                      onPhoto: true,
                      onPressed: onToggleWishlist,
                    ),
                    _RoundPhotoButton(
                      buttonKey: shareKey,
                      tooltip: 'Compartir',
                      icon: Icons.ios_share,
                      onPressed: onShare,
                    ),
                  ],
                ),
              ),
              if (onZoom != null)
                Positioned(
                  bottom: BoutiqueSpace.xs,
                  right: BoutiqueSpace.xs,
                  child: _RoundPhotoButton(
                    buttonKey: const Key('product-gallery-zoom'),
                    tooltip: 'Ampliar foto',
                    icon: Icons.zoom_in,
                    onPressed: onZoom ?? () {},
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundPhotoButton extends StatelessWidget {
  const _RoundPhotoButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.buttonKey,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final Key? buttonKey;

  /// Visible disc; the touch zone around it is the full 48pt.
  static const double _disc = 40;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    // White at 92 % over the photograph; in the dark theme the surface does
    // the same job, because the ink there is light.
    final ground = Theme.of(context).brightness == Brightness.dark
        ? palette.surfaceDeep.withValues(alpha: 0.92)
        : const Color(0xEBFFFFFF);
    return Semantics(
      button: true,
      label: tooltip,
      child: SizedBox(
        key: buttonKey,
        width: BoutiqueSpace.tapTarget,
        height: BoutiqueSpace.tapTarget,
        child: Material(
          type: MaterialType.transparency,
          child: InkResponse(
            onTap: onPressed,
            radius: BoutiqueSpace.tapTarget / 2,
            child: Tooltip(
              message: tooltip,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: ground,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: _disc,
                    height: _disc,
                    child: Icon(
                      icon,
                      size: 19,
                      color: palette.ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Four equal square thumbnails across the content; a fifth photograph and
/// beyond are reached with the arrows and by swiping the gallery.
class _Thumbnails extends StatelessWidget {
  const _Thumbnails({
    required this.images,
    required this.active,
    required this.title,
    required this.onSelect,
  });

  final List<String?> images;
  final int active;
  final String title;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Padding(
      padding: const EdgeInsets.only(top: BoutiqueSpace.sm),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = BoutiqueSpace.sm;
          final thumb = (constraints.maxWidth - gap * 3) / 4;
          final shown = math.min(images.length, 4);
          return Row(
            children: [
              for (var i = 0; i < shown; i++)
                Padding(
                  padding: EdgeInsets.only(right: i == shown - 1 ? 0 : gap),
                  child: Semantics(
                    button: true,
                    selected: i == active,
                    label: 'Foto ${i + 1} de ${images.length}',
                    child: InkWell(
                      onTap: () => onSelect(i),
                      child: Container(
                        key: ValueKey('thumb-$i'),
                        width: thumb,
                        height: thumb,
                        decoration: BoxDecoration(
                          color: palette.surfaceDeep,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: i == active
                                ? palette.borderControl
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6.5),
                          child: PackshotBlend(
                            ground: palette.surfaceDeep,
                            child: MonettaImage(
                              url: images[i],
                              fit: BoxFit.contain,
                              cacheWidth: MediaUrl.thumbWidth,
                              fallbackLabel: title,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info blocks
// ---------------------------------------------------------------------------

class _AvailabilityLine extends StatelessWidget {
  const _AvailabilityLine({required this.inStock});

  final bool inStock;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: inStock ? MonettaTokens.success : palette.sale,
          ),
        ),
        const SizedBox(width: BoutiqueSpace.sm),
        Expanded(
          child: Text(
            inStock ? 'Disponible' : 'Esta opción no está disponible',
            style: boutiqueText(size: 12, color: palette.inkMuted, height: 1.4),
          ),
        ),
      ],
    );
  }
}

/// Narrowest width that still holds the three guarantees side by side.
const double _kTrustRowMin = 340;

class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    // Three guarantees of the guide. The delivery days are the ones the
    // availability line below already states (3 a 5 días).
    const items = <(IconData, String, String)>[
      (
        Icons.verified_user_outlined,
        'Productos originales',
        'Garantía de autenticidad',
      ),
      (Icons.credit_card_outlined, 'Pago seguro', 'Compra con confianza'),
    ];

    Widget item(int i) => Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(items[i].$1, size: 26, color: palette.ink),
            const SizedBox(width: BoutiqueSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    items[i].$2,
                    style: boutiqueText(
                      size: 12,
                      weight: FontWeight.w600,
                      color: palette.ink,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    items[i].$3,
                    style: boutiqueText(
                      size: 11.5,
                      color: palette.inkMuted,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

    final stacked = Column(
      key: const Key('product-trust-row'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: BoutiqueSpace.md),
          item(i),
        ],
      ],
    );
    // With enlarged text three columns would truncate the copy: stack them.
    if (StorefrontLayout.enlargedText(MediaQuery.textScalerOf(context))) {
      return stacked;
    }
    // So would a narrow column, such as a two-sided window's right side,
    // where «autenticidad» no longer fits a third of the width.
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < _kTrustRowMin
          ? stacked
          : _trustColumns(palette, items.length, item),
    );
  }

  Widget _trustColumns(
    BoutiquePalette palette,
    int count,
    Widget Function(int) item,
  ) {
    return IntrinsicHeight(
      key: const Key('product-trust-row'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: BoutiqueSpace.sm,
                ),
                child: VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: palette.hairline,
                ),
              ),
            Expanded(child: item(i)),
          ],
        ],
      ),
    );
  }
}

class _BoutiqueAccordion extends StatelessWidget {
  const _BoutiqueAccordion({
    required this.label,
    required this.open,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool open;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.hairline, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            expanded: open,
            label: label,
            child: TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: BoutiqueSpace.tapTarget,
                ),
                padding: const EdgeInsets.symmetric(vertical: BoutiqueSpace.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: boutiqueSectionHeading(
                          size: 18,
                          color: palette.ink,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: reduceMotion(context) ? Duration.zero : kSnap,
                      child: Icon(
                        Icons.expand_more,
                        size: 20,
                        color: palette.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (open) ...[
            Padding(
              padding: const EdgeInsets.only(
                bottom: BoutiqueSpace.lg,
                right: BoutiqueSpace.sm,
              ),
              child: child,
            ),
          ],
        ],
      ),
    );
  }
}

/// A horizontal rail of related pieces.
///
/// Lazy common cards over one stable set, with manual paging and a full-set
/// route. Each real ID appears once; reduced motion uses immediate movement.
class _Rail extends StatefulWidget {
  const _Rail({required this.products, required this.title, super.key});
  final List<Product> products;
  final String title;
  @override
  State<_Rail> createState() => _RailState();
}

class _RailState extends State<_Rail> {
  final _controller = ScrollController();
  final _selections = <String, String>{};
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _move(double delta) {
    final position = _controller.position;
    final target =
        (_controller.offset + delta).clamp(0.0, position.maxScrollExtent);
    if (reduceMotion(context)) {
      _controller.jumpTo(target);
    } else {
      _controller.animateTo(target, duration: kSwap, curve: kMotionCurve);
    }
  }

  Future<void> _viewSet() async {
    final store = StoreScope.of(context);
    final titleStyle = boutiqueText(
      size: 20,
      weight: FontWeight.w600,
      color: context.boutique.ink,
    );
    final titlePainter = TextPainter(
      text: TextSpan(text: widget.title, style: titleStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: math.max(1, MediaQuery.sizeOf(context).width - 112));
    final toolbarHeight = math.max(kToolbarHeight, titlePainter.height + 16);
    titlePainter.dispose();
    await Navigator.of(context).push<void>(
      monettaFadeRoute(
        StoreScope(
          notifier: store,
          child: Scaffold(
            appBar: AppBar(
              toolbarHeight: toolbarHeight,
              title: Text(
                widget.title,
                style: titleStyle,
                softWrap: true,
                overflow: TextOverflow.visible,
              ),
            ),
            body: LayoutBuilder(
              builder: (context, constraints) => GridView.builder(
                key: ValueKey('product-set-grid-${widget.title}'),
                padding: const EdgeInsets.all(16),
                gridDelegate: productGridDelegate(
                  context,
                  availableWidth: constraints.maxWidth - 32,
                ),
                itemCount: widget.products.length,
                itemBuilder: (_, index) {
                  final product = widget.products[index];
                  return ProductCard(
                    key: ValueKey(product.id),
                    product: product,
                    initialVariantId: _selections[product.id],
                    onVariantChanged: (id) {
                      if (id != null) _selections[product.id] = id;
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final enlarged = StorefrontLayout.enlargedText(textScaler);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const density = ProductTileDensity.compact;
        final tileWidth = enlarged
            ? math.min(320.0, width * .85)
            : math.min(260.0, width * .55);
        return Column(
          children: [
            SizedBox(
              height: productTileExtent(
                tileWidth: tileWidth,
                textScaler: textScaler,
                density: density,
              ),
              child: ListView.separated(
                key: const Key('product-rail'),
                controller: _controller,
                clipBehavior: Clip.none,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: BoutiqueSpace.gutter,
                ),
                // Lazy construction/photography over an already authoritative,
                // stable set. Fewer than 40 remains the real count.
                itemCount: widget.products.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final product = widget.products[index];
                  return SizedBox(
                    width: tileWidth,
                    child: ProductCard(
                      key: ValueKey(product.id),
                      product: product,
                      density: density,
                      initialVariantId: _selections[product.id],
                      onVariantChanged: (id) {
                        if (id != null) _selections[product.id] = id;
                      },
                    ),
                  );
                },
              ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Productos anteriores',
                  onPressed: () => _move(-tileWidth),
                  icon: const Icon(Icons.chevron_left),
                ),
                TextButton(
                  key: ValueKey('product-set-${widget.title}'),
                  onPressed: _viewSet,
                  style: TextButton.styleFrom(
                    foregroundColor: context.boutique.ink,
                  ),
                  child: Text('Ver ${widget.title.toLowerCase()}'),
                ),
                IconButton(
                  tooltip: 'Productos siguientes',
                  onPressed: () => _move(tileWidth),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
