/// Warning before a second checkout while banner 3 is still active (DUP-02).
library;

import 'package:flutter/material.dart';

import '../boutique/boutique_tokens.dart';
import 'checkout_return.dart';

enum CheckoutDoubleChargeChoice { viewOrders, payAnyway }

Future<CheckoutDoubleChargeChoice?> showCheckoutDoubleChargeSheet(
  BuildContext context,
) {
  return showModalBottomSheet<CheckoutDoubleChargeChoice>(
    context: context,
    useSafeArea: true,
    showDragHandle: false,
    isScrollControlled: true,
    builder: (context) => const CheckoutDoubleChargeSheet(),
  );
}

class CheckoutDoubleChargeSheet extends StatelessWidget {
  const CheckoutDoubleChargeSheet({super.key});

  static const sheetKey = ValueKey<String>('checkout-double-charge-sheet');

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Material(
      key: sheetKey,
      color: palette.surface,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.paddingOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 3,
                decoration: BoxDecoration(
                  color: palette.hairline,
                  borderRadius: BoutiqueRadius.capsule,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              kCheckoutDoubleChargeTitle,
              style: boutiqueText(
                size: 18,
                weight: FontWeight.w600,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              kCheckoutDoubleChargeBody,
              style: boutiqueText(size: 13, color: palette.inkMuted),
            ),
            const SizedBox(height: 22),
            BoutiqueButton(
              key: const ValueKey('checkout-double-charge-orders'),
              label: kCheckoutReturnViewOrdersLabel,
              onPressed: () => Navigator.of(context).pop(
                CheckoutDoubleChargeChoice.viewOrders,
              ),
            ),
            const SizedBox(height: 10),
            BoutiqueButton(
              key: const ValueKey('checkout-double-charge-pay'),
              label: kCheckoutDoubleChargePayAnywayLabel,
              filled: false,
              onPressed: () => Navigator.of(context).pop(
                CheckoutDoubleChargeChoice.payAnyway,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
