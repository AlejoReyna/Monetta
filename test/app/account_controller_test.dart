import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/account_controller.dart';
import 'package:monetta_app/data/accounts_orders/account_deletion_client.dart';
import 'package:monetta_app/data/accounts_orders/accounts_orders_config.dart';
import 'package:monetta_app/data/accounts_orders/system_account_client.dart';
import 'package:monetta_app/data/accounts_orders/system_account_session_repository.dart';
import 'package:monetta_app/data/customer_auth/customer_account_config.dart';
import 'package:monetta_app/data/customer_auth/customer_auth_error.dart';
import 'package:monetta_app/data/customer_auth/customer_auth_gateway.dart';
import 'package:monetta_app/data/customer_auth/customer_profile.dart';
import 'package:monetta_app/data/customer_auth/customer_session_repository.dart';
import 'package:monetta_app/data/customer_auth/jwt.dart';
import 'package:monetta_app/data/customer_auth/secure_token_store.dart';
import 'package:monetta_app/data/local/account_store.dart';
import 'package:monetta_app/data/local/bag_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/order_summary_store.dart';
import 'package:monetta_app/data/local/wishlist_store.dart';
import 'package:monetta_app/data/customer_auth/customer_orders.dart';
import 'package:monetta_app/data/repositories/order_history_repository.dart';

class _FakeGateway implements CustomerAuthGateway {
  _FakeGateway({this.shouldThrow = false, this.throws});

  bool shouldThrow;
  String customerId = 'gid://shopify/Customer/1';
  String email = 'a@b.com';
  int endSessionCalls = 0;
  String? lastEndedIdToken;

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
              'sub': customerId,
              'email': email,
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

  @override
  Future<void> endSession({required String idTokenHint}) async {
    endSessionCalls += 1;
    lastEndedIdToken = idTokenHint;
  }
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

  @override
  Future<void> endSession({required String idTokenHint}) async {}
}

/// Fails every refresh the way a plane ride does.
class _OfflineGateway implements CustomerAuthGateway {
  @override
  Future<CustomerAuthResult> login() =>
      throw const CustomerAuthException(CustomerAuthErrorKind.offline);

  @override
  Future<CustomerAuthResult> refresh(String refreshToken) =>
      throw const CustomerAuthException(CustomerAuthErrorKind.offline);

  @override
  Future<void> endSession({required String idTokenHint}) async {}
}

class _FakeSecureTokenStore implements SecureTokenStore {
  final Map<String, String> values = {};
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  bool failReads = false;
  @override
  Future<String?> read(String key) async {
    await Future<void>.delayed(Duration.zero);
    if (failReads) throw StateError('asynchronous secure storage failure');
    return values[key];
  }

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

class _MatchClient implements AccountDeletionClient {
  _MatchClient(this.outcome);

  final AccountDeletionOutcome outcome;
  int deleteCalls = 0;
  String? deletedAccessToken;

  @override
  Future<AccountDeletionOutcome> precheck(String accessToken) async => outcome;

  @override
  Future<AccountDeletionOutcome> matchLegacyEmail({
    required String shopifyAccessToken,
    required String legacySessionToken,
  }) async =>
      outcome;

  @override
  Future<AccountDeletionOutcome> delete({
    required String accessToken,
    required String idToken,
    String? legacySessionToken,
  }) async {
    deleteCalls += 1;
    deletedAccessToken = accessToken;
    return const AccountDeletionDeleted();
  }

  @override
  void close() {}
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
    CustomerProfileService? profileService,
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
      profileService: profileService,
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

