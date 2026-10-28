/// Ficha de producto Fig.07 — boutique cálida.
///
/// Galería contenida (nunca recorta asas) con miniaturas, fav y compartir;
/// marca + nombre + precio con `-X%` solo cuando `compare_at` lo respalda;
/// swatches solo con mapeo fiable ([ProductOptionSelector]); envío y entrega
/// estimadas; muelle inferior con «Agregar a bolsa» y, al final de la
/// información, «Otras formas de comprar» (comprar ahora y apartar); confianza;
/// acordeones Descripción–Detalles–Envíos; relacionados con la [ProductCard]
/// compartida.
///
/// Agotado abre igual pero se distingue (sello + CTA de aviso en el muelle). El corazón
/// solo guarda — jamás navega.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/media/monetta_image.dart';
import '../../app/motion.dart';
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
import 'quick_view.dart';

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
    // The live catalog (realtime listener / Shopify delta sync) can replace
    // `store.products` while this screen is open, e.g. right after "Agregar"
    // on a slow network. A product that is unpublished or removed must not
    // crash the detail screen with `StateError: No element`.
    Product? found;
    for (final candidate in store.products) {
      if (candidate.id == widget.productId) {
        found = candidate;
        break;
      }
    }
    if (found == null) return const _ProductUnavailable();
    final product = found;
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
            gallery: (height) => Column(
              children: [
                SizedBox(
                  height: height,
                  child: _Gallery(
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
                      const SizedBox(height: BoutiqueSpace.lg),
                      Wrap(
                        spacing: BoutiqueSpace.md,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            kMoney.format(price),
                            style: boutiqueText(
                              size: 20,
                              weight: FontWeight.w700,
                              color: inStock ? palette.ink : palette.inkMuted,
                              height: 1.2,
                            ),
                          ),
                          // Previous price + -% render only off real
                          // `compare_at` data — never otherwise.
                          if (onSale && compare != null) ...[
                            Text(
                              kMoney.format(compare),
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
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.saleSurface,
                                  borderRadius: BoutiqueRadius.capsule,
                                ),
                                child: Text(
                                  '-$discount%',
                                  style: boutiqueEyebrow(
                                    size: 11,
                                    color: palette.sale,
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                      if (selectable.isNotEmpty) ...[
                        const SizedBox(height: BoutiqueSpace.xl),
                        ProductOptionSelector(
                          product: product,
                          selectedIndex: _variantIndex,
                          onSelect: (i) => setState(() {
                            _variantIndex = i;
                            _variantId = selectable[i].id;
                          }),
                        ),
                      ],
                      const SizedBox(height: BoutiqueSpace.xl),
                      const _TrustRow(),
                      const SizedBox(height: BoutiqueSpace.lg),
                      if (inStock) ...[
                        PurchaseDockButton(
                          key: const Key('purchase-dock-primary'),
                          label: _adding ? 'AGREGANDO…' : 'AGREGAR A BOLSA',
                          pending: _adding,
                          onPressed: _adding ? null : () => _add(product),
                        ),
                        const SizedBox(height: BoutiqueSpace.sm),
                        BoutiqueButton(
                          key: const Key('purchase-buy-now'),
                          label: 'COMPRAR AHORA',
                          filled: false,
                          onPressed: _adding ? null : () => _buyNow(product),
                        ),
                        const SizedBox(height: BoutiqueSpace.lg),
                        Text(
                          kApartadoSentence,
                          style: boutiqueText(
                            size: 13,
                            color: palette.ink,
                            height: 1.45,
                          ),
                        ),
                      ],
                      const SizedBox(height: BoutiqueSpace.sm),
                      _AvailabilityLine(inStock: inStock),
                      if (!inStock)
                        KeyedSubtree(
                          key: const ValueKey('create-restock-alert'),
                          child: PurchaseDockButton(
                            key: const Key('purchase-dock-primary'),
                            label: notifications?.saving == true
                                ? 'Guardando…'
                                : 'Avísame cuando vuelva',
                            onPressed: notifications?.saving == true
                                ? null
                                : () => _createRestockAlert(product),
                          ),
                        ),
                      const SizedBox(height: BoutiqueSpace.lg),
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
                          'Gratis desde ${kMoney.format(kFreeShippingThreshold)}. '
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
    return ColoredBox(
      color: palette.surfaceDeep,
      child: AspectRatio(
        aspectRatio: 4 / 5,
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
                // `contain` + inset: handles and straps are the
                // recognisable part — `cover` crops exactly those.
                child: Padding(
                  padding: const EdgeInsets.all(BoutiqueSpace.sm),
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 2.2,
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
            // Fav, zoom and share sit over the photo. The heart only
            // toggles the wishlist — it never navigates.
            Positioned(
              top: BoutiqueSpace.sm,
              right: BoutiqueSpace.sm,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RoundPhotoButton(
                    buttonKey: const Key('product-header-favorite'),
                    tooltip: wishlisted ? 'Quitar de guardados' : 'Guardar',
                    icon: wishlisted ? Icons.favorite : Icons.favorite_border,
                    filled: wishlisted,
                    onPressed: onToggleWishlist,
                  ),
                  const SizedBox(width: BoutiqueSpace.sm),
                  _RoundPhotoButton(
                    buttonKey: const Key('product-gallery-zoom'),
                    tooltip: 'Ampliar foto',
                    icon: Icons.zoom_in,
                    onPressed: () => _openZoom(
                      context,
                      images[page],
                      shopperProductName(product.title),
                    ),
                  ),
                  const SizedBox(width: BoutiqueSpace.sm),
                  _RoundPhotoButton(
                    buttonKey: shareKey,
                    tooltip: 'Compartir',
                    icon: Icons.ios_share,
                    onPressed: onShare,
                  ),
                ],
              ),
            ),
            if (images.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: BoutiqueSpace.lg,
                child: _RuleIndicator(count: images.length, active: page),
              ),
          ],
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

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Semantics(
      button: true,
      toggled: filled,
      label: tooltip,
      child: SizedBox(
        key: buttonKey,
        width: BoutiqueSpace.tapTarget,
        height: BoutiqueSpace.tapTarget,
        child: Center(
          child: Material(
            color: palette.surface,
            shape: const CircleBorder(),
            elevation: 0,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Tooltip(
                message: tooltip,
                child: SizedBox(
                  width: BoutiqueSpace.tapTarget,
                  height: BoutiqueSpace.tapTarget,
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
    );
  }
}

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
    return Container(
      color: palette.surfaceDeep,
      padding: const EdgeInsets.fromLTRB(
        BoutiqueSpace.gutter,
        BoutiqueSpace.sm,
        BoutiqueSpace.gutter,
        BoutiqueSpace.md,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = BoutiqueSpace.sm;
          // Four thumbs across, matching the guide strip. Extra photos scroll.
          final thumb = (constraints.maxWidth - gap * 3) / 4;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < images.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      right: i == images.length - 1 ? 0 : gap,
                    ),
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
                            color: palette.surface,
                            borderRadius: BoutiqueRadius.tile,
                            border: Border.all(
                              color:
                                  i == active ? palette.ink : palette.hairline,
                              width: i == active ? 1.5 : 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BoutiqueRadius.tile,
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
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RuleIndicator extends StatelessWidget {
  const _RuleIndicator({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final on = i == active;
        return AnimatedContainer(
          duration: reduceMotion(context) ? Duration.zero : kSnap,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: on ? 22 : 12,
          height: 2,
          decoration: BoxDecoration(
            color: on ? palette.ink : palette.ink.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
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
                ? 'Disponible · envío 3 a 5 días · gratis desde ${kMoney.format(kFreeShippingThreshold)}'
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
    return Container(
      key: const Key('product-trust-row'),
      padding: const EdgeInsets.symmetric(vertical: BoutiqueSpace.md),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: palette.hairline, width: 1),
          bottom: BorderSide(color: palette.hairline, width: 1),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) Container(width: 1, color: palette.hairline),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: BoutiqueSpace.xs,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(items[i].$1, size: 22, color: palette.ink),
                      const SizedBox(width: BoutiqueSpace.xs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              items[i].$2,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: boutiqueText(
                                size: 11,
                                weight: FontWeight.w600,
                                color: palette.ink,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              items[i].$3,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: boutiqueText(
                                size: 10,
                                color: palette.inkMuted,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
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
                          context: context,
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

class _Rail extends StatelessWidget {
  const _Rail({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final tileWidth = MediaQuery.sizeOf(context).width * 0.52;
    // 12pt photo gap plus ~120pt for brand, two-line name and price, matching
    // the grid caption contract. The caption is text, so it grows with the
    // text scale; the gap does not.
    final caption = MediaQuery.textScalerOf(context).scale(120);
    return SizedBox(
      height: tileWidth * 1.25 + 12 + caption,
      child: ListView.separated(
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: BoutiqueSpace.gutter),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: BoutiqueSpace.md),
        itemBuilder: (context, index) {
          final product = products[index];
          return SizedBox(
            width: tileWidth,
            child: ProductCard(
              product: product,
              onQuickView: () => showProductQuickView(context, product),
            ),
          );
        },
      ),
    );
  }
}


/// Shown when the product is no longer in the live catalog (removed or
/// unpublished in Shopify while the shopper was viewing it).
class _ProductUnavailable extends StatelessWidget {
  const _ProductUnavailable();

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    return Scaffold(
      key: const Key('product-unavailable'),
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Este producto ya no está disponible.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Lo que ya agregaste a tu bolsa se conserva.',
                  textAlign: TextAlign.center,
                ),
                if (navigator.canPop()) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    key: const Key('product-unavailable-back'),
                    onPressed: () => navigator.maybePop(),
                    child: const Text('Volver'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
