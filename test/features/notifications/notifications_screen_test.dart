import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/theme.dart';
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

void main() {
  group('NotificationsScreen', () {
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
  });
}
