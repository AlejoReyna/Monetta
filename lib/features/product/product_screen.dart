/// Ficha de producto Fig.07 — boutique cálida.
///
/// Galería cuadrada y contenida (nunca recorta asas) con cuatro miniaturas,
/// fav, compartir, zoom y flechas; marca + nombre + precio con `-X%` solo
/// cuando `compare_at` lo respalda; swatches solo con mapeo fiable
/// ([ProductOptionSelector]); fila de confianza; «Agregar a bolsa» y «Comprar
/// ahora»; disponibilidad y frase de apartado; acordeones Descripción–
/// Detalles–Envíos (cerrados al abrir); «Apartar»; relacionados en cuatro
/// tarjetas mini con la [ProductCard] compartida.
///
/// Agotado abre igual pero se distingue (sello + CTA de aviso en el muelle). El corazón
/// solo guarda — jamás navega.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/media/monetta_image.dart';
import '../../app/motion.dart';
import '../../app/storefront_layout.dart';
import '../../app/shopper_copy.dart';
import '../../app/theme.dart';
import '../../data/media/media_url.dart';
import '../../data/normalize/facets.dart';
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
import '../checkout/mini_cart.dart' show showMiniCart;
import '../navigation/guide_chrome.dart';
import '../navigation/guide_drawer.dart';
import '../navigation/monetta_bottom_navigation.dart';
import 'product_selection.dart';
import 'product_adaptive_body.dart';
import '../navigation/adaptive_storefront_scaffold.dart';
import '../../platform/system_layout_context.dart';
import '../../data/shopify/storefront_config.dart';
import 'purchase_dock.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({
    required this.productId,
    this.initialVariantIndex = 0,
    this.onClose,
    super.key,
  });

  final String productId;

  /// Variante seleccionada en la vista rápida u otra superficie previa.
  /// Se conserva al abrir la ficha para no perder la elección.
  final int initialVariantIndex;
  final VoidCallback? onClose;

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final Stopwatch _dwell = Stopwatch()..start();
  final PageController _gallery = PageController();
  final GlobalKey _shareSource = GlobalKey();
  String? _variantId;
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
    final request = ApartadoRequest(
      productTitle: product.title,
      productHandle: product.handle,
      price: selectedVariant(product, _variantIndex)?.price ?? product.price,
      attributionCode: const AttributionCodeGenerator().generate(
        DateTime.now().microsecondsSinceEpoch,
      ),
    );
    final launched = await launchUrl(
      request.uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp')),
      );
    }
  }

  Future<void> _openConcierge(Product product) async {
    final launched = await launchUrl(
      conciergeWhatsAppUri(productTitle: product.title),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp')),
      );
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

  Future<void> _createRestockAlert(Product product) async {
    final notifications = NotificationScope.maybeOf(context);
    if (notifications == null || !notifications.available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Los avisos todavía no están disponibles en esta versión.',
          ),
        ),
      );
      return;
    }
    final ok = await notifications.createRestockAlert(product.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Te avisaremos cuando esta pieza vuelva.'
              : notifications.lastError ?? 'No pudimos crear el aviso.',
        ),
      ),
    );
  }

  Future<void> _add(Product product) => _purchase(product, buyNow: false);

  Future<void> _buyNow(Product product) => _purchase(product, buyNow: true);

  /// Both purchase actions go through [tryAddSelectionToBag]; they differ only
  /// in what follows a successful add. The selected variant is never changed,
  /// whatever the outcome.
  Future<void> _purchase(Product product, {required bool buyNow}) async {
    if (_adding) return;
    setState(() => _adding = true);
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
          await showMiniCart(context);
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

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final product = store.products.firstWhere((p) => p.id == widget.productId);
    final facets = store.facetsFor(product.id);
    final wishlisted = store.wishlist.contains(product.id);
    final selectable = selectableVariants(product);
    _variantId ??= selectedVariant(product, _variantIndex)?.id;
    final selectedPosition = selectable.indexWhere((v) => v.id == _variantId);
    if (selectedPosition >= 0) _variantIndex = selectedPosition;
    final selectionMissing =
        _variantId != null && !product.variants.any((v) => v.id == _variantId);
    final selected =
        selectionMissing ? null : selectedVariant(product, _variantIndex);
    final price = selected?.price ?? product.price;
    final compare = selected?.compareAtPrice ?? product.compareAtPrice;
    final onSale = selectionOnSale(product, _variantIndex);
    final discount = selectionDiscountPercent(product, _variantIndex);
    final inStock =
        !selectionMissing && selectionInStock(product, _variantIndex);
    final images = product.images.isEmpty ? <String?>[null] : product.images;
    final shopifyDescription = shopifyDescriptionText(product.descriptionHtml);
    // Shopify remains the primary source of truth. When it is genuinely empty,
    // compose one conservative sentence from normalized catalog facts.
    final description = shopifyDescription.isNotEmpty
        ? shopifyDescription
        : factualDescription(
            title: product.title,
            brandSlug: facets?.brand?.value,
            categorySlug: facets?.category?.value,
            silhouetteSlug: facets?.silhouette?.value,
            colorSlug: facets == null || facets.colors.isEmpty
                ? null
                : facets.colors.first.value,
          );
    final recent = store.recentlyViewed(excluding: product.id);
    final related = facets?.brand?.value == null
        ? const <Product>[]
        : store.moreFromBrand(facets!.brand!.value, excluding: product.id);
    final notifications = NotificationScope.maybeOf(context);
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
                          style: boutiqueDisplay(22, color: palette.ink),
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
                          onSelect: (i) => setState(() {
                            _variantIndex = i;
                            _variantId = selectable[i].id;
                          }),
                        ),
                      ],
                      const SizedBox(height: BoutiqueSpace.lg),
                      const _TrustRow(),
                      const SizedBox(height: BoutiqueSpace.lg),
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
                      if (inStock) ...[
                        const SizedBox(height: BoutiqueSpace.sm),
                        Text(
                          kApartadoSentence,
                          style: boutiqueText(
                            size: 13,
                            color: palette.ink,
                            height: 1.45,
                          ),
                        ),
                      ],
                      if (!inStock) ...[
                        const SizedBox(height: BoutiqueSpace.sm),
                        KeyedSubtree(
                          key: const ValueKey('create-restock-alert'),
                          child: PurchaseDockButton(
                            key: const Key('purchase-dock-primary'),
                            label: notifications?.saving == true
                                ? 'Guardando…'
                                : 'Avísame cuando vuelva',
                            large: true,
                            onPressed: notifications?.saving == true
                                ? null
                                : () => _createRestockAlert(product),
                          ),
                        ),
                      ],
                      const SizedBox(height: BoutiqueSpace.lg),
                      Divider(height: 1, thickness: 1, color: palette.hairline),
                      _BoutiqueAccordion(
                        label: 'Descripción',
                        open: _open.contains('descripcion'),
                        onTap: () => setState(() {
                          _open.contains('descripcion')
                              ? _open.remove('descripcion')
                              : _open.add('descripcion');
                        }),
                        child: Text(
                          (description == null || description.isEmpty)
                              ? 'Pieza original importada de Estados Unidos.'
                              : description,
                          style: boutiqueText(
                            size: 14,
                            color: palette.ink,
                            height: 1.6,
                          ),
                        ),
                      ),
                      _BoutiqueAccordion(
                        label: 'Detalles',
                        open: _open.contains('detalles'),
                        onTap: () => setState(() {
                          _open.contains('detalles')
                              ? _open.remove('detalles')
                              : _open.add('detalles');
                        }),
                        child: _Details(facets: facets),
                      ),
                      _BoutiqueAccordion(
                        label: 'Envíos y devoluciones',
                        open: _open.contains('envio'),
                        onTap: () => setState(() {
                          _open.contains('envio')
                              ? _open.remove('envio')
                              : _open.add('envio');
                        }),
                        child: Text(
                          'Envío a todo México en 3 a 5 días hábiles, por DHL, FedEx o Estafeta. '
                          'Si la pieza no es lo que esperabas, escríbenos por WhatsApp y lo resolvemos.',
                          style: boutiqueText(
                            size: 14,
                            color: palette.ink,
                            height: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: BoutiqueSpace.sm),
                      _WhatsAppLink(onTap: () => _openConcierge(product)),
                      const SizedBox(height: BoutiqueSpace.xl),
                      _PurchaseSection(
                        onApartado: () => _openApartado(product),
                      ),
                    ],
                  ),
                ),
                if (related.isNotEmpty) ...[
                  const SizedBox(height: BoutiqueSpace.xxl),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      BoutiqueSpace.gutter,
                      0,
                      BoutiqueSpace.gutter,
                      BoutiqueSpace.md,
                    ),
                    child: Text(
                      'Productos relacionados',
                      style: boutiqueSectionHeading(
                        context: context,
                        color: palette.ink,
                      ),
                    ),
                  ),
                  _Rail(products: related),
                ],
                if (recent.isNotEmpty) ...[
                  const SizedBox(height: BoutiqueSpace.xxl),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      BoutiqueSpace.gutter,
                      0,
                      BoutiqueSpace.gutter,
                      BoutiqueSpace.md,
                    ),
                    child: Text(
                      'Vistas hace un momento',
                      style: boutiqueSectionHeading(
                        context: context,
                        color: palette.ink,
                      ),
                    ),
                  ),
                  _Rail(products: recent),
                ],
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
                Navigator.of(context).popUntil((route) => route.isFirst);
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
              if (!inStock)
                IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: BoutiqueSpace.lg,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: palette.canvas,
                        borderRadius: BoutiqueRadius.capsule,
                        border: Border.all(color: palette.ink, width: 1),
                      ),
                      child: Text(
                        'AGOTADO',
                        style: boutiqueEyebrow(size: 11, color: palette.ink),
                      ),
                    ),
                  ),
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
                    _RoundPhotoButton(
                      buttonKey: const Key('product-header-favorite'),
                      tooltip: wishlisted ? 'Quitar de guardados' : 'Guardar',
                      icon: wishlisted ? Icons.favorite : Icons.favorite_border,
                      filled: wishlisted,
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
              Positioned(
                bottom: BoutiqueSpace.xs,
                right: BoutiqueSpace.xs,
                child: _RoundPhotoButton(
                  buttonKey: const Key('product-gallery-zoom'),
                  tooltip: 'Ampliar foto',
                  icon: Icons.zoom_in,
                  onPressed: () => _openZoom(
                    context,
                    images[page],
                    shopperProductName(product.title),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _openZoom(BuildContext context, String? url, String title) {
  final palette = context.boutique;
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: palette.canvas,
      insetPadding: const EdgeInsets.all(BoutiqueSpace.md),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: MonettaImage(
                url: url,
                fit: BoxFit.contain,
                cacheWidth: MediaUrl.heroWidth,
                fallbackLabel: title,
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RoundPhotoButton extends StatelessWidget {
  const _RoundPhotoButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.buttonKey,
    this.filled = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final Key? buttonKey;
  final bool filled;

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
      toggled: filled,
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
                      color: filled ? palette.goldText : palette.ink,
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
                    child: GestureDetector(
                      onTap: () => onSelect(i),
                      behavior: HitTestBehavior.opaque,
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
            color: inStock ? const Color(0xFF3B7B4A) : palette.sale,
          ),
        ),
        const SizedBox(width: BoutiqueSpace.sm),
        Expanded(
          child: Text(
            inStock
                ? 'Disponible · envío 3 a 5 días'
                : 'Agotado · te avisamos cuando vuelva',
            style: boutiqueText(size: 12, color: palette.inkMuted, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    // Three guarantees of the guide. The delivery days are the ones the
    // availability line below already states (3 a 5 días).
    const items = <(IconData, String, String)>[
      (Icons.inventory_2_outlined, 'Entrega estimada', '3 a 5 días'),
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

    // With enlarged text three columns would truncate the copy: stack them.
    if (StorefrontLayout.enlargedText(MediaQuery.textScalerOf(context))) {
      return Column(
        key: const Key('product-trust-row'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: BoutiqueSpace.md),
            item(i),
          ],
        ],
      );
    }
    return IntrinsicHeight(
      key: const Key('product-trust-row'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
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
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
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

class _WhatsAppLink extends StatelessWidget {
  const _WhatsAppLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Semantics(
      button: true,
      label: 'Escribir por WhatsApp',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minHeight: BoutiqueSpace.tapTarget),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Icon(Icons.chat_outlined, size: 16, color: palette.ink),
              const SizedBox(width: BoutiqueSpace.sm),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Escribir por WhatsApp',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: boutiqueText(size: 13, color: palette.ink),
                    ),
                    const SizedBox(height: 4),
                    Container(height: 1, width: 140, color: palette.ink),
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

/// Apartar stays available after the product information. The guide's two
/// purchase buttons sit above the accordions.
class _PurchaseSection extends StatelessWidget {
  const _PurchaseSection({required this.onApartado});

  final VoidCallback onApartado;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Column(
      key: const Key('purchase-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Otras formas de comprar',
          style: boutiqueSectionHeading(context: context, color: palette.ink),
        ),
        const SizedBox(height: BoutiqueSpace.md),
        Center(
          child: TextButton(
            key: const Key('purchase-apartar'),
            onPressed: onApartado,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, BoutiqueSpace.tapTarget),
              foregroundColor: palette.ink,
            ),
            child: Text(
              'Apartar',
              style: boutiqueText(size: 14, weight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.facets});

  final CanonicalFacets? facets;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final rows = <(String, String)>[
      if (facets?.category != null)
        ('Tipo', categoryLabel(facets!.category!.value)),
      if (facets?.silhouette != null)
        ('Forma', silhouetteLabel(facets!.silhouette!.value)),
      if (facets != null && facets!.colors.isNotEmpty)
        ('Color', facets!.colors.map((c) => colorLabel(c.value)).join(', ')),
      if (facets != null && facets!.patterns.isNotEmpty)
        (
          'Motivo',
          facets!.patterns.map((p) => patternLabel(p.value)).join(', '),
        ),
    ];
    if (rows.isEmpty) {
      return Text(
        'Pieza original importada de Estados Unidos.',
        style: boutiqueText(size: 14, color: palette.ink, height: 1.6),
      );
    }
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 88,
                  child: Text(
                    row.$1,
                    style: boutiqueText(size: 12, color: palette.inkMuted),
                  ),
                ),
                Expanded(
                  child: Text(
                    row.$2,
                    style: boutiqueText(size: 13, color: palette.ink),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A horizontal rail of related pieces.
///
/// Four [ProductTileDensity.mini] cards across the width, scrolling when there
/// are more. With enlarged text four across would not fit a caption, so the
/// rail falls back to the regular compact card at about 40 % of the width.
class _Rail extends StatelessWidget {
  const _Rail({required this.products});

  final List<Product> products;

  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final enlarged = StorefrontLayout.enlargedText(textScaler);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final density =
            enlarged ? ProductTileDensity.compact : ProductTileDensity.mini;
        final tileWidth = enlarged
            ? width * 0.4
            : (width - 2 * BoutiqueSpace.gutter - 3 * _gap) / 4;
        return SizedBox(
          height: productTileExtent(
            tileWidth: tileWidth,
            textScaler: textScaler,
            density: density,
            footerExtent: enlarged ? null : 0,
          ),
          child: ListView.separated(
            key: const Key('product-rail'),
            clipBehavior: Clip.none,
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: BoutiqueSpace.gutter),
            itemCount: products.length,
            separatorBuilder: (_, __) => SizedBox(
              width: enlarged ? BoutiqueSpace.md : _gap,
            ),
            itemBuilder: (context, index) {
              final product = products[index];
              return SizedBox(
                width: tileWidth,
                child: ProductCard(
                  product: product,
                  density: density,
                  showViewProduct: enlarged,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
