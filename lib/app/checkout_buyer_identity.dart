/// Resolves Shopify Cart buyerIdentity for checkout launch.
///
/// Guests and legacy Monetta accounts stay on [GuestCartBuyerIdentity].
/// Shopify Customer Account sessions supply a fresh access token as
/// [AuthenticatedCartBuyerIdentity] when one is available.
library;

import '../data/local/database.dart' show Account;
import '../data/shopify/cart/cart_api.dart';

Future<CartBuyerIdentity> resolveCheckoutBuyerIdentity({
  Account? account,
  Future<String?> Function()? shopifyAccessToken,
  String? email,
  String? phone,
  String countryCode = 'MX',
}) async {
  final trimmedEmail = _trimOrNull(email) ?? _trimOrNull(account?.email);
  final trimmedPhone = _trimOrNull(phone);

  if (account != null &&
      account.authProvider == 'shopify' &&
      shopifyAccessToken != null) {
    try {
      final token = await shopifyAccessToken();
      final trimmedToken = token?.trim();
      if (trimmedToken != null && trimmedToken.isNotEmpty) {
        return AuthenticatedCartBuyerIdentity(
          accessToken: SensitiveCustomerAccessToken(trimmedToken),
          email: trimmedEmail,
          phone: trimmedPhone,
          countryCode: countryCode,
        );
      }
    } on Object {
      // Fall through to guest identity with contact details. Checkout can still
      // proceed; Shopify simply will not recognize the shopper as signed in.
    }
  }

  return GuestCartBuyerIdentity(
    email: trimmedEmail,
    phone: trimmedPhone,
    countryCode: countryCode,
  );
}

String? _trimOrNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
