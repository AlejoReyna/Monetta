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
    return ShopifyCartComposition._(
      controller: controller,
      checkout: ShopifyCheckoutCoordinator(
        launcher: checkoutLauncher ?? MethodChannelCheckoutLauncher(),
        urlPolicy: CheckoutUrlPolicy.forShopDomain(config.shopDomain),
        sessions: sessions,
        externalOpener:
            externalCheckoutOpener ?? const UrlLauncherExternalCheckoutOpener(),
      ),
    );
  }

  final CartController controller;
  final ShopifyCheckoutCoordinator checkout;
}
