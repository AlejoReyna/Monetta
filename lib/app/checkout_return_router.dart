// Routes validated return links to one audited action (Fase 5).
//
// The router never throws on hostile input and never marks a purchase as
// complete: `resumeCheckout` re-presents through the injected callback (the
// composition root wires it to the checkout coordinator, which reconciles
// and waits for the real terminal event), while anything unrecognized ends
// in the browser or is dropped.
library;

import '../data/shopify/cart/checkout_launcher.dart';
import '../data/shopify/cart/checkout_return_policy.dart';

/// What handling an incoming return link produced. Redacted by design.
enum CheckoutReturnOutcome { resumed, bag, browser, rejected }

final class CheckoutReturnRouter {
  CheckoutReturnRouter({
    required CheckoutReturnPolicy policy,
    required Future<CheckoutResult> Function(ValidatedCheckoutUrl url)
        onResumeCheckout,
    required Future<void> Function() onOpenBag,
    required ExternalCheckoutOpener externalOpener,
  })  : _policy = policy,
        _onResumeCheckout = onResumeCheckout,
        _onOpenBag = onOpenBag,
        _externalOpener = externalOpener;

  final CheckoutReturnPolicy _policy;
  final Future<CheckoutResult> Function(ValidatedCheckoutUrl url)
      _onResumeCheckout;
  final Future<void> Function() _onOpenBag;
  final ExternalCheckoutOpener _externalOpener;

  /// Classifies [rawValue] and runs the single matching action.
  ///
  /// Never throws: every failure mode (invalid link, missing handler,
  /// failed browser open) resolves to an outcome. Bag state is untouched
  /// here; only the resume callback may mutate it through the coordinator.
  Future<CheckoutReturnOutcome> handle(String rawValue) async {
    final decision = _policy.decide(rawValue);
    switch (decision.route) {
      case CheckoutReturnRoute.resumeCheckout:
        try {
          await _onResumeCheckout(decision.checkoutUrl!);
          return CheckoutReturnOutcome.resumed;
        } on Exception {
          return CheckoutReturnOutcome.rejected;
        }
      case CheckoutReturnRoute.openBag:
        try {
          await _onOpenBag();
          return CheckoutReturnOutcome.bag;
        } on Exception {
          return CheckoutReturnOutcome.rejected;
        }
      case CheckoutReturnRoute.openBrowser:
        try {
          await _externalOpener.open(decision.checkoutUrl!);
          return CheckoutReturnOutcome.browser;
        } on Exception {
          return CheckoutReturnOutcome.rejected;
        }
      case CheckoutReturnRoute.rejected:
        return CheckoutReturnOutcome.rejected;
    }
  }
}
