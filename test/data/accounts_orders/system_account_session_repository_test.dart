import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/accounts_orders/system_account_client.dart';
import 'package:monetta_app/data/accounts_orders/system_account_session_repository.dart';
import 'package:monetta_app/data/customer_auth/secure_token_store.dart';
import 'package:monetta_app/data/local/account_store.dart';
import 'package:monetta_app/data/local/bag_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/wishlist_store.dart';

class _FakeClient implements SystemAccountClient {
  String? loggedOutToken;

  @override
  Future<SystemAccountRegistration> register({
    required String email,
    required String password,
    required String? displayName,
    required String deviceId,
  }) async {
    expect(deviceId, 'dev-1');
    expect(password, 'password123');
    return SystemAccountRegistration(
      accountId: 'account-1',
      email: email.toLowerCase(),
      displayName: displayName,
      sessionToken: 'opaque-token',
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
        displayName: 'Ana',
        deviceId: deviceId,
      );

  @override
  Future<void> logout(String sessionToken) async {
    loggedOutToken = sessionToken;
  }
}

class _FakeSecureStore implements SecureTokenStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

void main() {
  late AppDatabase db;
  late _FakeClient client;
  late _FakeSecureStore secureStore;
  late SystemAccountSessionRepository repository;

  setUp(() async {
    db = openTestDatabase();
    client = _FakeClient();
    secureStore = _FakeSecureStore();
    final devices = DeviceStore(db);
    await devices.upsert(deviceId: 'dev-1', platform: 'ios', appVersion: '1');
    repository = SystemAccountSessionRepository(
      client: client,
      accountStore: AccountStore(db),
      sessionStore: SessionStore(db),
      deviceStore: devices,
      wishlistStore: WishlistStore(db),
      bagStore: BagStore(db),
      secureStore: secureStore,
      deviceId: 'dev-1',
    );
  });

  tearDown(() => db.close());

  test('register persists the account/session and merges guest state',
      () async {
    await WishlistStore(db).add('product-1');
    await BagStore(db).upsert(
      productId: 'product-2',
      variantId: 'variant-2',
      quantity: 1,
    );

    final account = await repository.register(
      email: 'SHOPPER@EXAMPLE.COM',
      password: 'password123',
      displayName: 'Ana',
    );

    expect(account.localAccountId, 'account-1');
    expect(account.shopifyCustomerId, isNull);
    expect(account.authProvider, 'monetta');
    expect(account.email, 'shopper@example.com');
    expect((await DeviceStore(db).byId('dev-1'))?.accountId, 'account-1');
    expect(
      (await db.select(db.wishlistItems).get()).single.accountId,
      'account-1',
    );
    expect((await db.select(db.bagLines).get()).single.accountId, 'account-1');
    expect(secureStore.values.values.single, 'opaque-token');
    expect(
      await repository.accessTokenFor(account.localAccountId),
      'opaque-token',
    );
  });

  test(
    'logout revokes the remote token and clears the local session',
    () async {
      final account = await repository.register(
        email: 'shopper@example.com',
        password: 'password123',
        displayName: null,
      );
      await repository.logout(account.localAccountId);

      expect(client.loggedOutToken, 'opaque-token');
      expect(secureStore.values, isEmpty);
      expect(await SessionStore(db).latestFor(account.localAccountId), isNull);
      expect((await DeviceStore(db).byId('dev-1'))?.accountId, isNull);
    },
  );
}
