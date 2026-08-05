/// The personalized feed.
///
/// Every card carries the reason it was shown, which is the whole point of the
/// engine: the shopper sees *why*, and Monetta can see the personalization
/// working without reading a dashboard.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/catalog_store.dart';
import '../../app/theme.dart';
import '../../main.dart';
import '../../reco/events.dart';
import '../../reco/explainer.dart';
import '../onboarding/onboarding_sheet.dart';
import '../product/product_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _askedOnboarding = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_askedOnboarding) return;
    _askedOnboarding = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _openOnboarding());
  }

  Future<void> _openOnboarding() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => StoreScope(
        notifier: StoreScope.of(context),
        child: const OnboardingSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final feed = store.feed();
    final topBrands = store.profile.topOf('brand');

    return Scaffold(
      appBar: AppBar(
        title: const Text('MONETTA'),
        actions: [
          IconButton(
            tooltip: 'Ajustar mis gustos',
            onPressed: _openOnboarding,
            icon: const Icon(Icons.tune, size: 20),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _ProfileBanner(
              topBrands: topBrands,
              eventCount: store.eventCount,
              productCount: store.products.length,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
            sliver: SliverGrid(
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.54,
                crossAxisSpacing: 12,
                mainAxisSpacing: 20,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _ProductCard(item: feed[index]),
                childCount: feed.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Makes the profile visible. Doubles as the privacy disclosure — the user can
/// see exactly what the app thinks it knows.
class _ProfileBanner extends StatelessWidget {
  const _ProfileBanner({
    required this.topBrands,
    required this.eventCount,
    required this.productCount,
  });

  final List<String> topBrands;
  final int eventCount;
  final int productCount;

  @override
  Widget build(BuildContext context) {
    final hasTaste = topBrands.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasTaste ? 'Para ti' : 'Novedades',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w300,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasTaste
                ? 'Basado en ${topBrands.map(brandLabel).join(' · ')}'
                    '   ·   $eventCount interacciones'
                : '$productCount productos originales importados',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.item});

  final Recommendation item;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final product = item.product;
    final inStock = product.isInStock;
    final wishlisted = store.wishlist.contains(product.id);

    return GestureDetector(
      onTap: () {
        store.record(EventType.productView, productId: product.id);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => StoreScope(
              notifier: store,
              child: ProductScreen(productId: product.id),
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: const Color(0xFFF6F4F1),
                  child: product.primaryImage == null
                      ? const Icon(Icons.image_not_supported_outlined)
                      : CachedNetworkImage(
                          imageUrl: product.primaryImage!,
                          fit: BoxFit.cover,
                          fadeInDuration: const Duration(milliseconds: 200),
                          errorWidget: (_, __, ___) =>
                              const Icon(Icons.broken_image_outlined),
                        ),
                ),
                if (!inStock)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.white.withValues(alpha: 0.55),
                      child: const Center(
                        child: Text(
                          'AGOTADO',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => store.toggleWishlist(product.id),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        wishlisted ? Icons.favorite : Icons.favorite_border,
                        size: 15,
                        color: wishlisted ? kGold : Colors.black54,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _ReasonChip(reason: item.reason),
          const SizedBox(height: 5),
          Text(
            product.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, height: 1.25),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Text(
                kMoney.format(product.price),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (product.isOnSale) ...[
                const SizedBox(width: 6),
                Text(
                  kMoney.format(product.compareAtPrice),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// The explanation chip. Urgency reasons are gold; taste reasons are quiet.
class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.reason});

  final RecoReason reason;

  @override
  Widget build(BuildContext context) {
    final urgent = reason.kind == ReasonKind.restocked ||
        reason.kind == ReasonKind.priceDrop;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: urgent ? kGold : kGold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        reason.text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9.5,
          letterSpacing: 0.2,
          fontWeight: FontWeight.w500,
          color: urgent ? Colors.white : kGold,
        ),
      ),
    );
  }
}