  test('a mismatched deletion login keeps the legacy account', () async {
    final controller = buildController(systemClient: _FakeSystemClient());
    await controller.loginWithSystemAccount(
      email: 'legacy@example.com',
      password: 'secret',
    );
    final localId = controller.account?.localAccountId;
    expect(controller.account?.authProvider, 'monetta');

    final result = await controller.signInForAccountDeletion(
      _MatchClient(const AccountDeletionEmailMismatch('a•••@gmail.com')),
    );

    expect(result, isA<LegacyDeletionMismatch>());
    expect((result as LegacyDeletionMismatch).maskedEmail, 'a•••@gmail.com');
    expect(controller.account?.authProvider, 'monetta');
    expect(controller.account?.localAccountId, localId);
    expect(await controller.accessTokenForBackend(), 'session-token');
    final device = await deviceStore.byId('dev-1');
    expect(device?.accountId, localId);
  });

  test('a matching deletion login adopts Shopify only after the server agrees',
      () async {
    final controller = buildController(systemClient: _FakeSystemClient());
    await controller.loginWithSystemAccount(
      email: 'legacy@example.com',
      password: 'secret',
    );

    final result = await controller.signInForAccountDeletion(
      _MatchClient(const AccountDeletionEmailMatch()),
    );

    expect(result, isA<LegacyDeletionMatched>());
    expect(controller.account?.authProvider, 'shopify');
    expect(
      (result as LegacyDeletionMatched).legacySessionToken,
      'session-token',
    );
    expect(await controller.accessTokenForBackend(), 'access');
  });

  test('legacy deletion cannot bypass the server email check', () async {
    final controller = buildController(systemClient: _FakeSystemClient());
    await controller.loginWithSystemAccount(
      email: 'legacy@example.com',
      password: 'secret',
    );
    await expectLater(
      controller.reauthenticateForDeletion(),
      throwsA(isA<CustomerAuthException>()),
    );
    expect(controller.account?.authProvider, 'monetta');
    expect(await controller.accessTokenForBackend(), 'session-token');
  });

  for (final sameCustomer in [true, false]) {
    test(
      'deletion re-login ${sameCustomer ? 'accepts the same' : 'rejects another'} customer',
      () async {
        final gateway = _FakeGateway();
        final controller = buildController(gateway: gateway);
        await controller.login();
        final target = controller.account!;
        final storedTokens = Map<String, String>.of(secureStore.values);
        if (sameCustomer) {
          // Changing email does not change the Shopify customer identity.
          gateway.email = 'updated@example.com';
        } else {
          // A shared email must not let a different customer pass the check.
          gateway.customerId = 'gid://shopify/Customer/2';
        }
        final client = _MatchClient(const AccountDeletionClear());
        Future<void> deleteAfterReauth() async {
          final fresh = await controller.reauthenticateForDeletion();
          await client.delete(
            accessToken: fresh.accessToken,
            idToken: fresh.idToken,
          );
        }

        if (sameCustomer) {
          await deleteAfterReauth();
          expect(client.deleteCalls, 1);
          expect(client.deletedAccessToken, 'access');
          expect(gateway.endSessionCalls, 0);
        } else {
          await expectLater(
            deleteAfterReauth(),
            throwsA(isA<AccountDeletionIdentityMismatch>()),
          );
          expect(client.deleteCalls, 0);
          expect(gateway.endSessionCalls, 1);
          expect(
            decodeIdTokenClaims(gateway.lastEndedIdToken!)['sub'],
            gateway.customerId,
          );
          expect(secureStore.values, storedTokens);
          expect(
            await accountStore.byShopifyCustomerId(gateway.customerId),
            isNull,
          );
        }
        expect(controller.account?.localAccountId, target.localAccountId);
        expect(
          controller.account?.email,
          sameCustomer ? gateway.email : target.email,
        );
        expect(
          (await deviceStore.byId('dev-1'))?.accountId,
          target.localAccountId,
        );
        controller.dispose();
      },
    );
  }

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

  test('backend token catches asynchronous Shopify session rejection',
      () async {
    final controller = buildController();
    await controller.login();
    secureStore.failReads = true;
    expect(await controller.accessTokenForBackend(), isNull);
  });

