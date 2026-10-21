/// Continuidad de Monetta Rewards (guía del cliente, página 15).
///
/// Comparte los catálogos públicos que ya existen en el contenido editorial.
/// No crea enlaces nuevos, no simula una tienda ni promete puntos: la regla
/// de recompensa por compartir sigue pendiente de confirmación y se muestra
/// como marcador visible.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme.dart';
import '../../domain/editorial_content.dart';
import '../../main.dart';
import '../boutique/boutique_tokens.dart';
import '../boutique/client_guide_sections.dart';

typedef RewardsShareCatalog = Future<void> Function(
  PartnerCatalog catalog,
  Rect? origin,
);
typedef RewardsCopyLink = Future<void> Function(String text);

class RewardsContinuityScreen extends StatelessWidget {
  const RewardsContinuityScreen({
    this.catalogs,
    this.onShare,
    this.onCopy,
    super.key,
  });

  /// Catálogos de prueba o configuración explícita. Sin valor, usa el
  /// contenido editorial vigente y, si no existe, el respaldo empaquetado.
  final List<PartnerCatalog>? catalogs;
  final RewardsShareCatalog? onShare;
  final RewardsCopyLink? onCopy;

  List<PartnerCatalog> _availableCatalogs(BuildContext context) {
    final content = EditorialContentScope.maybeOf(context)?.content ??
        MonettaEditorialContent.fallback;
    return catalogs ?? content.partner.catalogs;
  }

  PartnerCatalog? _pick(List<PartnerCatalog> source, String category) {
    for (final catalog in source) {
      if (catalog.category == category &&
          catalog.mode == PartnerCatalogMode.suggestedPrices &&
          catalog.uri != null) {
        return catalog;
      }
    }
    for (final catalog in source) {
      if (catalog.category == category && catalog.uri != null) {
        return catalog;
      }
    }
    return null;
  }

  Future<void> _share(BuildContext context, PartnerCatalog catalog) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    try {
      await (onShare ?? _defaultShare)(catalog, origin);
    } on Exception {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo compartir. Intenta de nuevo.'),
        ),
      );
    }
  }

  static Future<void> _defaultShare(
    PartnerCatalog catalog,
    Rect? origin,
  ) async {
    await Share.share(
      catalog.shareText,
      subject: 'Catálogo de ${catalog.categoryLabel}',
      sharePositionOrigin: origin,
    );
  }

  Future<void> _copy(BuildContext context, PartnerCatalog catalog) async {
    try {
      await (onCopy ?? _defaultCopy)(catalog.url);
    } on Exception {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo copiar el enlace. Intenta de nuevo.'),
        ),
      );
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enlace copiado')),
    );
  }

  static Future<void> _defaultCopy(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final source = _availableCatalogs(context);
    final bags = _pick(source, 'bags');
    final perfumes = _pick(source, 'perfume');
    final cards = <Widget>[
      if (bags != null)
        _CatalogCard(
          key: const ValueKey('rewards-continuity-bags'),
          catalog: bags,
          title: 'Catálogo de bolsos',
          body: 'Comparte esta colección.',
          imageAsset: 'assets/images/home_bag_shoulder.webp',
          onShare: () => unawaited(_share(context, bags)),
          onCopy: () => unawaited(_copy(context, bags)),
        ),
      if (perfumes != null)
        _CatalogCard(
          key: const ValueKey('rewards-continuity-perfumes'),
          catalog: perfumes,
          title: 'Catálogo de perfumes',
          body: 'Comparte esta colección.',
          icon: Icons.local_florist_outlined,
          onShare: () => unawaited(_share(context, perfumes)),
          onCopy: () => unawaited(_copy(context, perfumes)),
        ),
    ];

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        backgroundColor: palette.bar,
        foregroundColor: palette.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const MonettaWordmark.appBar(),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(.5),
          child: Container(height: .5, color: palette.hairline),
        ),
      ),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('rewards-continuity-scroll'),
          padding: const EdgeInsets.fromLTRB(
            BoutiqueSpace.gutter,
            BoutiqueSpace.xl,
            BoutiqueSpace.gutter,
            BoutiqueSpace.xxl,
          ),
          children: [
            ClientGuideEditorial(
              title: 'Comparte y gana',
              subtitle: 'Comparte el catálogo de Monetta con quien quieras. '
                  'Las recompensas por compartir se publicarán cuando el '
                  'programa las confirme.',
              imageAsset: 'assets/images/home_collection_bags.webp',
            ),
            const SizedBox(height: BoutiqueSpace.xl),
            Text(
              'Catálogos para compartir',
              style:
                  boutiqueSectionHeading(context: context, color: palette.ink),
            ),
            const SizedBox(height: BoutiqueSpace.md),
            if (cards.isEmpty)
              _ContinuityEmpty(key: const ValueKey('rewards-continuity-empty'))
            else
              for (var index = 0; index < cards.length; index++) ...[
                if (index > 0) const SizedBox(height: BoutiqueSpace.md),
                cards[index],
              ],
            const SizedBox(height: BoutiqueSpace.xl),
            _PendingNote(
              text: 'Los enlaces abren los catálogos públicos que Monetta ya '
                  'publicó. La recompensa por compartir aún no tiene una regla '
                  'confirmada; aquí verás el detalle cuando esté disponible.',
            ),
            const SizedBox(height: BoutiqueSpace.md),
            Text(
              'Los catálogos se comparten como enlace o desde el menú de '
              'compartir de tu teléfono.',
              style: boutiqueText(size: 12, color: palette.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({
    required this.catalog,
    required this.title,
    required this.body,
    required this.onShare,
    required this.onCopy,
    this.imageAsset,
    this.icon,
    super.key,
  });

  final PartnerCatalog catalog;
  final String title;
  final String body;
  final VoidCallback onShare;
  final VoidCallback onCopy;
  final String? imageAsset;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compact = MediaQuery.sizeOf(context).width < 600 || textScale > 1.3;
    final thumbnail = _Thumbnail(
      imageAsset: imageAsset,
      icon: icon,
    );
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: boutiqueRowLabel(context: context, color: palette.ink),
        ),
        const SizedBox(height: BoutiqueSpace.xs),
        Text(body, style: boutiqueText(size: 13, color: palette.inkMuted)),
      ],
    );
    final share = _ShareAction(
      key: ValueKey('rewards-continuity-share-${catalog.id}'),
      label: 'Compartir enlace',
      onTap: onShare,
    );

    return Container(
      padding: const EdgeInsets.all(BoutiqueSpace.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BoutiqueRadius.card,
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compact)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                thumbnail,
                const SizedBox(width: BoutiqueSpace.md),
                Expanded(child: copy),
              ],
            )
          else
            Row(
              children: [
                thumbnail,
                const SizedBox(width: BoutiqueSpace.lg),
                Expanded(child: copy),
                const SizedBox(width: BoutiqueSpace.md),
                share,
              ],
            ),
          if (compact) ...[
            const SizedBox(height: BoutiqueSpace.md),
            Align(alignment: Alignment.centerLeft, child: share),
          ],
          const SizedBox(height: BoutiqueSpace.md),
          _UrlRow(
            url: catalog.url,
            onCopy: onCopy,
            catalogId: catalog.id,
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({this.imageAsset, this.icon});

  final String? imageAsset;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final image = imageAsset;
    return ClipRRect(
      borderRadius: BoutiqueRadius.tile,
      child: SizedBox(
        width: 76,
        height: 76,
        child: image == null
            ? ColoredBox(
                color: palette.surfaceDeep,
                child: Icon(
                  icon ?? Icons.image_outlined,
                  size: 28,
                  color: palette.goldText,
                ),
              )
            : Image.asset(
                image,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: palette.surfaceDeep,
                  child: Icon(
                    icon ?? Icons.image_outlined,
                    size: 28,
                    color: palette.goldText,
                  ),
                ),
              ),
      ),
    );
  }
}

