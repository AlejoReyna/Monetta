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

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/shopper_copy.dart';
import '../../app/theme.dart';
import '../../domain/catalog_item.dart';
import '../product/external_product_screen.dart';

String externalSourceBadge(CatalogSourceType source) {
  switch (source) {
    case CatalogSourceType.coachUs:
      return 'Coach US · USD';
    case CatalogSourceType.michaelKorsUs:
      return 'Michael Kors US · USD';
    case CatalogSourceType.guessUs:
      return 'GUESS US · USD';
    case CatalogSourceType.steveMaddenUs:
      return 'Steve Madden US · USD';
    case CatalogSourceType.marcJacobsUs:
      return 'Marc Jacobs US · USD';
    case CatalogSourceType.toryBurchUs:
      return 'Tory Burch US · USD';
    case CatalogSourceType.kateSpadeUs:
      return 'Kate Spade US · USD';
    case CatalogSourceType.guessFactoryUs:
      return 'GUESS Factory US · USD';
    case CatalogSourceType.gpMcallenPerfumes:
      return 'GP McAllen · USD';
    case CatalogSourceType.monettaShopify:
      return '';
  }
}

String externalCtaLabel(CatalogSourceType source) {
  switch (source) {
    case CatalogSourceType.coachUs:
      return 'Ver en Coach';
    case CatalogSourceType.michaelKorsUs:
      return 'Ver en Michael Kors';
    case CatalogSourceType.guessUs:
      return 'Ver en GUESS';
    case CatalogSourceType.steveMaddenUs:
      return 'Ver en Steve Madden';
    case CatalogSourceType.marcJacobsUs:
      return 'Ver en Marc Jacobs';
    case CatalogSourceType.toryBurchUs:
      return 'Ver en Tory Burch';
    case CatalogSourceType.kateSpadeUs:
      return 'Ver en Kate Spade';
    case CatalogSourceType.guessFactoryUs:
      return 'Ver en GUESS Factory';
    case CatalogSourceType.gpMcallenPerfumes:
      return 'Ver en GP McAllen';
    case CatalogSourceType.monettaShopify:
      return '';
  }
}

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
          ),
          _ExternalRail(items: bagAndWalletItems, openLink: openLink),
        ],
        if (perfumeItems.isNotEmpty) ...[
          if (bagAndWalletItems.isNotEmpty) const SizedBox(height: 12),
          const SectionHeading(
            kicker: 'Perfumería · GP McAllen',
            title: 'Perfumes seleccionados',
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
    final width = MediaQuery.sizeOf(context).width * 0.56;

    return SizedBox(
      // Room for source provenance plus the optional color-variant rail.
      height: width / 0.75 + 218,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) => SizedBox(
          width: width,
          child: _ExternalCard(item: items[index], openLink: openLink),
        ),
      ),
    );
  }
}

class _ExternalCard extends StatefulWidget {
  const _ExternalCard({required this.item, required this.openLink});

  final CatalogItem item;
  final ExternalLinkOpener openLink;

  @override
  State<_ExternalCard> createState() => _ExternalCardState();
}

class _ExternalCardState extends State<_ExternalCard> {
  int _selectedVariantIndex = 0;

  CatalogVariant? get _selectedVariant => widget.item.variants.isEmpty
      ? null
      : widget.item.variants[_selectedVariantIndex];

  String get _detailUrl => _selectedVariant?.detailUrl ?? widget.item.detailUrl;
  String? get _imageUrl => _selectedVariant?.imageUrl ?? widget.item.imageUrl;
  Money? get _price => _selectedVariant?.price ?? widget.item.price;

  void _openDetail(BuildContext context) {
    showExternalProductDetail(
      context,
      item: widget.item,
      openLink: widget.openLink,
      initialVariantIndex: _selectedVariantIndex,
    );
  }

  Future<void> _openMerchant(BuildContext context) async {
    // Re-validated here, independent of whatever the backend already
    // checked — scheme must be HTTPS and the host must actually belong to
    // this item's declared source. See `domain/catalog_item.dart`.
    if (!isValidExternalDetailUrlForSource(widget.item.source, _detailUrl)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Enlace no válido para ${widget.item.merchant}'),
          ),
        );
      }
      return;
    }
    final uri = Uri.parse(_detailUrl);
    final launched = await widget.openLink(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir ${widget.item.merchant}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openDetail(context),
      // Deliberately no favorite icon, no "add to bag" affordance — this
      // This card only opens a read-only detail; it can never enter cart.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: ColoredBox(
              color: context.monettaColors.surfaceMuted,
              child: _imageUrl == null
                  ? Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        size: 18,
                        color: context.monettaColors.contentMuted,
                      ),
                    )
                  : CachedNetworkImage(
                      key: ValueKey(_imageUrl),
                      imageUrl: _imageUrl!,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 240),
                      placeholder: (_, __) => ColoredBox(
                        color: context.monettaColors.surfaceMuted,
                      ),
                      errorWidget: (_, __, ___) => Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 18,
                          color: context.monettaColors.contentMuted,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            externalSourceBadge(widget.item.source).toUpperCase(),
            style: eyebrow(size: 9.5),
          ),
          const SizedBox(height: 6),
          Text(
            shopperProductName(widget.item.title),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: display(14, weight: FontWeight.w400, height: 1.35),
          ),
          const SizedBox(height: 6),
          Text(
            formatCatalogMoney(_price),
            style: sans(size: 12.5, weight: FontWeight.w500),
          ),
          if (widget.item.variants.length > 1) ...[
            const SizedBox(height: 7),
            Text(
              'Color: ${_selectedVariant!.displayName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: sans(size: 10.5, weight: FontWeight.w500),
            ),
            const SizedBox(height: 5),
            SizedBox(
              height: 30,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.item.variants.length,
                separatorBuilder: (_, __) => const SizedBox(width: 5),
                itemBuilder: (context, index) {
                  final variant = widget.item.variants[index];
                  return ChoiceChip(
                    key: ValueKey(variant.variantId),
                    label: Text(variant.displayName),
                    selected: index == _selectedVariantIndex,
                    onSelected: (_) {
                      setState(() => _selectedVariantIndex = index);
                    },
                    labelStyle: sans(
                      size: 9.5,
                      color: index == _selectedVariantIndex
                          ? context.monettaColors.canvas
                          : context.monettaColors.contentPrimary,
                    ),
                    selectedColor: context.monettaColors.contentPrimary,
                    backgroundColor: context.monettaColors.surfaceMuted,
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    visualDensity: VisualDensity.compact,
                    showCheckmark: false,
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Candidato de compra · origen EE. UU.',
            style: sans(size: 10.5, color: context.monettaColors.contentMuted),
          ),
          const SizedBox(height: 6),
          // Where this listing's data actually came from — shown as text in
          // the description itself, not only reachable by tapping the CTA.
          Text(
            _sourceLabel(_detailUrl),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: sans(size: 10, color: context.monettaColors.contentMuted),
          ),
          const SizedBox(height: 6),
          UnderlineLink(
            label: externalCtaLabel(widget.item.source),
            onTap: () => _openMerchant(context),
            size: 11,
          ),
        ],
      ),
    );
  }
}

String _sourceLabel(String detailUrl) {
  final uri = Uri.tryParse(detailUrl);
  if (uri == null || uri.host.isEmpty) return detailUrl;
  return '${uri.host}${uri.path}';
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
        'Candidatos para compra manual del propietario. Precio y disponibilidad '
        'pueden haber cambiado en el sitio del comercio.$stamp',
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
