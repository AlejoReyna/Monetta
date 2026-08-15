/// Persists a first-party Monetta account and its opaque device session.
library;

import '../customer_auth/secure_token_store.dart';
import '../local/account_store.dart';
import '../local/bag_store.dart';
import '../local/database.dart';
import '../local/wishlist_store.dart';
import 'system_account_client.dart';

class SystemAccountSessionRepository {
  SystemAccountSessionRepository({
    required SystemAccountClient? client,
    required AccountStore accountStore,
    required SessionStore sessionStore,
    required DeviceStore deviceStore,
    required WishlistStore wishlistStore,
    required BagStore bagStore,
    required SecureTokenStore secureStore,
    required String deviceId,
  })  : _client = client,
        _accountStore = accountStore,
        _sessionStore = sessionStore,
        _deviceStore = deviceStore,
        _wishlistStore = wishlistStore,
        _bagStore = bagStore,
        _secureStore = secureStore,
        _deviceId = deviceId;

  final SystemAccountClient? _client;
  final AccountStore _accountStore;
  final SessionStore _sessionStore;
  final DeviceStore _deviceStore;
  final WishlistStore _wishlistStore;
  final BagStore _bagStore;
  final SecureTokenStore _secureStore;
  final String _deviceId;

  bool get canRegister => _client != null;
  bool get canLogin => _client != null;

  Future<bool> hasUsableLocalSession(String localAccountId) async {
    final session = await _sessionStore.latestFor(localAccountId);
    if (session == null ||
        !session.accessTokenExpiresAt.isAfter(DateTime.now().toUtc())) {
      return false;
    }
    return await _secureStore.read(session.secureStorageKeyRef) != null;
  }

  Future<Account> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('System account registration is not configured');
    }
    final registration = await client.register(
      email: email,
      password: password,
      displayName: displayName,
      deviceId: _deviceId,
    );
    return _persist(registration);
  }

  Future<Account> login({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('System account login is not configured');
    }
    final registration = await client.login(
      email: email,
      password: password,
      deviceId: _deviceId,
    );
    return _persist(registration);
  }

  Future<Account> _persist(SystemAccountRegistration registration) async {
    final existing = await _accountStore.byLocalId(registration.accountId);
    await _accountStore.upsert(
      localAccountId: registration.accountId,
      email: registration.email,
      displayName: registration.displayName,
      authProvider: 'monetta',
      createdAt: existing?.createdAt ?? DateTime.now().toUtc(),
    );

    final secureStorageKey = 'system_auth/session/${registration.accountId}';
    await _secureStore.write(secureStorageKey, registration.sessionToken);
    await _sessionStore.save(
      accountId: registration.accountId,
      secureStorageKeyRef: secureStorageKey,
      accessTokenExpiresAt: registration.expiresAt,
    );
    await _deviceStore.attachAccount(_deviceId, registration.accountId);
    await _wishlistStore.mergeDeviceItemsIntoAccount(registration.accountId);
    await _bagStore.mergeDeviceItemsIntoAccount(registration.accountId);
    return (await _accountStore.byLocalId(registration.accountId))!;
  }

  Future<void> logout(String localAccountId) async {
    final session = await _sessionStore.latestFor(localAccountId);
    if (session != null) {
      final token = await _secureStore.read(session.secureStorageKeyRef);
      if (token != null && _client != null) {
        try {
          await _client.logout(token);
        } catch (_) {
          // Local logout must still succeed while the service is unreachable.
        }
      }
      await _secureStore.delete(session.secureStorageKeyRef);
    }
    await _sessionStore.deleteFor(localAccountId);
    await _deviceStore.detachAccount(_deviceId);
  }
}
