import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/account_controller.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/main.dart';
import 'package:monetta_app/data/accounts_orders/accounts_orders_config.dart';
import 'package:monetta_app/data/local/account_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/order_summary_store.dart';
import 'package:monetta_app/data/repositories/order_history_repository.dart';
import 'package:monetta_app/features/orders/order_detail_screen.dart';
import 'package:monetta_app/features/orders/orders_screen.dart';
import 'package:monetta_app/features/rewards/rewards_section.dart';

import '../../support/client_guide_capture.dart';

void main() {
  for (final (size, scale, brightness) in [
    (const Size(390, 844), 1.0, Brightness.light),
    (const Size(320, 568), 2.0, Brightness.light),
    (const Size(834, 1194), 1.0, Brightness.light),
    (const Size(390, 844), 1.0, Brightness.dark),
  ]) {
    testWidgets(
        'order cards preserve detail access at $size / $scale / $brightness',
        (tester) async {
      final db = openTestDatabase();
      final controller = AccountController(
        accountStore: AccountStore(db),
        deviceStore: DeviceStore(db),
        orderHistoryRepository: OrderHistoryRepository(
          store: OrderSummaryStore(db),
          config: AccountsOrdersConfig.disabled,
        ),
        deviceId: 'fixture-device',
      )
        ..account = Account(
          localAccountId: 'fixture-account',
          authProvider: 'shopify',
          createdAt: DateTime.utc(2026),
          lastSeenAt: DateTime.utc(2026),
        )
        ..orders = [
          for (var i = 1; i <= 2; i++)
            OrderSummary(
              id: 'fixture-$i',
              accountId: 'fixture-account',
              displayNumber: '#DEMO-$i',
              source: 'shopify_checkout',
              status: 'paid',
              fulfillmentStatus: i == 1 ? 'fulfilled' : 'delivered',
              totalAmount: 1000 * i.toDouble(),
              currencyCode: 'MXN',
              placedAt: DateTime.utc(2026, 5, i),
            ),
        ]
        ..ordersStatus = OrderHistoryStatus.populated;
      addTearDown(() async {
        controller.dispose();
        await db.close();
      });
      final catalog = CatalogStore(database: db);
      addTearDown(catalog.dispose);
      await pumpClientGuide(
        tester,
        StoreScope(
          notifier: catalog,
          child: OrdersScreen(
            controller: controller,
            rewardsReader: FakeRewardsReader(),
          ),
        ),
        size: size,
        textScale: scale,
        brightness: brightness,
      );
      expect(find.text('Completos'), findsOneWidget);
      expect(
        find.text('Las imágenes de este pedido aún no están disponibles.'),
        findsNWidgets(2),
      );
      expect(tester.takeException(), isNull);
      if (scale == 1) {
        await captureClientGuide(
          tester,
          'orders-${size.width.toInt()}-${brightness.name}',
        );
      }
      final card = find.byKey(const ValueKey('order-card-fixture-1'));
      final action =
          find.descendant(of: card, matching: find.byType(OutlinedButton));
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.byType(OrderDetailScreen), findsOneWidget);
      expect(find.text('#DEMO-1'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
