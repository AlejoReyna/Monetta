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

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/catalog_item.dart';
import '../../main.dart';
import '../home/external_catalog_section.dart'
    show ExternalLinkOpener, defaultExternalLinkOpener;
import '../product/product_screen.dart';

class CatalogBrowseScreen extends StatelessWidget {
  const CatalogBrowseScreen({
    required this.items,
    this.openExternalLink = defaultExternalLinkOpener,
    super.key,
  });

  final List<CatalogItem> items;
  final ExternalLinkOpener openExternalLink;

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
    );
  }
}

class _BrowseTile extends StatelessWidget {
  const _BrowseTile({required this.item, required this.openExternalLink});

  final CatalogItem item;
  final ExternalLinkOpener openExternalLink;

  Future<void> _tap(BuildContext context) async {
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

    if (!isValidExternalDetailUrl(item)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enlace no válido para ${item.merchant}')),
        );
      }
      return;
    }
    final launched = await openExternalLink(Uri.parse(item.detailUrl));
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir ${item.merchant}')),
      );
    }
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
            child: ColoredBox(
              color: kMist,
              child: item.imageUrl == null
                  ? const Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        size: 18,
                        color: kInkMuted,
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: item.imageUrl!,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 240),
                      placeholder: (_, __) => const ColoredBox(color: kMist),
                      errorWidget: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 18,
                          color: kInkMuted,
                        ),
                      ),
                    ),
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
