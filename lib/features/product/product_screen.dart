/// Ficha de producto Fig.07 — boutique cálida.
///
/// Galería contenida (nunca recorta asas) con miniaturas, fav y compartir;
/// marca + nombre + precio actual de la variante seleccionada;
/// swatches solo con mapeo fiable ([ProductOptionSelector]); envío y entrega
/// en el checkout; muelle inferior con «Agregar al carrito» y, al final de la
/// información, «Otras formas de comprar» (comprar ahora y apartar);
/// acordeones Descripción–Detalles–Envíos; relacionados con la [ProductCard]
/// compartida.
///
/// Agotado abre igual pero se distingue (sello + CTA de aviso en el muelle). El corazón
/// solo guarda — jamás navega.
library;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/media/monetta_image.dart';
import '../../app/motion.dart';
import '../../app/shopper_copy.dart';
import '../../app/text_scale_policy.dart';
import '../../app/theme.dart';
import '../../data/media/media_url.dart';
import '../../data/normalize/facets.dart';
import '../../data/shopify/cart_attribution.dart';
import '../../domain/product.dart';
import '../../main.dart';
import '../../reco/events.dart';
import '../../reco/explainer.dart';
import '../boutique/boutique_tokens.dart';
import '../account/account_screen.dart';
import '../catalog/search_screen.dart';
import '../catalog/product_card.dart';
import '../checkout/checkout_screen.dart';
import '../checkout/mini_cart.dart' show showMiniCart;
import 'product_header.dart';
import 'product_selection.dart';
import 'product_unavailable.dart';
import 'purchase_dock.dart';
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
  final Set<String> _open = <String>{'descripcion', 'detalles', 'envio'};

  /// True while an add is in flight; blocks a second tap on any purchase
  /// action so one tap never turns into two units.
  bool _adding = false;

  @override
  void dispose() {
    _dwell.stop();
    _gallery.dispose();
    super.dispose();
  }

  void _recordDwell() {
    _dwell.stop();
    final store = StoreScope.of(context);
    store.record(
      EventType.productView,
      productId: widget.productId,
      dwellMs: _dwell.elapsedMilliseconds,
    );
    NotificationScope.maybeOf(context)?.recordPushOutcome('product_viewed');
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
    Product? found;
    for (final candidate in store.products) {
      if (candidate.id == widget.productId) {
        found = candidate;
        break;
      }
    }
    // The product can leave the catalog while the page is open (live sync) or
    // never have been in it (stale link): show the unavailable state instead
    // of throwing. If it returns, the next rebuild shows the page again.
    if (found == null) return const ProductUnavailable();
    final product = found;
    final facets = store.facetsFor(product.id);
    final wishlisted = store.wishlist.contains(product.id);
    final selectable = selectableVariants(product);
    final selected = selectedVariant(product, _variantIndex);
    final price = selected?.price ?? product.price;
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
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _recordDwell();
      },
      child: Scaffold(
        backgroundColor: palette.canvas,
        appBar: buildProductDetailAppBar(
          context,
          onBack: () => Navigator.of(context).maybePop(),
          onSearch: () => openSearch(context),
          actions: [
            IconButton(
              key: const Key('product-header-account'),
              tooltip: 'Mi cuenta',
              icon: const Icon(Icons.person_outline, size: 23),
              onPressed: () => openAccount(
                context,
                controller: AccountScope.of(context),
              ),
            ),
            const BagAction(),
          ],
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
                      style: boutiqueProductName(color: palette.ink),
                    ),
                    const SizedBox(height: BoutiqueSpace.lg),
                    Wrap(
                      spacing: BoutiqueSpace.md,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          kMoney.format(price),
                          key: const ValueKey('product-current-price'),
                          style: boutiqueText(
                            size: 20,
                            weight: FontWeight.w700,
                            color: inStock ? palette.ink : palette.inkMuted,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                    if (selectable.isNotEmpty) ...[
                      const SizedBox(height: BoutiqueSpace.xl),
                      ProductOptionSelector(
                        product: product,
                        selectedIndex: _variantIndex,
                        onSelect: (i) => setState(() => _variantIndex = i),
                      ),
                    ],
                    const SizedBox(height: BoutiqueSpace.xl),
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
                            ? 'Consulta los detalles de esta pieza.'
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
                        'Consulta las condiciones de envío y cambios con nuestro equipo por WhatsApp.',
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
                      inStock: inStock,
                      adding: _adding,
                      onBuyNow: () => _buyNow(product),
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
                    facets?.brand == null
                        ? 'Más piezas'
                        : 'Más de ${brandLabel(facets!.brand!.value)}',
                    style: boutiqueSectionHeading(color: palette.ink),
                  ),
                ),
                _Rail(
                  key: const ValueKey('product-recommendations'),
                  products: related,
                ),
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
                    style: boutiqueSectionHeading(color: palette.ink),
                  ),
                ),
                _Rail(
                  key: const ValueKey('product-recently-viewed'),
                  products: recent,
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
        bottomNavigationBar: PurchaseDock(
          child: inStock
              ? PurchaseDockButton(
                  key: const Key('purchase-dock-primary'),
                  label: _adding ? 'Agregando…' : 'Agregar al carrito',
                  pending: _adding,
                  onPressed: _adding ? null : () => _add(product),
                )
              // The restock alert keeps its historical key; the button keeps
              // the dock key in every state.
              : KeyedSubtree(
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
      color: kPackshotGround,
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
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 2.2,
                  child: MonettaImage(
                    url: images[i],
                    fit: BoxFit.contain,
                    backgroundColor: kPackshotGround,
                    maxCoverTrim: kPackshotMaxCoverTrim,
                    cacheWidth: MediaUrl.heroWidth,
                    fallbackLabel:
                        '${shopperProductName(product.title)} · Monetta',
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
                    key: const Key('product-gallery-favorite'),
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
    super.key,
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
            color: kPackshotGround,
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
                    color: filled ? palette.goldText : const Color(0xFF111111),
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
      color: kPackshotGround,
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
                        color: kPackshotGround,
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
                          backgroundColor: kPackshotGround,
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
                        style: boutiqueSectionHeading(color: palette.ink),
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

/// "Otras formas de comprar": the secondary purchase actions, after the
/// information and before the related rails. The primary action lives in the
/// dock. A sold-out selection offers only "Apartar".
class _PurchaseSection extends StatelessWidget {
  const _PurchaseSection({
    required this.inStock,
    required this.adding,
    required this.onBuyNow,
    required this.onApartado,
  });

  final bool inStock;
  final bool adding;
  final VoidCallback onBuyNow;
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
          style: boutiqueSectionHeading(color: palette.ink),
        ),
        const SizedBox(height: BoutiqueSpace.md),
        if (inStock) ...[
          BoutiqueButton(
            key: const Key('purchase-buy-now'),
            label: 'Comprar ahora',
            onPressed: adding ? null : onBuyNow,
            filled: false,
          ),
          const SizedBox(height: BoutiqueSpace.sm),
        ],
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
        'No hay detalles adicionales de esta pieza.',
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
  const _Rail({required this.products, super.key});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final tileWidth = MediaQuery.sizeOf(context).width * 0.52;
    // 12pt photo gap plus ~120pt for brand, two-line name and price, matching
    // the grid caption contract. The caption is text, so it grows with the
    // text scale; the gap does not.
    final caption = 120 *
        textScaleFactorFor(
          MediaQuery.textScalerOf(context),
          ProductTileDensity.grid.nameSize,
        );
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
              photoInset: 0,
              showSaleBadge: false,
              onQuickView: () => showProductQuickView(context, product),
            ),
          );
        },
      ),
    );
  }
}
