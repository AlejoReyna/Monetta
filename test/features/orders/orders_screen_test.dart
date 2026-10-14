import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/account_controller.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/accounts_orders/accounts_orders_config.dart';
import 'package:monetta_app/data/customer_auth/customer_auth_error.dart';
import 'package:monetta_app/data/local/account_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/order_summary_store.dart';
import 'package:monetta_app/data/repositories/order_history_repository.dart';
import 'package:monetta_app/features/orders/order_detail_screen.dart';
import 'package:monetta_app/features/orders/orders_screen.dart';
import 'package:monetta_app/features/rewards/rewards_models.dart';
import 'package:monetta_app/features/rewards/rewards_section.dart';

OrderSummary _order({
  String id = 'gid://shopify/Order/1',
  String? displayNumber = '#1001',
  String? fulfillmentStatus,
  String? shopifyOrderId = 'gid://shopify/Order/1',
  String source = 'shopify_checkout',
  String? attributionCode,
  String status = 'paid',
  String? paymentMethod,
  double total = 11480,
}) =>
    OrderSummary(
      id: id,
      accountId: 'acct-1',
      displayNumber: displayNumber,
      fulfillmentStatus: fulfillmentStatus,
      shopifyOrderId: shopifyOrderId,
      source: source,
      attributionCode: attributionCode,
      status: status,
      paymentMethod: paymentMethod,
      totalAmount: total,
      currencyCode: 'MXN',
      placedAt: DateTime.utc(2026, 5, 12),
    );

Account _account() => Account(
      localAccountId: 'acct-1',
      shopifyCustomerId: 'gid://shopify/Customer/1',
      email: 'ana@example.com',
      displayName: 'Ana',
      authProvider: 'shopify',
      createdAt: DateTime.utc(2026, 1, 1),
      lastSeenAt: DateTime.utc(2026, 1, 1),
    );

AccountController _controller(AppDatabase db) => AccountController(
      accountStore: AccountStore(db),
      deviceStore: DeviceStore(db),
      orderHistoryRepository: OrderHistoryRepository(
        store: OrderSummaryStore(db),
        config: AccountsOrdersConfig.disabled,
      ),
      deviceId: 'dev-1',
    );

FakeRewardsReader _rewards() => FakeRewardsReader(
      perOrder: {
        'gid://shopify/Order/1': const OrderRewardsState(
          orderShopifyId: 'gid://shopify/Order/1',
          isWholesale: false,
          earnedPendingCents: 5400,
          earnedReleasedCents: 0,
          usedCents: 0,
          state: 'pending',
        ),
      },
    );

Widget _host(AccountController controller, {FakeRewardsReader? rewards}) =>
    MaterialApp(
      theme: buildTheme(),
      home: OrdersScreen(
        controller: controller,
        rewardsReader: rewards ?? _rewards(),
      ),
    );

