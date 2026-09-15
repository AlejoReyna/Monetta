import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/notifications/notification_models.dart';
import 'package:monetta_app/features/notifications/notification_inbox.dart';

MonettaNotification _item({
  String id = 'n1',
  String ownerId = 'acct-A',
  DateTime? at,
}) =>
    MonettaNotification(
      id: id,
      title: 'Tu pedido va en camino',
      body: 'El pedido #1001 fue enviado.',
      route: const NotificationRouteData(type: 'home'),
      receivedAt: at ?? DateTime.utc(2026, 9, 14, 10),
      ownerId: ownerId,
      kind: MonettaNotificationKind.order,
    );

void main() {
  group('NotificationInbox', () {
    test('isolates accounts: A never sees B', () {
      final inbox = NotificationInbox();
      inbox.ingest(_item(id: 'a1', ownerId: 'acct-A'));
      inbox.ingest(_item(id: 'b1', ownerId: 'acct-B'));

      expect(inbox.itemsFor('acct-A').map((i) => i.id), ['a1']);
      expect(inbox.itemsFor('acct-B').map((i) => i.id), ['b1']);
      expect(inbox.unreadCountFor('acct-A'), 1);
    });

    test('dedupes repeated deliveries', () {
      final inbox = NotificationInbox();
      inbox.ingest(_item(id: 'dup'));
      inbox.ingest(_item(id: 'dup'));

      expect(inbox.itemsFor('acct-A'), hasLength(1));
    });

    test('orders newest first', () {
      final inbox = NotificationInbox();
      inbox.ingest(_item(id: 'old', at: DateTime.utc(2026, 9, 13)));
      inbox.ingest(_item(id: 'new', at: DateTime.utc(2026, 9, 14)));

      expect(
        inbox.itemsFor('acct-A').map((i) => i.id),
        ['new', 'old'],
      );
    });

    test('markRead and markAllRead only touch the owner', () {
      final inbox = NotificationInbox();
      inbox.ingest(_item(id: 'a1', ownerId: 'acct-A'));
      inbox.ingest(_item(id: 'b1', ownerId: 'acct-B'));

      inbox.markRead('acct-A', 'a1');
      expect(inbox.unreadCountFor('acct-A'), 0);
      expect(inbox.unreadCountFor('acct-B'), 1);

      inbox.ingest(_item(id: 'a2', ownerId: 'acct-A'));
      inbox.markAllRead('acct-A');
      expect(inbox.unreadCountFor('acct-A'), 0);
      expect(inbox.unreadCountFor('acct-B'), 1);
    });

    test('clearOwner keeps the other account intact', () {
      final inbox = NotificationInbox();
      inbox.ingest(_item(id: 'a1', ownerId: 'acct-A'));
      inbox.ingest(_item(id: 'b1', ownerId: 'acct-B'));

      inbox.clearOwner('acct-A');
      expect(inbox.itemsFor('acct-A'), isEmpty);
      expect(inbox.itemsFor('acct-B'), hasLength(1));
    });
  });

  group('notificationRouteIsSupported', () {
    test('supports the routes the app can open', () {
      expect(
        notificationRouteIsSupported(
          const NotificationRouteData(type: 'home'),
        ),
        isTrue,
      );
      expect(
        notificationRouteIsSupported(
          const NotificationRouteData(
            type: 'product',
            productKey: 'shopify:123',
          ),
        ),
        isTrue,
      );
      expect(
        notificationRouteIsSupported(
          const NotificationRouteData(
            type: 'collection',
            collectionHandle: 'bolsas',
          ),
        ),
        isTrue,
      );
      expect(
        notificationRouteIsSupported(
          const NotificationRouteData(type: 'order'),
        ),
        isTrue,
      );
    });

    test('rejects routes without destination data', () {
      expect(
        notificationRouteIsSupported(
          const NotificationRouteData(type: 'product'),
        ),
        isFalse,
      );
      expect(
        notificationRouteIsSupported(
          const NotificationRouteData(type: 'unknown-type'),
        ),
        isFalse,
      );
    });
  });
}