class _ShareAction extends StatelessWidget {
  const _ShareAction({
    required this.label,
    required this.onTap,
    super.key,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BoutiqueRadius.control,
        child: Container(
          constraints: const BoxConstraints(minHeight: BoutiqueSpace.tapTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: BoutiqueSpace.sm,
            vertical: BoutiqueSpace.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.share_outlined, size: 18, color: palette.goldText),
              const SizedBox(width: BoutiqueSpace.xs),
              Flexible(
                child: Text(
                  label,
                  style: boutiqueText(
                    size: 13,
                    weight: FontWeight.w600,
                    color: palette.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UrlRow extends StatelessWidget {
  const _UrlRow({
    required this.url,
    required this.onCopy,
    required this.catalogId,
  });

  final String url;
  final VoidCallback onCopy;
  final String catalogId;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        BoutiqueSpace.md,
        BoutiqueSpace.xs,
        BoutiqueSpace.xs,
        BoutiqueSpace.xs,
      ),
      decoration: BoxDecoration(
        color: palette.surfaceDeep,
        borderRadius: BoutiqueRadius.control,
        border: Border.all(color: palette.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: boutiqueText(size: 12, color: palette.inkMuted),
            ),
          ),
          IconButton(
            key: ValueKey('rewards-continuity-copy-$catalogId'),
            tooltip: 'Copiar enlace',
            onPressed: onCopy,
            icon: Icon(Icons.copy_rounded, size: 18, color: palette.ink),
          ),
        ],
      ),
    );
  }
}

class _ContinuityEmpty extends StatelessWidget {
  const _ContinuityEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Container(
      padding: const EdgeInsets.all(BoutiqueSpace.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BoutiqueRadius.card,
        border: Border.all(color: palette.hairline),
      ),
      child: Text(
        'Los catálogos para compartir todavía no están configurados. '
        'Vuelve a intentarlo más tarde.',
        style: boutiqueText(size: 13, color: palette.inkMuted),
      ),
    );
  }
}

class _PendingNote extends StatelessWidget {
  const _PendingNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Row(
      key: const ValueKey('rewards-continuity-pending-note'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 17, color: palette.goldText),
        const SizedBox(width: BoutiqueSpace.sm),
        Expanded(
          child: Text(
            text,
            style: boutiqueText(size: 12, color: palette.inkMuted),
          ),
        ),
      ],
    );
  }
}
