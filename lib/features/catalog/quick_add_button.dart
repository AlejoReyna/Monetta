/// The "+" on the photo of a buyable card.
///
/// One buyable variant is added straight away and confirmed with the mini cart;
/// several variants open the quick view so the shopper chooses explicitly. It
/// never adds a variant on the shopper's behalf, and it goes through the same
/// purchase path as the ficha ([tryAddSelectionToBag]).
library;

import 'package:flutter/material.dart';

import '../../domain/product.dart';
import '../../main.dart';
import '../boutique/boutique_tokens.dart';
import '../checkout/mini_cart.dart';
import '../product/product_selection.dart';
import '../product/quick_view.dart';

/// Tappable zone of the control (48x48) over a 40 px visual circle.
const double _kZone = 48;
const double _kCircle = 40;

class ProductQuickAddButton extends StatefulWidget {
  const ProductQuickAddButton({
    required this.product,
    required this.productName,
    super.key,
  });

  final Product product;

  /// The name as the card prints it, used for the accessible label.
  final String productName;

  @override
  State<ProductQuickAddButton> createState() => _ProductQuickAddButtonState();
}

class _ProductQuickAddButtonState extends State<ProductQuickAddButton> {
  bool _pending = false;

  Future<void> _onPressed() async {
    if (_pending) return;
    final product = widget.product;

    if (selectableVariants(product).length > 1) {
      // Several variants: the shopper picks one in the quick view. Nothing is
      // added here.
      await showProductQuickView(context, product, requireChoice: true);
      return;
    }

    setState(() => _pending = true);
    final result = await tryAddSelectionToBag(context, product, 0);
    if (!mounted) return;
    setState(() => _pending = false);

    switch (result.status) {
      case BagAddStatus.added:
        NotificationScope.maybeOf(context)?.recordPushOutcome('add_to_cart');
        await showMiniCart(context);
      case BagAddStatus.soldOut:
        _say('Esta opción está agotada.');
      case BagAddStatus.unavailable:
        _say('Esta pieza no está disponible por ahora.');
      case BagAddStatus.failed:
        _say('No pudimos agregar la pieza. Intenta de nuevo.');
    }
  }

  void _say(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final name = widget.productName;
    return Semantics(
      container: true,
      button: true,
      enabled: !_pending,
      label:
          _pending ? 'Agregando $name al carrito' : 'Agregar $name al carrito',
      excludeSemantics: true,
      onTap: _pending ? null : _onPressed,
      child: SizedBox(
        width: _kZone,
        height: _kZone,
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.canvas.withValues(alpha: 0.95),
              border: Border.all(color: palette.hairline),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 6,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                // A pending control keeps absorbing the tap: with a null
                // handler it would fall through to the card and open the ficha.
                onTap: _pending ? () {} : _onPressed,
                child: SizedBox(
                  width: _kCircle,
                  height: _kCircle,
                  child: Center(
                    child: _pending
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: palette.ink,
                            ),
                          )
                        : Icon(
                            Icons.add_rounded,
                            size: 22,
                            color: palette.ink,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
