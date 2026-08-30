/// Product detail. The object first, then the facts that close the sale.
library;

import 'package:flutter/material.dart';
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
import '../catalog/product_card.dart';
import '../checkout/checkout_screen.dart';
import '../checkout/mini_cart.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({required this.productId, super.key});

  final String productId;

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final Stopwatch _dwell = Stopwatch()..start();
  final PageController _gallery = PageController();
  int _page = 0;
  int _variantIndex = 0;
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

  ProductVariant? _selected(Product product) {
    final selectable = product.variants.where((v) => !v.isDefault).toList();
    if (selectable.isEmpty) {
      return product.variants.isEmpty ? null : product.variants.first;
    }
    if (_variantIndex < 0 || _variantIndex >= selectable.length) {
      return selectable.first;
    }
    return selectable[_variantIndex];
  }

  Future<void> _openApartado(Product product) async {
    final store = StoreScope.of(context);
    store.record(EventType.whatsappApartado, productId: product.id);
    final request = ApartadoRequest(
      productTitle: product.title,
      productHandle: product.handle,
      price: _selected(product)?.price ?? product.price,
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

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final product = store.products.firstWhere((p) => p.id == widget.productId);
    final facets = store.facetsFor(product.id);
    final wishlisted = store.wishlist.contains(product.id);
    final selectable = product.variants.where((v) => !v.isDefault).toList();
    final selected = _selected(product);
    final price = selected?.price ?? product.price;
    final compare = selected?.compareAtPrice ?? product.compareAtPrice;
    final onSale = compare != null && compare > price;
    final inStock = selected?.available ?? product.isInStock;
    final images = product.images.isEmpty ? <String?>[null] : product.images;
    final description = () {
      final html = stripHtml(product.descriptionHtml);
      if (html.isNotEmpty) return html;
      return factualDescription(
        title: product.title,
        brandSlug: facets?.brand?.value,
        categorySlug: facets?.category?.value,
        silhouetteSlug: facets?.silhouette?.value,
        colorSlug:
            facets?.colors.isEmpty == true ? null : facets!.colors.first.value,
      );
    }();
    final recent = store.recentlyViewed(excluding: product.id);
    final related = facets?.brand?.value == null
        ? const <Product>[]
        : store.moreFromBrand(
            facets!.brand!.value,
            excluding: product.id,
          );
    final notifications = NotificationScope.maybeOf(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _recordDwellAndPop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: _recordDwellAndPop,
          ),
          title: const MonettaWordmark.appBar(),
          actions: [
            IconButton(
              tooltip: wishlisted ? 'Quitar de guardados' : 'Guardar',
              icon: Icon(
                wishlisted ? Icons.favorite : Icons.favorite_border,
                size: 20,
                color: wishlisted
                    ? context.monettaColors.accent
                    : context.monettaColors.contentPrimary,
              ),
              onPressed: () => store.toggleWishlist(product.id),
            ),
            const BagAction(),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(0.5),
            child: Divider(height: 0.5),
          ),
        ),
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            AspectRatio(
              aspectRatio: 4 / 5,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _gallery,
                    itemCount: images.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) => Hero(
                      tag: i == 0 ? 'product-image-${product.id}' : 'p-$i',
                      child: _ZoomImage(url: images[i]),
                    ),
                  ),
                  if (images.length > 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 18,
                      child: _RuleIndicator(
                        count: images.length,
                        active: _page,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (facets?.brand != null) ...[
                    Text(
                      brandLabel(facets!.brand!.value).toUpperCase(),
                      style: eyebrow(size: 10.5),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Reveal(
                    child: Text(
                      product.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: display(26),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        kMoney.format(price),
                        style: sans(size: 17, weight: FontWeight.w500),
                      ),
                      if (onSale)
                        Text(
                          kMoney.format(compare),
                          style: sans(
                            size: 13,
                            color: context.monettaColors.contentMuted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (inStock)
                    Text(
                      kApartadoSentence,
                      style: sans(size: 13, height: 1.45),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    inStock
                        ? 'Disponible · envío 3 a 5 días · gratis desde ${kMoney.format(kFreeShippingThreshold)}'
                        : 'Agotado',
                    style: sans(
                      size: 12,
                      color: inStock
                          ? context.monettaColors.contentPrimary
                          : context.monettaColors.contentMuted,
                    ),
                  ),
                  if (selectable.length > 1) ...[
                    const SizedBox(height: 28),
                    Text('Opción'.toUpperCase(), style: eyebrow()),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < selectable.length; i++)
                          GestureDetector(
                            onTap: () => setState(() => _variantIndex = i),
                            child: AnimatedContainer(
                              duration:
                                  reduceMotion(context) ? Duration.zero : kSwap,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: i == _variantIndex
                                    ? context.monettaColors.contentPrimary
                                    : context.monettaColors.surface,
                                border: Border.all(
                                  color: i == _variantIndex
                                      ? context.monettaColors.contentPrimary
                                      : context.monettaColors.divider,
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                selectable[i].title.toUpperCase(),
                                style: eyebrow(
                                  size: 8.5,
                                  color: i == _variantIndex
                                      ? context.monettaColors.canvas
                                      : context.monettaColors.contentPrimary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (description != null) ...[
                    const SizedBox(height: 28),
                    Text(description, style: sans(size: 13.5, height: 1.6)),
                  ],
                  const SizedBox(height: 28),
                  _FactLink(
                    label: 'Detalles',
                    open: _open.contains('detalles'),
                    onTap: () => setState(() {
                      _open.contains('detalles')
                          ? _open.remove('detalles')
                          : _open.add('detalles');
                    }),
                    child: _Details(facets: facets),
                  ),
                  _FactLink(
                    label: 'Envío y cambios',
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
                      style: sans(size: 13, height: 1.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  UnderlineLink(
                    label: 'Escribir por WhatsApp',
                    onTap: () => _openConcierge(product),
                  ),
                ],
              ),
            ),
            if (related.isNotEmpty) ...[
              const SizedBox(height: 36),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Text(
                  facets?.brand == null
                      ? 'Más piezas'
                      : 'Más de ${brandLabel(facets!.brand!.value)}',
                  style: display(22),
                ),
              ),
              _Rail(products: related),
            ],
            if (recent.isNotEmpty) ...[
              const SizedBox(height: 36),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Text('Vistas hace un momento', style: display(22)),
              ),
              _Rail(products: recent),
            ],
            const SizedBox(height: 40),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: context.monettaColors.surfaceRaised,
            border: Border(
              top: BorderSide(
                color: context.monettaColors.divider,
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        kMoney.format(price),
                        style: sans(size: 16, weight: FontWeight.w500),
                      ),
                    ),
                    if (inStock)
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: () {
                            store.addToBag(product);
                            NotificationScope.maybeOf(
                              context,
                            )?.recordPushOutcome('add_to_cart');
                            showMiniCart(context);
                          },
                          child: const Text('AGREGAR A LA BOLSA'),
                        ),
                      )
                    else
                      Expanded(
                        flex: 2,
                        child: OutlinedButton(
                          key: const ValueKey('create-restock-alert'),
                          onPressed: notifications?.saving == true
                              ? null
                              : () => _createRestockAlert(product),
                          child: Text(
                            notifications?.saving == true
                                ? 'GUARDANDO…'
                                : 'AVÍSAME CUANDO VUELVA',
                            style: const TextStyle(height: 1.1),
                          ),
                        ),
                      ),
                  ],
                ),
                if (inStock) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => _openApartado(product),
                    child: const Text('APARTAR'),
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

class _Rail extends StatelessWidget {
  const _Rail({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).width * 0.52 / 0.82 + 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => SizedBox(
          width: MediaQuery.sizeOf(context).width * 0.52,
          child: ProductCard(product: products[index]),
        ),
      ),
    );
  }
}

class _FactLink extends StatelessWidget {
  const _FactLink({
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UnderlineLink(label: label, onTap: onTap),
          if (open) ...[
            const SizedBox(height: 12),
            child,
          ],
        ],
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.facets});

  final CanonicalFacets? facets;

  @override
  Widget build(BuildContext context) {
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
        style: sans(size: 13, height: 1.6),
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
                    style: sans(
                      size: 12,
                      color: context.monettaColors.contentMuted,
                    ),
                  ),
                ),
                Expanded(child: Text(row.$2, style: sans(size: 12.5))),
              ],
            ),
          ),
      ],
    );
  }
}

class _RuleIndicator extends StatelessWidget {
  const _RuleIndicator({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final on = i == active;
        return AnimatedContainer(
          duration: reduceMotion(context) ? Duration.zero : kSnap,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: on ? 22 : 12,
          height: 1.5,
          color: on
              ? context.monettaColors.contentPrimary
              : context.monettaColors.contentPrimary.withValues(alpha: 0.25),
        );
      }),
    );
  }
}

class _ZoomImage extends StatelessWidget {
  const _ZoomImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.monettaColors.surfaceMuted,
      child: url == null
          ? Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                size: 20,
                color: context.monettaColors.contentMuted,
              ),
            )
          : InteractiveViewer(
              minScale: 1,
              maxScale: 2.2,
              child: MonettaImage(
                url: url,
                fit: BoxFit.cover,
                cacheWidth: MediaUrl.heroWidth,
              ),
            ),
    );
  }
}
