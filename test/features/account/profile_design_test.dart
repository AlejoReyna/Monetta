import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' show Value;
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
import 'package:monetta_app/features/notifications/notification_inbox.dart';
import 'package:monetta_app/features/orders/order_detail_screen.dart';
import 'package:monetta_app/features/rewards/rewards_models.dart';
import 'package:monetta_app/features/rewards/rewards_section.dart';
import 'package:monetta_app/main.dart';

import '../../support/bundled_fonts.dart';

const _captureKey = ValueKey('profile-capture');

OrderSummary _order(String id, DateTime date, String fulfillment) =>
    OrderSummary(
      id: 'gid://shopify/Order/$id',
      accountId: 'profile-account',
      displayNumber: '#$id',
      fulfillmentStatus: fulfillment,
      shopifyOrderId: 'gid://shopify/Order/$id',
      source: 'shopify_checkout',
      status: 'paid',
      totalAmount: 2500,
      currencyCode: 'MXN',
      placedAt: date,
    );

void main() {
  setUpAll(() async {
    await loadBundledFonts();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  late AppDatabase db;
  late AccountController controller;
  late CatalogStore store;

  setUp(() {
    db = openTestDatabase();
    store = CatalogStore(database: db);
    controller = AccountController(
      accountStore: AccountStore(db),
      deviceStore: DeviceStore(db),
      orderHistoryRepository: OrderHistoryRepository(
        store: OrderSummaryStore(db),
        config: AccountsOrdersConfig.disabled,
      ),
      deviceId: 'profile-device',
    )
      ..account = Account(
        localAccountId: 'profile-account',
        shopifyCustomerId: 'gid://shopify/Customer/10',
        email: 'ana@example.com',
        displayName: 'Ana Fernández',
        authProvider: 'shopify',
        createdAt: DateTime.utc(2026),
        lastSeenAt: DateTime.utc(2026),
      )
      ..ordersStatus = OrderHistoryStatus.populated
      ..orders = [
        _order('1001', DateTime.utc(2026, 9, 1), 'delivered'),
        _order('1048', DateTime.utc(2026, 10, 10), 'fulfilled'),
      ];
  });

  tearDown(() async {
    controller.dispose();
    store.dispose();
    await db.close();
  });

  Future<void> mount(
    WidgetTester tester, {
    RewardsReader? reader,
    NotificationInbox? inbox,
    bool dark = false,
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: _captureKey,
        child: StoreScope(
          notifier: store,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildTheme(),
            darkTheme: buildTheme(brightness: Brightness.dark),
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: AccountScreen(
              controller: controller,
              rewardsReader: reader,
              notificationInbox: inbox,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('latest purchase opens its own detail even with unsorted history',
      (tester) async {
    await mount(tester, reader: FakeRewardsReader());
    expect(find.text('02'), findsOneWidget);
    expect(find.text('1 en camino'), findsOneWidget);
    expect(find.text('#1048'), findsOneWidget);
    expect(find.text('#1001'), findsNothing);
    final action = find.byKey(const ValueKey('profile-open-latest-order'));
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(
      tester.widget<OrderDetailScreen>(find.byType(OrderDetailScreen)).order.id,
      'gid://shopify/Order/1048',
    );
  });

  testWidgets('favorite count updates from the account wishlist',
      (tester) async {
    await tester.runAsync(store.loadFromAsset);
    await mount(tester);
    final card = find.byKey(const ValueKey('account-open-favorites'));
    expect(
      find.descendant(of: card, matching: find.text('00')),
      findsOneWidget,
    );
    await tester
        .runAsync(() => store.toggleWishlist('gid://shopify/Product/10'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: card, matching: find.text('01')),
      findsOneWidget,
    );
    await tester
        .runAsync(() => store.toggleWishlist('gid://shopify/Product/10'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: card, matching: find.text('00')),
      findsOneWidget,
    );
  });

  testWidgets('email fallback is hidden and a personal name persists',
      (tester) async {
    controller.account = controller.account!.copyWith(
      displayName: const Value('ana@example.com'),
    );
    await tester.runAsync(() async {
      await db.into(db.accounts).insert(controller.account!);
    });
    await mount(tester);
    expect(find.text('ana@example.com'), findsNothing);
    final information = find.byKey(const ValueKey('account-open-information'));
    await tester.ensureVisible(information);
    await tester.tap(information);
    await tester.pumpAndSettle();
    expect(find.text('ana@example.com'), findsOneWidget);
    final field = find.byKey(const ValueKey('profile-name-field'));
    await tester.enterText(field, 'Ana Fernández');
    final save = find.byKey(const ValueKey('profile-save-name'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Ana Fernández'), findsOneWidget);
    final stored = await tester.runAsync(
      () => AccountStore(db).byLocalId('profile-account'),
    );
    expect(stored?.displayName, 'Ana Fernández');
    expect(stored?.email, 'ana@example.com');
  });

  testWidgets('wallet reads exact cents and opens real rewards activity',
      (tester) async {
    await mount(
      tester,
      reader: FakeRewardsReader(
        summary: RewardsSummary(
          redemptionEnabled: false,
          availableCents: 12345,
          pendingCents: 5425,
          reservedCents: 0,
          nextExpiry: null,
          asOf: DateTime.utc(2026, 10, 13),
          firstPurchaseEnabled: false,
          reviewEnabled: false,
          referralEnabled: false,
        ),
      ),
    );
    expect(find.text('\$123.45'), findsOneWidget);
    expect(find.text('El canje aún no está habilitado'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('profile-rewards-card')));
    await tester.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('rewards-movements-toggle'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('Aún no hay movimientos en tu cuenta.'), findsOneWidget);
  });

  testWidgets('name editor rejects email and remains usable with large text',
      (tester) async {
    await tester.runAsync(() async {
      await db.into(db.accounts).insert(controller.account!);
    });
    await mount(tester, scale: 2);
    final information = find.byKey(const ValueKey('account-open-information'));
    await tester.ensureVisible(information);
    await tester.tap(information);
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('profile-name-field'));
    await tester.enterText(field, 'ana@example.com');
    final save = find.byKey(const ValueKey('profile-save-name'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Escribe tu nombre, no tu correo.'), findsOneWidget);
    expect(controller.account?.displayName, 'Ana Fernández');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'unknown order history and unavailable saldo never look like zero',
      (tester) async {
    controller.orders = [];
    controller.ordersStatus = OrderHistoryStatus.failed;
    await mount(tester);
    final orders = find.byKey(const ValueKey('account-open-orders'));
    expect(
      find.descendant(of: orders, matching: find.text('—')),
      findsOneWidget,
    );
    expect(find.text('Monetta Rewards aún no está disponible'), findsOneWidget);
    expect(find.text('\$0.00'), findsNothing);
    expect(
      find.textContaining('No pudimos cargar tus pedidos'),
      findsOneWidget,
    );
  });

  testWidgets('notification badge responds only to the active account',
      (tester) async {
    final inbox = NotificationInbox();
    addTearDown(inbox.dispose);
    await mount(tester, inbox: inbox);
    void ingest(String id, String owner) => inbox.ingest(
          MonettaNotification(
            id: id,
            title: 'Tu pedido',
            body: 'Está en camino',
            route: const NotificationRouteData(type: 'order'),
            receivedAt: DateTime.utc(2026, 10, 13),
            ownerId: owner,
          ),
        );
    ingest('other', 'other-account');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Notificaciones'), findsOneWidget);
    ingest('own', 'profile-account');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Notificaciones, 1 sin leer'), findsOneWidget);
    inbox.markAllRead('profile-account');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Notificaciones'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets(
        'profile renders and scrolls in ${dark ? 'dark' : 'light'} theme',
        (tester) async {
      await mount(tester, reader: FakeRewardsReader(), dark: dark);
      if (Platform.environment['CAPTURE_PROFILE'] == '1') {
        Future<void> capture(String name) async {
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(_captureKey),
            );
            final image = await boundary.toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            image.dispose();
            await File('/tmp/monetta-profile-$name.png')
                .writeAsBytes(data!.buffer.asUint8List());
          });
        }

        await capture(dark ? 'dark' : 'light');
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -430));
        await tester.pumpAndSettle();
        await capture(dark ? 'dark-scroll' : 'light-scroll');
      }
      await tester.ensureVisible(find.byKey(const ValueKey('account-logout')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('floating navigation remains usable with large text',
      (tester) async {
    await mount(tester, reader: FakeRewardsReader(), scale: 2);
    await tester.ensureVisible(find.byKey(const ValueKey('account-logout')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('bottom-nav-account')), findsOneWidget);
  });
}
