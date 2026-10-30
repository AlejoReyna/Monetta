/// Bloques boutique compartidos por las pantallas del paquete E.
///
/// Cuenta, Favoritos, Mis pedidos, Detalle, Contacto y Notificaciones usan
/// estos mismos encabezados, filas, cápsulas y avisos para leerse como una
/// sola boutique: fondo marfil, tinta casi negra, dorado solo en marcas y
/// texto dorado accesible, separadores finos e iconografía lineal.
library;

import 'package:flutter/material.dart';

import '../boutique/boutique_tokens.dart';
import '../boutique/client_guide_components.dart';
import '../../app/monetta_tokens.g.dart';

/// Cabecera de pantalla E: ojo editorial serif + título + subtítulo.
class AccountPageHeader extends StatelessWidget {
  const AccountPageHeader({
    required this.kicker,
    required this.title,
    this.subtitle,
    super.key,
  });

  final String kicker;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          kicker.toUpperCase(),
          style: boutiqueEyebrow(size: 11, color: palette.goldText),
        ),
        const SizedBox(height: BoutiqueSpace.xs),
        Text(
          title,
          style: boutiqueDisplay(28, color: palette.ink),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: BoutiqueSpace.sm),
          Text(
            subtitle!,
            style: boutiqueText(size: 14, color: palette.inkMuted),
          ),
        ],
      ],
    );
  }
}

/// Título de sección sans con conteo opcional, como en la lámina.
class ESectionTitle extends StatelessWidget {
  const ESectionTitle({
    required this.title,
    this.count,
    super.key,
  });

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Row(
      children: [
        Expanded(
          child: Text(title, style: boutiqueTitle(color: palette.ink)),
        ),
        if (count != null)
          Text(
            '$count',
            style: boutiqueText(size: 13, color: palette.inkMuted),
          ),
      ],
    );
  }
}

/// Tarjeta de sección sobre marfil.
class ECard extends StatelessWidget {
  const ECard({
    required this.children,
    this.padding = const EdgeInsets.all(BoutiqueSpace.lg),
    super.key,
  });

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BoutiqueRadius.card,
        border: Border.all(color: palette.hairline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// Fila de acceso con icono lineal, título, subtítulo y chevron.
/// Nunca depende solo del color: el chevron y el texto comunican la acción.
class EAccessRow extends StatelessWidget {
  const EAccessRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final enabled = onTap != null;
    return Semantics(
      button: enabled,
      label: subtitle == null ? title : '$title. $subtitle',
      child: InkWell(
        onTap: onTap,
        borderRadius: BoutiqueRadius.control,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(
            vertical: BoutiqueSpace.md,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: palette.hairline),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 24, color: palette.ink),
              const SizedBox(width: BoutiqueSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: boutiqueRowLabel(
                        context: context,
                        color: enabled ? palette.ink : palette.inkMuted,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: boutiqueText(
                          size: 12,
                          color: palette.inkMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Text(
                  trailing!,
                  style: boutiqueText(
                    size: 12,
                    weight: FontWeight.w600,
                    color: palette.goldText,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: palette.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cápsula de estado: texto + punto, nunca color solo.
class EStatusCapsule extends StatelessWidget {
  const EStatusCapsule({
    required this.label,
    required this.dark,
    this.guideIcon,
    super.key,
  });

  final String label;
  final bool dark;
  final IconData? guideIcon;

  factory EStatusCapsule.forOrderKey(
    String key, {
    required String label,
    IconData? guideIcon,
  }) {
    return EStatusCapsule(
      label: label,
      dark: key == 'delivered',
      guideIcon: guideIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    if (guideIcon != null) {
      final isLight = Theme.of(context).brightness == Brightness.light;
      final foreground = dark && isLight ? MonettaTokens.success : palette.ink;
      return Semantics(
        label: 'Estado: $label',
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: MonettaTokens.space[2],
            vertical: MonettaTokens.space[1],
          ),
          decoration: BoxDecoration(
            color: dark && isLight
                ? MonettaTokens.successSurface
                : palette.surfaceDeep,
            borderRadius: const BorderRadius.all(
              Radius.circular(MonettaTokens.radiusPill),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                guideIcon,
                size: MonettaTokens.logoHeight,
                color: foreground,
              ),
              SizedBox(width: MonettaTokens.space[1]),
              Flexible(
                child: Text(
                  label,
                  style: clientGuideStyle(
                    context,
                    MonettaTokens.cardLabel,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Semantics(
      label: 'Estado: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: dark ? palette.ink : Colors.transparent,
          borderRadius: BoutiqueRadius.capsule,
          border: Border.all(
            color: dark ? palette.ink : palette.hairline,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dark ? palette.gold : palette.goldText,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: boutiqueText(
                  size: 11,
                  weight: FontWeight.w600,
                  color: dark ? palette.canvas : palette.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aviso honesto en línea: caché, error o sesión. Siempre con acción
/// cuando hay algo que hacer (reintentar / iniciar sesión).
class ENotice extends StatelessWidget {
  const ENotice({
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.info_outline_rounded,
    super.key,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BoutiqueSpace.md),
      decoration: BoxDecoration(
        color: palette.surfaceDeep,
        borderRadius: BoutiqueRadius.card,
        border: Border.all(color: palette.hairline, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: palette.inkMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: boutiqueText(size: 13, color: palette.ink),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 6),
                  Semantics(
                    button: true,
                    label: actionLabel,
                    child: InkWell(
                      onTap: onAction,
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: BoutiqueSpace.tapTarget - 8,
                        ),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          actionLabel!,
                          style: boutiqueText(
                            size: 13,
                            weight: FontWeight.w600,
                            color: palette.ink,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Estado vacío de sección: icono lineal, título y acción real.
class EEmptyState extends StatelessWidget {
  const EEmptyState({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: BoutiqueSpace.xxl,
          horizontal: BoutiqueSpace.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: palette.gold, width: 1),
              ),
              child: Icon(icon, size: 28, color: palette.goldText),
            ),
            const SizedBox(height: BoutiqueSpace.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: boutiqueTitle(size: 16, color: palette.ink),
            ),
            const SizedBox(height: BoutiqueSpace.sm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: boutiqueText(size: 13, color: palette.inkMuted),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: BoutiqueSpace.lg),
              BoutiqueButton(
                label: actionLabel!,
                filled: false,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Chip de filtro: borde + relleno + texto, nunca color solo.
class EFilterChip extends StatelessWidget {
  const EFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Filtrar por $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BoutiqueRadius.capsule,
        child: Container(
          constraints:
              const BoxConstraints(minHeight: BoutiqueSpace.tapTarget - 8),
          padding: const EdgeInsets.symmetric(
            horizontal: BoutiqueSpace.lg,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: selected ? palette.ink : Colors.transparent,
            borderRadius: BoutiqueRadius.capsule,
            border: Border.all(
              color: selected ? palette.ink : palette.hairline,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: boutiqueText(
              size: 13,
              weight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? palette.canvas : palette.ink,
            ),
          ),
        ),
      ),
    );
  }
}
