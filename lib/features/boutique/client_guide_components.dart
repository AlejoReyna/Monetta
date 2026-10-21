/// Presentation primitives for the client guide. All scales come from M1.
library;

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
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final foreground = outlined ? palette.ink : palette.onAction;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: outlined ? null : palette.action,
        foregroundColor: foreground,
        minimumSize: const Size(double.infinity, MonettaTokens.controlHeight),
        padding: EdgeInsets.symmetric(
          horizontal: MonettaTokens.space[4],
          vertical: MonettaTokens.space[2],
        ),
        side: BorderSide(
          color: outlined ? palette.borderControl : palette.action,
        ),
        shape: const StadiumBorder(),
        textStyle: clientGuideStyle(context, MonettaTokens.control),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(label, textAlign: TextAlign.center)),
          if (chevron) ...[
            SizedBox(width: MonettaTokens.space[2]),
            Icon(Icons.chevron_right, size: MonettaTokens.logoHeight),
          ],
        ],
      ),
    );
  }
}
