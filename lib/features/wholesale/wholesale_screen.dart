/// Pantalla Mayoreo del paquete F (figura 10).
///
/// Secciones: portada editorial, condiciones reales, precio por volumen
/// (cualitativo, sin tarifas inventadas), cómo funciona, pagos/envíos y CTA.
/// Propiedad de F: no editar desde otros paquetes; la integración global
/// (Home) vive en `docs/redesign/PAQUETE_F_INTEGRACION.md`, no aquí.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/shopper_copy.dart';
import '../../app/theme.dart';
import 'wholesale_content.dart';

Future<bool> _launch(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Punto de entrada documentado para el parche de integración (Home):
/// `Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WholesaleScreen()))`.
class WholesaleScreen extends StatelessWidget {
  const WholesaleScreen({super.key});

  Future<void> _quote(BuildContext context) async {
    final uri = wholesaleQuoteUri();
    if (!await _launch(uri)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.monettaColors;
    return Scaffold(
      appBar: AppBar(title: const MonettaWordmark.appBar()),
      body: ListView(
        key: const ValueKey('wholesale-scroll'),
        padding: EdgeInsets.zero,
        children: [
          _Cover(onQuote: () => _quote(context)),
          const SizedBox(height: 56),
          const SectionHeading(
            kicker: 'CONDICIONES REALES',
            title: 'Mayoreo sin letras chicas',
          ),
          _Conditions(colors: colors),
          const SizedBox(height: 56),
          const SectionHeading(
            kicker: 'PRECIO POR VOLUMEN',
            title: 'Compra más, mejora tu precio',
          ),
          _VolumePricing(colors: colors, onQuote: () => _quote(context)),
          const SizedBox(height: 56),
          const SectionHeading(
            kicker: 'CÓMO FUNCIONA',
            title: 'De la selección al pedido',
          ),
          _Steps(colors: colors),
          const SizedBox(height: 56),
          _Logistics(colors: colors),
          const SizedBox(height: 56),
          _RewardsNote(colors: colors),
          const SizedBox(height: 56),
          _FinalCta(onQuote: () => _quote(context)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.onQuote});

  final VoidCallback onQuote;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 520,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/campaign_olive.jpg',
            fit: BoxFit.cover,
            alignment: const Alignment(0, .18),
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) =>
                Container(color: context.monettaColors.surfaceMuted),
          ),
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MAYOREO MONETTA',
                    style: eyebrow(color: const Color(0xFFC49A65)),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Compra desde 3 piezas. Obtén mejores precios.',
                    style: editorial(34, color: Colors.white, height: 1.08),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Productos originales para tu negocio, con apartado y '
                    'acompañamiento por WhatsApp.',
                    style: sans(
                      size: 13.5,
                      color: const Color(0xFFE6E1DB),
                      height: 1.58,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('wholesale-quote-top'),
                      onPressed: onQuote,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: kInk,
                      ),
                      child: const Text('COTIZAR POR WHATSAPP'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'MAYOREO DESDE 3 PIEZAS · SIN MONTO MÍNIMO',
                    style: eyebrow(size: 8, color: const Color(0xFFD8D0C6)),
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

class _Conditions extends StatelessWidget {
  const _Conditions({required this.colors});

  final MonettaColors colors;

  static const _icons = {
    'piezas': Icons.inventory_2_outlined,
    'anticipo': Icons.payments_outlined,
    'plazo': Icons.schedule_outlined,
    'original': Icons.verified_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          final cards = [
            for (final c in WholesaleTerms.conditions)
              _ConditionCard(
                colors: colors,
                icon: _icons[c.icon] ?? Icons.circle_outlined,
                title: c.title,
                body: c.body,
              ),
          ];
          if (!wide) {
            return Column(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  cards[i],
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: cards[i]),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ConditionCard extends StatelessWidget {
  const _ConditionCard({
    required this.colors,
    required this.icon,
    required this.title,
    required this.body,
  });

  final MonettaColors colors;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.divider, width: .5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: colors.accent),
          const SizedBox(height: 16),
          Text(title, style: editorial(20)),
          const SizedBox(height: 8),
          Text(
            body,
            style: sans(size: 12.5, color: colors.contentMuted, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _VolumePricing extends StatelessWidget {
  const _VolumePricing({required this.colors, required this.onQuote});

  final MonettaColors colors;
  final VoidCallback onQuote;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 30, 22, 30),
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          border: Border(left: BorderSide(color: colors.accent, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CÓMO SE FORMA TU PRECIO', style: eyebrow()),
            const SizedBox(height: 12),
            Text(
              WholesaleTerms.volumePricingNote,
              style: sans(size: 13.5, color: colors.contentMuted, height: 1.6),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: const [
                _VolumeChip(label: '3+ MODELOS'),
                _VolumeChip(label: r'ANTICIPO $800'),
                _VolumeChip(label: '20 DÍAS'),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const ValueKey('wholesale-quote-volume'),
                onPressed: onQuote,
                child: const Text('PEDIR MI COTIZACIÓN'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VolumeChip extends StatelessWidget {
  const _VolumeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: context.monettaColors.divider, width: .5),
      ),
      child: Text(label, style: eyebrow(size: 8)),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.colors});

  final MonettaColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          for (var i = 0; i < WholesaleTerms.steps.length; i++)
            _StepRow(
              colors: colors,
              step: WholesaleTerms.steps[i],
              isLast: i == WholesaleTerms.steps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.colors,
    required this.step,
    required this.isLast,
  });

  final MonettaColors colors;
  final WholesaleStep step;
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
                  style: eyebrow(color: colors.accentContent),
                ),
                const SizedBox(height: 10),
                if (!isLast)
                  Expanded(
                    child: VerticalDivider(
                      color: colors.divider,
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
                      color: colors.contentMuted,
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

class _Logistics extends StatelessWidget {
  const _Logistics({required this.colors});

  final MonettaColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colors.surfaceMuted,
      padding: const EdgeInsets.symmetric(vertical: 38),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PAGOS, ENVÍOS Y DEVOLUCIONES', style: eyebrow()),
            const SizedBox(height: 16),
            for (final method in WholesaleTerms.paymentMethods)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check,
                      size: 15,
                      color: colors.accentContent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(method, style: sans(size: 12.5, height: 1.5)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            Text(
              WholesaleTerms.shipping,
              style: sans(size: 12.5, color: colors.contentMuted, height: 1.6),
            ),
            const SizedBox(height: 10),
            Text(
              WholesaleTerms.returns,
              style: sans(size: 12.5, color: colors.contentMuted, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardsNote extends StatelessWidget {
  const _RewardsNote({required this.colors});

  final MonettaColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          border: Border.all(color: colors.divider, width: .5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: 18,
              color: colors.contentMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                WholesaleTerms.rewardsNote,
                style:
                    sans(size: 12.5, color: colors.contentMuted, height: 1.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinalCta extends StatelessWidget {
  const _FinalCta({required this.onQuote});

  final VoidCallback onQuote;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kInk,
      padding: const EdgeInsets.symmetric(vertical: 52, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TU PRÓXIMA VENTA PUEDE EMPEZAR HOY',
            style: eyebrow(color: const Color(0xFFC49A65)),
          ),
          const SizedBox(height: 12),
          Text(
            'Mándanos tus modelos y te cotizamos mayoreo.',
            style: editorial(28, color: Colors.white, height: 1.18),
          ),
          const SizedBox(height: 12),
          Text(
            'WhatsApp $kWhatsAppNumberDisplay · respuesta con '
            'disponibilidad y precio por producto.',
            style:
                sans(size: 12.5, color: const Color(0xFFD6D1CB), height: 1.55),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('wholesale-quote-bottom'),
              onPressed: onQuote,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: kInk,
              ),
              child: const Text('COTIZAR POR WHATSAPP'),
            ),
          ),
        ],
      ),
    );
  }
}
