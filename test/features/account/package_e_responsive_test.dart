import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/account_controller.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/accounts_orders/accounts_orders_config.dart';
import 'package:monetta_app/data/local/account_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/order_summary_store.dart';
import 'package:monetta_app/data/notifications/notification_models.dart';
import 'package:monetta_app/data/repositories/order_history_repository.dart';
import 'package:monetta_app/features/account/account_screen.dart';
import 'package:monetta_app/features/contact/contact_screen.dart';
import 'package:monetta_app/features/favorites/favorites_screen.dart';
import 'package:monetta_app/features/notifications/notification_inbox.dart';
import 'package:monetta_app/features/notifications/notifications_screen.dart';
import 'package:monetta_app/features/orders/order_detail_screen.dart';
import 'package:monetta_app/features/orders/orders_screen.dart';
import 'package:monetta_app/features/rewards/rewards_models.dart';
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

Account _longAccount() => Account(
      localAccountId: 'acct-1',
      shopifyCustomerId: 'gid://shopify/Customer/1',
      email: 'ana.garcia.con.un.nombre.muy.largo.para.probar@example.com',
      displayName: 'Ana María García Hernández de los Santos Torres',
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

FakeRewardsReader _rewards() => FakeRewardsReader(
      summary: RewardsSummary(
        redemptionEnabled: true,
        availableCents: 18400,
        pendingCents: 5400,
        reservedCents: 0,
        nextExpiry: RewardsExpiry(
          cents: 2000,
          at: DateTime.utc(2027, 9, 10),
        ),
        asOf: DateTime.utc(2026, 9, 14),
        firstPurchaseEnabled: false,
        reviewEnabled: false,
        referralEnabled: false,
      ),
      activity: [
        RewardsMovement(
          id: 1,
          type: 'earn_released',
          state: 'available',
          amountCents: 5400,
          orderShopifyId: 'gid://shopify/Order/1',
          reason: 'Se liberó al entregar tu pedido #1001 con un mensaje largo '
              'para comprobar que el renglón envuelve sin desbordar.',
          createdAt: DateTime.utc(2026, 9, 10),
        ),
      ],
    );

Future<void> _check(
  WidgetTester tester,
  String name,
  Widget screen, {
  CatalogStore? store,
}) async {
  Widget app = MaterialApp(theme: buildTheme(), home: screen);
  if (store != null) {
    app = StoreScope(notifier: store, child: app);
  }
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  // Desplazar todo el contenido: ningún desborde en ningún tramo.
  final scrollable = find.byType(Scrollable).first;
  for (var i = 0; i < 6; i++) {
    await tester.drag(scrollable, const Offset(0, -400));
    await tester.pumpAndSettle();
  }
  final error = tester.takeException();
  debugPrint('RESPONSIVE-$name: $error');
  expect(error, isNull, reason: 'desborde en $name');
}

void main() {
  group('Paquete E en teléfono estrecho con texto ampliado', () {
    testWidgets('cuenta, pedidos, detalle, contacto y notificaciones',
        (tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      tester.view.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(
        () => tester.view.platformDispatcher.clearTextScaleFactorTestValue(),
      );

      final db = openTestDatabase();
      final store = CatalogStore(database: db);
      addTearDown(() async {
        store.dispose();
        await db.close();
      });
      await store.loadFromAsset();
      final controller = _controller(db)
        ..account = _longAccount()
        ..orders = [_order()]
        ..ordersStatus = OrderHistoryStatus.populated;
      final inbox = NotificationInbox()
        ..ingest(
          MonettaNotification(
            id: 'n1',
            title: 'Tu pedido va en camino con un título largo para probar',
            body: 'El pedido #1001 fue enviado y este cuerpo largo debe '
                'envolverse en varias líneas sin romper la tarjeta ni '
                'desbordar en un teléfono estrecho con texto ampliado.',
            route: const NotificationRouteData(type: 'home'),
            receivedAt: DateTime.now().toUtc(),
            ownerId: 'acct-1',
            kind: MonettaNotificationKind.order,
          ),
        );

      await _check(
        tester,
        'cuenta',
        AccountScreen(
          controller: controller,
          rewardsReader: _rewards(),
          notificationInbox: inbox,
        ),
        store: store,
      );
      await _check(
        tester,
        'pedidos',
        OrdersScreen(controller: controller, rewardsReader: _rewards()),
      );
      await _check(
        tester,
        'detalle',
        OrderDetailScreen(order: _order(), rewardsReader: _rewards()),
      );
      await _check(tester, 'contacto', const ContactScreen(openUri: null));
      await _check(
        tester,
        'notificaciones',
        NotificationsScreen(
          inbox: inbox,
          ownerId: 'acct-1',
          rewardsReader: _rewards(),
        ),
      );
      await _check(tester, 'favoritos', const FavoritesScreen(), store: store);
    });
  });
}
