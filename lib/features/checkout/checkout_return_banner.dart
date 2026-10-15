/// Banners for a checkout that returned without completion (MON-UX-03).
///
/// Titles are the PM-approved sentences. Body and retry CTA are designer
/// placeholders until copy exists in the repo. Nothing here names a card,
/// a provider, or a decline reason.
library;

import 'package:flutter/material.dart';

import '../boutique/boutique_tokens.dart';
import 'checkout_return.dart';

class CheckoutReturnBanner extends StatelessWidget {
  const CheckoutReturnBanner({
    required this.phase,
    super.key,
  });

  final CheckoutReturnPhase phase;

  static const bannerKey = ValueKey<String>('checkout-return-banner');

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final title = switch (phase) {
      CheckoutReturnPhase.paymentNotCompleted =>
        kCheckoutReturnPaymentNotCompletedTitle,
      CheckoutReturnPhase.sheetDidNotOpen =>
        kCheckoutReturnSheetDidNotOpenTitle,
      CheckoutReturnPhase.reviewing => kCheckoutReturnReviewingTitle,
    };
    final body = switch (phase) {
      CheckoutReturnPhase.paymentNotCompleted =>
        kCheckoutReturnPaymentNotCompletedBodyTodo,
      CheckoutReturnPhase.sheetDidNotOpen =>
        kCheckoutReturnSheetDidNotOpenBodyTodo,
      CheckoutReturnPhase.reviewing => kCheckoutReturnReviewingBodyTodo,
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (phase == CheckoutReturnPhase.reviewing) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: palette.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: boutiqueText(
                      size: 16,
                      weight: FontWeight.w600,
                      color: palette.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: boutiqueText(size: 12, color: palette.inkMuted),
            ),
            const SizedBox(height: 8),
            Text(
              kCheckoutReturnRetryCtaTodo,
              style: boutiqueText(size: 12, color: palette.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
