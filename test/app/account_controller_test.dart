import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/account_controller.dart';
import 'package:monetta_app/data/accounts_orders/accounts_orders_config.dart';
import 'package:monetta_app/data/customer_auth/customer_account_config.dart';
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
  _FakeGateway({this.shouldThrow = false});

  bool shouldThrow;

  @override
  Future<CustomerAuthResult> login() async {
    if (shouldThrow) throw StateError('user cancelled');
    final payload = base64Url
        .encode(utf8.encode(jsonEncode({'sub': 'gid://shopify/Customer/1', 'email': 'a@b.com'})))
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

class _FakeSecureTokenStore implements SecureTokenStore {
  final Map<String, String> values = {};
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  late AppDatabase db;
  late DeviceStore deviceStore;
  late AccountStore accountStore;

  AccountController buildController({bool loginThrows = false, bool usable = true}) {
    final gateway = _FakeGateway(shouldThrow: loginThrows);
    final sessionRepo = CustomerSessionRepository(
      authGateway: gateway,
      accountStore: accountStore,
      sessionStore: SessionStore(db),
      deviceStore: deviceStore,
      wishlistStore: WishlistStore(db),
      bagStore: BagStore(db),
      secureStore: _FakeSecureTokenStore(),
      deviceId: 'dev-1',
    );
    return AccountController(
      sessionRepository: sessionRepo,
      accountStore: accountStore,
      deviceStore: deviceStore,
      orderHistoryRepository: OrderHistoryRepository(
        store: OrderSummaryStore(db),
        config: AccountsOrdersConfig.disabled,
      ),
      config: usable
          ? const CustomerAccountConfig(shopId: '1', clientId: 'shp_x', redirectUri: 'shop.1.oauth://c')
          : CustomerAccountConfig.fromEnvironment(),
      deviceId: 'dev-1',
    );
  }

  setUp(() async {
    db = openTestDatabase();
    deviceStore = DeviceStore(db);
    accountStore = AccountStore(db);
    await deviceStore.upsert(deviceId: 'dev-1', platform: 'ios', appVersion: '1.0.0');
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

  test('login() surfaces a failure without throwing, and does not sign in', () async {
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

  test('restore() re-hydrates account state from a previous login (e.g. app restart)', () async {
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
}
