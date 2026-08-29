import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/account_controller.dart';
import 'package:monetta_app/data/accounts_orders/accounts_orders_config.dart';
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
import 'package:monetta_app/features/account/account_screen.dart';

class _SecureStore implements SecureTokenStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _PendingShopGateway implements CustomerAuthGateway {
  final loginCompleter = Completer<CustomerAuthResult>();
  int loginCalls = 0;

  @override
  Future<CustomerAuthResult> login() {
    loginCalls += 1;
    return loginCompleter.future;
  }

  void succeed() => loginCompleter.complete(_authResult());

  void cancel() => loginCompleter.completeError(
        const CustomerAuthException(CustomerAuthErrorKind.cancelled),
      );

  @override
  Future<CustomerAuthResult> refresh(String refreshToken) async =>
      _authResult();
}

CustomerAuthResult _authResult() {
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

Future<AccountController> _buildController(
  AppDatabase db,
  CustomerAuthGateway gateway,
) async {
  final deviceStore = DeviceStore(db);
  await deviceStore.upsert(
    deviceId: 'dev-1',
    platform: 'ios',
    appVersion: '1',
  );
  return AccountController(
    sessionRepository: CustomerSessionRepository(
      authGateway: gateway,
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
    config: const CustomerAccountConfig(
      shopDomain: 'shop.example.com',
      shopId: '1',
      clientId: 'client-id',
      redirectUri: 'shop.1.oauth://callback',
    ),
    deviceId: 'dev-1',
  );
}

void main() {
  testWidgets(
    'Account opens hosted auth directly and never renders the hardcoded login',
    (tester) async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final gateway = _PendingShopGateway();
      final controller = await _buildController(db, gateway);
      var openedAdmin = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => unawaited(
                  openAccount(
                    context,
                    controller: controller,
                    canOpenAdmin: () => true,
                    onOpenAdmin: () => openedAdmin = true,
                  ),
                ),
                child: const Text('ACCOUNT'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('ACCOUNT'));
      await tester.pump();

      expect(gateway.loginCalls, 1);
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('Inicia sesión'), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byKey(const ValueKey('shop-sign-in-button')), findsNothing);
      expect(find.byKey(const ValueKey('shop-register-button')), findsNothing);

      gateway.succeed();
      await tester.pumpAndSettle();

      expect(find.text('Sesión iniciada'), findsOneWidget);
      expect(find.text('ana@example.com'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);

      final adminEntry = find.byKey(const ValueKey('open-owner-admin'));
      expect(adminEntry, findsOneWidget);
      await tester.tap(adminEntry);
      expect(openedAdmin, isTrue);

      await tester.tap(find.text('CERRAR SESIÓN'));
      await tester.pumpAndSettle();
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('Inicia sesión'), findsNothing);
    },
  );

  testWidgets('cancelling hosted auth keeps the shopper on the current page', (
    tester,
  ) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final gateway = _PendingShopGateway();
    final controller = await _buildController(db, gateway);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => unawaited(
                openAccount(context, controller: controller),
              ),
              child: const Text('ACCOUNT'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ACCOUNT'));
    await tester.pump();
    gateway.cancel();
    await tester.pumpAndSettle();

    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.text('Inicia sesión'), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });
}
