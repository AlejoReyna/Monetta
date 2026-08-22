import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/account_controller.dart';
import 'package:monetta_app/data/accounts_orders/accounts_orders_config.dart';
import 'package:monetta_app/data/accounts_orders/system_account_client.dart';
import 'package:monetta_app/data/accounts_orders/system_account_session_repository.dart';
import 'package:monetta_app/data/customer_auth/customer_account_config.dart';
import 'package:monetta_app/data/customer_auth/customer_auth_error.dart';
import 'package:monetta_app/data/customer_auth/customer_auth_gateway.dart';
import 'package:monetta_app/data/customer_auth/customer_session_repository.dart';
import 'package:monetta_app/data/customer_auth/secure_token_store.dart';
import 'package:monetta_app/data/local/account_store.dart';
import 'package:monetta_app/data/local/bag_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/order_summary_store.dart';
import 'package:monetta_app/data/local/wishlist_store.dart';
import 'package:monetta_app/data/repositories/order_history_repository.dart';

class _FakeGateway implements CustomerAuthGateway {
  _FakeGateway({this.shouldThrow = false, this.throws});

  bool shouldThrow;

  /// A classified failure, the way `AppAuthCustomerGateway` reports one.
  Object? throws;

  @override
  Future<CustomerAuthResult> login() async {
    final failure = throws;
    if (failure != null) throw failure;
    if (shouldThrow) throw StateError('user cancelled');
    final payload = base64Url
        .encode(
          utf8.encode(
            jsonEncode({
              'sub': 'gid://shopify/Customer/1',
              'email': 'a@b.com',
            }),
          ),
        )
        .replaceAll('=', '');
    return CustomerAuthResult(
      accessToken: 'access',
      refreshToken: 'refresh',
      idToken: 'h.$payload.s',
      accessTokenExpiresAt: DateTime.utc(2026, 1, 1, 1),
    );
  }

  @override
  Future<CustomerAuthResult> refresh(String refreshToken) => login();
}

/// Refuses every refresh the way Shopify does once a refresh token has been
/// revoked or has expired.
class _RevokedGateway implements CustomerAuthGateway {
  @override
  Future<CustomerAuthResult> login() =>
      throw const CustomerAuthException(CustomerAuthErrorKind.sessionExpired);

  @override
  Future<CustomerAuthResult> refresh(String refreshToken) =>
      throw const CustomerAuthException(CustomerAuthErrorKind.sessionExpired);
}

/// Fails every refresh the way a plane ride does.
class _OfflineGateway implements CustomerAuthGateway {
  @override
  Future<CustomerAuthResult> login() =>
      throw const CustomerAuthException(CustomerAuthErrorKind.offline);

  @override
  Future<CustomerAuthResult> refresh(String refreshToken) =>
      throw const CustomerAuthException(CustomerAuthErrorKind.offline);
}

