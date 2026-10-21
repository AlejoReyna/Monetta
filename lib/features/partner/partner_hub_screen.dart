/// Reseller hub: share catalogs and start a WhatsApp quote.
/// Opening WhatsApp or a catalog link does not approve reseller status,
/// reserve stock, charge a deposit, create an order, or post commissions.
library;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/shopper_copy.dart';
import '../contact/contact_links.dart';
import '../../app/theme.dart';
import '../../domain/editorial_content.dart';
import '../../domain/home_content.dart';

typedef PartnerUriLauncher = Future<bool> Function(Uri uri);
typedef PartnerCatalogSharer = Future<void> Function(
  PartnerCatalog catalog,
  Rect? origin,
);

const _aboutMonetta = 'https://monetta.mx/pages/contact';

const _wholesaleDetails = <PartnerFaq>[
  PartnerFaq(
    question: 'Sistema de apartado',
    answer: 'El apartado es un proceso manual por WhatsApp: Monetta confirma '
        'disponibilidad, registra el anticipo y crea el pedido en Shopify. '
        'Abrir el chat no reserva stock ni cobra. Anticipo de referencia: '
        r'$800 MXN mayoreo / $400 MXN menudeo, liquidación hasta 20 días. '
        'Escríbenos al 826 106 6868.',
  ),
  PartnerFaq(
    question: 'Productos originales',
    answer: 'Somos una boutique online especializada en productos originales, '
        'con más de tres años de experiencia y verificación como empresa en '
        'Estados Unidos: Monetta Wholesale LLC.',
  ),
  PartnerFaq(
    question: 'Métodos de pago',
    answer: 'Aceptamos transferencia y depósito bancario, tarjetas de crédito '
        'o débito, PayPal, Apple Pay y Mercado Pago.',
  ),
  PartnerFaq(
    question: 'Información sobre envíos',
    answer: 'Enviamos a todo México por FedEx, Estafeta y DHL. Al salir tu '
        'pedido recibirás los detalles por correo; la entrega toma entre 2 y '
        '7 días hábiles según tu ubicación.',
  ),
  PartnerFaq(
    question: 'Políticas de devolución',
    answer: 'Tienes 48 horas desde la entrega para aclaraciones, cambios o '
        'devoluciones, y 72 horas para modificar apartados o cotizaciones. El '
        'costo de envío se determina según el motivo de la solicitud.',
  ),
  PartnerFaq(
    question: 'Productos sobre pedido',
    answer: 'Los modelos con la insignia “Sobre pedido” se preparan para envío '
        'entre 5 y 7 días después del cierre del pedido. Te avisaremos por '
        'correo cuando estén en camino.',
  ),
];

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

  Future<void> _openUri(BuildContext context, Uri uri) async {
    if (!await _launch(uri)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace')),
      );
    }
  }

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

    final catalogFaqs = content.faqs
        .where((faq) => !faq.question.toLowerCase().contains('apartado'))
        .toList(growable: false);

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
          _PartnerHero(
            content: content,
            onQuote: () => _quote(context),
          ),
          const SizedBox(height: 64),
          const _WholesaleDiscount(),
          const SizedBox(height: 68),
          const SectionHeading(
            kicker: 'CÓMO VENDER POR CATÁLOGO',
            title: 'Tu negocio, paso a paso',
          ),
          _Steps(steps: content.steps),
          const SizedBox(height: 60),
          _Terms(terms: content.terms),
          const SizedBox(height: 68),
          const SectionHeading(
            kicker: 'CATÁLOGOS PARA COMPARTIR',
            title: 'Elige cómo quieres vender',
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
          if (catalogFaqs.isNotEmpty) ...[
            const SizedBox(height: 6),
            _CatalogGuide(faqs: catalogFaqs),
          ],
          const SizedBox(height: 68),
          const SectionHeading(
            kicker: 'TODO LO QUE NECESITAS SABER',
            title: 'Preguntas frecuentes',
          ),
          const _WholesaleDetails(),
          const SizedBox(height: 72),
          _CommunitySection(onOpen: (uri) => _openUri(context, uri)),
          const SizedBox(height: 72),
          const _ExperiencesSection(),
          const SizedBox(height: 72),
          _FinalCallToAction(
            onQuote: () => _quote(context),
            onAbout: () => _openUri(context, Uri.parse(_aboutMonetta)),
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

class _PartnerHero extends StatelessWidget {
  const _PartnerHero({required this.content, required this.onQuote});

  final PartnerProgramContent content;
  final VoidCallback onQuote;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final image = Image.asset(
          'assets/images/campaign_olive.jpg',
          fit: BoxFit.cover,
          alignment: const Alignment(0, .18),
          filterQuality: FilterQuality.medium,
        );
        if (wide) {
          return SizedBox(
            height: 650,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 11, child: image),
                Expanded(
                  flex: 9,
                  child: _HeroCopy(
                    content: content,
                    onQuote: onQuote,
                    wide: true,
                  ),
                ),
              ],
            ),
          );
        }

        return SizedBox(
          height: 590,
          child: Stack(
            fit: StackFit.expand,
            children: [
              image,
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x12000000),
                      Color(0x22000000),
                      Color(0xE6000000),
                    ],
                    stops: [0, .36, 1],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _HeroCopy(
                  content: content,
                  onQuote: onQuote,
                  wide: false,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({
    required this.content,
    required this.onQuote,
    required this.wide,
  });

  final PartnerProgramContent content;
  final VoidCallback onQuote;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: wide ? kInk : Colors.transparent,
      padding: EdgeInsets.fromLTRB(
        wide ? 40 : 20,
        wide ? 48 : 28,
        wide ? 40 : 20,
        wide ? 48 : 30,
      ),
      child: Column(
        mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            content.eyebrow,
            style: eyebrow(color: const Color(0xFFC49A65)),
          ),
          const SizedBox(height: 16),
          Text(
            content.headline,
            style: editorial(
              wide ? 38 : 36,
              color: Colors.white,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            content.body,
            style: sans(
              size: wide ? 14 : 13.5,
              color: const Color(0xFFE6E1DB),
              height: 1.58,
            ),
          ),
          const SizedBox(height: 26),
          SizedBox(
            width: wide ? 250 : double.infinity,
            child: FilledButton(
              key: const ValueKey('partner-quote-top'),
              onPressed: onQuote,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: kInk,
              ),
              child: const Text('QUIERO VENDER'),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'MAYOREO DESDE 3 PIEZAS · SIN MONTO MÍNIMO',
            style: eyebrow(size: 8, color: const Color(0xFFD8D0C6)),
          ),
        ],
      ),
    );
  }
}

