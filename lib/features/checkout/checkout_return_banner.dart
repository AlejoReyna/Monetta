/// Banners for a checkout that returned without completion (MON-UX-03).
///
/// Copy is the designer text, kept in [checkout_return.dart]. Nothing here
/// names a card, a provider, or a decline reason.
library;

import 'package:flutter/material.dart';

import '../boutique/boutique_tokens.dart';
import '../boutique/client_guide_components.dart';
import '../../app/monetta_tokens.g.dart';
import 'checkout_return.dart';

class CheckoutReturnBanner extends StatelessWidget {
  const CheckoutReturnBanner({
    required this.phase,
    this.bodyOverride,
    this.onRetry,
    this.onViewOrders,
    this.onWhatsApp,
    super.key,
  });

  final CheckoutReturnPhase phase;

  /// Replaces the generic sheet-did-not-open body when checkout was refused
  /// before the sheet opened, for example the storefront password page.
  final String? bodyOverride;
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
          padding: EdgeInsets.only(bottom: MonettaTokens.space[3]),
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
    final fallbackBody = switch (phase) {
      CheckoutReturnPhase.confirming => '',
      CheckoutReturnPhase.paymentNotCompleted =>
        kCheckoutReturnPaymentNotCompletedBody,
      CheckoutReturnPhase.sheetDidNotOpen => kCheckoutReturnSheetDidNotOpenBody,
      CheckoutReturnPhase.reviewing => kCheckoutReturnReviewingBody,
    };
    final override = bodyOverride?.trim();
    final body =
        override != null && override.isNotEmpty ? override : fallbackBody;
    return Semantics(
      key: bannerKey,
      container: true,
      liveRegion: true,
      label: title,
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.only(bottom: MonettaTokens.space[3]),
        padding: EdgeInsets.all(MonettaTokens.space[3]),
        decoration: BoxDecoration(
          color: palette.surfaceDeep,
          borderRadius: BoutiqueRadius.card,
          border: Border.all(color: palette.hairline, width: .5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: clientGuideStyle(context, MonettaTokens.sectionTitle),
            ),
            SizedBox(height: MonettaTokens.space[1]),
            Text(
              body,
              style: clientGuideStyle(
                context,
                MonettaTokens.body,
                color: palette.inkMuted,
              ),
            ),
            if (phase == CheckoutReturnPhase.paymentNotCompleted ||
                phase == CheckoutReturnPhase.sheetDidNotOpen) ...[
              SizedBox(height: MonettaTokens.space[3]),
              BoutiqueButton(
                key: const ValueKey('checkout-retry-button'),
                label: kCheckoutReturnRetryLabel,
                onPressed: onRetry,
              ),
            ],
            if (phase == CheckoutReturnPhase.reviewing) ...[
              SizedBox(height: MonettaTokens.space[3]),
              BoutiqueButton(
                key: const ValueKey('checkout-view-orders-button'),
                label: kCheckoutReturnViewOrdersLabel,
                onPressed: onViewOrders,
              ),
              SizedBox(height: MonettaTokens.space[1]),
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
