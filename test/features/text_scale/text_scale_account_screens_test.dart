/// UI-03 (objective state): Cuenta, Pedidos (lista) and Pedido (detalle) mount
/// and scroll to their end without any `FlutterError` at 375x812 and 440x956,
/// with the text scale at 1.0, 1.3 and 1.5 under the E-T1 / D-12 policy and the
/// real Inter and Playfair Display faces. See `text_scale_matrix.dart`.
///
/// The account has a long name and e-mail, every optional entry (admin,
/// partner, invitation) is wired so its row renders, and the orders carry long
/// statuses and an apartado with an attribution code.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/account_controller.dart';
import 'package:monetta_app/data/accounts_orders/accounts_orders_config.dart';
import 'package:monetta_app/data/local/account_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/order_summary_store.dart';
import 'package:monetta_app/data/notifications/notification_models.dart';
import 'package:monetta_app/data/repositories/order_history_repository.dart';
import 'package:monetta_app/features/account/account_screen.dart';
import 'package:monetta_app/features/notifications/notification_inbox.dart';
import 'package:monetta_app/features/orders/order_detail_screen.dart';
import 'package:monetta_app/features/orders/orders_screen.dart';
import 'package:monetta_app/features/rewards/rewards_models.dart';
import 'package:monetta_app/features/rewards/rewards_section.dart';

import '../../support/text_scale_matrix.dart';

AccountController _controller() {
  final db = openTestDatabase();
  addTearDown(db.close);
  return AccountController(
    accountStore: AccountStore(db),
    deviceStore: DeviceStore(db),
    orderHistoryRepository: OrderHistoryRepository(
      store: OrderSummaryStore(db),
      config: AccountsOrdersConfig.disabled,
    ),
    deviceId: 'dev-1',
  );
}

Account _longAccount() => Account(
      localAccountId: 'acct-1',
      shopifyCustomerId: 'gid://shopify/Customer/1',
      email: 'ana.garcia.con.un.nombre.muy.largo.para.probar@example.com',
      displayName: 'Ana María García Hernández de los Santos Torres',
      authProvider: 'shopify',
      createdAt: DateTime.utc(2026, 1, 1),
      lastSeenAt: DateTime.utc(2026, 1, 1),
    );

OrderSummary _order({
  String id = 'gid://shopify/Order/1',
  String? displayNumber = '#1001',
  String? fulfillmentStatus = 'fulfilled',
  String? shopifyOrderId = 'gid://shopify/Order/1',
  String source = 'shopify_checkout',
  String? attributionCode,
  String status = 'paid',
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
      totalAmount: total,
      currencyCode: 'MXN',
      placedAt: DateTime.utc(2026, 5, 12),
    );

OrderSummary _apartado() => _order(
      id: 'apartado:9',
      displayNumber: null,
      fulfillmentStatus: null,
      shopifyOrderId: null,
      source: 'whatsapp_apartado',
      attributionCode: 'MN-7K3Q',
      status: 'pending',
      total: 400,
    );

FakeRewardsReader _rewards() => FakeRewardsReader(
      summary: RewardsSummary(
        redemptionEnabled: true,
        availableCents: 18400,
        pendingCents: 5400,
        reservedCents: 0,
        nextExpiry: RewardsExpiry(cents: 2000, at: DateTime.utc(2027, 9, 10)),
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

NotificationInbox _inbox() => NotificationInbox()
  ..ingest(
    MonettaNotification(
      id: 'n1',
      title: 'Tu pedido va en camino con un título largo para probar',
      body: 'El pedido #1001 fue enviado y este cuerpo largo debe envolverse '
          'en varias líneas sin romper la tarjeta ni desbordar.',
      route: const NotificationRouteData(type: 'home'),
      receivedAt: DateTime.utc(2026, 9, 10),
      ownerId: 'acct-1',
      kind: MonettaNotificationKind.order,
    ),
  );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useBundledFonts();

  registerTextScaleMatrix(
    'Cuenta',
    (tester, store) async {
      final controller = _controller()
        ..account = _longAccount()
        ..orders = [_order()]
        ..ordersStatus = OrderHistoryStatus.populated;
      return AccountScreen(
        controller: controller,
        rewardsReader: _rewards(),
        notificationInbox: _inbox(),
        canOpenAdmin: () => true,
        onOpenAdmin: () {},
        onOpenPartner: () {},
        onOpenInvite: () {},
      );
    },
    anchor: (store) => find.text('Mi cuenta'),
  );

  registerTextScaleMatrix(
    'Pedidos lista',
    (tester, store) async {
      final controller = _controller()
        ..account = _longAccount()
        ..orders = [
          _order(),
          _order(
            id: 'gid://shopify/Order/2',
            displayNumber: '#1000',
            fulfillmentStatus: 'delivered',
            shopifyOrderId: 'gid://shopify/Order/2',
            total: 6490,
          ),
          _apartado(),
        ]
        ..ordersStatus = OrderHistoryStatus.populated;
      return OrdersScreen(controller: controller, rewardsReader: _rewards());
    },
    anchor: (store) => find.text('#1001'),
  );

  registerTextScaleMatrix(
    'Pedido detalle',
    (tester, store) async =>
        OrderDetailScreen(order: _order(), rewardsReader: _rewards()),
    anchor: (store) => find.text('#1001'),
  );

  registerTextScaleMatrix(
    'Pedido detalle apartado',
    (tester, store) async =>
        OrderDetailScreen(order: _apartado(), rewardsReader: _rewards()),
    anchor: (store) => find.text('MN-7K3Q'),
  );
}
