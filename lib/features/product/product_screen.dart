/// Product detail.
///
/// Two things here are load-bearing for the business rather than the UI: the
/// dwell timer (which weights the taste profile) and the WhatsApp apartado CTA,
/// which is how a large share of this store's revenue actually closes.
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

class ProductScreen extends StatefulWidget {
  const ProductScreen({required this.productId, super.key});

  final String productId;

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final Stopwatch _dwell = Stopwatch()..start();

  @override
  void dispose() {
    _dwell.stop();
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
    final product =
        store.products.firstWhere((p) => p.id == widget.productId);

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
    final product =
        store.products.firstWhere((p) => p.id == widget.productId);
    final facets = store.facetsFor(product.id);
    final wishlisted = store.wishlist.contains(product.id);

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
          title: const Text('MONETTA'),
          actions: [
            IconButton(
              icon: Icon(
                wishlisted ? Icons.favorite : Icons.favorite_border,
                size: 20,
                color: wishlisted ? kGold : null,
              ),
              onPressed: () => store.toggleWishlist(product.id),
            ),
          ],
        ),
        body: ListView(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ColoredBox(
                color: const Color(0xFFF6F4F1),
                child: product.primaryImage == null
                    ? const Icon(Icons.image_not_supported_outlined)
                    : CachedNetworkImage(
                        imageUrl: product.primaryImage!,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (facets?.brand != null)
                    Text(
                      brandLabel(facets!.brand!.value).toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 2,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    product.title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w400,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        kMoney.format(product.price),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (product.isOnSale) ...[
                        const SizedBox(width: 10),
                        Text(
                          kMoney.format(product.compareAtPrice),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          color: kGold,
                          child: Text(
                            '-${(product.discountFraction * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    product.isInStock ? 'Disponible' : 'Agotado',
                    style: TextStyle(
                      fontSize: 12,
                      color: product.isInStock
                          ? Colors.green.shade700
                          : Colors.red.shade400,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (facets != null) _FacetChips(facets: facets),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Column(
                children: [
                  FilledButton(
                    onPressed: product.isInStock
                        ? () {
                            store.record(
                              EventType.addToCart,
                              productId: product.id,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Agregado a la bolsa'),
                              ),
                            );
                          }
                        : null,
                    child: Text(
                      product.isInStock ? 'Agregar a la bolsa' : 'Agotado',
                    ),
                  ),
                  const SizedBox(height: 10),
                  // The layaway flow. Not a secondary action on this store —
                  // deposit $400 MXN, 20 days to pay, arranged over WhatsApp.
                  OutlinedButton(
                    onPressed: _openApartado,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: const RoundedRectangleBorder(),
                      side: const BorderSide(color: kGold),
                      foregroundColor: kGold,
                    ),
                    child: const Text('Apartar por WhatsApp · anticipo \$400'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

/// Shows the normalized facets — useful in the demo to prove classification is
/// working on products whose raw Shopify fields are empty or wrong.
class _FacetChips extends StatelessWidget {
  const _FacetChips({required this.facets});

  final CanonicalFacets facets;

  @override
  Widget build(BuildContext context) {
    final labels = <String>[
      if (facets.category != null) facets.category!.value,
      if (facets.silhouette != null) facets.silhouette!.value,
      for (final color in facets.colors) color.value,
      for (final pattern in facets.patterns) pattern.value,
      facets.priceBand,
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: labels
          .map(
            (label) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                label,
                style: const TextStyle(fontSize: 10.5, letterSpacing: 0.3),
              ),
            ),
          )
          .toList(),
    );
  }
}