class _WholesaleDiscount extends StatelessWidget {
  const _WholesaleDiscount();

  @override
  Widget build(BuildContext context) {
    return _ContentFrame(
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 32, 22, 34),
        decoration: BoxDecoration(
          color: context.monettaColors.surfaceMuted,
          border: Border(
            left: BorderSide(
              color: context.monettaColors.accent,
              width: 3,
            ),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 680;
            final title = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DESCUENTOS DE MAYOREO',
                  style: eyebrow(color: context.monettaColors.accentContent),
                ),
                const SizedBox(height: 9),
                Text(
                  'Compra más. Tu precio mejora solo.',
                  style: editorial(wide ? 30 : 26),
                ),
              ],
            );
            final body = Text(
              'Añade al carrito todos los modelos que quieras. El descuento '
              'de mayoreo se aplica automáticamente a cada producto antes '
              'de pagar.',
              style: sans(
                size: 13.5,
                color: context.monettaColors.contentMuted,
                height: 1.6,
              ),
            );
            if (!wide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, const SizedBox(height: 18), body],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: title),
                const SizedBox(width: 48),
                Expanded(child: body),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.steps});

  final List<PartnerStep> steps;

  @override
  Widget build(BuildContext context) {
    return _ContentFrame(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < steps.length; index++) ...[
                  if (index > 0) const SizedBox(width: 28),
                  Expanded(child: _StepCard(step: steps[index])),
                ],
              ],
            );
          }
          return Column(
            children: [
              for (var index = 0; index < steps.length; index++)
                _StepRow(
                  step: steps[index],
                  isLast: index == steps.length - 1,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step});

  final PartnerStep step;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: context.monettaColors.contentPrimary),
        const SizedBox(height: 14),
        Text(
          step.number,
          style: eyebrow(color: context.monettaColors.accentContent),
        ),
        const SizedBox(height: 26),
        Text(step.title, style: editorial(24)),
        const SizedBox(height: 10),
        Text(
          step.body,
          style: sans(
            size: 12.5,
            color: context.monettaColors.contentMuted,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.isLast});

  final PartnerStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Text(
                  step.number,
                  style: eyebrow(color: context.monettaColors.accentContent),
                ),
                const SizedBox(height: 10),
                if (!isLast)
                  Expanded(
                    child: VerticalDivider(
                      color: context.monettaColors.divider,
                      width: 1,
                      thickness: .5,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 34),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.title, style: editorial(23)),
                  const SizedBox(height: 8),
                  Text(
                    step.body,
                    style: sans(
                      size: 13,
                      color: context.monettaColors.contentMuted,
                      height: 1.58,
                    ),
                  ),
                ],
              ),
            ),
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
      color: context.monettaColors.surfaceMuted,
      padding: const EdgeInsets.symmetric(vertical: 38),
      child: _ContentFrame(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 760 ? 4 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: terms.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                childAspectRatio: columns == 4 ? 1.65 : 1.45,
              ),
              itemBuilder: (context, index) {
                final term = terms[index];
                final isRightEdge = (index + 1) % columns == 0;
                final isBottomRow = index >= terms.length - columns;
                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      right: isRightEdge
                          ? BorderSide.none
                          : BorderSide(color: context.monettaColors.divider),
                      bottom: isBottomRow
                          ? BorderSide.none
                          : BorderSide(color: context.monettaColors.divider),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        term.value,
                        textAlign: TextAlign.center,
                        style: editorial(26),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        term.label.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: eyebrow(
                          size: 7.5,
                          color: context.monettaColors.contentMuted,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
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
    return _ContentFrame(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: Text(title, style: editorial(24))),
              Text(
                '${catalogs.length} OPCIONES',
                style: eyebrow(
                  size: 8,
                  color: context.monettaColors.contentMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(),
          for (var index = 0; index < catalogs.length; index++) ...[
            _CatalogCard(
              catalog: catalogs[index],
              onOpen: () => onOpen(catalogs[index]),
              onShare: catalogs[index].mode.isClientFacing
                  ? (buttonContext) => onShare(buttonContext, catalogs[index])
                  : null,
              onQuote: catalogs[index].mode == PartnerCatalogMode.wholesale
                  ? () => onQuote(catalogs[index])
                  : null,
            ),
            if (index < catalogs.length - 1) const Divider(),
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
      padding: const EdgeInsets.symmetric(vertical: 19),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: context.monettaColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    catalog.mode.label.toUpperCase(),
                    style: eyebrow(size: 9),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                catalog.description,
                style: sans(
                  size: 12.5,
                  color: context.monettaColors.contentMuted,
                  height: 1.5,
                ),
              ),
              if (catalog.updatedLabel case final label?) ...[
                const SizedBox(height: 5),
                Text(
                  label,
                  style: sans(
                    size: 10,
                    color: context.monettaColors.contentMuted,
                  ),
                ),
              ],
            ],
          );
          final actions = _CatalogActions(
            catalog: catalog,
            onOpen: onOpen,
            onShare: onShare,
            onQuote: onQuote,
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [copy, const SizedBox(height: 15), actions],
            );
          }
          return Row(
            children: [
              Expanded(child: copy),
              const SizedBox(width: 24),
              SizedBox(width: 280, child: actions),
            ],
          );
        },
      ),
    );
  }
}

