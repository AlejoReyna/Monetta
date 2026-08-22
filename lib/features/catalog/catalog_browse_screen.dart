/// Full-catalog browsing: every deduplicated [CatalogItem] — Monetta and
/// external, Monetta preferred on an exact brand+title collision — reachable
/// in one place, not just through the ranked feed or the capped external
/// rail. See `app/mixed_feed.dart#fullDeduplicatedCatalog`.
///
/// Built on a top-level `GridView.builder` (its own scrollable, no
/// `shrinkWrap`) so only the tiles actually on screen are ever built — a
/// catalog of any size renders lazily here, unlike the home feed's grid,
/// which is intentionally bounded to the ranked feed's own limit.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/media/monetta_image.dart';
import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../domain/catalog_item.dart';
import '../../main.dart';
import '../account/account_screen.dart';
import '../checkout/checkout_screen.dart';
import 'extracted_badge.dart';
import '../navigation/monetta_bottom_navigation.dart';
import '../product/external_product_screen.dart';
import '../product/product_screen.dart';

class CatalogBrowseScreen extends StatelessWidget {
  const CatalogBrowseScreen({
    required this.items,
    this.openExternalLink = defaultExternalLinkOpener,
    this.bagCount = 0,
    super.key,
  });

  final List<CatalogItem> items;
  final ExternalLinkOpener openExternalLink;
  final int bagCount;

  static const _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    // 0.46, not 0.50 — an external tile's caption has one more line: the
    // source-link text.
    childAspectRatio: 0.46,
    crossAxisSpacing: 14,
    mainAxisSpacing: 36,
  );

  @override
  Widget build(BuildContext context) {
    // Two clearly separated groups, each with its own heading — Monetta
    // first, external research items second — rather than one undifferentiated
    // grid. `fullDeduplicatedCatalog` already orders the flat list this way
    // (Monetta items, then deduped external items); this just draws the seam.
    final monettaItems = items.where((i) => !i.isExternal).toList();
    final externalItems = items.where((i) => i.isExternal).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Todo el catálogo'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Divider(height: 0.5),
        ),
      ),
      body: items.isEmpty
          ? Center(child: Text('Sin resultados', style: eyebrow()))
          : CustomScrollView(
              slivers: [
                if (monettaItems.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: SectionHeading(
                      kicker: 'Monetta',
                      title: 'Catálogo Monetta',
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    sliver: SliverGrid(
                      gridDelegate: _gridDelegate,
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _BrowseTile(
                          item: monettaItems[index],
                          openExternalLink: openExternalLink,
                        ),
                        childCount: monettaItems.length,
                      ),
                    ),
                  ),
                ],
                if (externalItems.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: monettaItems.isEmpty ? 0 : kSectionGap,
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SectionHeading(
                      kicker: 'Investigación · Estados Unidos',
                      title: 'También en marcas de Estados Unidos',
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    sliver: SliverGrid(
                      gridDelegate: _gridDelegate,
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _BrowseTile(
                          item: externalItems[index],
                          openExternalLink: openExternalLink,
                        ),
                        childCount: externalItems.length,
                      ),
                    ),
                  ),
                ] else
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
      bottomNavigationBar: MonettaBottomNavigation(
        current: MonettaBottomDestination.catalog,
        bagCount: bagCount,
        onSelected: (destination) {
          switch (destination) {
            case MonettaBottomDestination.home:
              Navigator.of(context).popUntil((route) => route.isFirst);
            case MonettaBottomDestination.catalog:
              break;
            case MonettaBottomDestination.bag:
              unawaited(openBag(context));
            case MonettaBottomDestination.account:
              unawaited(
                openAccount(
                  context,
                  controller: AccountScope.of(context),
                ),
              );
          }
        },
      ),
    );
  }
}

void openCatalogBrowse(
  BuildContext context, {
  required List<CatalogItem> items,
}) {
  final store = StoreScope.of(context);
  Navigator.of(context).push(
    monettaFadeRoute(
      StoreScope(
        notifier: store,
        child: CatalogBrowseScreen(
          items: items,
          bagCount: store.bagQuantity,
        ),
      ),
    ),
  );
}

class _BrowseTile extends StatelessWidget {
  const _BrowseTile({required this.item, required this.openExternalLink});

  final CatalogItem item;
  final ExternalLinkOpener openExternalLink;

  void _tap(BuildContext context) {
    if (!item.isExternal) {
      final productId = item.shopifyProductId;
      if (productId == null) return;
      unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => StoreScope(
              notifier: StoreScope.of(context),
              child: ProductScreen(productId: productId),
            ),
          ),
        ),
      );
      return;
    }

    unawaited(
      showExternalProductDetail(
        context,
        item: item,
        openLink: openExternalLink,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _tap(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: kMist,
                  child: MonettaImage(
                    url: item.imageUrl,
                    fallbackLabel: item.imageUrl == null ? null : item.title,
                  ),
                ),
                if (item.isExternal)
                  const Positioned(
                    top: 8,
                    left: 8,
                    child: ExtractedBadge(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${item.merchant}${item.isExternal ? ' · ${item.price?.currencyCode ?? 'USD'}' : ''}'
                .toUpperCase(),
            style: eyebrow(size: 9.5),
          ),
          const SizedBox(height: 6),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: display(14, weight: FontWeight.w400, height: 1.35),
          ),
          const SizedBox(height: 6),
          Text(
            formatCatalogMoney(item.price),
            style: sans(size: 12.5, weight: FontWeight.w500),
          ),
          if (item.isExternal) ...[
            const SizedBox(height: 4),
            Text(
              'Candidato de compra · origen EE. UU.',
              style: sans(size: 10.5, color: kInkMuted),
            ),
            const SizedBox(height: 4),
            // Where this listing's data actually came from — visible text,
            // not only reachable by tapping the tile.
            Text(
              sourceLinkLabel(item),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: sans(size: 9.5, color: kInkMuted),
            ),
          ],
        ],
      ),
    );
  }
}
