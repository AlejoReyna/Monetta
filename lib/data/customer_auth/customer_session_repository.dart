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
import 'customer_auth_error.dart';
import 'customer_auth_gateway.dart';
import 'customer_identity.dart';
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
    CustomerIdentityService? identityService,
    Uuid? uuid,
  })  : _authGateway = authGateway,
        _identityService = identityService,
        _accountStore = accountStore,
        _sessionStore = sessionStore,
        _deviceStore = deviceStore,
        _wishlistStore = wishlistStore,
        _bagStore = bagStore,
        _secureStore = secureStore,
        _deviceId = deviceId,
        _uuid = uuid ?? const Uuid();

  final CustomerAuthGateway _authGateway;

  /// Null only in tests and in builds predating the Customer Account API
  /// call — [login] then falls back to id-token claims, which is a strictly
  /// weaker identity (see [login]).
  final CustomerIdentityService? _identityService;
  final AccountStore _accountStore;
  final SessionStore _sessionStore;
  final DeviceStore _deviceStore;
  final WishlistStore _wishlistStore;
  final BagStore _bagStore;
  final SecureTokenStore _secureStore;
  final String _deviceId;
  final Uuid _uuid;

  /// The access token lives here and nowhere else — never in Drift, never in
  /// secure storage (README § 4). It dies with the process, which is exactly
  /// its intended lifetime; the refresh token is what survives a restart.
  String? _accessToken;
  DateTime? _accessTokenExpiresAt;
  String? _accessTokenAccountId;

  Future<String>? _refreshInFlight;
  String? _refreshingAccountId;

  /// Refresh this far ahead of expiry, so a token does not go stale
  /// mid-request after passing the check.
  static const Duration _expiryHeadroom = Duration(minutes: 2);

  /// Opens Shopify's hosted login page, exchanges the code, resolves who just
  /// signed in, and — on success — merges this device's guest wishlist and
  /// bag into the account (`docs/ACCOUNTS_AND_SYNC_PLAN.md` § 5: merge, never
  /// discard or silently keep separate).
  ///
  /// Identity comes from an authenticated `customer { id }` call, not from the
  /// id token this app decoded without verifying its signature — see
  /// `customer_identity.dart`. The id token is the fallback, not the source:
  /// if that one call fails the shopper still gets signed in (they just
  /// finished a browser flow; refusing them over a network blip would be the
  /// worse failure) with the weaker claims-derived identity.
  Future<CustomerAuthSession> login() async {
    final result = await _authGateway.login();
    final identity = await _resolveIdentity(result);

    final existing =
        await _accountStore.byShopifyCustomerId(identity.shopifyCustomerId);
    final localAccountId = existing?.localAccountId ?? _uuid.v4();

    await _accountStore.upsert(
      localAccountId: localAccountId,
      shopifyCustomerId: identity.shopifyCustomerId,
      email: identity.email,
      displayName: identity.displayName,
      authProvider: 'shopify',
      createdAt: existing?.createdAt ?? DateTime.now().toUtc(),
    );
    await _persistRefreshToken(localAccountId, result);

    // Switching accounts on one device: `attachAccount` overwrites the
    // device's `accountId`, and the merges below only touch rows still scoped
    // to *no* account (`accountId IS NULL`). The previous shopper's own rows
    // stay attached to their account and are simply no longer visible, which
    // is the behaviour that survives them signing back in.
    await _deviceStore.attachAccount(_deviceId, localAccountId);
    await _wishlistStore.mergeDeviceItemsIntoAccount(localAccountId);
    await _bagStore.mergeDeviceItemsIntoAccount(localAccountId);

    final account = await _accountStore.byLocalId(localAccountId);
    return CustomerAuthSession(
      account: account!,
      accessToken: result.accessToken,
    );
  }

  Future<CustomerIdentity> _resolveIdentity(CustomerAuthResult result) async {
    final service = _identityService;
    if (service != null) {
      try {
        return await service.fetch(result.accessToken);
      } on CustomerAuthException catch (error) {
        // Deliberately swallowed rather than rethrown, then re-derived from
        // the id token below. The one case that must not be swallowed is a
        // rejected token: that means the exchange produced something Shopify
        // will not honour, and signing the shopper in on top of it would
        // create an account whose every later API call fails.
        if (error.kind == CustomerAuthErrorKind.sessionExpired) rethrow;
      }
    }
    return _identityFromIdToken(result.idToken);
  }

  CustomerIdentity _identityFromIdToken(String? idToken) {
    if (idToken == null) {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'token response carried no id token and no identity',
      );
    }
    final claims = decodeIdTokenClaims(idToken);
    final sub = claims['sub'] as String?;
    if (sub == null || sub.isEmpty) {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'id token carried no "sub" claim',
      );
    }
    return CustomerIdentity(
      shopifyCustomerId: sub,
      email: claims['email'] as String?,
    );
  }

  /// A usable access token for [localAccountId], refreshing only when the
  /// in-memory one is missing or about to expire.
  ///
  /// This is the method Customer Account API calls should use;
  /// [refreshAccessToken] is the unconditional version underneath it.
  Future<String> accessTokenFor(String localAccountId) {
    final cached = _accessToken;
    final expiresAt = _accessTokenExpiresAt;
    if (cached != null &&
        _accessTokenAccountId == localAccountId &&
        expiresAt != null &&
        expiresAt.isAfter(DateTime.now().toUtc().add(_expiryHeadroom))) {
      return Future.value(cached);
    }
    return refreshAccessToken(localAccountId);
  }

  /// Silently exchanges the stored refresh token for a fresh access token —
  /// no browser, no shopper interaction. Throws [NoActiveSessionException]
  /// if [login] was never called (or [logout] was) for this account.
  ///
  /// Single-flight: concurrent callers share one exchange rather than each
  /// starting their own. That is not just an optimisation here — Shopify
  /// rotates the refresh token on use, so a second parallel exchange would
  /// present a token the first one has already spent, and the loser of that
  /// race gets `invalid_grant` and signs the shopper out for no reason.
  Future<String> refreshAccessToken(String localAccountId) {
    final inFlight = _refreshInFlight;
    if (inFlight != null && _refreshingAccountId == localAccountId) {
      return inFlight;
    }
    _refreshingAccountId = localAccountId;
    final future = _refresh(localAccountId);
    _refreshInFlight = future;
    return future.whenComplete(() {
      if (identical(_refreshInFlight, future)) {
        _refreshInFlight = null;
        _refreshingAccountId = null;
      }
    });
  }

  Future<String> _refresh(String localAccountId) async {
    final session = await _sessionStore.latestFor(localAccountId);
    if (session == null) throw NoActiveSessionException(localAccountId);

    final refreshToken = await _secureStore.read(session.secureStorageKeyRef);
    if (refreshToken == null) throw NoActiveSessionException(localAccountId);

    final result = await _authGateway.refresh(refreshToken);
    await _persistRefreshToken(localAccountId, result);
    return result.accessToken;
  }

  /// True when this device still holds a refresh token for [localAccountId] —
  /// which is what "still signed in after a restart" actually means. The
  /// access token deliberately does not survive a restart (README § 4), so
  /// its expiry is not part of the answer.
  Future<bool> hasUsableLocalSession(String localAccountId) async {
    final session = await _sessionStore.latestFor(localAccountId);
    if (session == null) return false;
    return await _secureStore.read(session.secureStorageKeyRef) != null;
  }

  /// Clears the local session. The device stays known (install history,
  /// push token via `DeviceStore`) but is no longer attributed to the
  /// account that just signed out; the account row itself is untouched, so
  /// signing back in later resumes the same [Account.localAccountId].
  /// Local only: this does not end the shopper's session inside Shopify's
  /// hosted pages. Shopify's end-session endpoint needs an `id_token_hint`
  /// and opens a browser, and this app keeps no id token past login — see
  /// `README.md` § 8 for that gap. Signing out here means the next login
  /// re-opens the hosted page and may not ask for credentials again.
  Future<void> logout(String localAccountId) async {
    final session = await _sessionStore.latestFor(localAccountId);
    if (session != null) {
      await _secureStore.delete(session.secureStorageKeyRef);
    }
    await _sessionStore.deleteFor(localAccountId);
    await _deviceStore.detachAccount(_deviceId);
    _forgetAccessToken();
  }

  void _forgetAccessToken() {
    _accessToken = null;
    _accessTokenExpiresAt = null;
    _accessTokenAccountId = null;
  }

  Future<void> _persistRefreshToken(
    String localAccountId,
    CustomerAuthResult result,
  ) async {
    _accessToken = result.accessToken;
    _accessTokenExpiresAt = result.accessTokenExpiresAt;
    _accessTokenAccountId = localAccountId;

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
      accessTokenExpiresAt: result.accessTokenExpiresAt ??
          DateTime.now().toUtc().add(const Duration(hours: 1)),
    );
  }
}
