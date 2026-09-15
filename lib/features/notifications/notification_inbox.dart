/// Bandeja de notificaciones del paquete E.
///
/// La infraestructura push existente ([NotificationController]) gestiona
/// permiso, registro y preferencias, pero no conserva un historial legible.
/// Esta bandeja es la lista que las pantallas presentan: ingest tipada,
/// lectura por cuenta, destinos verificables y estados vacíos.
///
/// Alcance honesto: en memoria por sesión, aislada por cuenta (`''` =
/// invitado). La persistencia duradera y los eventos de saldo del servidor
/// pertenecen a F (outbox + worker); ver `PAQUETE_E_ENTREGA.md` y el parche
/// de integración global. Nada aquí inventa notificaciones: solo aparece lo
/// que realmente llegó vía [ingest].
library;

import 'package:flutter/foundation.dart';

import '../../data/notifications/notification_models.dart';

/// Una notificación ya recibida por el dispositivo.
class MonettaNotification {
  MonettaNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.route,
    required this.receivedAt,
    required this.ownerId,
    this.kind = MonettaNotificationKind.general,
    bool read = false,
  }) : _read = read;

  final String id;
  final String title;
  final String body;
  final NotificationRouteData route;
  final DateTime receivedAt;

  /// `localAccountId` verificado o `''` para invitado. Nunca se mezclan.
  final String ownerId;
  final MonettaNotificationKind kind;

  bool _read;
  bool get read => _read;
}

enum MonettaNotificationKind {
  general,
  order,
  rewards,
  product,
}

String notificationKindLabel(MonettaNotificationKind kind) => switch (kind) {
      MonettaNotificationKind.general => 'Aviso',
      MonettaNotificationKind.order => 'Pedido',
      MonettaNotificationKind.rewards => 'Saldo Monetta',
      MonettaNotificationKind.product => 'Producto',
    };

/// Destino verificable de una notificación. Solo rutas que la app sabe
/// abrir (producto existente, colección por handle, inicio). Lo demás cae a
/// inicio sin inventar pantallas.
bool notificationRouteIsSupported(NotificationRouteData route) {
  return switch (route.type) {
    'home' => true,
    'product' => route.productKey != null && route.productKey!.isNotEmpty,
    'collection' =>
      route.collectionHandle != null && route.collectionHandle!.isNotEmpty,
    'order' => true,
    'account' => true,
    _ => false,
  };
}

class NotificationInbox extends ChangeNotifier {
  NotificationInbox();

  final List<MonettaNotification> _items = [];

  List<MonettaNotification> itemsFor(String ownerId) => List.unmodifiable(
        _items.where((item) => item.ownerId == ownerId).toList()
          ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt)),
      );

  int unreadCountFor(String ownerId) =>
      _items.where((i) => i.ownerId == ownerId && !i.read).length;

  /// Registra una notificación realmente recibida. Los duplicados por
  /// `deliveryId`/id no se guardan dos veces.
  void ingest(MonettaNotification notification) {
    if (_items.any((item) => item.id == notification.id)) return;
    _items.add(notification);
    notifyListeners();
  }

  void markRead(String ownerId, String id) {
    for (final item in _items) {
      if (item.ownerId == ownerId && item.id == id && !item.read) {
        item._read = true;
        notifyListeners();
        return;
      }
    }
  }

  void markAllRead(String ownerId) {
    var changed = false;
    for (final item in _items) {
      if (item.ownerId == ownerId && !item.read) {
        item._read = true;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  /// Limpia solo la cuenta indicada al cerrar sesión o cambiar de cuenta.
  void clearOwner(String ownerId) {
    final before = _items.length;
    _items.removeWhere((item) => item.ownerId == ownerId);
    if (_items.length != before) notifyListeners();
  }
}
