import 'package:url_launcher/url_launcher.dart';

import '../data/shopify/cart/checkout_launcher.dart';

final class UrlLauncherExternalCheckoutOpener
    implements ExternalCheckoutOpener {
  const UrlLauncherExternalCheckoutOpener();

  @override
  Future<bool> open(ValidatedCheckoutUrl checkoutUrl) async {
    try {
      return await launchUrl(
        checkoutUrl.revealForNativeBridge(),
        mode: LaunchMode.externalApplication,
      );
    } on Exception {
      return false;
    }
  }
}
