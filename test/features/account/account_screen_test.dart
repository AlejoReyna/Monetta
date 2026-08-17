import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/account_controller.dart';
import 'package:monetta_app/data/accounts_orders/accounts_orders_config.dart';
import 'package:monetta_app/data/accounts_orders/system_account_client.dart';
import 'package:monetta_app/data/accounts_orders/system_account_session_repository.dart';
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
      expect(find.text('Tu cuenta'), findsOneWidget);
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
}