class _CatalogActions extends StatelessWidget {
  const _CatalogActions({
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
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            key: ValueKey('open-${catalog.id}'),
            onPressed: onOpen,
            child: const Text('ABRIR'),
          ),
        ),
        const SizedBox(width: 10),
        if (onShare != null)
          Builder(
            builder: (buttonContext) => IconButton.outlined(
              key: ValueKey('share-${catalog.id}'),
              tooltip: 'Compartir catálogo',
              onPressed: () => onShare!(buttonContext),
              icon: const Icon(Icons.ios_share_outlined, size: 19),
            ),
          )
        else
          Expanded(
            child: OutlinedButton(
              key: ValueKey('quote-${catalog.id}'),
              onPressed: onQuote,
              child: const Text('COTIZAR'),
            ),
          ),
      ],
    );
  }
}

class _CatalogGuide extends StatelessWidget {
  const _CatalogGuide({required this.faqs});

  final List<PartnerFaq> faqs;

  @override
  Widget build(BuildContext context) {
    return _ContentFrame(
      child: Container(
        color: context.monettaColors.surfaceMuted,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ANTES DE COMPARTIR', style: eyebrow()),
            const SizedBox(height: 8),
            for (final faq in faqs) _FaqTile(faq: faq),
          ],
        ),
      ),
    );
  }
}

