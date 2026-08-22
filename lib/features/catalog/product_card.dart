/// One shopper card. Brand, title, price. No recommender sentences.
library;

import 'package:flutter/material.dart';

import '../../app/media/monetta_image.dart';
import '../../app/motion.dart';
import '../../app/shopper_copy.dart';
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
                  urls: product.images,
                  fallbackLabel: brand == null
                      ? product.title
                      : '${brandLabel(brand)} · ${product.title}',
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: sans(size: 12, height: 1.3).copyWith(letterSpacing: 0.6),
            ),
            const SizedBox(height: 2),
          ],
          Text(
            cardPieceName(
              title: product.title,
              colorSlug: facets?.colors.isEmpty == true
                  ? null
                  : facets!.colors.first.value,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: sans(size: 12, height: 1.35),
          ),
          const SizedBox(height: 2),
          Wrap(
            spacing: 7,
            runSpacing: 2,
            children: [
              Text(
                kMoney.format(product.price),
                style: sans(size: 12, height: 1.3),
              ),
              if (product.isOnSale)
                Text(
                  kMoney.format(product.compareAtPrice),
                  style: sans(
                    size: 12,
                    color: kInkMuted,
                    height: 1.3,
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
  const _CardImage({required this.urls, required this.fallbackLabel});

  final List<String> urls;
  final String fallbackLabel;

  @override
  State<_CardImage> createState() => _CardImageState();
}

class _CardImageState extends State<_CardImage> {
  int _activeIndex = 0;
  bool _showSecond = false;

  List<String> get _candidates => [
        for (final url in widget.urls)
          if (url.trim().isNotEmpty) url,
      ];

  void _advance() {
    if (_activeIndex + 1 >= _candidates.length || !mounted) return;
    setState(() {
      _activeIndex += 1;
      _showSecond = false;
    });
  }

  @override
  void didUpdateWidget(covariant _CardImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.urls != widget.urls) {
      _activeIndex = 0;
      _showSecond = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _candidates;
    final url = candidates.isEmpty ? null : candidates[_activeIndex];
    return GestureDetector(
      onLongPressStart: candidates.length < 2
          ? null
          : (_) => setState(() => _showSecond = true),
      onLongPressEnd: candidates.length < 2
          ? null
          : (_) => setState(() => _showSecond = false),
      child: ColoredBox(
        color: kMist,
        child: url == null
            ? MonettaImage(
                url: null,
                fallbackLabel: widget.fallbackLabel,
              )
            : AnimatedSwitcher(
                duration: reduceMotion(context) ? Duration.zero : kSwap,
                child: MonettaImage(
                  key: ValueKey(url),
                  url: _showSecond && candidates.length > 1
                      ? candidates[1]
                      : url,
                  cacheWidth: MediaUrl.cardWidth,
                  fallbackLabel: widget.fallbackLabel,
                  onFailed: _advance,
                ),
              ),
      ),
    );
  }
}
