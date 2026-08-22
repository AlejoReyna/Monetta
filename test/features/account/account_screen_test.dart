import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/account_controller.dart';
import 'package:monetta_app/data/accounts_orders/accounts_orders_config.dart';
import 'package:monetta_app/data/accounts_orders/system_account_client.dart';
import 'package:monetta_app/data/accounts_orders/system_account_session_repository.dart';
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
import 'package:monetta_app/features/account/account_screen.dart';

class _Client implements SystemAccountClient {
  @override
  Future<SystemAccountRegistration> register({
    required String email,
    required String password,
    required String? displayName,
    required String deviceId,
  }) async {
    return SystemAccountRegistration(
      accountId: 'account-1',
      email: email,
      displayName: displayName,
      sessionToken: 'token',
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

class _SecureStore implements SecureTokenStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _ShopGateway implements CustomerAuthGateway {
  int loginCalls = 0;

  @override
  Future<CustomerAuthResult> login() async {
    loginCalls += 1;
    final payload = base64Url
        .encode(
          utf8.encode(
            jsonEncode({
              'sub': 'gid://shopify/Customer/1',
              'email': 'ana@example.com',
            }),
          ),
        )
        .replaceAll('=', '');
    return CustomerAuthResult(
      accessToken: 'access',
      refreshToken: 'refresh',
      idToken: 'header.$payload.signature',
      accessTokenExpiresAt: DateTime.utc(2027),
    );
  }

  @override
  Future<CustomerAuthResult> refresh(String refreshToken) => login();
}

void main() {
  testWidgets(
    'a shopper can create a Monetta account without Shopify',
    (tester) async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final deviceStore = DeviceStore(db);
      await deviceStore.upsert(
        deviceId: 'dev-1',
        platform: 'ios',
        appVersion: '1',
      );
      final controller = AccountController(
        systemSessionRepository: SystemAccountSessionRepository(
          client: _Client(),
          accountStore: AccountStore(db),
          sessionStore: SessionStore(db),
          deviceStore: deviceStore,
          wishlistStore: WishlistStore(db),
          bagStore: BagStore(db),
          secureStore: _SecureStore(),
          deviceId: 'dev-1',
        ),
        accountStore: AccountStore(db),
        deviceStore: deviceStore,
        orderHistoryRepository: OrderHistoryRepository(
          store: OrderSummaryStore(db),
          config: AccountsOrdersConfig.disabled,
        ),
        deviceId: 'dev-1',
      );

      await tester.pumpWidget(
        MaterialApp(home: AccountScreen(controller: controller)),
      );
      expect(find.text('Inicia sesión'), findsOneWidget);
      // No Shopify credentials in this build, so the Monetta form is the only
      // way in and is shown expanded rather than behind the toggle.
      expect(find.text('USAR MI CUENTA MONETTA'), findsNothing);
      expect(
        find.text('Entra con el correo y contraseña de tu cuenta Monetta.'),
        findsOneWidget,
      );
      expect(find.text('ENTRAR'), findsOneWidget);

      await tester.tap(find.text('REGISTRARME'));
      await tester.pumpAndSettle();
      expect(
        find.text('Regístrate con tu correo y una contraseña Monetta.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'Ana');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'ana@example.com',
      );
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'password123',
      );
      // The form runs past the bottom of the 800x600 test surface, and a tap
      // whose target is off-screen only warns — it does not fail.
      await tester.ensureVisible(find.text('CREAR CUENTA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CREAR CUENTA'));
      await tester.pumpAndSettle();

      expect(find.text('Sesión iniciada'), findsOneWidget);
      expect(find.text('ana@example.com'), findsOneWidget);
    },
  );

  testWidgets('Shop registration and direct Account entry use the hosted flow',
      (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final db = openTestDatabase();
    addTearDown(db.close);
    final deviceStore = DeviceStore(db);
    await deviceStore.upsert(
      deviceId: 'dev-1',
      platform: 'ios',
      appVersion: '1',
    );
    final gateway = _ShopGateway();
    final secureStore = _SecureStore();
    final controller = AccountController(
      sessionRepository: CustomerSessionRepository(
        authGateway: gateway,
        accountStore: AccountStore(db),
        sessionStore: SessionStore(db),
        deviceStore: deviceStore,
        wishlistStore: WishlistStore(db),
        bagStore: BagStore(db),
        secureStore: secureStore,
        deviceId: 'dev-1',
      ),
      accountStore: AccountStore(db),
      deviceStore: deviceStore,
      orderHistoryRepository: OrderHistoryRepository(
        store: OrderSummaryStore(db),
        config: AccountsOrdersConfig.disabled,
      ),
      config: const CustomerAccountConfig(
        shopDomain: 'shop.example.com',
        shopId: '1',
        clientId: 'client-id',
        redirectUri: 'shop.1.oauth://callback',
      ),
      deviceId: 'dev-1',
    );

    await tester.pumpWidget(
      MaterialApp(home: AccountScreen(controller: controller)),
    );

    final button = find.byKey(const ValueKey('shop-sign-in-button'));
    final registerButton = find.byKey(
      const ValueKey('shop-register-button'),
    );
    expect(button, findsOneWidget);
    expect(registerButton, findsOneWidget);
    expect(find.byIcon(Icons.person_outline_rounded), findsNothing);
    expect(find.text('Iniciar sesión con shop'), findsOneWidget);
    expect(
      tester.widget<Material>(button).color,
      const Color(0xFF5A31F4),
    );
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(registerButton);
    await tester.tap(registerButton);
    await tester.pumpAndSettle();

    expect(gateway.loginCalls, 1);
    expect(find.text('Sesión iniciada'), findsOneWidget);

    await controller.logout();
    await tester.pumpAndSettle();

    // Account navigation opts into this mode: presenting the route should
    // launch hosted auth without making the shopper tap a second button.
    await tester.pumpWidget(
      MaterialApp(
        home: AccountScreen(
          key: const ValueKey('direct-account-entry'),
          controller: controller,
          openHostedLoginOnStart: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(gateway.loginCalls, 2);
    expect(find.text('Sesión iniciada'), findsOneWidget);
    expect(find.text('ana@example.com'), findsOneWidget);

    var openedAdmin = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AccountScreen(
          controller: controller,
          canOpenAdmin: () => true,
          onOpenAdmin: () => openedAdmin = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final adminEntry = find.byKey(const ValueKey('open-owner-admin'));
    expect(adminEntry, findsOneWidget);
    expect(find.text('ADMINISTRAR MONETTA'), findsOneWidget);
    await tester.tap(adminEntry);
    expect(openedAdmin, isTrue);
  });
}
