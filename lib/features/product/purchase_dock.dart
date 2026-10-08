/// Bottom purchase dock of the product pages.
///
/// One surface in the bar colour that holds a single primary action: 8 px of
/// air, a 48 px button, 8 px of air (64 px of content) plus the real bottom
/// inset, applied once. It grows with the text scale and never clips a label.
library;

import 'package:flutter/material.dart';

import '../boutique/boutique_tokens.dart';

/// Minimum height of a dock action.
const double kPurchaseDockButtonHeight = 48;

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
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final enabled = onPressed != null && !pending;
    final background =
        enabled ? palette.ink : palette.ink.withValues(alpha: 0.6);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? onPressed : null,
      child: Material(
        color: background,
        borderRadius: BoutiqueRadius.control,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BoutiqueRadius.control,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: kPurchaseDockButtonHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BoutiqueSpace.xl,
                vertical: BoutiqueSpace.md,
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
                        color: palette.canvas,
                      ),
                    ),
                    const SizedBox(width: BoutiqueSpace.sm),
                  ],
                  Flexible(
                    // No line cap: at large text scales the button grows
                    // instead of truncating the label.
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: boutiqueText(
                        size: 14,
                        weight: FontWeight.w600,
                        color: palette.canvas,
                        height: 1.2,
                      ),
                    ),
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
