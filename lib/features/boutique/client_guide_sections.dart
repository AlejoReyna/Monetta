/// Shared presentation for the continuation pages of the client guide.
library;

import 'package:flutter/material.dart';
import '../../app/monetta_tokens.g.dart';
import '../../app/theme.dart';
import 'boutique_tokens.dart';
import 'client_guide_components.dart';

class ClientGuideEditorial extends StatelessWidget {
  const ClientGuideEditorial({
    required this.title,
    required this.subtitle,
    required this.imageAsset,
    this.action,
    super.key,
  });
  final String title;
  final String subtitle;
  final String imageAsset;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return ColoredBox(
      color: palette.surfaceDeep,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < MonettaTokens.breakpointMedium;
          final copy = Padding(
            padding:
                EdgeInsets.all(MonettaTokens.gutterFor(constraints.maxWidth)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: clientGuideStyle(context, MonettaTokens.campaign),
                ),
                SizedBox(height: MonettaTokens.space[2]),
                Text(
                  subtitle,
                  style: clientGuideStyle(
                    context,
                    MonettaTokens.body,
                    color: palette.inkMuted,
                  ),
                ),
                if (action != null) ...[
                  SizedBox(height: MonettaTokens.space[3]),
                  action!,
                ],
              ],
            ),
          );
          final photo = Image.asset(
            imageAsset,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            errorBuilder: (_, __, ___) => ColoredBox(color: palette.surface),
          );
          // At large text sizes the copy gets the full width and natural height.
          if (compact && MediaQuery.textScalerOf(context).scale(1) > 1.3) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [copy, AspectRatio(aspectRatio: 2, child: photo)],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: compact ? 3 : 2, child: copy),
                Expanded(flex: 2, child: photo),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ClientGuideServices extends StatelessWidget {
  const ClientGuideServices({super.key});
  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    const services = [
      (Icons.local_shipping_outlined, 'Envíos', 'Costo y plazo por confirmar'),
      (Icons.lock_outline, 'Pagos seguros', 'Compra con confianza'),
      (Icons.verified_outlined, 'Productos originales', 'Conoce cada pieza'),
      (
        Icons.headset_mic_outlined,
        'Atención personalizada',
        'Estamos para ayudarte'
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth >= MonettaTokens.breakpointMedium ? 4 : 2;
        return ColoredBox(
          color: palette.surface,
          child: Padding(
            padding: EdgeInsets.all(MonettaTokens.space[3]),
            child: Wrap(
              children: [
                for (final service in services)
                  SizedBox(
                    width: (constraints.maxWidth - MonettaTokens.space[3] * 2) /
                        columns,
                    child: Padding(
                      padding: EdgeInsets.all(MonettaTokens.space[2]),
                      child: Column(
                        children: [
                          Icon(
                            service.$1,
                            color: palette.goldText,
                            size: MonettaTokens.space[5],
                          ),
                          SizedBox(height: MonettaTokens.space[1]),
                          Text(
                            service.$2,
                            textAlign: TextAlign.center,
                            style: clientGuideStyle(
                              context,
                              MonettaTokens.cardLabel,
                            ),
                          ),
                          SizedBox(height: MonettaTokens.space[0]),
                          Text(
                            service.$3,
                            textAlign: TextAlign.center,
                            style: clientGuideStyle(
                              context,
                              MonettaTokens.navLabel,
                              color: palette.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ClientGuideFooter extends StatelessWidget {
  const ClientGuideFooter({
    required this.onContact,
    required this.onAbout,
    super.key,
  });
  final VoidCallback onContact;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Container(
      key: const ValueKey('client-guide-footer'),
      color: palette.bar,
      padding: EdgeInsets.all(MonettaTokens.space[4]),
      child: Column(
        children: [
          const MonettaWordmark(height: MonettaTokens.logoHeight),
          SizedBox(height: MonettaTokens.space[3]),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: MonettaTokens.space[3],
            children: [
              TextButton(
                onPressed: onContact,
                child: const Text('Ayuda y contacto'),
              ),
              TextButton(
                onPressed: onAbout,
                child: const Text('Nuestra historia'),
              ),
            ],
          ),
          SizedBox(height: MonettaTokens.space[1]),
          Text(
            'Información de envíos y políticas: pendiente de aprobación.',
            textAlign: TextAlign.center,
            style: clientGuideStyle(
              context,
              MonettaTokens.navLabel,
              color: palette.inkMuted,
            ),
          ),
          SizedBox(height: MonettaTokens.space[3]),
          Text(
            'Monetta · Todos los derechos reservados',
            textAlign: TextAlign.center,
            style: clientGuideStyle(
              context,
              MonettaTokens.navLabel,
              color: palette.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
