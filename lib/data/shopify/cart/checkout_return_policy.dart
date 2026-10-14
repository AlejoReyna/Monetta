// Return-link policy for offsite payments (Fase 5).
//
// When a provider (PayPal, Mercado Pago, 3DS/bank redirect) sends the buyer
// back to the app through a Universal/App Link, this policy classifies the
// incoming URL. It never treats arrival as payment proof: resuming only
// re-presents the checkout through Checkout Kit so Shopify can emit the real
// terminal event (`completed` / `cancelled` / `failed`).
library;

import 'checkout_launcher.dart';

/// Where an incoming return link must go.
enum CheckoutReturnRoute {
  /// Same-session checkout URL: re-present through Checkout Kit.
  resumeCheckout,

  /// Storefront cart page: open the local bag.
  openBag,

  /// Recognized host but unrecognized path (including thank-you pages):
  /// hand to the external browser. Never claims purchase completion.
  openBrowser,

  /// Anything else: drop silently. No privileged flow, no navigation.
  rejected,
}

/// Classification result. The validated URL is exposed only for the native
/// bridge / external opener; stringification is always redacted.
final class CheckoutReturnDecision {
  const CheckoutReturnDecision._(this.route, this.checkoutUrl);

  const CheckoutReturnDecision.resume(ValidatedCheckoutUrl url)
      : this._(CheckoutReturnRoute.resumeCheckout, url);

  const CheckoutReturnDecision.openBag() : this._(CheckoutReturnRoute.openBag, null);

  const CheckoutReturnDecision.openBrowser(ValidatedCheckoutUrl url)
      : this._(CheckoutReturnRoute.openBrowser, url);

  const CheckoutReturnDecision.rejected()
      : this._(CheckoutReturnRoute.rejected, null);

  final CheckoutReturnRoute route;
  final ValidatedCheckoutUrl? checkoutUrl;

  @override
  String toString() => 'CheckoutReturnDecision(${route.name}, <redacted>)';
}

/// Validates return-link hosts/paths/state and rejects unallowed schemes.
///
/// Allowed hosts come from the same allowlist as checkout presentation
/// (shop domain plus the configured return domain, staging and production
/// kept separate). Custom URL schemes, the OAuth callback scheme and any
/// non-HTTPS input are always rejected: only the OS-verified Universal/App
/// Link (HTTPS) can enter a privileged flow.
final class CheckoutReturnPolicy {
  CheckoutReturnPolicy({required CheckoutUrlPolicy urlPolicy})
      : _urlPolicy = urlPolicy;

  /// Convenience for composition roots without a policy instance at hand.
  factory CheckoutReturnPolicy.forHosts(Iterable<String> allowedHosts) =>
      CheckoutReturnPolicy(
        urlPolicy: CheckoutUrlPolicy(allowedHosts: allowedHosts),
      );

  final CheckoutUrlPolicy _urlPolicy;

  CheckoutReturnDecision decide(String rawValue) {
    if (rawValue.isEmpty || rawValue.length > 4096) {
      return const CheckoutReturnDecision.rejected();
    }
    final ValidatedCheckoutUrl validated;
    try {
      validated = _urlPolicy.validate(rawValue);
    } on CheckoutUrlPolicyException {
      return const CheckoutReturnDecision.rejected();
    }
    final path = validated.revealForNativeBridge().path.toLowerCase();
    // Thank-you/order-status pages prove nothing inside the app and must
    // never reopen a checkout sheet: show them in the browser instead.
    if (_isThankYou(path)) {
      return CheckoutReturnDecision.openBrowser(validated);
    }
    if (path.contains('/checkouts/')) {
      return CheckoutReturnDecision.resume(validated);
    }
    if (path == '/cart') {
      return const CheckoutReturnDecision.openBag();
    }
    return CheckoutReturnDecision.openBrowser(validated);
  }

  static bool _isThankYou(String lowerPath) =>
      lowerPath.contains('/thank-you') || lowerPath.contains('/thank_you');
}
