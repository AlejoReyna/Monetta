/// Banners for a checkout that returned without completion (MON-UX-03).
///
/// Copy is the designer text, kept in [checkout_return.dart]. Nothing here
/// names a card, a provider, or a decline reason.
library;

import 'package:flutter/material.dart';

import '../boutique/boutique_tokens.dart';
import 'checkout_return.dart';

class CheckoutReturnBanner extends StatelessWidget {
  const CheckoutReturnBanner({
    required this.phase,
    this.onRetry,
    this.onViewOrders,
    this.onWhatsApp,
    super.key,
  });

  final CheckoutReturnPhase phase;
  final VoidCallback? onRetry;
  final VoidCallback? onViewOrders;
  final VoidCallback? onWhatsApp;

  static const bannerKey = ValueKey<String>('checkout-return-banner');

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    if (phase == CheckoutReturnPhase.confirming) {
      return Semantics(
        key: bannerKey,
        container: true,
        liveRegion: true,
        label: kCheckoutReturnConfirmingText,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: palette.ink,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  kCheckoutReturnConfirmingText,
                  style: boutiqueText(size: 13, color: palette.ink),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final title = switch (phase) {
      CheckoutReturnPhase.confirming => kCheckoutReturnConfirmingText,
      CheckoutReturnPhase.paymentNotCompleted =>
        kCheckoutReturnPaymentNotCompletedTitle,
      CheckoutReturnPhase.sheetDidNotOpen =>
        kCheckoutReturnSheetDidNotOpenTitle,
      CheckoutReturnPhase.reviewing => kCheckoutReturnReviewingTitle,
    };
    final body = switch (phase) {
      CheckoutReturnPhase.confirming => '',
      CheckoutReturnPhase.paymentNotCompleted =>
        kCheckoutReturnPaymentNotCompletedBody,
      CheckoutReturnPhase.sheetDidNotOpen => kCheckoutReturnSheetDidNotOpenBody,
      CheckoutReturnPhase.reviewing => kCheckoutReturnReviewingBody,
    };
    return Semantics(
      key: bannerKey,
      container: true,
      liveRegion: true,
      label: title,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BoutiqueRadius.card,
          border: Border.all(color: palette.hairline, width: .5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: boutiqueText(
                size: 16,
                weight: FontWeight.w600,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: boutiqueText(size: 12, color: palette.inkMuted),
            ),
            if (phase == CheckoutReturnPhase.paymentNotCompleted ||
                phase == CheckoutReturnPhase.sheetDidNotOpen) ...[
              const SizedBox(height: 16),
              BoutiqueButton(
                key: const ValueKey('checkout-retry-button'),
                label: kCheckoutReturnRetryLabel,
                onPressed: onRetry,
              ),
            ],
            if (phase == CheckoutReturnPhase.reviewing) ...[
              const SizedBox(height: 16),
              BoutiqueButton(
                key: const ValueKey('checkout-view-orders-button'),
                label: kCheckoutReturnViewOrdersLabel,
                onPressed: onViewOrders,
              ),
              const SizedBox(height: 10),
              BoutiqueButton(
                key: const ValueKey('checkout-whatsapp-button'),
                label: kCheckoutReturnWhatsAppLabel,
                filled: false,
                onPressed: onWhatsApp,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