  test('backend token catches asynchronous Monetta session rejection',
      () async {
    final controller = buildController(systemClient: _FakeSystemClient());
    await controller.register(
      email: 'test@example.invalid',
      password: 'test-password',
    );
    secureStore.failReads = true;
    expect(await controller.accessTokenForBackend(), isNull);
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

  test('loadOrders discards stale response after logout (F14)', () async {
    final gate = Completer<List<CustomerAccountOrder>>();
    final caa = _GatedCaa(gate);
    final controller = AccountController(
      sessionRepository: CustomerSessionRepository(
        authGateway: _FakeGateway(),
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
        customerOrders: caa,
      ),
      config: const CustomerAccountConfig(
        shopDomain: 'shop.example.com',
        shopId: '1',
        clientId: 'shp_x',
        redirectUri: 'shop.1.oauth://c',
      ),
      deviceId: 'dev-1',
    );

    // First CAA call (login → loadOrders) returns empty immediately.
    await controller.login();
    expect(controller.isSignedIn, isTrue);

    // Second call is gated so logout can race the in-flight refresh.
    caa.blockNext = true;
    final pending = controller.loadOrders();
    await Future<void>.delayed(Duration.zero);
    await controller.logout();
    gate.complete([
      CustomerAccountOrder(
        id: 'gid://shopify/Order/1',
        name: '#1',
        number: 1,
        processedAt: DateTime.utc(2026, 8, 1),
        financialStatus: 'PAID',
        fulfillmentStatus: null,
        totalAmount: 10,
        currencyCode: 'MXN',
      ),
    ]);
    await pending;

    expect(controller.isSignedIn, isFalse);
    expect(controller.orders, isEmpty);
    expect(controller.ordersStatus, OrderHistoryStatus.unavailable);
    expect(controller.account, isNull);
  });

  test('loadOrders surfaces unavailable when no remote source is usable',
      () async {
    final controller = buildController();
    await controller.login();
    await controller.loadOrders();
    expect(controller.ordersStatus, OrderHistoryStatus.unavailable);
    expect(controller.orders, isEmpty);
  });

  group('Shopify profile', () {
    final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);

    /// Signs in on a Shopify account. [arrange] runs before the login, because
    /// the login itself starts loading the profile in the background.
    Future<(AccountController, _FakeProfileService)> signedIn({
      _FakeGateway? gateway,
      void Function(_FakeProfileService service)? arrange,
    }) async {
      final service = _FakeProfileService();
      arrange?.call(service);
      final controller = buildController(
        gateway: gateway,
        profileService: service,
      );
      await controller.login();
      expect(controller.isSignedIn, isTrue);
      await pumpEventQueue();
      return (controller, service);
    }

    test('signing in loads the profile without anyone asking for it', () async {
      final photoUrl = profilePhotoDataUrl(jpeg);
      final (controller, service) = await signedIn(
        arrange: (service) => service.profile = CustomerProfile(
          shopifyCustomerId: 'gid://shopify/Customer/1',
          firstName: 'Ana',
          photoDataUrl: photoUrl,
        ),
      );

      expect(service.calls, ['fetch']);
      expect(controller.profile?.firstName, 'Ana');
      expect(controller.profilePhotoBytes, jpeg);
      expect(controller.profileLoading, isFalse);
    });

    test('restoring a session loads the profile in the background', () async {
      await buildController().login();
      final service = _FakeProfileService();
      final restarted = buildController(profileService: service);

      await restarted.restore();
      await pumpEventQueue();

      expect(restarted.isSignedIn, isTrue);
      expect(service.calls, ['fetch']);
      expect(restarted.profile?.firstName, 'Ana');
    });

    test('restore does not load a profile when nobody is signed in', () async {
      final service = _FakeProfileService();
      final controller = buildController(profileService: service);

      await controller.restore();
      await pumpEventQueue();

      expect(controller.isSignedIn, isFalse);
      expect(service.calls, isEmpty);
    });

    test('a request in flight is joined, and a loaded profile is not refetched',
        () async {
      final (controller, service) = await signedIn(
        arrange: (service) => service.gate = Completer<void>(),
      );
      expect(service.calls, ['fetch']);
      expect(controller.profileLoading, isTrue);

      final first = controller.loadProfile();
      final second = controller.loadProfile();
      expect(service.calls, ['fetch']);

      service.gate!.complete();
      await Future.wait([first, second]);
      expect(controller.profile?.firstName, 'Ana');

      await controller.loadProfile();
      expect(service.calls, ['fetch']);
    });

    test('a failed background load can be retried by asking again', () async {
      final (controller, service) = await signedIn(
        arrange: (service) => service.failure = const CustomerAuthException(
          CustomerAuthErrorKind.offline,
        ),
      );
      expect(controller.profile, isNull);

      service.failure = null;
      await controller.loadProfile();

      expect(service.calls, ['fetch', 'fetch']);
      expect(controller.profile?.firstName, 'Ana');
    });

    test('switching to account B loads B, not A', () async {
      final gateway = _FakeGateway();
      final (controller, service) = await signedIn(
        gateway: gateway,
        arrange: (service) => service.queued.addAll(const [
          CustomerProfile(
            shopifyCustomerId: 'gid://shopify/Customer/1',
            firstName: 'Ana',
          ),
          CustomerProfile(
            shopifyCustomerId: 'gid://shopify/Customer/2',
            firstName: 'Beto',
          ),
        ]),
      );
      expect(controller.profile?.firstName, 'Ana');

      gateway.customerId = 'gid://shopify/Customer/2';
      gateway.email = 'b@b.com';
      await controller.login();
      await pumpEventQueue();

      expect(service.calls, ['fetch', 'fetch']);
      expect(controller.profile?.firstName, 'Beto');
    });

    test('loadProfile fetches with the Customer Account token', () async {
      final (controller, service) = await signedIn();

      await controller.loadProfile();

      expect(controller.canEditProfile, isTrue);
      expect(service.calls, ['fetch']);
      expect(service.tokens.single, 'access');
      expect(controller.profile?.firstName, 'Ana');
      expect(controller.profileLoading, isFalse);
    });

    test('a failed load leaves the profile empty and does not throw', () async {
      final (controller, service) = await signedIn(
        arrange: (service) => service.failure = const CustomerAuthException(
          CustomerAuthErrorKind.offline,
        ),
      );

      await controller.loadProfile();

      expect(service.calls, ['fetch', 'fetch']);
      expect(controller.profile, isNull);
      expect(controller.profileLoading, isFalse);
    });

    test('legacy Monetta accounts cannot edit or load a profile', () async {
      final service = _FakeProfileService();
      final controller = buildController(
        systemClient: _FakeSystemClient(),
        profileService: service,
      );
      await controller.loginWithSystemAccount(
        email: 'legacy@example.com',
        password: 'secret',
      );
      expect(controller.account?.authProvider, 'monetta');

      expect(controller.canEditProfile, isFalse);
      await pumpEventQueue();
      await controller.loadProfile();
      final outcome = await controller.saveProfile(firstName: 'Nuevo');

      expect(service.calls, isEmpty);
      expect(outcome.status, ProfileSaveStatus.failed);
    });

    test('a controller without the service cannot edit', () async {
      final controller = buildController();
      await controller.login();
      expect(controller.canEditProfile, isFalse);
    });

    test('saving a name updates the profile and Accounts.displayName',
        () async {
      final (controller, service) = await signedIn();
      await controller.loadProfile();
      service.reportedDisplayName = 'Lucía Ruiz';
      final before = controller.account!;

      final outcome = await controller.saveProfile(firstName: '  Lucía ');

      expect(outcome.status, ProfileSaveStatus.saved);
      expect(service.calls, ['fetch', 'updateFirstName']);
      expect(service.lastFirstName, 'Lucía');
      expect(controller.profile?.firstName, 'Lucía');
      expect(controller.profile?.displayName, 'Lucía Ruiz');
      expect(controller.account?.displayName, 'Lucía Ruiz');
      // Every other column is carried over untouched.
      final stored = await accountStore.byLocalId(before.localAccountId);
      expect(stored?.displayName, 'Lucía Ruiz');
      expect(stored?.email, before.email);
      expect(stored?.shopifyCustomerId, before.shopifyCustomerId);
      expect(stored?.authProvider, 'shopify');
      expect(stored?.createdAt, before.createdAt);
      expect(controller.profileSaving, isFalse);
    });

    test('saving a photo sends only the photo and keeps it in memory',
        () async {
      final (controller, service) = await signedIn();
      await controller.loadProfile();

      final outcome = await controller.saveProfile(photoJpeg: jpeg);

      expect(outcome.isSaved, isTrue);
      expect(service.calls, ['fetch', 'setPhoto']);
      expect(service.lastCustomerId, 'gid://shopify/Customer/1');
      expect(service.lastDataUrl, profilePhotoDataUrl(jpeg));
      expect(controller.profilePhotoBytes, jpeg);
      // The photo is never written to the local database.
      final stored = await accountStore.byLocalId(
        controller.account!.localAccountId,
      );
      expect(stored.toString(), isNot(contains('data:image')));
    });

    test('removing the photo calls removePhoto and clears it', () async {
      final (controller, service) = await signedIn(
        arrange: (service) => service.profile = CustomerProfile(
          shopifyCustomerId: 'gid://shopify/Customer/1',
          firstName: 'Ana',
          photoDataUrl: profilePhotoDataUrl(jpeg),
        ),
      );
      expect(controller.profilePhotoBytes, jpeg);

      final outcome = await controller.saveProfile(removePhoto: true);

      expect(outcome.isSaved, isTrue);
      expect(service.calls.last, 'removePhoto');
      expect(controller.profile?.photoDataUrl, isNull);
      expect(controller.profilePhotoBytes, isNull);
    });

    test('works before the profile loaded, using the stored customer id',
        () async {
      final (controller, service) = await signedIn(
        arrange: (service) {
          service
            ..gate = Completer<void>()
            ..gatedCall = 'fetch';
        },
      );
      expect(controller.profile, isNull);

      final outcome = await controller.saveProfile(photoJpeg: jpeg);

      expect(outcome.isSaved, isTrue);
      expect(service.lastCustomerId, 'gid://shopify/Customer/1');
      expect(controller.profile?.shopifyCustomerId, 'gid://shopify/Customer/1');
    });

    test('maps failures to typed outcomes with Spanish messages', () async {
      final (controller, service) = await signedIn();

      service.failure = const ProfilePhotoTooLargeException(61000);
      var outcome = await controller.saveProfile(photoJpeg: jpeg);
      expect(outcome.status, ProfileSaveStatus.tooLarge);
      expect(outcome.message, 'La foto es demasiado grande. Elige otra.');

      service.failure = const CustomerAuthException(
        CustomerAuthErrorKind.offline,
      );
      outcome = await controller.saveProfile(photoJpeg: jpeg);
      expect(outcome.status, ProfileSaveStatus.failed);
      expect(
        outcome.message,
        'Sin conexión. Revisa tu internet e inténtalo de nuevo.',
      );

      service.failure = const CustomerAuthException(
        CustomerAuthErrorKind.sessionExpired,
      );
      outcome = await controller.saveProfile(photoJpeg: jpeg);
      expect(outcome.status, ProfileSaveStatus.sessionExpired);
      expect(outcome.message, 'Tu sesión terminó. Inicia sesión de nuevo.');

      service.failure = const CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'customer metafieldsSet userErrors: ACCESS_DENIED',
      );
      outcome = await controller.saveProfile(photoJpeg: jpeg);
      expect(outcome.status, ProfileSaveStatus.failed);
      expect(
        outcome.message,
        'No pudimos guardar tu perfil. Inténtalo de nuevo.',
      );

      service.failure = StateError('boom');
      outcome = await controller.saveProfile(photoJpeg: jpeg);
      expect(outcome.status, ProfileSaveStatus.failed);
      expect(controller.profileSaving, isFalse);
    });

    test('a name that saved stays applied when the photo then fails', () async {
      final inner = _FakeProfileService()..reportedDisplayName = 'Lucía';
      final controller = buildController(profileService: _FailOnPhoto(inner));
      await controller.login();
      await controller.loadProfile();

      final outcome = await controller.saveProfile(
        firstName: 'Lucía',
        photoJpeg: jpeg,
      );

      expect(outcome.status, ProfileSaveStatus.failed);
      expect(controller.profile?.firstName, 'Lucía');
      expect(controller.account?.displayName, 'Lucía');
      expect(controller.profile?.photoDataUrl, isNull);
    });

    test('a late load for account A is discarded after switching to B',
        () async {
      final gateway = _FakeGateway();
      final (controller, service) = await signedIn(
        gateway: gateway,
        arrange: (service) => service
          ..gate = Completer<void>()
          ..queued.addAll(const [
            CustomerProfile(
              shopifyCustomerId: 'gid://shopify/Customer/1',
              firstName: 'Ana',
            ),
            CustomerProfile(
              shopifyCustomerId: 'gid://shopify/Customer/2',
              firstName: 'Beto',
            ),
          ]),
      );
      final accountA = controller.account!.localAccountId;
      expect(service.calls, ['fetch']);
      expect(controller.profileLoading, isTrue);

      gateway.customerId = 'gid://shopify/Customer/2';
      gateway.email = 'b@b.com';
      await controller.login();
      await pumpEventQueue();
      expect(controller.account?.localAccountId, isNot(accountA));
      expect(controller.profile, isNull);
      expect(service.calls, ['fetch', 'fetch']);

      service.gate!.complete();
      await pumpEventQueue();

      // A's answer was dropped; B's own request is the one that landed.
      expect(controller.profile?.firstName, 'Beto');
      expect(controller.profile?.shopifyCustomerId, 'gid://shopify/Customer/2');
      expect(controller.profileLoading, isFalse);
    });

    test('a load that lands after logout is discarded', () async {
      final (controller, service) = await signedIn(
        arrange: (service) => service.gate = Completer<void>(),
      );
      expect(controller.profileLoading, isTrue);

      await controller.logout();
      service.gate!.complete();
      await pumpEventQueue();

      expect(controller.profile, isNull);
      expect(controller.profilePhotoBytes, isNull);
      expect(controller.profileLoading, isFalse);
    });

    test('a late save for account A is discarded after switching to B',
        () async {
      final gateway = _FakeGateway();
      final (controller, service) = await signedIn(
        gateway: gateway,
        arrange: (service) => service.queued.addAll(const [
          CustomerProfile(
            shopifyCustomerId: 'gid://shopify/Customer/1',
            firstName: 'Ana',
          ),
          CustomerProfile(
            shopifyCustomerId: 'gid://shopify/Customer/2',
            firstName: 'Beto',
          ),
        ]),
      );
      final accountA = controller.account!.localAccountId;
      final before = controller.account!.displayName;
      service
        ..gate = Completer<void>()
        ..gatedCall = 'updateFirstName';

      final pending = controller.saveProfile(firstName: 'Lucía');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(service.calls, ['fetch', 'updateFirstName']);

      gateway.customerId = 'gid://shopify/Customer/2';
      gateway.email = 'b@b.com';
      await controller.login();
      await pumpEventQueue();
      final accountB = controller.account!;
      expect(accountB.localAccountId, isNot(accountA));

      service.gate!.complete();
      final outcome = await pending;

      expect(outcome.status, ProfileSaveStatus.discarded);
      // B keeps its own profile; A's «Lucía» never reached it.
      expect(controller.profile?.firstName, 'Beto');
      expect(controller.profileSaving, isFalse);
      expect(controller.account?.localAccountId, accountB.localAccountId);
      expect(controller.account?.displayName, accountB.displayName);
      // A's stored name was not touched by the discarded save either.
      expect((await accountStore.byLocalId(accountA))?.displayName, before);
    });

    test('logout clears the profile and orphans a save in flight', () async {
      final (controller, service) = await signedIn();
      await controller.loadProfile();
      expect(controller.profile, isNotNull);

      service.gate = Completer<void>();
      final pending = controller.saveProfile(photoJpeg: jpeg);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await controller.logout();

      expect(controller.profile, isNull);
      expect(controller.profilePhotoBytes, isNull);
      expect(controller.canEditProfile, isFalse);

      service.gate!.complete();
      final outcome = await pending;
      expect(outcome.status, ProfileSaveStatus.discarded);
      expect(controller.profile, isNull);
    });

    test('logging in again as the same account keeps the loaded profile',
        () async {
      final (controller, _) = await signedIn();
      await controller.loadProfile();
      final loaded = controller.profile;

      await controller.login();

      expect(controller.profile, same(loaded));
    });
  });
}

/// Delegates to [inner] except that setting a photo fails.
class _FailOnPhoto implements CustomerProfileService {
  _FailOnPhoto(this.inner);

