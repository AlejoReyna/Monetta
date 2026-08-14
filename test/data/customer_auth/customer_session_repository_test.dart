import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/customer_auth/customer_auth_gateway.dart';
import 'package:monetta_app/data/customer_auth/customer_session_repository.dart';
import 'package:monetta_app/data/customer_auth/secure_token_store.dart';
import 'package:monetta_app/data/local/account_store.dart';
import 'package:monetta_app/data/local/bag_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/wishlist_store.dart';

/// Records what was requested and replays a canned result — same shape as
/// `test/shopify/catalog_sync_test.dart`'s `FakeTransport`.
class FakeCustomerAuthGateway implements CustomerAuthGateway {
  FakeCustomerAuthGateway({required this.loginResult});

  CustomerAuthResult loginResult;
  CustomerAuthResult? refreshResult;
  int loginCalls = 0;
  int refreshCalls = 0;
  String? lastRefreshTokenRequested;

  @override
  Future<CustomerAuthResult> login() async {
    loginCalls++;
    return loginResult;
  }

  @override
  Future<CustomerAuthResult> refresh(String refreshToken) async {
    refreshCalls++;
    lastRefreshTokenRequested = refreshToken;
    return refreshResult ?? loginResult;
  }
}

class FakeSecureTokenStore implements SecureTokenStore {
  final Map<String, String> values = {};

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> delete(String key) async => values.remove(key);
}

String _fakeIdToken({required String sub, String? email}) {
  String segment(Map<String, dynamic> json) => base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final header = segment({'alg': 'none'});
  final payload = segment({'sub': sub, if (email != null) 'email': email});
  return '$header.$payload.signature';
}

