/// Secure persistence contract for Shopify cart sessions.
library;

import 'cart_api.dart';

/// Partitions cart sessions by store/environment and buyer.
///
/// [buyerKey] is a stable local account identifier, never an email or token.
/// Null represents the guest cart for this installation.
final class CartSessionScope {
  const CartSessionScope.guest({required this.shopDomain}) : buyerKey = null;

  const CartSessionScope.authenticated({
    required this.shopDomain,
    required String localAccountId,
  }) : buyerKey = localAccountId;

  final String shopDomain;
  final String? buyerKey;

  bool get isAuthenticated => buyerKey != null;

  @override
  bool operator ==(Object other) =>
      other is CartSessionScope &&
      other.shopDomain == shopDomain &&
      other.buyerKey == buyerKey;

  @override
  int get hashCode => Object.hash(shopDomain, buyerKey);

  @override
  String toString() => 'CartSessionScope(shopDomain: $shopDomain, '
      'authenticated: $isAuthenticated, buyer: <redacted>)';
}

/// Implementations must use Keychain/Keystore-backed storage, not Drift,
/// shared preferences or plaintext files.
abstract interface class CartSessionStore {
  Future<SensitiveCartId?> read(CartSessionScope scope);

  Future<void> write(CartSessionScope scope, SensitiveCartId cartId);

  Future<void> delete(CartSessionScope scope);
}
