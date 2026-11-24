import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/app/account_controller.dart';
import 'package:monetta_app/app/notification_controller.dart';
import 'package:monetta_app/data/accounts_orders/accounts_orders_config.dart';
import 'package:monetta_app/data/local/account_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/order_summary_store.dart';
import 'package:monetta_app/data/repositories/order_history_repository.dart';
import 'package:monetta_app/main.dart' show NotificationScope;
import 'package:monetta_app/data/notifications/notification_models.dart';
import 'package:monetta_app/features/notifications/notification_inbox.dart';
import 'package:monetta_app/features/notifications/notifications_screen.dart';
import 'package:monetta_app/features/rewards/rewards_section.dart';

MonettaNotification _item({
  String id = 'n1',
  String ownerId = 'acct-1',
  String type = 'home',
  String? productKey,
}) =>
    MonettaNotification(
      id: id,
      title: 'Tu pedido va en camino',
      body: 'El pedido #1001 fue enviado.',
      route: NotificationRouteData(
        type: type,
        productKey: productKey,
      ),
      receivedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
      ownerId: ownerId,
      kind: MonettaNotificationKind.order,
    );

Widget _host({
  required NotificationInbox inbox,
  String ownerId = 'acct-1',
  void Function(NotificationRouteData route)? onOpenRoute,
  FakeRewardsReader? rewards,
}) =>
    MaterialApp(
      theme: buildTheme(),
      home: NotificationsScreen(
        inbox: inbox,
        ownerId: ownerId,
        onOpenRoute: onOpenRoute,
        rewardsReader: rewards,
      ),
    );