class _FakeSecureTokenStore implements SecureTokenStore {
  final Map<String, String> values = {};
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _FakeSystemClient implements SystemAccountClient {
  bool shouldThrow = false;

  @override
  Future<SystemAccountRegistration> register({
    required String email,
    required String password,
    required String? displayName,
    required String deviceId,
  }) async {
    if (shouldThrow) throw StateError('offline');
    return SystemAccountRegistration(
      accountId: 'monetta-account-1',
      email: email,
      displayName: displayName,
      sessionToken: 'session-token',
      expiresAt: DateTime.utc(2027),
    );
  }

  @override
  Future<SystemAccountRegistration> login({
    required String email,
    required String password,
    required String deviceId,
  }) =>
      register(
        email: email,
        password: password,
        displayName: null,
        deviceId: deviceId,
      );

  @override
  Future<void> logout(String sessionToken) async {}
}

void main() {
  late AppDatabase db;
  late DeviceStore deviceStore;
  late AccountStore accountStore;

  /// Shared across every controller a test builds, because the Keychain /
  /// Keystore it stands in for is shared too: a refresh token written before
  /// a restart is still there after one. A per-controller store would make
  /// "restore a session" pass for the wrong reason.
  late _FakeSecureTokenStore secureStore;

  AccountController buildController({
    bool loginThrows = false,
    bool usable = true,
    Object? loginError,
    CustomerAuthGateway? gateway,
    _FakeSystemClient? systemClient,
  }) {
    final sessionRepo = CustomerSessionRepository(
      authGateway:
          gateway ?? _FakeGateway(shouldThrow: loginThrows, throws: loginError),
      accountStore: accountStore,
      sessionStore: SessionStore(db),
      deviceStore: deviceStore,
      wishlistStore: WishlistStore(db),
      bagStore: BagStore(db),
      secureStore: secureStore,
      deviceId: 'dev-1',
    );
    return AccountController(
      sessionRepository: sessionRepo,
      // Production builds both (see `main.dart`), so a controller that can do
      // Shopify *and* Monetta is the shape worth testing against.
      systemSessionRepository: systemClient == null
          ? null
          : SystemAccountSessionRepository(
              client: systemClient,
              accountStore: accountStore,
              sessionStore: SessionStore(db),
              deviceStore: deviceStore,
              wishlistStore: WishlistStore(db),
              bagStore: BagStore(db),
              secureStore: secureStore,
              deviceId: 'dev-1',
            ),
      accountStore: accountStore,
      deviceStore: deviceStore,
      orderHistoryRepository: OrderHistoryRepository(
        store: OrderSummaryStore(db),
        config: AccountsOrdersConfig.disabled,
      ),
      config: usable
          ? const CustomerAccountConfig(
              shopDomain: 'shop.example.com',
              shopId: '1',
              clientId: 'shp_x',
              redirectUri: 'shop.1.oauth://c',
            )
          : CustomerAccountConfig.fromEnvironment(),
      deviceId: 'dev-1',
    );
  }

  AccountController buildSystemController(_FakeSystemClient client) {
    return AccountController(
      systemSessionRepository: SystemAccountSessionRepository(
        client: client,
        accountStore: accountStore,
        sessionStore: SessionStore(db),
        deviceStore: deviceStore,
        wishlistStore: WishlistStore(db),
        bagStore: BagStore(db),
        secureStore: secureStore,
        deviceId: 'dev-1',
      ),
      accountStore: accountStore,
      deviceStore: deviceStore,
      orderHistoryRepository: OrderHistoryRepository(
        store: OrderSummaryStore(db),
        config: AccountsOrdersConfig.disabled,
      ),
      deviceId: 'dev-1',
    );
  }

  setUp(() async {
    db = openTestDatabase();
    deviceStore = DeviceStore(db);
    accountStore = AccountStore(db);
    secureStore = _FakeSecureTokenStore();
    await deviceStore.upsert(
      deviceId: 'dev-1',
      platform: 'ios',
      appVersion: '1.0.0',
    );
  });

  tearDown(() => db.close());

  test('canLogin reflects CustomerAccountConfig.isUsable', () {
    expect(buildController(usable: true).canLogin, isTrue);
    expect(buildController(usable: false).canLogin, isFalse);
  });

  test('login() sets account and clears loading/error on success', () async {
    final controller = buildController();
    expect(controller.isSignedIn, isFalse);

    final future = controller.login();
    expect(controller.isLoading, isTrue);
    await future;

    expect(controller.isLoading, isFalse);
    expect(controller.isSignedIn, isTrue);
    expect(controller.account?.email, 'a@b.com');
    expect(controller.lastError, isNull);
  });

  test('login() surfaces a failure without throwing, and does not sign in',
      () async {
    final controller = buildController(loginThrows: true);
    await controller.login();

    expect(controller.isLoading, isFalse);
    expect(controller.isSignedIn, isFalse);
    expect(controller.lastError, isNotNull);
  });

  test('logout() clears the signed-in account', () async {
    final controller = buildController();
    await controller.login();
    expect(controller.isSignedIn, isTrue);

    await controller.logout();

    expect(controller.isSignedIn, isFalse);
    expect(controller.account, isNull);
  });

  test(
      'restore() re-hydrates account state from a previous login (e.g. app restart)',
      () async {
    final controller = buildController();
    await controller.login();
    final localAccountId = controller.account!.localAccountId;

    // Simulate a fresh controller instance after an app restart: same
    // device, same underlying Drift rows, no in-memory state carried over.
    final restored = buildController();
    expect(restored.isSignedIn, isFalse);

    await restored.restore();

    expect(restored.isSignedIn, isTrue);
    expect(restored.account?.localAccountId, localAccountId);
  });

  test('login() is a no-op when login is not available', () async {
    final controller = buildController(usable: false);
    await controller.login();
    expect(controller.isSignedIn, isFalse);
    expect(controller.isLoading, isFalse);
  });

  group('revalidateSession', () {
    /// Signs in on one controller, then hands back a second one restored from
    /// the same rows and the same Keychain — an app restart, with whichever
    /// gateway the next launch would meet.
    Future<AccountController> restartWith(CustomerAuthGateway gateway) async {
      await buildController().login();
      final restarted = buildController(gateway: gateway);
      await restarted.restore();
      expect(restarted.isSignedIn, isTrue, reason: 'restore() precondition');
      return restarted;
    }

    test('a revoked refresh token signs the shopper out locally', () async {
      final controller = await restartWith(_RevokedGateway());

      await controller.revalidateSession();

      expect(controller.isSignedIn, isFalse);
      expect(controller.account, isNull);
      expect(controller.lastError?.flow, AccountAuthFlow.shopify);
      expect(controller.lastError?.kind, CustomerAuthErrorKind.sessionExpired);

      // And it stays signed out: the refresh token is gone, so the next
      // restart has nothing to restore.
      final next = buildController();
      await next.restore();
      expect(next.isSignedIn, isFalse);
    });

    test('being offline is not being signed out', () async {
      final controller = await restartWith(_OfflineGateway());

      await controller.revalidateSession();

      expect(controller.isSignedIn, isTrue);
      expect(controller.lastError, isNull);
    });

    test('a Monetta account is never revalidated against Shopify', () async {
      // The gateway would sign this account out if it were ever consulted.
      final controller = buildController(
        gateway: _RevokedGateway(),
        systemClient: _FakeSystemClient(),
      );
      await controller.register(
        email: 'shopper@example.com',
        password: 'password123',
      );
      expect(controller.account?.authProvider, 'monetta');

      await controller.revalidateSession();

      expect(controller.isSignedIn, isTrue);
      expect(controller.lastError, isNull);
    });
  });

  test('register() creates and selects a first-party account without Shopify',
      () async {
    final controller = buildSystemController(_FakeSystemClient());
    expect(controller.canRegister, isTrue);

    await controller.register(
      email: 'shopper@example.com',
      password: 'password123',
      displayName: 'Ana',
    );

    expect(controller.isSignedIn, isTrue);
    expect(controller.account?.localAccountId, 'monetta-account-1');
    expect(controller.account?.shopifyCustomerId, isNull);
    expect(controller.account?.authProvider, 'monetta');
  });
}
