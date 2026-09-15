/// Keychain/Keystore-backed Shopify cart session persistence.
library;

import 'dart:convert';

import '../customer_auth/secure_token_store.dart';
import '../shopify/cart/cart_api.dart';
import '../shopify/cart/cart_session_store.dart';

/// Keeps the Shopify layer pure Dart while adapting its persistence port to
/// the app's existing `flutter_secure_storage` seam.
final class SecureCartSessionStore implements CartSessionStore {
  const SecureCartSessionStore(this._secureStore);

  final SecureTokenStore _secureStore;

  @override
  Future<SensitiveCartId?> read(CartSessionScope scope) async {
    final value = await _secureStore.read(_storageKey(scope));
    if (value == null || value.trim().isEmpty) return null;
    return SensitiveCartId(value);
  }

  @override
  Future<void> write(CartSessionScope scope, SensitiveCartId cartId) =>
      _secureStore.write(
        _storageKey(scope),
        cartId.revealForStorefrontRequest(),
      );

  @override
  Future<void> delete(CartSessionScope scope) =>
      _secureStore.delete(_storageKey(scope));

  static String _storageKey(CartSessionScope scope) {
    final domain = base64Url.encode(utf8.encode(scope.shopDomain));
    final buyer = base64Url.encode(
      utf8.encode(
        scope.buyerKey == null ? 'guest' : 'account:${scope.buyerKey}',
      ),
    );
    return 'shopify-cart-session-v2/$domain/$buyer';
  }
}
