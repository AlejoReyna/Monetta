/// The owner-procurement rail: verified US merchant listings surfaced
/// alongside Monetta's own feed.
///
/// Everything here is deliberately inert with respect to the revenue path —
/// no wishlist heart, no add-to-bag, no WhatsApp apartado. A tap anywhere on
/// a card, or the CTA specifically, opens the merchant's own page outside
/// the app (`LaunchMode.externalApplication`). See `domain/catalog_item.dart`
/// (`PurchaseMode.ownerProcurement`) and `docs/ARCHITECTURE.md` §
/// "External catalog prototype" for why this boundary exists.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../domain/catalog_item.dart';

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
    case CatalogSourceType.monettaShopify:
      return '';
  }
}

/// Opens an external product's page outside the app. Exposed so it can be
/// swapped in tests (see `test/features/home/external_catalog_section_test.dart`).
typedef ExternalLinkOpener = Future<bool> Function(Uri uri);

Future<bool> defaultExternalLinkOpener(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(
          kicker: 'Investigación · Estados Unidos',
          title: 'También en marcas de Estados Unidos',
        ),
        _ExternalRail(items: items, openLink: openLink),
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
      // +156 (was +130): the extra 26px fits the source-link line added
      // below the delivery note.
      height: width / 0.75 + 156,
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

class _ExternalCard extends StatelessWidget {
  const _ExternalCard({required this.item, required this.openLink});

  final CatalogItem item;
  final ExternalLinkOpener openLink;

  Future<void> _open(BuildContext context) async {
    // Re-validated here, independent of whatever the backend already
    // checked — scheme must be HTTPS and the host must actually belong to
    // this item's declared source. See `domain/catalog_item.dart`.
    if (!isValidExternalDetailUrl(item)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enlace no válido para ${item.merchant}')),
        );
      }
      return;
    }
    final uri = Uri.parse(item.detailUrl);
    final launched = await openLink(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir ${item.merchant}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _open(context),
      // Deliberately no favorite icon, no "add to bag" affordance — this
      // card can only ever lead outside the app, never into Monetta's cart.
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
            externalSourceBadge(item.source).toUpperCase(),
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
          const SizedBox(height: 4),
          Text(
            'Candidato de compra · origen EE. UU.',
            style: sans(size: 10.5, color: kInkMuted),
          ),
          const SizedBox(height: 6),
          // Where this listing's data actually came from — shown as text in
          // the description itself, not only reachable by tapping the CTA.
          Text(
            sourceLinkLabel(item),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: sans(size: 10, color: kInkMuted),
          ),
          const SizedBox(height: 6),
          UnderlineLink(
            label: externalCtaLabel(item.source),
            onTap: () => _open(context),
            size: 11,
          ),
        ],
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
        'Candidatos para compra manual del propietario. Precio y disponibilidad '
        'pueden haber cambiado en el sitio del comercio.$stamp',
        style: sans(size: 10.5, color: kInkMuted),
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