  final _FakeProfileService inner;

  @override
  Future<CustomerProfile> fetch(String accessToken) => inner.fetch(accessToken);

  @override
  Future<String?> updateFirstName(String accessToken, String firstName) =>
      inner.updateFirstName(accessToken, firstName);

  @override
  Future<void> setPhoto(
    String accessToken,
    String customerId,
    String dataUrl,
  ) async =>
      throw const CustomerAuthException(CustomerAuthErrorKind.server);

  @override
  Future<void> removePhoto(String accessToken, String customerId) =>
      inner.removePhoto(accessToken, customerId);
}

/// Records every call and can hold the next one open so a test can switch
/// accounts while a request is in flight.
class _FakeProfileService implements CustomerProfileService {
  CustomerProfile profile = const CustomerProfile(
    shopifyCustomerId: 'gid://shopify/Customer/1',
    firstName: 'Ana',
    lastName: 'Ruiz',
    displayName: 'Ana Ruiz',
  );
  Object? failure;
  Completer<void>? gate;

  /// When set, only this call waits on [gate]; the rest answer at once.
  String? gatedCall;

  /// Answers handed out, one per `fetch`, before falling back to [profile].
  /// Taken when the call is made, so each request keeps its own answer even
  /// when several are in flight.
  final queued = <CustomerProfile>[];
  String? reportedDisplayName;
  final calls = <String>[];
  final tokens = <String>[];
  String? lastFirstName;
  String? lastDataUrl;
  String? lastCustomerId;

