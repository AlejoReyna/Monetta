import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../boutique/boutique_tokens.dart';

/// Transparent target: colour is confined to the supplied heart silhouette.
class ProductFavoriteButton extends StatelessWidget {
  const ProductFavoriteButton({
    required this.selected,
    required this.onPressed,
    this.onPhoto = false,
    super.key,
  });
  final bool onPhoto;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
        toggled: selected,
        button: true,
        label: selected ? 'Quitar de favoritos' : 'Guardar en favoritos',
        excludeSemantics: true,
        onTap: onPressed,
        child: IconButton(
          tooltip: selected ? 'Quitar de favoritos' : 'Guardar en favoritos',
          onPressed: onPressed,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: SvgPicture.asset(
            'assets/images/v41/icons/${selected ? 'favorito_guardado' : 'favorito'}.svg',
            width: 30,
            height: 30,
            excludeFromSemantics: true,
            colorFilter: ColorFilter.mode(
              selected
                  ? const Color(0xFFA58248)
                  : onPhoto
                      ? const Color(0xFF242622)
                      : context.boutique.ink,
              BlendMode.srcIn,
            ),
          ),
        ),
      );
}

class ProductSoldOutBadge extends StatelessWidget {
  const ProductSoldOutBadge({super.key});
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Text(
              'AGOTADO',
              style: boutiqueText(
                size: 10,
                weight: FontWeight.w600,
                color: Colors.white,
                height: 1.2,
              ),
            ),
          ),
        ),
      );
}
