/// Presentation primitives for the client guide. All scales come from M1.
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../app/monetta_tokens.g.dart';
import 'boutique_tokens.dart';

TextStyle clientGuideStyle(
  BuildContext context,
  MonettaTypeRole role, {
  Color? color,
}) {
  final size = role.sizeFor(MediaQuery.sizeOf(context).width);
  return TextStyle(
    fontFamily: role.serif ? kBoutiqueSerifFamily : kBoutiqueSansFamily,
    fontFamilyFallback:
        role.serif ? kBoutiqueSerifFallback : kBoutiqueSansFallback,
    fontSize: size,
    fontWeight: FontWeight.values[role.weight ~/ 100 - 1],
    height: role.lineHeight,
    letterSpacing: size * role.tracking,
    color: color ?? context.boutique.ink,
  );
}

class ClientGuideButton extends StatelessWidget {
  const ClientGuideButton({
    required this.label,
    required this.onPressed,
    this.outlined = false,
    this.chevron = false,
    this.compact = false,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final bool chevron;

  /// Tighter side padding and a smaller chevron, for a button that shares a
  /// row with other content (the order card's «Ver detalles»).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final foreground = palette.ink;
    return GuideGlassSurface(
        halo: !outlined && onPressed != null,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: foreground,
            minimumSize:
                const Size(double.infinity, MonettaTokens.controlHeight),
            padding: EdgeInsets.symmetric(
              horizontal:
                  compact ? MonettaTokens.space[1] : MonettaTokens.space[4],
              vertical: MonettaTokens.space[2],
            ),
            side: BorderSide(
              color: outlined ? palette.borderControl : palette.action,
            ),
            shape: const StadiumBorder(),
            textStyle: clientGuideStyle(context, MonettaTokens.control),
          ).copyWith(
              side: WidgetStateProperty.resolveWith((states) => BorderSide(
                    color: states.contains(WidgetState.focused)
                        ? MonettaTokens.focusColor
                        : palette.borderControl,
                    width: states.contains(WidgetState.focused)
                        ? MonettaTokens.focusWidth
                        : 1,
                  ))),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(label, textAlign: TextAlign.center)),
              if (chevron) ...[
                SizedBox(width: compact ? 0 : MonettaTokens.space[2]),
                Icon(
                  Icons.chevron_right,
                  size: compact ? 20 : MonettaTokens.logoHeight,
                ),
              ],
            ],
          ),
        ));
  }
}

/// Static Glass material. System high contrast and explicit opaque fallback
/// use white with no backdrop sampling. No animation or persistent shimmer.
class GuideGlassSurface extends StatelessWidget {
  const GuideGlassSurface(
      {required this.child,
      this.halo = false,
      this.opaque = false,
      this.radius = 24,
      super.key});
  final Widget child;
  final bool halo;
  final bool opaque;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final fallback = opaque ||
        MediaQuery.highContrastOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final surface = ColoredBox(
        color: fallback ? Colors.white : Colors.white.withValues(alpha: .88),
        child: child);
    return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            const BoxShadow(
                color: Color(0x0D242622), blurRadius: 8, offset: Offset(0, 2)),
            if (halo)
              const BoxShadow(
                  color: MonettaTokens.haloColor,
                  blurRadius: MonettaTokens.haloBlur,
                  spreadRadius: MonettaTokens.haloSpread),
          ],
        ),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: fallback
                ? surface
                : BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: surface)));
  }
}

class GuideGlassIconButton extends StatelessWidget {
  const GuideGlassIconButton(
      {required this.tooltip,
      required this.icon,
      required this.onPressed,
      super.key});
  final String tooltip;
  final Widget icon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(4),
      child: GuideGlassSurface(
          radius: 24,
          child: IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            icon: icon,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            style: ButtonStyle(
                side: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.focused)
                        ? const BorderSide(
                            color: MonettaTokens.focusColor,
                            width: MonettaTokens.focusWidth)
                        : BorderSide.none)),
          )));
}
