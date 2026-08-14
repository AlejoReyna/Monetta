/// Wires the Customer Account API OAuth exchange (`customer_auth_gateway.dart`)
/// together with `data/local`'s account schema — the `data/repositories/`
/// pattern (`docs/ARCHITECTURE.md`), applied to accounts instead of the
/// catalog. See `docs/ACCOUNTS_AND_SYNC_PLAN.md` Phase 1.
library;

import 'package:uuid/uuid.dart';

import '../local/account_store.dart';
import '../local/bag_store.dart';
import '../local/database.dart' hide BagLine;
import '../local/wishlist_store.dart';
import 'customer_auth_gateway.dart';
import 'jwt.dart';
import 'secure_token_store.dart';

class CustomerAuthSession {
  const CustomerAuthSession({required this.account, required this.accessToken});

  final Account account;

  /// Usable immediately for an authenticated Customer Account API call —
  /// never persisted anywhere by this repository. A short-lived access
  /// token has no business surviving a process restart; only the refresh
  /// token in [SecureTokenStore] does. Whoever calls the API holds this in
  /// memory for as long as the process lives, and calls
  /// [CustomerSessionRepository.refreshAccessToken] once it's stale.
  final String accessToken;
}

/// Thrown when an operation needs a session that doesn't exist. Distinct
/// from an `AppAuth`/network failure — this means "call [login] first", not
/// "retry".
class NoActiveSessionException implements Exception {
  const NoActiveSessionException(this.localAccountId);
  final String localAccountId;

  @override
  String toString() => 'NoActiveSessionException($localAccountId)';
}

class CustomerSessionRepository {
  CustomerSessionRepository({
    required CustomerAuthGateway authGateway,
    required AccountStore accountStore,
    required SessionStore sessionStore,
    required DeviceStore deviceStore,
    required WishlistStore wishlistStore,
    required BagStore bagStore,
    required SecureTokenStore secureStore,
    required String deviceId,
    Uuid? uuid,
  })  : _authGateway = authGateway,
        _accountStore = accountStore,
        _sessionStore = sessionStore,
        _deviceStore = deviceStore,
        _wishlistStore = wishlistStore,
        _bagStore = bagStore,
        _secureStore = secureStore,
        _deviceId = deviceId,
        _uuid = uuid ?? const Uuid();

  final CustomerAuthGateway _authGateway;
  final AccountStore _accountStore;
  final SessionStore _sessionStore;
  final DeviceStore _deviceStore;
  final WishlistStore _wishlistStore;
  final BagStore _bagStore;
  final SecureTokenStore _secureStore;
  final String _deviceId;
  final Uuid _uuid;

  /// Opens Shopify's hosted login page, exchanges the code, and — on
  /// success — merges this device's guest wishlist and bag into the
  /// account (`docs/ACCOUNTS_AND_SYNC_PLAN.md` § 5: merge, never discard or
  /// silently keep separate).
  Future<CustomerAuthSession> login() async {
    final result = await _authGateway.login();
    final idToken = result.idToken;
    if (idToken == null) {
      throw StateError('Shopify token response carried no id token');
    }
    final claims = decodeIdTokenClaims(idToken);
    final shopifyCustomerId = claims['sub'] as String?;
    if (shopifyCustomerId == null) {
      throw StateError('id token carried no "sub" claim');
    }
    final email = claims['email'] as String?;

    final existing = await _accountStore.byShopifyCustomerId(shopifyCustomerId);
    final localAccountId = existing?.localAccountId ?? _uuid.v4();

    await _accountStore.upsert(
      localAccountId: localAccountId,
      shopifyCustomerId: shopifyCustomerId,
      email: email,
      authProvider: 'shopify',
      createdAt: existing?.createdAt ?? DateTime.now().toUtc(),
    );
    await _persistRefreshToken(localAccountId, result);

    await _deviceStore.attachAccount(_deviceId, localAccountId);
    await _wishlistStore.mergeDeviceItemsIntoAccount(localAccountId);
    await _bagStore.mergeDeviceItemsIntoAccount(localAccountId);

    final account = await _accountStore.byLocalId(localAccountId);
    return CustomerAuthSession(account: account!, accessToken: result.accessToken);
  }

  /// Silently exchanges the stored refresh token for a fresh access token —
  /// no browser, no shopper interaction. Throws [NoActiveSessionException]
  /// if [login] was never called (or [logout] was) for this account.
  Future<String> refreshAccessToken(String localAccountId) async {
    final session = await _sessionStore.latestFor(localAccountId);
    if (session == null) throw NoActiveSessionException(localAccountId);

    final refreshToken = await _secureStore.read(session.secureStorageKeyRef);
    if (refreshToken == null) throw NoActiveSessionException(localAccountId);

    final result = await _authGateway.refresh(refreshToken);
    await _persistRefreshToken(localAccountId, result);
    return result.accessToken;
  }

  /// Clears the local session. The device stays known (install history,
  /// push token via `DeviceStore`) but is no longer attributed to the
  /// account that just signed out; the account row itself is untouched, so
  /// signing back in later resumes the same [Account.localAccountId].
  Future<void> logout(String localAccountId) async {
    final session = await _sessionStore.latestFor(localAccountId);
    if (session != null) {
      await _secureStore.delete(session.secureStorageKeyRef);
    }
    await _sessionStore.deleteFor(localAccountId);
    await _deviceStore.detachAccount(_deviceId);
  }

  Future<void> _persistRefreshToken(
    String localAccountId,
    CustomerAuthResult result,
  ) async {
    final refreshToken = result.refreshToken;
    if (refreshToken == null) {
      // No refresh token to persist — rare, but not fatal: the shopper
      // stays signed in until the access token expires, then simply needs
      // to log in again. Silently doing nothing here is correct; deleting
      // an unrelated prior session would not be.
      return;
    }
    final key = 'customer_auth/refresh_token/$localAccountId';
    await _secureStore.write(key, refreshToken);
    await _sessionStore.save(
      accountId: localAccountId,
      secureStorageKeyRef: key,
      accessTokenExpiresAt:
          result.accessTokenExpiresAt ?? DateTime.now().toUtc().add(const Duration(hours: 1)),
    );
  }
}
