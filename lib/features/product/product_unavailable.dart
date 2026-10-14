/// Estado de la ficha cuando su producto ya no está en el catálogo.
///
/// Se muestra en lugar de la ficha si el producto salió del catálogo mientras
/// estaba abierta, o si nunca estuvo en él. Ofrece volver al catálogo o
/// cerrar la ficha.
library;

import 'package:flutter/material.dart';

import '../navigation/monetta_page_header.dart';

import '../boutique/boutique_tokens.dart';

class ProductUnavailable extends StatelessWidget {
  const ProductUnavailable({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    // The system back gesture pops normally: there is no product to record a
    // view for, so no interception is needed here.
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: buildMonettaPageAppBar(
        context,
        title: 'Producto',
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              vertical: BoutiqueSpace.xxl,
              horizontal: BoutiqueSpace.gutter,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.gold, width: 1),
                      ),
                      child: Icon(
                        Icons.inventory_2_outlined,
                        size: 28,
                        color: palette.goldText,
                      ),
                    ),
                  ),
                  const SizedBox(height: BoutiqueSpace.lg),
                  Text(
                    'Este artículo ya no está disponible',
                    textAlign: TextAlign.center,
                    style: boutiqueTitle(size: 16, color: palette.ink),
                  ),
                  const SizedBox(height: BoutiqueSpace.sm),
                  Text(
                    'Es posible que se haya vendido o que ya no forme parte '
                    'del catálogo.',
                    textAlign: TextAlign.center,
                    style: boutiqueText(size: 13, color: palette.inkMuted),
                  ),
                  const SizedBox(height: BoutiqueSpace.xl),
                  BoutiqueButton(
                    label: 'Explorar el catálogo',
                    onPressed: () => Navigator.of(context)
                        .popUntil((route) => route.isFirst),
                  ),
                  const SizedBox(height: BoutiqueSpace.md),
                  BoutiqueButton(
                    label: 'Volver',
                    filled: false,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