class _ScopedNotifications extends ChangeNotifier
    implements NotificationController {
  @override
  bool get available => true;
  @override
  NotificationPermissionState get permission =>
      NotificationPermissionState.granted;
  @override
  NotificationPreferences get preferences => const NotificationPreferences();
  @override
  bool get saving => false;
  @override
  String? get lastError => null;
  NotificationRouteData? opened;
  @override
  void Function(NotificationRouteData) get onOpenRoute =>
      (route) => opened = route;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('NotificationsScreen', () {
    testWidgets('opening from a route uses shared push state and preferences',
        (tester) async {
      final controller = _ScopedNotifications();
      final inbox = NotificationInbox()..ingest(_item());
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        builder: (context, child) =>
            NotificationScope(notifier: controller, child: child!),
        home: Builder(
            builder: (context) => Scaffold(
                    body: TextButton(
                  onPressed: () => openNotifications(context,
                      inbox: inbox, ownerId: 'acct-1'),
                  child: const Text('Abrir avisos'),
                ))),
      ));
      await tester.tap(find.text('Abrir avisos'));
      await tester.pumpAndSettle();
      expect(find.text('Avisos'), findsNothing);
      expect(find.text('Notificaciones'), findsOneWidget);
      expect(find.text('Recibes avisos en este dispositivo.'), findsNothing);
      expect(find.text('Gestionar preferencias'), findsNothing);

      final recentsRect = tester.getRect(find.text('Recientes'));
      final filterBtn = find.byKey(
        const ValueKey('notifications-preferences-filter'),
      );
      expect(filterBtn, findsOneWidget);
      expect(
        find.byTooltip('Gestionar preferencias'),
        findsOneWidget,
      );
      final filterRect = tester.getRect(filterBtn);
      expect((filterRect.center.dy - recentsRect.center.dy).abs(), lessThan(8));

      await tester.tap(find.byKey(const ValueKey('notification-row-n1')));
      await tester.pumpAndSettle();
      expect(controller.opened?.type, 'home');
      await tester.tap(filterBtn);
      await tester.pumpAndSettle();
      expect(find.text('Tus notificaciones'), findsOneWidget);
      expect(find.byKey(const ValueKey('save-notification-preferences')),
          findsOneWidget);
    });

    testWidgets('empty inbox is honest and offers no dead actions',
        (tester) async {
      await tester.pumpWidget(_host(inbox: NotificationInbox()));
      await tester.pumpAndSettle();

      expect(find.text('Aún no tienes notificaciones'), findsOneWidget);
      expect(
        find.text('Las notificaciones aún no están configuradas en esta '
            'versión de la app.'),
        findsOneWidget,
      );
    });

    testWidgets('tapping a notification marks it read and opens its route',
        (tester) async {
      final inbox = NotificationInbox()..ingest(_item());
      NotificationRouteData? opened;
      await tester.pumpWidget(
        _host(
          inbox: inbox,
          onOpenRoute: (route) => opened = route,
        ),
      );
      await tester.pumpAndSettle();

      expect(inbox.unreadCountFor('acct-1'), 1);
      await tester.tap(find.byKey(const ValueKey('notification-row-n1')));
      await tester.pumpAndSettle();

      expect(inbox.unreadCountFor('acct-1'), 0);
      expect(opened, isNotNull);
      expect(opened!.type, 'home');
    });

    testWidgets('only the active account inbox is shown', (tester) async {
      final inbox = NotificationInbox()
        ..ingest(_item(id: 'a1', ownerId: 'acct-1'))
        ..ingest(_item(id: 'b1', ownerId: 'acct-2'));
      await tester.pumpWidget(_host(inbox: inbox));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('notification-row-a1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('notification-row-b1')),
        findsNothing,
      );
    });

    testWidgets('mark-all-read clears the unread state', (tester) async {
      final inbox = NotificationInbox()
        ..ingest(_item(id: 'a1'))
        ..ingest(_item(id: 'a2'));
      await tester.pumpWidget(_host(inbox: inbox));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('notifications-mark-all-read')),
      );
      await tester.pumpAndSettle();
      expect(inbox.unreadCountFor('acct-1'), 0);
      expect(
        find.byKey(const ValueKey('notifications-mark-all-read')),
        findsNothing,
      );
    });

    testWidgets('unsupported routes explain themselves', (tester) async {
      final inbox = NotificationInbox()
        ..ingest(_item(id: 'bad', type: 'product'));
      var opened = 0;
      await tester.pumpWidget(
        _host(
          inbox: inbox,
          onOpenRoute: (_) => opened++,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('notification-row-bad')));
      await tester.pumpAndSettle();

      expect(opened, 0);
      expect(
        find.text('Este aviso ya no tiene un destino disponible.'),
        findsOneWidget,
      );
      // Aun así quedó como leído.
      expect(inbox.unreadCountFor('acct-1'), 0);
    });

    testWidgets('rewards section integrates without faking data',
        (tester) async {
      await tester.pumpWidget(
        _host(inbox: NotificationInbox(), rewards: FakeRewardsReader()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tu saldo Monetta'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('rewards-balance-card')),
        findsOneWidget,
      );
    });

    testWidgets('uses AutoRewardsSection when accountController is provided',
        (tester) async {
      final db = openTestDatabase();
      final account = AccountController(
        accountStore: AccountStore(db),
        deviceStore: DeviceStore(db),
        orderHistoryRepository: OrderHistoryRepository(
          store: OrderSummaryStore(db),
          config: AccountsOrdersConfig.disabled,
        ),
        deviceId: 'dev-notif',
      )..account = Account(
          localAccountId: 'acct-1',
          authProvider: 'monetta',
          createdAt: DateTime.utc(2026, 8, 27),
          lastSeenAt: DateTime.utc(2026, 8, 27),
        );
      addTearDown(() async {
        account.dispose();
        await db.close();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: NotificationsScreen(
            inbox: NotificationInbox(),
            ownerId: 'acct-1',
            accountController: account,
            rewardsReader: FakeRewardsReader(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AutoRewardsSection), findsOneWidget);
      expect(
        find.byKey(const ValueKey('rewards-balance-card')),
        findsOneWidget,
      );
    });
  });
}
