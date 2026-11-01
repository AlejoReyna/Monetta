import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/account_controller.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/accounts_orders/accounts_orders_config.dart';
import 'package:monetta_app/data/local/account_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/order_summary_store.dart';
import 'package:monetta_app/data/repositories/order_history_repository.dart';
import 'package:monetta_app/features/orders/orders_screen.dart';
import 'package:monetta_app/features/rewards/rewards_section.dart';

import '../../support/client_guide_capture.dart';

OrderSummary _order(String id, String number, String fulfillment) =>
    OrderSummary(
      id: id,
      accountId: 'acct-1',
      displayNumber: number,
      fulfillmentStatus: fulfillment,
      shopifyOrderId: id,
      source: 'shopify_checkout',
      status: 'paid',
      totalAmount: 11480,
      currencyCode: 'MXN',
      placedAt: DateTime.utc(2026, 5, 12),
    );

AccountController _controller(AppDatabase db) => AccountController(
      accountStore: AccountStore(db),
      deviceStore: DeviceStore(db),
      orderHistoryRepository: OrderHistoryRepository(
        store: OrderSummaryStore(db),
        config: AccountsOrdersConfig.disabled,
      ),
      deviceId: 'dev-1',
    )
      ..account = Account(
        localAccountId: 'acct-1',
        shopifyCustomerId: 'gid://shopify/Customer/1',
        email: 'ana@example.com',
        displayName: 'Ana',
        authProvider: 'shopify',
        createdAt: DateTime.utc(2026),
        lastSeenAt: DateTime.utc(2026),
      )
      ..ordersStatus = OrderHistoryStatus.populated;

void main() {
  testWidgets(
      'ORD-GUIDE three tabs always visible, no Rewards card, no refresh link, '
      'thumbnails placeholder, total and «Ver detalles»', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = openTestDatabase();
    addTearDown(db.close);
    // One order, in transit: «Completos» has nothing behind it and still shows.
    final controller = _controller(db)
      ..orders = [_order('gid://shopify/Order/1', '#MNT1', 'fulfilled')];
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: OrdersScreen(
          controller: controller,
          rewardsReader: FakeRewardsReader(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final key in ['all', 'inTransit', 'delivered']) {
      expect(find.byKey(ValueKey('orders-filter-$key')), findsOneWidget);
    }
    expect(find.text('Todos'), findsOneWidget);
    expect(find.text('Completos'), findsOneWidget);
    // Left to right, in the guide's order.
    final xs = [
      for (final key in ['all', 'inTransit', 'delivered'])
        tester.getTopLeft(find.byKey(ValueKey('orders-filter-$key'))).dx,
    ];
    expect(xs, orderedEquals([...xs]..sort()));

    expect(find.byKey(const ValueKey('rewards-section')), findsNothing);
    expect(find.text('Actualizar pedidos'), findsNothing);
    expect(find.byKey(const ValueKey('refresh-orders')), findsNothing);

    // The card: number, date, capsule with chevron, thumbnails, total, action.
    expect(find.text('#MNT1'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets);
    expect(
      find.byKey(
        const ValueKey(
          'order-thumbs-placeholder-gid://shopify/Order/1',
        ),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Total: '), findsOneWidget);
    expect(find.textContaining('MXN'), findsWidgets);
    expect(find.text('Ver detalles'), findsOneWidget);
  });

  testWidgets('ORD-GUIDE selecting «Completos» filters the list',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = openTestDatabase();
    addTearDown(db.close);
    final controller = _controller(db)
      ..orders = [
        _order('gid://shopify/Order/1', '#MNT1', 'fulfilled'),
        _order('gid://shopify/Order/2', '#MNT2', 'delivered'),
      ];
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: OrdersScreen(
          controller: controller,
          rewardsReader: FakeRewardsReader(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('#MNT1'), findsOneWidget);
    expect(find.text('#MNT2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('orders-filter-delivered')));
    await tester.pumpAndSettle();
    expect(find.text('#MNT1'), findsNothing);
    expect(find.text('#MNT2'), findsOneWidget);
  });

  for (final (scale, sameRow) in [(1.0, true), (2.0, false)]) {
    testWidgets(
        'ORD-GUIDE total and «Ver detalles» share a row at 390 px, scale '
        '$scale; larger text flows the button down', (tester) async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final controller = _controller(db)
        ..orders = [_order('gid://shopify/Order/1', '#MNT1', 'fulfilled')];
      addTearDown(controller.dispose);
      await pumpClientGuide(
        tester,
        OrdersScreen(
          controller: controller,
          rewardsReader: FakeRewardsReader(),
        ),
        textScale: scale,
      );
      final total = tester.getCenter(find.textContaining('Total: ')).dy;
      final button = tester.getCenter(find.text('Ver detalles')).dy;
      if (sameRow) {
        expect((total - button).abs(), lessThan(8));
      } else {
        expect(button, greaterThan(total));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
