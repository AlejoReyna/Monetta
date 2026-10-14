/// Production construction root for the Shopify cart and discount stack.
///
/// Construction is side-effect free: it performs no reconciliation or network
/// request. The bag explicitly starts reconciliation when it is presented.
library;

import '../data/customer_auth/secure_token_store.dart';
import '../data/local/secure_cart_session_store.dart';
import '../data/shopify/cart/cart_repository.dart';
import '../data/shopify/cart/cart_write_coordinator.dart';
import '../data/shopify/cart/checkout_launcher.dart';
import '../data/shopify/cart/checkout_return_policy.dart';
import '../data/shopify/cart/storefront_cart_api.dart';
import '../data/shopify/cart_attribution.dart';
import '../data/shopify/http_storefront_transport.dart';
import '../data/shopify/storefront_client.dart';
import '../data/shopify/storefront_config.dart';
import '../platform/external_checkout_opener.dart';
import '../platform/shopify_checkout_channel.dart';
import 'cart_controller.dart';
import 'shopify_checkout_coordinator.dart';

final class ShopifyCartComposition {
  const ShopifyCartComposition._({
    required this.controller,
    required this.checkout,
    required this.returnPolicy,
  });

  factory ShopifyCartComposition.production({
    required StorefrontConfig config,
    required HttpStorefrontTransport transport,
    required SecureTokenStore secureStore,
    required CartAttribution attribution,
    CheckoutLauncher? checkoutLauncher,
    ExternalCheckoutOpener? externalCheckoutOpener,
  }) {
    final client = StorefrontClient.forCart(
      config: config,
      transport: transport,
    );
    final api = StorefrontCartApi(client);
    final sessions = SecureCartSessionStore(secureStore);
    final repository = CartRepository(
      api: api,
      sessions: sessions,
      writes: SerialCartWriteCoordinator(),
      attribution: attribution,
    );
    final controller = CartController(reconciler: repository);
    final urlPolicy = CheckoutUrlPolicy(allowedHosts: _checkoutHosts(config));
    return ShopifyCartComposition._(
      controller: controller,
      checkout: ShopifyCheckoutCoordinator(
        launcher: checkoutLauncher ?? MethodChannelCheckoutLauncher(),
        urlPolicy: urlPolicy,
        sessions: sessions,
        externalOpener:
            externalCheckoutOpener ?? const UrlLauncherExternalCheckoutOpener(),
      ),
      returnPolicy: CheckoutReturnPolicy(urlPolicy: urlPolicy),
    );
  }

  final CartController controller;
  final ShopifyCheckoutCoordinator checkout;

  /// Classifies offsite-payment return links with the same host allowlist
  /// used for presentation. Staging and production stay separate through
  /// their own `--dart-define-from-file` values.
  final CheckoutReturnPolicy returnPolicy;

  /// Shop domain plus the optional dedicated return domain
  /// (`SHOPIFY_CHECKOUT_RETURN_DOMAIN`). Empty or malformed values fall back
  /// to the shop domain alone; production must set its own file's value.
  static Set<String> _checkoutHosts(StorefrontConfig config) {
    const raw = String.fromEnvironment('SHOPIFY_CHECKOUT_RETURN_DOMAIN');
    final candidate = raw.trim().toLowerCase();
    if (candidate.isEmpty ||
        candidate.contains(RegExp(r'[/\\:@\s]')) ||
        candidate.startsWith('.') ||
        candidate.endsWith('.')) {
      return {config.shopDomain};
    }
    final parsed = Uri.tryParse('https://$candidate');
    if (parsed?.host != candidate) return {config.shopDomain};
    return {config.shopDomain, candidate};
  }
}