class _WholesaleDetails extends StatelessWidget {
  const _WholesaleDetails();

  @override
  Widget build(BuildContext context) {
    return _ContentFrame(
      child: Column(
        children: [
          for (var index = 0; index < _wholesaleDetails.length; index++) ...[
            _FaqTile(
              faq: _wholesaleDetails[index],
              index: '${index + 1}'.padLeft(2, '0'),
            ),
            if (index < _wholesaleDetails.length - 1) const Divider(),
          ],
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.faq, this.index});

  final PartnerFaq faq;
  final String? index;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.fromLTRB(0, 0, 30, 18),
          leading: index == null
              ? null
              : Text(
                  index!,
                  style: eyebrow(
                    size: 8,
                    color: context.monettaColors.accentContent,
                  ),
                ),
          title: Text(
            faq.question,
            style: sans(size: 13.5, weight: FontWeight.w500),
          ),
          iconColor: context.monettaColors.contentPrimary,
          collapsedIconColor: context.monettaColors.contentPrimary,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                faq.answer,
                style: sans(
                  size: 12.5,
                  color: context.monettaColors.contentMuted,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunitySection extends StatelessWidget {
  const _CommunitySection({required this.onOpen});

  final ValueChanged<Uri> onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kInk,
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: _ContentFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GRUPOS DE MONETTA',
              style: eyebrow(color: const Color(0xFFC49A65)),
            ),
            const SizedBox(height: 9),
            Text(
              'Emprender se siente mejor en comunidad.',
              style: editorial(28, color: Colors.white),
            ),
            const SizedBox(height: 28),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 720;
                final cards = [
                  _CommunityCard(
                    icon: Icons.chat_bubble_outline,
                    count: '+2,000',
                    title: 'Comunidad en WhatsApp',
                    body: 'Accede a modelos, ofertas exclusivas y '
                        'actualizaciones para tu negocio.',
                    actions: [
                      for (var index = 0;
                          index < monettaWhatsAppGroups.length;
                          index++)
                        _CommunityAction(
                          label: 'GRUPO ${index + 1}',
                          onTap: () =>
                              onOpen(Uri.parse(monettaWhatsAppGroups[index])),
                        ),
                    ],
                  ),
                  _CommunityCard(
                    icon: Icons.facebook,
                    count: '+21,000',
                    title: 'El grupo más cool en Facebook',
                    body: 'Descubre modelos originales y publicaciones '
                        'exclusivas de Monetta.',
                    actions: [
                      _CommunityAction(
                        label: 'IR AL GRUPO',
                        onTap: () => onOpen(Uri.parse(monettaFacebookGroup)),
                      ),
                    ],
                  ),
                ];
                if (!wide) {
                  return Column(
                    children: [
                      cards.first,
                      const SizedBox(height: 12),
                      cards.last,
                    ],
                  );
                }
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: cards.first),
                      const SizedBox(width: 14),
                      Expanded(child: cards.last),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityCard extends StatelessWidget {
  const _CommunityCard({
    required this.icon,
    required this.count,
    required this.title,
    required this.body,
    required this.actions,
  });

  final IconData icon;
  final String count;
  final String title;
  final String body;
  final List<_CommunityAction> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x42FFFFFF), width: .5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFC49A65), size: 25),
              const Spacer(),
              Text(count, style: editorial(25, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 24),
          Text(title, style: editorial(22, color: Colors.white)),
          const SizedBox(height: 10),
          Text(
            body,
            style: sans(
              size: 12.5,
              color: const Color(0xFFD6D1CB),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 18,
            runSpacing: 14,
            children: [
              for (final action in actions)
                UnderlineLink(
                  label: action.label,
                  onTap: action.onTap,
                  color: Colors.white,
                  size: 11,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommunityAction {
  const _CommunityAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;
}

class _ExperiencesSection extends StatelessWidget {
  const _ExperiencesSection();

  @override
  Widget build(BuildContext context) {
    final home = HomeContent.fallback;
    final testimonials = home.testimonials.take(2).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          kicker: 'EXPERIENCIAS DE CLIENTES',
          title: 'Negocios que ya comenzaron',
          trailing: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${home.reviewAverage ?? 4.9}', style: editorial(22)),
              Text(
                '${home.reviewCount ?? 139} RESEÑAS',
                style: eyebrow(
                  size: 7,
                  color: context.monettaColors.contentMuted,
                ),
              ),
            ],
          ),
        ),
        _ContentFrame(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              final cards = [
                for (final testimonial in testimonials)
                  _TestimonialCard(testimonial: testimonial),
              ];
              if (!wide) {
                return SizedBox(
                  height: 248,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: cards.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => SizedBox(
                      width: (constraints.maxWidth * .86).clamp(280.0, 360.0),
                      child: cards[index],
                    ),
                  ),
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < cards.length; index++) ...[
                      if (index > 0) const SizedBox(width: 12),
                      Expanded(child: cards[index]),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  const _TestimonialCard({required this.testimonial});

  final HomeTestimonial testimonial;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: context.monettaColors.surfaceMuted,
        border: Border.all(color: context.monettaColors.divider, width: .5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var index = 0; index < testimonial.rating; index++)
                Icon(
                  Icons.star,
                  size: 14,
                  color: context.monettaColors.accent,
                ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Text(
              '“${testimonial.body}”',
              style: editorial(19, height: 1.35),
            ),
          ),
          const SizedBox(height: 16),
          Text(testimonial.reviewer.toUpperCase(), style: eyebrow(size: 8)),
          if (testimonial.verified)
            Text(
              'COMPRA VERIFICADA',
              style: eyebrow(
                size: 7,
                color: context.monettaColors.contentMuted,
              ),
            ),
        ],
      ),
    );
  }
}

class _FinalCallToAction extends StatelessWidget {
  const _FinalCallToAction({required this.onQuote, required this.onAbout});

  final VoidCallback onQuote;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.monettaColors.surfaceMuted,
      padding: const EdgeInsets.symmetric(vertical: 58),
      child: _ContentFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TU PRÓXIMA VENTA PUEDE EMPEZAR HOY',
              style: eyebrow(color: context.monettaColors.accentContent),
            ),
            const SizedBox(height: 12),
            Text(
              'Nosotros ponemos los productos. Tú haces crecer la comunidad.',
              style: editorial(30, height: 1.18),
            ),
            const SizedBox(height: 25),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 520;
                final quote = SizedBox(
                  width: wide ? 280 : double.infinity,
                  child: FilledButton(
                    key: const ValueKey('partner-quote-bottom'),
                    onPressed: onQuote,
                    child: const Text('COTIZAR POR WHATSAPP'),
                  ),
                );
                final about = TextButton(
                  onPressed: onAbout,
                  child: const Text('MÁS SOBRE MONETTA'),
                );
                if (!wide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [quote, const SizedBox(height: 10), about],
                  );
                }
                return Row(
                  children: [quote, const SizedBox(width: 16), about],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentFrame extends StatelessWidget {
  const _ContentFrame({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
