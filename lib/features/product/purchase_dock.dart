/// Bottom purchase dock of the product pages.
///
/// One surface in the bar colour that holds a single primary action: 8 px of
/// air, a 48 px button, 8 px of air (64 px of content) plus the real bottom
/// inset, applied once. It grows with the text scale and never clips a label.
library;

import 'package:flutter/material.dart';

import '../boutique/boutique_tokens.dart';
import '../boutique/client_guide_components.dart';

/// Minimum height of a dock action.
const double kPurchaseDockButtonHeight = 48;

/// Height of the full-width page buttons (the preview and the product page).
const double kPurchaseButtonHeight = 52;

/// Air above and below the action.
const double _kDockVerticalPadding = 8;

/// Dock surface. Place it in `Scaffold.bottomNavigationBar`.
class PurchaseDock extends StatelessWidget {
  const PurchaseDock({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return DecoratedBox(
      key: const Key('purchase-dock'),
      decoration: BoxDecoration(
        color: palette.bar,
        border: Border(
          top: BorderSide(color: palette.hairline, width: 0.5),
        ),
      ),
      // The surface above paints under the inset; the padding below keeps the
      // action clear of it.
      child: SafeArea(
        top: false,
        maintainBottomViewPadding: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BoutiqueSpace.gutter,
            vertical: _kDockVerticalPadding,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: kPurchaseDockButtonHeight,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The dock's primary action: ink fill, full width, at least 48 px high.
///
/// The key is passed in by each surface. With [pending] it shows a small
/// progress indicator beside the label and is disabled, so a second tap
/// cannot repeat the action.
class PurchaseDockButton extends StatelessWidget {
  const PurchaseDockButton({
    required this.label,
    required this.onPressed,
    this.pending = false,
    this.large = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool pending;

  /// The page button of the preview and the product page: 52pt tall, Inter
  /// regular 15 with a tracked label. The dock keeps its 48pt / 600 / 14.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final enabled = onPressed != null && !pending;
    final foreground = large ? const Color(0xFF242622) : palette.onAction;
    final button = Material(
      color: large ? Colors.transparent : palette.action,
      shape: StadiumBorder(
        side:
            large ? BorderSide(color: palette.borderControl) : BorderSide.none,
      ),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight:
                large ? kPurchaseButtonHeight : kPurchaseDockButtonHeight,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: BoutiqueSpace.xl,
              vertical: large ? BoutiqueSpace.sm : BoutiqueSpace.md,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (pending) ...[
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(width: BoutiqueSpace.sm),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: boutiqueText(
                      size: large ? 15 : 14,
                      weight: large ? FontWeight.w400 : FontWeight.w600,
                      color: foreground,
                      height: 1.2,
                    ).copyWith(letterSpacing: large ? .9 : null),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? onPressed : null,
      child: large ? GuideGlassSurface(child: button) : button,
    );
  }
}

/// The outlined companion of the large [PurchaseDockButton]: a 52pt pill with
/// a [BoutiquePalette.borderControl] outline and a tracked label in
/// [textColor]. «VER PRODUCTO» and «COMPRAR AHORA» are drawn with it.
class PurchaseOutlineButton extends StatelessWidget {
  const PurchaseOutlineButton({
    required this.label,
    required this.onPressed,
    required this.textColor,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: GuideGlassSurface(
        halo: onPressed != null,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, kPurchaseButtonHeight),
            padding: const EdgeInsets.symmetric(
              horizontal: BoutiqueSpace.xl,
              vertical: BoutiqueSpace.sm,
            ),
            side: BorderSide(color: palette.borderControl),
            shape: const StadiumBorder(),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: boutiqueText(
              size: 15,
              color: onPressed != null
                  ? const Color(0xFF242622)
                  : const Color(0x73242622),
              height: 1.2,
            ).copyWith(letterSpacing: .9),
          ),
        ),
      ),
    );
  }
}