void main() {
  late AppDatabase db;
  late AccountStore accounts;
  late SessionStore sessions;
  late DeviceStore devices;
  late WishlistStore wishlist;
  late BagStore bag;
  late FakeSecureTokenStore secureStore;

  setUp(() async {
    db = openTestDatabase();
    accounts = AccountStore(db);
    sessions = SessionStore(db);
    devices = DeviceStore(db);
    wishlist = WishlistStore(db);
    bag = BagStore(db);
    secureStore = FakeSecureTokenStore();
    await devices.upsert(deviceId: 'dev-1', platform: 'ios', appVersion: '1.0.0');
  });

  tearDown(() => db.close());

  CustomerSessionRepository repoWith(CustomerAuthGateway gateway) {
    return CustomerSessionRepository(
      authGateway: gateway,
      accountStore: accounts,
      sessionStore: sessions,
      deviceStore: devices,
      wishlistStore: wishlist,
      bagStore: bag,
      secureStore: secureStore,
      deviceId: 'dev-1',
    );
  }

  group('CustomerSessionRepository.login', () {
    test('creates an account, a session, and merges device-scoped wishlist/bag', () async {
      await wishlist.add('p1');
      await bag.upsert(productId: 'p2', variantId: 'v2', quantity: 1);

      final gateway = FakeCustomerAuthGateway(
        loginResult: CustomerAuthResult(
          accessToken: 'access-1',
          refreshToken: 'refresh-1',
          idToken: _fakeIdToken(sub: 'gid://shopify/Customer/1', email: 'shopper@example.com'),
          accessTokenExpiresAt: DateTime.utc(2026, 1, 1, 1),
        ),
      );

      final session = await repoWith(gateway).login();

      expect(session.accessToken, 'access-1');
      expect(session.account.shopifyCustomerId, 'gid://shopify/Customer/1');
      expect(session.account.email, 'shopper@example.com');

      final device = await devices.byId('dev-1');
      expect(device?.accountId, session.account.localAccountId);

      final wishlistRows = await db.select(db.wishlistItems).get();
      expect(wishlistRows.single.accountId, session.account.localAccountId);
      final bagRows = await db.select(db.bagLines).get();
      expect(bagRows.single.accountId, session.account.localAccountId);

      final storedSession = await sessions.latestFor(session.account.localAccountId);
      expect(storedSession, isNotNull);
      final storedRefreshToken = await secureStore.read(storedSession!.secureStorageKeyRef);
      expect(storedRefreshToken, 'refresh-1');
    });

    test('logging in twice with the same sub claim reuses the same local account', () async {
      final gateway = FakeCustomerAuthGateway(
        loginResult: CustomerAuthResult(
          accessToken: 'access-1',
          refreshToken: 'refresh-1',
          idToken: _fakeIdToken(sub: 'gid://shopify/Customer/1'),
          accessTokenExpiresAt: DateTime.utc(2026, 1, 1, 1),
        ),
      );
      final repo = repoWith(gateway);

      final first = await repo.login();
      final second = await repo.login();

      expect(second.account.localAccountId, first.account.localAccountId);
      expect(await db.select(db.accounts).get(), hasLength(1));
    });

    test('a missing refresh token does not crash — the shopper is signed in without one', () async {
      final gateway = FakeCustomerAuthGateway(
        loginResult: CustomerAuthResult(
          accessToken: 'access-1',
          refreshToken: null,
          idToken: _fakeIdToken(sub: 'gid://shopify/Customer/1'),
          accessTokenExpiresAt: DateTime.utc(2026, 1, 1, 1),
        ),
      );

      final session = await repoWith(gateway).login();
      expect(await sessions.latestFor(session.account.localAccountId), isNull);
    });
  });

  group('CustomerSessionRepository.refreshAccessToken', () {
    test('exchanges the stored refresh token and updates the session in place', () async {
      final gateway = FakeCustomerAuthGateway(
        loginResult: CustomerAuthResult(
          accessToken: 'access-1',
          refreshToken: 'refresh-1',
          idToken: _fakeIdToken(sub: 'gid://shopify/Customer/1'),
          accessTokenExpiresAt: DateTime.utc(2026, 1, 1, 1),
        ),
      );
      final repo = repoWith(gateway);
      final session = await repo.login();

      gateway.refreshResult = CustomerAuthResult(
        accessToken: 'access-2',
        refreshToken: 'refresh-2',
        idToken: null,
        accessTokenExpiresAt: DateTime.utc(2026, 1, 1, 2),
      );

      final newAccessToken = await repo.refreshAccessToken(session.account.localAccountId);

      expect(newAccessToken, 'access-2');
      expect(gateway.lastRefreshTokenRequested, 'refresh-1');
      expect(await db.select(db.sessions).get(), hasLength(1));
      final storedSession = await sessions.latestFor(session.account.localAccountId);
      final storedRefreshToken = await secureStore.read(storedSession!.secureStorageKeyRef);
      expect(storedRefreshToken, 'refresh-2');
    });

    test('throws NoActiveSessionException when nobody has logged in', () async {
      final gateway = FakeCustomerAuthGateway(
        loginResult: CustomerAuthResult(
          accessToken: 'a',
          refreshToken: 'r',
          idToken: null,
          accessTokenExpiresAt: null,
        ),
      );

      expect(
        () => repoWith(gateway).refreshAccessToken('nonexistent'),
        throwsA(isA<NoActiveSessionException>()),
      );
    });
  });

  group('CustomerSessionRepository.logout', () {
    test('clears the secure-storage entry, deletes the session, and detaches the device', () async {
      final gateway = FakeCustomerAuthGateway(
        loginResult: CustomerAuthResult(
          accessToken: 'access-1',
          refreshToken: 'refresh-1',
          idToken: _fakeIdToken(sub: 'gid://shopify/Customer/1'),
          accessTokenExpiresAt: DateTime.utc(2026, 1, 1, 1),
        ),
      );
      final repo = repoWith(gateway);
      final session = await repo.login();
      final localAccountId = session.account.localAccountId;

      await repo.logout(localAccountId);

      expect(await sessions.latestFor(localAccountId), isNull);
      expect(secureStore.values, isEmpty);
      final device = await devices.byId('dev-1');
      expect(device?.accountId, isNull);

      // The account itself survives logout — signing back in resumes it.
      expect(await accounts.byLocalId(localAccountId), isNotNull);
    });
  });
}
