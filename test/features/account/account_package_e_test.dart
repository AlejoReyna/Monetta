import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/account_controller.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/accounts_orders/accounts_orders_config.dart';
import 'package:monetta_app/data/customer_auth/customer_auth_error.dart';
import 'package:monetta_app/data/local/account_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/order_summary_store.dart';
import 'package:monetta_app/data/repositories/order_history_repository.dart';
import 'package:monetta_app/features/account/account_screen.dart';
import 'package:monetta_app/features/contact/contact_screen.dart';
import 'package:monetta_app/features/favorites/favorites_screen.dart';
import 'package:monetta_app/features/notifications/notification_inbox.dart';
import 'package:monetta_app/features/notifications/notifications_screen.dart';
import 'package:monetta_app/features/orders/orders_screen.dart';
import 'package:monetta_app/features/rewards/rewards_section.dart';
import 'package:monetta_app/main.dart';

AccountController _controller(AppDatabase db) => AccountController(
      accountStore: AccountStore(db),
      deviceStore: DeviceStore(db),
      orderHistoryRepository: OrderHistoryRepository(
        store: OrderSummaryStore(db),
        config: AccountsOrdersConfig.disabled,
      ),
      deviceId: 'dev-1',
    );

Account _account() => Account(
      localAccountId: 'acct-1',
      shopifyCustomerId: 'gid://shopify/Customer/1',
      email: 'ana@example.com',
      displayName: 'Ana García',
      authProvider: 'shopify',
      createdAt: DateTime.utc(2026, 1, 1),
      lastSeenAt: DateTime.utc(2026, 1, 1),
    );

OrderSummary _order() => OrderSummary(
      id: 'gid://shopify/Order/1',
      accountId: 'acct-1',
      displayNumber: '#1001',
      fulfillmentStatus: 'fulfilled',
      shopifyOrderId: 'gid://shopify/Order/1',
      source: 'shopify_checkout',
      attributionCode: null,
      status: 'paid',
      totalAmount: 11480,
      currencyCode: 'MXN',
      placedAt: DateTime.utc(2026, 5, 12),
    );

Widget _host(
  AccountController controller, {
  CatalogStore? store,
  FakeRewardsReader? rewards,
  NotificationInbox? inbox,
}) {
  final catalog = store;
  final Widget child = AccountScreen(
    controller: controller,
    canOpenAdmin: () => false,
    rewardsReader: rewards,
    notificationInbox: inbox ?? NotificationInbox(),
  );
  // StoreScope va sobre el Navigator — igual que AppRouteScopes en
  // producción — para que las rutas empujadas (Favoritos) lo conserven.
  Widget app = MaterialApp(theme: buildTheme(), home: child);
  if (catalog != null) {
    app = StoreScope(notifier: catalog, child: app);
  }
  return app;
}

void main() {
  group('AccountScreen paquete E', () {
    testWidgets('identity shows verified provider, never points or levels',
        (tester) async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final controller = _controller(db)
        ..account = _account()
        ..ordersStatus = OrderHistoryStatus.empty;

      await tester.pumpWidget(_host(controller));
      await tester.pumpAndSettle();

      expect(find.text('Qué gusto verte,'), findsOneWidget);
      expect(find.text('Ana García'), findsOneWidget);
      final information =
          find.byKey(const ValueKey('account-open-information'));
      await tester.ensureVisible(information);
      await tester.tap(information);
      await tester.pumpAndSettle();
      expect(find.text('ana@example.com'), findsOneWidget);
      expect(find.text('Cuenta Shopify verificada'), findsOneWidget);
      expect(find.textContaining('puntos'), findsNothing);
      expect(find.textContaining('Nivel'), findsNothing);
      expect(find.textContaining('320'), findsNothing);
    });

    testWidgets('rewards unavailable is honest without backend', (
      tester,
    ) async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final controller = _controller(db)
        ..account = _account()
        ..ordersStatus = OrderHistoryStatus.empty;

      await tester.pumpWidget(_host(controller));
      await tester.pumpAndSettle();

      expect(
        find.text('Monetta Rewards aún no está disponible'),
        findsOneWidget,
      );
    });

    testWidgets('access rows navigate to the real E destinations',
        (tester) async {
      final db = openTestDatabase();
      final store = CatalogStore(database: db);
      addTearDown(() async {
        store.dispose();
        await db.close();
      });
      await store.loadFromAsset();
      final controller = _controller(db)
        ..account = _account()
        ..orders = [_order()]
        ..ordersStatus = OrderHistoryStatus.populated;

      await tester.pumpWidget(
        _host(controller, store: store, rewards: FakeRewardsReader()),
      );
      await tester.pumpAndSettle();

      Future<void> openAndClose(Finder row, Type screen) async {
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(find.byType(screen), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back).first);
        await tester.pumpAndSettle();
      }

      await openAndClose(
        find.byKey(const ValueKey('account-open-orders')),
        OrdersScreen,
      );
      await openAndClose(
        find.byKey(const ValueKey('account-open-favorites')),
        FavoritesScreen,
      );
      await openAndClose(
        find.byKey(const ValueKey('account-open-contact')),
        ContactScreen,
      );
      await openAndClose(
        find.byKey(const ValueKey('account-open-notifications')),
        NotificationsScreen,
      );
    });

    testWidgets('session expiry offers hosted re-login', (tester) async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final controller = _controller(db)
        ..account = _account()
        ..ordersStatus = OrderHistoryStatus.failed
        ..lastError = const AccountError(
          flow: AccountAuthFlow.shopify,
          kind: CustomerAuthErrorKind.sessionExpired,
        );

      await tester.pumpWidget(_host(controller));
      await tester.pumpAndSettle();

      expect(find.textContaining('Tu sesión terminó'), findsWidgets);
      // canLogin es falso sin repositorio de sesión: no hay login fantasma.
      expect(controller.canLogin, isFalse);
    });

    testWidgets('logout returns to the previous route', (tester) async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final controller = _controller(db)
        ..account = _account()
        ..ordersStatus = OrderHistoryStatus.empty;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => unawaited(
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AccountScreen(controller: controller),
                    ),
                  ),
                ),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      expect(find.text('Mi cuenta'), findsOneWidget);

      final logout = find.text('CERRAR SESIÓN');
      await tester.scrollUntilVisible(logout, 400);
      await tester.pumpAndSettle();
      await tester.tap(logout);
      await tester.pumpAndSettle();

      expect(find.text('Mi cuenta'), findsNothing);
      expect(find.text('OPEN'), findsOneWidget);
      expect(controller.isSignedIn, isFalse);
      expect(controller.orders, isEmpty);
    });

    testWidgets('invite row only exists when F wires it', (tester) async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final controller = _controller(db)
        ..account = _account()
        ..ordersStatus = OrderHistoryStatus.empty;

      await tester.pumpWidget(_host(controller));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('account-invite')), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: AccountScreen(
            controller: controller,
            onOpenInvite: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('account-invite')), findsOneWidget);
    });
  });
}
