/// Product detail, in the maison register.
///
/// Two things here are load-bearing for the business rather than the UI: the
/// dwell timer (which weights the taste profile) and the WhatsApp apartado CTA,
/// which is how a large share of this store's revenue actually closes. Both
/// survived the restyle unchanged — the apartado in fact gained prominence,
/// since it is now the only gold element on the screen.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../data/normalize/facets.dart';
import '../../data/shopify/cart_attribution.dart';
import '../../main.dart';
import '../../reco/events.dart';
import '../../reco/explainer.dart';
import '../checkout/checkout_screen.dart';

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

  @override
  void dispose() {
    _dwell.stop();
    _gallery.dispose();
    super.dispose();
  }

  /// Record the dwell-weighted view on the way out — a 45-second read counts
  /// for more than a 2-second bounce.
  void _recordDwellAndPop() {
    final store = StoreScope.of(context);
    store.record(
      EventType.productView,
      productId: widget.productId,
      dwellMs: _dwell.elapsedMilliseconds,
    );
    Navigator.of(context).pop();
  }

  Future<void> _openApartado() async {
    final store = StoreScope.of(context);
    final product = store.products.firstWhere((p) => p.id == widget.productId);

    store.record(EventType.whatsappApartado, productId: product.id);

    final request = ApartadoRequest(
      productTitle: product.title,
      productHandle: product.handle,
      price: product.price,
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

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final product = store.products.firstWhere((p) => p.id == widget.productId);
    final facets = store.facetsFor(product.id);
    final wishlisted = store.wishlist.contains(product.id);
    final images = product.images.isEmpty ? <String?>[null] : product.images;

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
          title: const MonettaWordmark(),
          actions: [
            IconButton(
              icon: Icon(
                wishlisted ? Icons.favorite : Icons.favorite_border,
                size: 20,
                color: wishlisted ? kGold : kInk,
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
            // Full-bleed gallery at 4:5. Portrait, because every product here
            // is a bag, a wallet or a watch — objects that are taller than
            // they are wide once styled.
            AspectRatio(
              aspectRatio: 4 / 5,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _gallery,
                    itemCount: images.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) => _Image(url: images[i]),
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
                  Text(product.title, style: display(26)),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        kMoney.format(product.price),
                        style: sans(size: 17, weight: FontWeight.w500),
                      ),
                      if (product.isOnSale) ...[
                        const SizedBox(width: 12),
                        Text(
                          kMoney.format(product.compareAtPrice),
                          style: sans(
                            size: 13,
                            color: kInkMuted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Outlined, not filled. A solid red discount flag is
                        // the single loudest way to make a product look cheap.
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: kGold, width: 0.8),
                          ),
                          child: Text(
                            '-${(product.discountFraction * 100).round()}%',
                            style: eyebrow(
                              size: 9.5,
                              color: kGold,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: product.isInStock
                              ? const Color(0xFF5C7E08)
                              : kInkMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        product.isInStock
                            ? 'Disponible'.toUpperCase()
                            : 'Agotado'.toUpperCase(),
                        style: eyebrow(
                          size: 9.5,
                          color: product.isInStock
                              ? const Color(0xFF5C7E08)
                              : kInkMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            if (facets != null) _Specification(facets: facets),
            const SizedBox(height: 40),
          ],
        ),
        // Pinned, so the committing action never scrolls away on a long page.
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: kHairline),
          ),
          child: SafeArea(
            minimum: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton(
                  onPressed: product.isInStock
                      ? () {
                          store.addToBag(product);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Agregado a la bolsa'),
                            ),
                          );
                        }
                      : null,
                  child: Text(
                    product.isInStock
                        ? 'Agregar a la bolsa'.toUpperCase()
                        : 'Agotado'.toUpperCase(),
                  ),
                ),
                const SizedBox(height: 10),
                // The layaway flow. Not a secondary action on this store —
                // deposit $400 MXN, 20 days to pay, arranged over WhatsApp.
                OutlinedButton(
                  onPressed: _openApartado,
                  child: const Text('APARTAR POR WHATSAPP · ANTICIPO \$400'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Gallery position as thin rules rather than dots.
///
/// Dots are a Material signature and read as an app; a set of hairline rules
/// reads as print. Same information, and it survives on a light image because
/// the inactive rule still has a visible edge.
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
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: on ? 22 : 12,
          height: 1.5,
          color: on ? kInk : kInk.withValues(alpha: 0.25),
        );
      }),
    );
  }
}

/// The normalized facets, presented as a specification table.
///
/// Still proves classification is working on products whose raw Shopify fields
/// are empty or wrong — but a hairline-ruled table is how a maison lists
/// composition and dimensions, so the debugging value now arrives disguised as
/// product copy.
class _Specification extends StatelessWidget {
  const _Specification({required this.facets});

  final CanonicalFacets facets;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      if (facets.category != null) ('Categoría', facets.category!.value),
      if (facets.silhouette != null) ('Silueta', facets.silhouette!.value),
      if (facets.colors.isNotEmpty)
        ('Color', facets.colors.map((c) => c.value).join(', ')),
      if (facets.patterns.isNotEmpty)
        ('Estampado', facets.patterns.map((p) => p.value).join(', ')),
      if (facets.priceBand != null) ('Gama', facets.priceBand!),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Text('Detalles'.toUpperCase(), style: eyebrow()),
        ),
        for (final (label, value) in rows)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(border: Border(top: kHairline)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 108,
                  child: Text(label, style: sans(size: 12, color: kInkMuted)),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: sans(size: 12.5),
                  ),
                ),
              ],
            ),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(border: Border(top: kHairline)),
          child: SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _Image extends StatelessWidget {
  const _Image({required this.url});

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
              width: double.infinity,
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