  Future<void> _enter(String call, String token) async {
    calls.add(call);
    tokens.add(token);
    final held = gate;
    if (held != null && (gatedCall == null || gatedCall == call)) {
      await held.future;
    }
    final error = failure;
    if (error != null) throw error;
  }

  @override
  Future<CustomerProfile> fetch(String accessToken) async {
    final answer = queued.isNotEmpty ? queued.removeAt(0) : profile;
    await _enter('fetch', accessToken);
    return answer;
  }

  @override
  Future<String?> updateFirstName(String accessToken, String firstName) async {
    await _enter('updateFirstName', accessToken);
    lastFirstName = firstName;
    return reportedDisplayName;
  }

  @override
  Future<void> setPhoto(
    String accessToken,
    String customerId,
    String dataUrl,
  ) async {
    await _enter('setPhoto', accessToken);
    lastCustomerId = customerId;
    lastDataUrl = dataUrl;
  }

  @override
  Future<void> removePhoto(String accessToken, String customerId) async {
    await _enter('removePhoto', accessToken);
    lastCustomerId = customerId;
  }
}

class _GatedCaa implements CustomerOrdersService {
  _GatedCaa(this.gate);

  final Completer<List<CustomerAccountOrder>> gate;
  bool blockNext = false;

  @override
  Future<List<CustomerAccountOrder>> fetchOrders(
    String accessToken, {
    int first = 25,
  }) async {
    if (blockNext) {
      blockNext = false;
      return gate.future;
    }
    return const [];
  }
}
