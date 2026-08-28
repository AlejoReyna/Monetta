/// Public reseller toolkit: understand the flow, open/share a client-safe
/// catalog, then hand a quote to Monetta over WhatsApp.
library;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/shopper_copy.dart';
import '../../app/theme.dart';
import '../../domain/editorial_content.dart';

typedef PartnerUriLauncher = Future<bool> Function(Uri uri);
typedef PartnerCatalogSharer = Future<void> Function(
  PartnerCatalog catalog,
  Rect? origin,
);

class PartnerHubScreen extends StatelessWidget {
  const PartnerHubScreen({
    required this.content,
    this.launchUri,
    this.shareCatalog,
    super.key,
  });

  final PartnerProgramContent content;
  final PartnerUriLauncher? launchUri;
  final PartnerCatalogSharer? shareCatalog;

  Future<bool> _launch(Uri uri) => (launchUri ?? _defaultLaunchPartnerUri)(uri);

  Future<void> _openCatalog(
    BuildContext context,
    PartnerCatalog catalog,
  ) async {
    final uri = catalog.uri;
    if (uri == null || !await _launch(uri)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el catálogo')),
      );
    }
  }

  Future<void> _share(
    BuildContext context,
    PartnerCatalog catalog,
  ) async {
    final renderBox = context.findRenderObject();
    final origin = renderBox is RenderBox
        ? renderBox.localToGlobal(Offset.zero) & renderBox.size
        : null;
    try {
      await (shareCatalog ?? _defaultSharePartnerCatalog)(catalog, origin);
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo compartir el catálogo')),
      );
    }
  }

  Future<void> _quote(
    BuildContext context, {
    PartnerCatalog? catalog,
  }) async {
    final uri = partnerQuoteWhatsAppUri(
      category: catalog?.categoryLabel,
      catalogMode: catalog?.mode.label,
    );
    if (!await _launch(uri)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<PartnerCatalog>>{};
    for (final catalog in content.catalogs) {
      groups.putIfAbsent(catalog.categoryLabel, () => []).add(catalog);
    }

    return Scaffold(
      appBar: AppBar(
        title: const MonettaWordmark.appBar(),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Divider(height: 0.5),
        ),
      ),
      body: ListView(
        key: const ValueKey('partner-hub-scroll'),
        padding: EdgeInsets.zero,
        children: [
          Container(
            color: kInk,
            padding: const EdgeInsets.fromLTRB(20, 58, 20, 58),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(content.eyebrow, style: eyebrow(color: kGold)),
                  const SizedBox(height: 18),
                  Text(
                    content.headline,
                    style: display(36, color: Colors.white, height: 1.18),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    content.body,
                    style: sans(
                      size: 14,
                      color: const Color(0xFFD6D6D6),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 30),
                  FilledButton(
                    key: const ValueKey('partner-quote-top'),
                    onPressed: () => _quote(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: kInk,
                    ),
                    child: const Text('QUIERO COTIZAR'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 58),
          const SectionHeading(
            kicker: 'ASÍ FUNCIONA',
            title: 'Empieza en tres pasos',
          ),
          _Steps(steps: content.steps),
          const SizedBox(height: 58),
          _Terms(terms: content.terms),
          const SizedBox(height: 64),
          const SectionHeading(
            kicker: 'CATÁLOGOS DISPONIBLES',
            title: 'Elige qué quieres vender',
          ),
          for (final entry in groups.entries)
            _CatalogGroup(
              title: entry.key,
              catalogs: entry.value,
              onOpen: (catalog) => _openCatalog(context, catalog),
              onShare: (buttonContext, catalog) =>
                  _share(buttonContext, catalog),
              onQuote: (catalog) => _quote(context, catalog: catalog),
            ),
          const SizedBox(height: 42),
          Container(
            color: kMist,
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 50),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PREGUNTAS FRECUENTES', style: eyebrow()),
                const SizedBox(height: 14),
                for (final faq in content.faqs) _FaqTile(faq: faq),
                const SizedBox(height: 26),
                FilledButton(
                  key: const ValueKey('partner-quote-bottom'),
                  onPressed: () => _quote(context),
                  child: const Text('COTIZAR POR WHATSAPP'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> _defaultLaunchPartnerUri(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

Future<void> _defaultSharePartnerCatalog(
  PartnerCatalog catalog,
  Rect? origin,
) async {
  await Share.share(
    catalog.shareText,
    subject: 'Catálogo de ${catalog.categoryLabel}',
    sharePositionOrigin: origin,
  );
}

class _Steps extends StatelessWidget {
  const _Steps({required this.steps});

  final List<PartnerStep> steps;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final children = [
          for (final step in steps) Expanded(child: _StepCard(step: step)),
        ];
        if (wide) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _withGaps(children, horizontal: true),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              for (final step in steps) ...[
                _StepCard(step: step),
                if (step != steps.last) const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    );
  }

  List<Widget> _withGaps(List<Widget> children, {required bool horizontal}) {
    final result = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) result.add(SizedBox(width: horizontal ? 12 : 0));
      result.add(children[i]);
    }
    return result;
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step});

  final PartnerStep step;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(border: Border.all(color: kLine)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(step.number, style: eyebrow(color: kGold)),
          const SizedBox(height: 18),
          Text(step.title, style: display(20)),
          const SizedBox(height: 8),
          Text(
            step.body,
            style: sans(size: 12.5, color: kInkMuted, height: 1.55),
          ),
        ],
      ),
    );
  }
}

class _Terms extends StatelessWidget {
  const _Terms({required this.terms});

  final List<PartnerTerm> terms;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kMist,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 760 ? 4 : 2;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: terms.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              childAspectRatio: columns == 4 ? 1.7 : 1.55,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final term = terms[index];
              return Container(
                padding: const EdgeInsets.all(14),
                color: Colors.white,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      term.value,
                      textAlign: TextAlign.center,
                      style: display(23),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      term.label,
                      textAlign: TextAlign.center,
                      style: sans(size: 10.5, color: kInkMuted, height: 1.25),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CatalogGroup extends StatelessWidget {
  const _CatalogGroup({
    required this.title,
    required this.catalogs,
    required this.onOpen,
    required this.onShare,
    required this.onQuote,
  });

  final String title;
  final List<PartnerCatalog> catalogs;
  final ValueChanged<PartnerCatalog> onOpen;
  final void Function(BuildContext, PartnerCatalog) onShare;
  final ValueChanged<PartnerCatalog> onQuote;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 42),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: display(22)),
          const SizedBox(height: 14),
          for (final catalog in catalogs) ...[
            _CatalogCard(
              catalog: catalog,
              onOpen: () => onOpen(catalog),
              onShare: catalog.mode.isClientFacing
                  ? (buttonContext) => onShare(buttonContext, catalog)
                  : null,
              onQuote: catalog.mode == PartnerCatalogMode.wholesale
                  ? () => onQuote(catalog)
                  : null,
            ),
            if (catalog != catalogs.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({
    required this.catalog,
    required this.onOpen,
    required this.onShare,
    required this.onQuote,
  });

  final PartnerCatalog catalog;
  final VoidCallback onOpen;
  final ValueChanged<BuildContext>? onShare;
  final VoidCallback? onQuote;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('partner-catalog-${catalog.id}'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(border: Border.all(color: kLine)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  catalog.mode.label.toUpperCase(),
                  style: eyebrow(color: kGold),
                ),
              ),
              Text(
                catalog.mode.isClientFacing ? 'PARA COMPARTIR' : 'USO INTERNO',
                style: eyebrow(size: 8),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(catalog.description, style: sans(size: 12.5, height: 1.5)),
          if (catalog.updatedLabel case final label?) ...[
            const SizedBox(height: 5),
            Text(label, style: sans(size: 10, color: kInkMuted)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: ValueKey('open-${catalog.id}'),
                  onPressed: onOpen,
                  child: const Text('ABRIR'),
                ),
              ),
              if (onShare != null) ...[
                const SizedBox(width: 10),
                Builder(
                  builder: (buttonContext) => IconButton.outlined(
                    key: ValueKey('share-${catalog.id}'),
                    tooltip: 'Compartir catálogo',
                    onPressed: () => onShare!(buttonContext),
                    icon: const Icon(Icons.ios_share_outlined, size: 19),
                  ),
                ),
              ] else if (onQuote != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    key: ValueKey('quote-${catalog.id}'),
                    onPressed: onQuote,
                    child: const Text('COTIZAR'),
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

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.faq});

  final PartnerFaq faq;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 18),
          title: Text(
            faq.question,
            style: sans(size: 13, weight: FontWeight.w500),
          ),
          iconColor: kInk,
          collapsedIconColor: kInk,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                faq.answer,
                style: sans(size: 12.5, color: kInkMuted, height: 1.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
