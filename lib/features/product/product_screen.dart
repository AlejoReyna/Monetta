/// Ficha de producto Fig.07 — boutique cálida.
///
/// Galería contenida (nunca recorta asas) con miniaturas, fav y compartir;
/// marca + nombre + precio con `-X%` solo cuando `compare_at` lo respalda;
/// swatches solo con mapeo fiable ([ProductOptionSelector]); envío y entrega
/// estimadas; agregar + comprar ahora; confianza; acordeones
/// Descripción–Detalles–Envíos; relacionados con la [ProductCard] compartida.
///
/// Agotado abre igual pero se distingue (sello + CTA de aviso). El corazón
/// solo guarda — jamás navega.
library;

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
import '../boutique/boutique_tokens.dart';
import '../catalog/product_card.dart';
import '../checkout/checkout_screen.dart';
import 'product_selection.dart';
import 'quick_view.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({
    required this.productId,
    this.initialVariantIndex = 0,
    super.key,
  });

  final String productId;

  /// Variante seleccionada en la vista rápida u otra superficie previa.
  /// Se conserva al abrir la ficha para no perder la elección.
  final int initialVariantIndex;

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final Stopwatch _dwell = Stopwatch()..start();
  final PageController _gallery = PageController();
  int _page = 0;
  late int _variantIndex = widget.initialVariantIndex;
  final Set<String> _open = <String>{};

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
    Navigator.of(context).pop();
  }

  Future<void> _openApartado(Product product) async {
    final store = StoreScope.of(context);
    store.record(EventType.whatsappApartado, productId: product.id);
    final request = ApartadoRequest(
      productTitle: product.title,
      productHandle: product.handle,
      price: selectedVariant(product, _variantIndex)?.price ?? product.price,
      attributionCode: const AttributionCodeGenerator()
          .generate(DateTime.now().microsecondsSinceEpoch),
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
    try {
      await Share.share(
        '${shopperProductName(product.title)} · ${kMoney.format(price)} en Monetta',
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
          content:
              Text('Los avisos todavía no están disponibles en esta versión.'),
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

  void _goToPage(int index) {
    setState(() => _page = index);
    if (reduceMotion(context)) {
      _gallery.jumpToPage(index);
    } else {
      _gallery.animateToPage(
        index,
        duration: kSwap,
        curve: kMotionCurve,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final product = store.products.firstWhere((p) => p.id == widget.productId);
    final facets = store.facetsFor(product.id);
    final wishlisted = store.wishlist.contains(product.id);
    final selectable = selectableVariants(product);
    final selected = selectedVariant(product, _variantIndex);
    final price = selected?.price ?? product.price;
    final compare = selected?.compareAtPrice ?? product.compareAtPrice;
    final onSale = selectionOnSale(product, _variantIndex);
    final discount = selectionDiscountPercent(product, _variantIndex);
    final inStock = selectionInStock(product, _variantIndex);
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
        : store.moreFromBrand(
            facets!.brand!.value,
            excluding: product.id,
          );
    final notifications = NotificationScope.maybeOf(context);
    final palette = context.boutique;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _recordDwellAndPop();
      },
      child: Scaffold(
        backgroundColor: palette.canvas,
        appBar: AppBar(
          backgroundColor: palette.canvas,
          foregroundColor: palette.ink,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            tooltip: 'Volver',
            onPressed: _recordDwellAndPop,
          ),
          title: const MonettaWordmark.appBar(),
          actions: [
            IconButton(
              tooltip: wishlisted ? 'Quitar de guardados' : 'Guardar',
              icon: Icon(
                wishlisted ? Icons.favorite : Icons.favorite_border,
                size: 20,
                color: wishlisted ? palette.goldText : palette.ink,
              ),
              onPressed: () => store.toggleWishlist(product.id),
            ),
            const BagAction(),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(0.5),
            child: Divider(height: 0.5, color: palette.hairline),
          ),
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _Gallery(
                product: product,
                images: images,
                page: _page,
                controller: _gallery,
                wishlisted: wishlisted,
                inStock: inStock,
                onPageChanged: (i) => setState(() => _page = i),
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
                        brandLabel(facets!.brand!.value).toUpperCase(),
                        style:
                            boutiqueEyebrow(size: 11, color: palette.inkMuted),
                      ),
                      const SizedBox(height: BoutiqueSpace.md),
                    ],
                    Text(
                      shopperProductName(product.title),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: boutiqueDisplay(24, color: palette.ink),
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
                                color: palette.sale,
                                borderRadius: BoutiqueRadius.capsule,
                              ),
                              child: Text(
                                '-$discount%',
                                style: boutiqueEyebrow(
                                  size: 11,
                                  color: const Color(0xFFFFFFFF),
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                    const SizedBox(height: BoutiqueSpace.md),
                    if (inStock)
                      Text(
                        kApartadoSentence,
                        style: boutiqueText(
                          size: 13,
                          color: palette.ink,
                          height: 1.45,
                        ),
                      ),
                    const SizedBox(height: BoutiqueSpace.sm),
                    _AvailabilityLine(inStock: inStock),
                    if (selectable.isNotEmpty) ...[
                      const SizedBox(height: BoutiqueSpace.xl),
                      ProductOptionSelector(
                        product: product,
                        selectedIndex: _variantIndex,
                        onSelect: (i) => setState(() => _variantIndex = i),
                      ),
                    ],
                    const SizedBox(height: BoutiqueSpace.xl),
                    _ShippingCard(),
                    const SizedBox(height: BoutiqueSpace.xl),
                    const _TrustRow(),
                    const SizedBox(height: BoutiqueSpace.sm),
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
                      label: 'Envíos y cambios',
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
                    facets?.brand == null
                        ? 'Más piezas'
                        : 'Más de ${brandLabel(facets!.brand!.value)}',
                    style: boutiqueTitle(color: palette.ink),
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
                    style: boutiqueTitle(color: palette.ink),
                  ),
                ),
                _Rail(products: recent),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
        bottomNavigationBar: _PurchaseBar(
          product: product,
          variantIndex: _variantIndex,
          price: price,
          compare: compare,
          onSale: onSale,
          inStock: inStock,
          notificationsSaving: notifications?.saving == true,
          onAdd: () => addToBagAndShowMiniCart(context, product, _variantIndex),
          onBuyNow: () => buyNowOpenBag(context, product, _variantIndex),
          onApartado: () => _openApartado(product),
          onRestock: () => _createRestockAlert(product),
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
    required this.onToggleWishlist,
    required this.onShare,
  });

  final Product product;
  final List<String?> images;
  final int page;
  final PageController controller;
  final bool wishlisted;
  final bool inStock;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onToggleWishlist;
  final VoidCallback onShare;

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
            // Fav + share: 48pt targets over the photo. The heart only
            // toggles the wishlist — it never navigates.
            Positioned(
              top: BoutiqueSpace.sm,
              right: BoutiqueSpace.sm,
              child: Column(
                children: [
                  _RoundPhotoButton(
                    tooltip: wishlisted ? 'Quitar de guardados' : 'Guardar',
                    icon: wishlisted ? Icons.favorite : Icons.favorite_border,
                    filled: wishlisted,
                    onPressed: onToggleWishlist,
                  ),
                  const SizedBox(height: BoutiqueSpace.sm),
                  _RoundPhotoButton(
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

class _RoundPhotoButton extends StatelessWidget {
  const _RoundPhotoButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Semantics(
      button: true,
      toggled: filled,
      label: tooltip,
      child: SizedBox(
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
                  width: 40,
                  height: 40,
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < images.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  right: i == images.length - 1 ? 0 : BoutiqueSpace.sm,
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
                      width: 56,
                      height: 68,
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BoutiqueRadius.tile,
                        border: Border.all(
                          color: i == active ? palette.ink : palette.hairline,
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

class _ShippingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Container(
      padding: const EdgeInsets.all(BoutiqueSpace.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BoutiqueRadius.card,
        border: Border.all(color: palette.hairline, width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping_outlined, size: 20, color: palette.ink),
              const SizedBox(width: BoutiqueSpace.md),
              Expanded(
                child: Text(
                  'Envío gratis desde ${kMoney.format(kFreeShippingThreshold)}',
                  style: boutiqueText(
                    size: 13,
                    weight: FontWeight.w600,
                    color: palette.ink,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: BoutiqueSpace.sm),
          Row(
            children: [
              const SizedBox(width: 32),
              Expanded(
                child: Text(
                  'Entrega estimada: 3 a 5 días hábiles a todo México.',
                  style: boutiqueText(
                    size: 12,
                    color: palette.inkMuted,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    const items = <(IconData, String)>[
      (Icons.verified_outlined, 'Original'),
      (Icons.flight_outlined, 'Importado de EE. UU.'),
      (Icons.lock_outline, 'Pago seguro'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: BoutiqueSpace.lg,
        horizontal: BoutiqueSpace.sm,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: palette.hairline, width: 1),
          bottom: BorderSide(color: palette.hairline, width: 1),
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Column(
                children: [
                  Icon(items[i].$1, size: 20, color: palette.ink),
                  const SizedBox(height: BoutiqueSpace.sm),
                  Text(
                    items[i].$2,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: boutiqueText(
                      size: 11,
                      color: palette.inkMuted,
                      height: 1.3,
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
        border: Border(
          bottom: BorderSide(color: palette.hairline, width: 1),
        ),
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
                constraints:
                    const BoxConstraints(minHeight: BoutiqueSpace.tapTarget),
                padding: const EdgeInsets.symmetric(vertical: BoutiqueSpace.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: boutiqueText(
                          size: 14,
                          weight: FontWeight.w600,
                          color: palette.ink,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: reduceMotion(context) ? Duration.zero : kSnap,
                      child:
                          Icon(Icons.expand_more, size: 20, color: palette.ink),
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
        (
          'Color',
          facets!.colors.map((c) => colorLabel(c.value)).join(', '),
        ),
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
    return SizedBox(
      // 132 reserves the 12pt photo gap plus ~120pt for brand, two-line name
      // and price, matching the grid caption contract.
      height: tileWidth * 1.25 + 132,
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

// ---------------------------------------------------------------------------
// Sticky purchase bar
// ---------------------------------------------------------------------------

class _PurchaseBar extends StatelessWidget {
  const _PurchaseBar({
    required this.product,
    required this.variantIndex,
    required this.price,
    required this.compare,
    required this.onSale,
    required this.inStock,
    required this.notificationsSaving,
    required this.onAdd,
    required this.onBuyNow,
    required this.onApartado,
    required this.onRestock,
  });

  final Product product;
  final int variantIndex;
  final double price;
  final double? compare;
  final bool onSale;
  final bool inStock;
  final bool notificationsSaving;
  final VoidCallback onAdd;
  final VoidCallback onBuyNow;
  final VoidCallback onApartado;
  final VoidCallback onRestock;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(
          top: BorderSide(color: palette.hairline, width: 1),
        ),
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          BoutiqueSpace.gutter,
          BoutiqueSpace.md,
          BoutiqueSpace.gutter,
          BoutiqueSpace.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Price + availability stack vertically so 2x text scale
            // wraps instead of overflowing a Row.
            Wrap(
              spacing: BoutiqueSpace.sm,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  kMoney.format(price),
                  style: boutiqueText(
                    size: 17,
                    weight: FontWeight.w700,
                    color: inStock ? palette.ink : palette.inkMuted,
                  ),
                ),
                if (onSale && compare != null)
                  Text(
                    kMoney.format(compare),
                    style: boutiqueText(
                      size: 13,
                      color: palette.inkMuted,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              inStock ? 'Disponible' : 'Agotado',
              style: boutiqueEyebrow(
                size: 10,
                color: inStock ? const Color(0xFF3B7B4A) : palette.sale,
              ),
            ),
            const SizedBox(height: BoutiqueSpace.md),
            if (inStock) ...[
              BoutiqueButton(label: 'AGREGAR A LA BOLSA', onPressed: onAdd),
              const SizedBox(height: BoutiqueSpace.sm),
              BoutiqueButton(
                label: 'COMPRAR AHORA',
                onPressed: onBuyNow,
                filled: false,
              ),
              Center(
                child: TextButton(
                  onPressed: onApartado,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, BoutiqueSpace.tapTarget),
                    foregroundColor: palette.inkMuted,
                  ),
                  child: Text(
                    'APARTAR',
                    style: boutiqueEyebrow(size: 11, color: palette.inkMuted),
                  ),
                ),
              ),
            ] else ...[
              BoutiqueButton(
                label: notificationsSaving
                    ? 'GUARDANDO…'
                    : 'AVÍSAME CUANDO VUELVA',
                key: const ValueKey('create-restock-alert'),
                onPressed: notificationsSaving ? null : onRestock,
              ),
              Center(
                child: TextButton(
                  onPressed: onApartado,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, BoutiqueSpace.tapTarget),
                    foregroundColor: palette.inkMuted,
                  ),
                  child: Text(
                    'APARTAR',
                    style: boutiqueEyebrow(size: 11, color: palette.inkMuted),
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