void main() {
  group('OrdersScreen', () {
    testWidgets('lists real orders with summary, status and detail entry',
        (tester) async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final controller = _controller(db)
        ..account = _account()
        ..orders = [
          _order(fulfillmentStatus: 'fulfilled'),
          _order(
            id: 'gid://shopify/Order/2',
            displayNumber: '#1000',
            fulfillmentStatus: 'delivered',
            shopifyOrderId: 'gid://shopify/Order/2',
          ),
        ]
        ..ordersStatus = OrderHistoryStatus.populated;

      await tester.pumpWidget(_host(controller));
      await tester.pumpAndSettle();

      expect(find.text('#1001'), findsOneWidget);
      expect(find.text('#1000'), findsOneWidget);
      expect(find.text('En camino'), findsWidgets);
      expect(find.text('Entregado'), findsWidgets);
      // Resumen honesto de la lista visible.
      expect(find.textContaining('2 pedidos'), findsOneWidget);
      expect(find.byKey(const ValueKey('refresh-orders')), findsOneWidget);
    });

    testWidgets('filters narrow to verified subsets', (tester) async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final controller = _controller(db)
        ..account = _account()
        ..orders = [
          _order(fulfillmentStatus: 'fulfilled'),
          _order(
            id: 'gid://shopify/Order/2',
            displayNumber: '#1000',
            fulfillmentStatus: 'delivered',
            shopifyOrderId: 'gid://shopify/Order/2',
          ),
          _order(
            id: 'apartado:9',
            displayNumber: null,
            fulfillmentStatus: null,
            shopifyOrderId: null,
            source: 'whatsapp_apartado',
            attributionCode: 'MN-7K3Q',
            status: 'pending',
          ),
        ]
        ..ordersStatus = OrderHistoryStatus.populated;

      await tester.pumpWidget(_host(controller));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('orders-filter-delivered')));
      await tester.pumpAndSettle();
      expect(find.text('#1000'), findsOneWidget);
      expect(find.text('#1001'), findsNothing);
      expect(find.text('MN-7K3Q'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('orders-filter-apartado')));
      await tester.pumpAndSettle();
      expect(find.text('MN-7K3Q'), findsOneWidget);
      expect(find.text('#1000'), findsNothing);
    });

    testWidgets('tapping a card opens its own detail, not the first order',
        (tester) async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final controller = _controller(db)
        ..account = _account()
        ..orders = [
          _order(),
          _order(
            id: 'gid://shopify/Order/2',
            displayNumber: '#1000',
            fulfillmentStatus: 'delivered',
            shopifyOrderId: 'gid://shopify/Order/2',
          ),
        ]
        ..ordersStatus = OrderHistoryStatus.populated;

      await tester.pumpWidget(_host(controller));
      await tester.pumpAndSettle();

      final target = find.byKey(
        const ValueKey('order-card-gid://shopify/Order/2'),
      );
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();

      // El detalle correlacionado: la identidad del segundo pedido.
      expect(find.byType(OrderDetailScreen), findsOneWidget);
      expect(find.text('Entregado'), findsWidgets);
      expect(
        find.text('El transportista confirmó la entrega de tu pedido.'),
        findsOneWidget,
      );
    });

    testWidgets('cards label payment from financial_status, never a catch-all',
        (tester) async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final controller = _controller(db)
        ..account = _account()
        ..orders = [
          _order(
            id: 'gid://shopify/Order/paid',
            displayNumber: '#1001',
            shopifyOrderId: 'gid://shopify/Order/paid',
            status: 'paid',
          ),
          _order(
            id: 'gid://shopify/Order/pending',
            displayNumber: '#1002',
            shopifyOrderId: 'gid://shopify/Order/pending',
            status: 'pending',
            paymentMethod: 'manual',
          ),
          _order(
            id: 'gid://shopify/Order/unknown',
            displayNumber: '#1003',
            shopifyOrderId: 'gid://shopify/Order/unknown',
            status: 'unknown',
          ),
          _order(
            id: 'gid://shopify/Order/refunded',
            displayNumber: '#1004',
            shopifyOrderId: 'gid://shopify/Order/refunded',
            fulfillmentStatus: 'shipped',
            status: 'refunded',
          ),
        ]
        ..ordersStatus = OrderHistoryStatus.populated;

      await tester.pumpWidget(_host(controller));
      await tester.pumpAndSettle();

      expect(find.text('Confirmado'), findsOneWidget);
      expect(find.text('Esperando tu transferencia'), findsOneWidget);
      expect(find.text('Pago en proceso'), findsOneWidget);
      expect(find.text('Reembolsado'), findsOneWidget);
      expect(find.text('Ver pedido'), findsOneWidget);
      expect(find.text('En camino'), findsNothing);
      expect(find.text('Con ajuste'), findsNothing);
      expect(
        find.byKey(const ValueKey('order-card-gid://shopify/Order/pending')),
        findsOneWidget,
      );
    });

    testWidgets('empty history does not read as an error', (tester) async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final controller = _controller(db)
        ..account = _account()
        ..orders = const []
        ..ordersStatus = OrderHistoryStatus.empty;

      await tester.pumpWidget(_host(controller));
      await tester.pumpAndSettle();

      expect(find.text('Aún no tienes pedidos'), findsOneWidget);
      expect(find.textContaining('No pudimos'), findsNothing);
    });

    testWidgets('failed load offers retry and stale cache says so',
        (tester) async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final controller = _controller(db)
        ..account = _account()
        ..orders = const []
        ..ordersStatus = OrderHistoryStatus.failed;

      await tester.pumpWidget(_host(controller));
      await tester.pumpAndSettle();
      expect(
        find.text('No pudimos cargar tus pedidos. Intenta actualizar.'),
        findsOneWidget,
      );

      controller.orders = [_order()];
      controller.ordersStatus = OrderHistoryStatus.staleCache;
      controller.notifyListeners();
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Mostrando pedidos guardados. No pudimos actualizar ahora.',
        ),
        findsOneWidget,
      );
      expect(find.text('#1001'), findsOneWidget);
    });

    testWidgets('session expiry explains itself with a real action',
        (tester) async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final controller = _controller(db)
        ..account = _account()
        ..orders = [_order()]
        ..ordersStatus = OrderHistoryStatus.staleCache
        ..lastError = const AccountError(
          flow: AccountAuthFlow.shopify,
          kind: CustomerAuthErrorKind.sessionExpired,
        );

      await tester.pumpWidget(_host(controller));
      await tester.pumpAndSettle();
      expect(find.textContaining('Tu sesión terminó'), findsOneWidget);
    });

    testWidgets('rewards failure never hides the orders', (tester) async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final controller = _controller(db)
        ..account = _account()
        ..orders = [_order()]
        ..ordersStatus = OrderHistoryStatus.populated;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: OrdersScreen(controller: controller, rewardsReader: null),
        ),
      );
      await tester.pumpAndSettle();

      // Sin backend: estado honesto de Rewards, pedidos intactos.
      expect(
        find.text('Monetta Rewards aún no está disponible'),
        findsOneWidget,
      );
      expect(find.text('#1001'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('order-rewards-status')),
        findsNothing,
      );
    });
  });
}
