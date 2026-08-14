/// One shopper card. Brand, title, price. No recommender sentences.
library;

import 'package:flutter/material.dart';

import '../../app/media/monetta_image.dart';
import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../data/media/media_url.dart';
import '../../domain/product.dart';
import '../../main.dart';
import '../../reco/events.dart';
import '../../reco/explainer.dart';
import '../product/product_screen.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    required this.product,
    this.urgency,
    this.wide = false,
    super.key,
  });

  final Product product;

  /// Restock or a real discount only. Never a "porque te gustan" line.
  final String? urgency;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final facets = store.facetsFor(product.id);
    final brand = facets?.brand?.value;
    final wishlisted = store.wishlist.contains(product.id);
    final second = product.images.length > 1 ? product.images[1] : null;

    return GestureDetector(
      onTap: () => openProduct(context, product),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _CardImage(
                  url: product.primaryImage,
                  secondUrl: second,
                ),
                if (!product.isInStock)
                  ColoredBox(
                    color: Colors.white.withValues(alpha: 0.68),
                    child: Center(child: Text('AGOTADO', style: eyebrow())),
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    tooltip: wishlisted ? 'Quitar de guardados' : 'Guardar',
                    onPressed: () => store.toggleWishlist(product.id),
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
          if (urgency != null) ...[
            Text(
              urgency!.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: eyebrow(size: 8.5, color: kSale),
            ),
            const SizedBox(height: 6),
          ],
          if (brand != null) ...[
            Text(
              brandLabel(brand).toUpperCase(),
              style: sans(size: 10.5, weight: FontWeight.w600),
            ),
            const SizedBox(height: 3),
          ],
          Text(
            product.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: sans(size: 12.5, height: 1.35),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 7,
            runSpacing: 2,
            children: [
              Text(
                kMoney.format(product.price),
                style: sans(size: 12, weight: FontWeight.w600),
              ),
              if (product.isOnSale)
                Text(
                  kMoney.format(product.compareAtPrice),
                  style: sans(
                    size: 11,
                    color: kInkMuted,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

void openProduct(BuildContext context, Product product) {
  final store = StoreScope.of(context);
  store.record(EventType.productView, productId: product.id);
  Navigator.of(context).push(
    monettaFadeRoute(
      StoreScope(
        notifier: store,
        child: ProductScreen(productId: product.id),
      ),
    ),
  );
}

class _CardImage extends StatefulWidget {
  const _CardImage({required this.url, this.secondUrl});

  final String? url;
  final String? secondUrl;

  @override
  State<_CardImage> createState() => _CardImageState();
}

class _CardImageState extends State<_CardImage> {
  bool _showSecond = false;

  @override
  Widget build(BuildContext context) {
    final url = _showSecond ? (widget.secondUrl ?? widget.url) : widget.url;
    return GestureDetector(
      onLongPressStart:
          widget.secondUrl == null ? null : (_) => setState(() => _showSecond = true),
      onLongPressEnd:
          widget.secondUrl == null ? null : (_) => setState(() => _showSecond = false),
      child: ColoredBox(
        color: kMist,
        child: url == null
            ? const Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  size: 20,
                  color: kInkMuted,
                ),
              )
            : AnimatedSwitcher(
                duration: reduceMotion(context) ? Duration.zero : kSwap,
                child: MonettaImage(
                  key: ValueKey(url),
                  url: url,
                  cacheWidth: MediaUrl.cardWidth,
                ),
              ),
      ),
    );
  }
}
