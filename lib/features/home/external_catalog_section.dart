/// The owner-procurement rail: verified US merchant listings surfaced
/// alongside Monetta's own feed.
///
/// Everything here is deliberately inert with respect to the revenue path —
/// no wishlist heart, no add-to-bag, no WhatsApp apartado. A card opens an
/// in-app description; only its explicit merchant CTA leaves the app via
/// `LaunchMode.externalApplication`. See `domain/catalog_item.dart`
/// (`PurchaseMode.ownerProcurement`) and `docs/ARCHITECTURE.md` §
/// "External catalog prototype" for why this boundary exists.
library;

import 'package:flutter/material.dart';

import '../../app/media/monetta_image.dart';
import '../../app/shopper_copy.dart';
import '../../app/theme.dart';
import '../../data/media/media_url.dart';
import '../../domain/catalog_item.dart';
import '../product/external_product_screen.dart';

class ExternalCatalogSection extends StatelessWidget {
  const ExternalCatalogSection({
    required this.items,
    required this.generatedAt,
    this.openLink = defaultExternalLinkOpener,
    super.key,
  });

  final List<CatalogItem> items;
  final DateTime? generatedAt;
  final ExternalLinkOpener openLink;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final displayItems = [...items]..sort((a, b) {
        final aHasColors = a.variants.length > 1;
        final bHasColors = b.variants.length > 1;
        if (aHasColors == bHasColors) return 0;
        return aHasColors ? -1 : 1;
      });
    final perfumeItems = displayItems
        .where((item) => item.vertical == CatalogVertical.perfumes)
        .toList(growable: false);
    final bagAndWalletItems = displayItems
        .where((item) => item.vertical != CatalogVertical.perfumes)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (bagAndWalletItems.isNotEmpty) ...[
          const SectionHeading(
            kicker: 'Bolsas y carteras · Estados Unidos',
            title: 'Selección de marcas originales',
            animateKickerColor: true,
          ),
          _ExternalRail(items: bagAndWalletItems, openLink: openLink),
        ],
        if (perfumeItems.isNotEmpty) ...[
          if (bagAndWalletItems.isNotEmpty) const SizedBox(height: 12),
          const SectionHeading(
            kicker: 'Perfumería · GP McAllen',
            title: 'Perfumes seleccionados',
            animateKickerColor: true,
          ),
          _ExternalRail(items: perfumeItems, openLink: openLink),
        ],
        const SizedBox(height: 16),
        _Disclosure(generatedAt: generatedAt),
        const SizedBox(height: kSectionGap),
      ],
    );
  }
}

class _ExternalRail extends StatelessWidget {
  const _ExternalRail({required this.items, required this.openLink});

  final List<CatalogItem> items;
  final ExternalLinkOpener openLink;

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final width = ((viewportWidth - 32) / 2).clamp(156.0, 220.0);

    return SizedBox(
      // Match the regular 4:5 product image and compact three-line card copy.
      height: width / 0.8 + 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) => SizedBox(
          width: width,
          child: _ExternalCard(item: items[index], openLink: openLink),
        ),
      ),
    );
  }
}

class _ExternalCard extends StatelessWidget {
  const _ExternalCard({required this.item, required this.openLink});

  final CatalogItem item;
  final ExternalLinkOpener openLink;

  void _openDetail(BuildContext context) {
    showExternalProductDetail(
      context,
      item: item,
      openLink: openLink,
    );
  }

  @override
  Widget build(BuildContext context) {
    final brand = humanizeCatalogValue(
      item.brand.trim().isEmpty ? item.merchant : item.brand,
    );
    final title = externalProductName(
      title: item.title,
      category: item.category,
    );
    return Semantics(
      button: true,
      label: '$brand, $title',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openDetail(context),
        // Deliberately no favorite or bag affordance: this card opens the
        // read-only detail and cannot enter Monetta checkout.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 5,
              child: ColoredBox(
                color: context.monettaColors.surfaceMuted,
                child: MonettaImage(
                  url: item.imageUrl,
                  fit: BoxFit.cover,
                  cacheWidth: MediaUrl.cardWidth,
                  fallbackLabel: '$brand · $title',
                ),
              ),
            ),
            const SizedBox(height: 11),
            Text(
              brand.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: sans(size: 12, height: 1.3).copyWith(letterSpacing: 0.6),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: sans(size: 12, height: 1.35),
            ),
            const SizedBox(height: 2),
            Text(
              formatCatalogMoney(item.price),
              style: sans(size: 12, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _Disclosure extends StatelessWidget {
  const _Disclosure({required this.generatedAt});

  final DateTime? generatedAt;

  @override
  Widget build(BuildContext context) {
    final stamp = generatedAt == null
        ? ''
        : ' Última actualización: ${_formatStamp(generatedAt!)}.';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        'Selección en EE. UU. para compra manual. Precio y disponibilidad por '
        'confirmar.$stamp',
        style: sans(size: 10.5, color: context.monettaColors.contentMuted),
      ),
    );
  }
}

const List<String> _kSpanishMonthAbbr = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// `d MMM, HH:mm` in Spanish, without depending on `intl`'s locale data
/// tables (which require `initializeDateFormatting` — an app-startup
/// dependency this small, static label shouldn't need).
String _formatStamp(DateTime timestamp) {
  final local = timestamp.toLocal();
  final month = _kSpanishMonthAbbr[local.month - 1];
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '${local.day} $month, $hh:$mm';
}
