import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/customer_auth/customer_auth_error.dart';
import 'package:monetta_app/data/customer_auth/customer_auth_gateway.dart';
import 'package:monetta_app/data/customer_auth/customer_identity.dart';
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

/// Replays a canned `customer { id }` answer, or the failure of your choice.
class FakeCustomerIdentityService implements CustomerIdentityService {
  FakeCustomerIdentityService({this.identity, this.error});

  CustomerIdentity? identity;
  CustomerAuthException? error;
  int calls = 0;
  String? lastAccessToken;

  @override
  Future<CustomerIdentity> fetch(String accessToken) async {
    calls++;
    lastAccessToken = accessToken;
    final failure = error;
    if (failure != null) throw failure;
    return identity!;
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

  CustomerSessionRepository repoWith(
    CustomerAuthGateway gateway, {
    CustomerIdentityService? identityService,
  }) {
    return CustomerSessionRepository(
      authGateway: gateway,
      identityService: identityService,
      accountStore: accounts,
      sessionStore: sessions,
      deviceStore: devices,
      wishlistStore: wishlist,
      bagStore: bag,
      secureStore: secureStore,
      deviceId: 'dev-1',
    );
  }

  FakeCustomerAuthGateway gatewayWith({
    String accessToken = 'access-1',
    String? refreshToken = 'refresh-1',
    String sub = 'gid://shopify/Customer/1',
    String? email,
    DateTime? expiresAt,
  }) {
    return FakeCustomerAuthGateway(
      loginResult: CustomerAuthResult(
        accessToken: accessToken,
        refreshToken: refreshToken,
        idToken: _fakeIdToken(sub: sub, email: email),
        accessTokenExpiresAt: expiresAt ?? DateTime.utc(2026, 1, 1, 1),
      ),
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

  group('CustomerSessionRepository.login identity', () {
    test('the Customer Account API answer wins over the id token claims',
        () async {
      // The id token is decoded without verifying its signature, so it is the
      // fallback, not the source of truth — `customer_identity.dart`.
      final gateway = gatewayWith(
        sub: 'gid://shopify/Customer/claims',
        email: 'stale@example.com',
      );
      final identityService = FakeCustomerIdentityService(
        identity: const CustomerIdentity(
          shopifyCustomerId: 'gid://shopify/Customer/api',
          email: 'real@example.com',
          displayName: 'Ana Ruiz',
        ),
      );

      final session = await repoWith(
        gateway,
        identityService: identityService,
      ).login();

      expect(identityService.calls, 1);
      expect(identityService.lastAccessToken, 'access-1');
      expect(session.account.shopifyCustomerId, 'gid://shopify/Customer/api');
      expect(session.account.email, 'real@example.com');
      expect(session.account.displayName, 'Ana Ruiz');
    });

    test('an offline identity call still signs the shopper in, from claims',
        () async {
      final gateway = gatewayWith(
        sub: 'gid://shopify/Customer/1',
        email: 'shopper@example.com',
      );
      final identityService = FakeCustomerIdentityService(
        error: const CustomerAuthException(CustomerAuthErrorKind.offline),
      );

      final session = await repoWith(
        gateway,
        identityService: identityService,
      ).login();

      expect(session.account.shopifyCustomerId, 'gid://shopify/Customer/1');
      expect(session.account.email, 'shopper@example.com');
    });

    test('a rejected access token fails the login instead of creating an account',
        () async {
      final identityService = FakeCustomerIdentityService(
        error: const CustomerAuthException(
          CustomerAuthErrorKind.sessionExpired,
        ),
      );

      await expectLater(
        repoWith(gatewayWith(), identityService: identityService).login(),
        throwsA(
          isA<CustomerAuthException>().having(
            (e) => e.kind,
            'kind',
            CustomerAuthErrorKind.sessionExpired,
          ),
        ),
      );
      expect(await db.select(db.accounts).get(), isEmpty);
      final device = await devices.byId('dev-1');
      expect(device?.accountId, isNull);
    });

    test('no identity service and no id token is a failure, not a null id',
        () async {
      final gateway = FakeCustomerAuthGateway(
        loginResult: const CustomerAuthResult(
          accessToken: 'access-1',
          refreshToken: 'refresh-1',
          idToken: null,
          accessTokenExpiresAt: null,
        ),
      );

      await expectLater(
        repoWith(gateway).login(),
        throwsA(isA<CustomerAuthException>()),
      );
    });
  });

  group('CustomerSessionRepository.accessTokenFor', () {
    test('reuses the in-memory token from login instead of refreshing',
        () async {
      final gateway = gatewayWith(
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );
      final repo = repoWith(gateway);
      final session = await repo.login();

      final token = await repo.accessTokenFor(session.account.localAccountId);

      expect(token, 'access-1');
      expect(gateway.refreshCalls, 0);
    });

    test('refreshes a token that is already inside the expiry headroom',
        () async {
      final gateway = gatewayWith(
        expiresAt: DateTime.now().toUtc().add(const Duration(seconds: 30)),
      );
      final repo = repoWith(gateway);
      final session = await repo.login();
      gateway.refreshResult = CustomerAuthResult(
        accessToken: 'access-2',
        refreshToken: 'refresh-2',
        idToken: null,
        accessTokenExpiresAt: DateTime.now().toUtc().add(
              const Duration(hours: 1),
            ),
      );

      final token = await repo.accessTokenFor(session.account.localAccountId);

      expect(token, 'access-2');
      expect(gateway.refreshCalls, 1);
    });

    test('concurrent callers share one refresh (single-flight)', () async {
      // Shopify rotates the refresh token on use, so a second parallel
      // exchange would spend a token the first one already consumed and the
      // loser would sign the shopper out for no reason.
      final gateway = gatewayWith(
        expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
      );
      final repo = repoWith(gateway);
      final session = await repo.login();
      final accountId = session.account.localAccountId;

      final tokens = await Future.wait([
        repo.accessTokenFor(accountId),
        repo.accessTokenFor(accountId),
        repo.refreshAccessToken(accountId),
      ]);

      expect(gateway.refreshCalls, 1);
      expect(tokens, everyElement('access-1'));

      // The single-flight latch clears once it settles, so a later call still
      // reaches Shopify.
      await repo.refreshAccessToken(accountId);
      expect(gateway.refreshCalls, 2);
    });

    test('a failed refresh does not wedge the latch shut', () async {
      final gateway = gatewayWith(
        expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
      );
      final repo = repoWith(gateway);
      final session = await repo.login();
      final accountId = session.account.localAccountId;
      await secureStore.delete('customer_auth/refresh_token/$accountId');

      await expectLater(
        repo.accessTokenFor(accountId),
        throwsA(isA<NoActiveSessionException>()),
      );

      // The latch has to clear on failure too, or one lost refresh would
      // leave the shopper permanently unable to get a token.
      await secureStore.write(
        'customer_auth/refresh_token/$accountId',
        'refresh-restored',
      );
      expect(await repo.accessTokenFor(accountId), 'access-1');
      expect(gateway.lastRefreshTokenRequested, 'refresh-restored');
    });
  });

  group('CustomerSessionRepository.hasUsableLocalSession', () {
    test('true after login, false once the refresh token is gone', () async {
      final repo = repoWith(gatewayWith());
      final session = await repo.login();
      final accountId = session.account.localAccountId;

      expect(await repo.hasUsableLocalSession(accountId), isTrue);

      // What an OS-level credential reset or a reinstall looks like: the Drift
      // rows survive, the Keychain entry does not.
      secureStore.values.clear();
      expect(await repo.hasUsableLocalSession(accountId), isFalse);
    });

    test('false for an account that never logged in', () async {
      expect(
        await repoWith(gatewayWith()).hasUsableLocalSession('nobody'),
        isFalse,
      );
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
