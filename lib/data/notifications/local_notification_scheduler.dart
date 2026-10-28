/// Device-only notifications: foreground presentation and cart reminders.
library;

import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'notification_models.dart';

abstract interface class LocalNotificationScheduler {
  Future<NotificationRouteData?> initialize(
    void Function(NotificationRouteData route) onOpen,
  );
  Future<void> showForeground(NotificationEnvelope message);
  Future<void> scheduleCartReminder({
    required LocalCartReminderConfig config,
  });
  Future<void> cancelCartReminder();
}

class PluginLocalNotificationScheduler implements LocalNotificationScheduler {
  PluginLocalNotificationScheduler({
    required this.timezone,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _cartReminderId = 932104;
  static const _remoteChannel = AndroidNotificationDetails(
    'monetta_remote',
    'Novedades de Monetta',
    channelDescription: 'Alertas solicitadas y novedades que elegiste recibir.',
    importance: Importance.high,
    priority: Priority.high,
  );
  static const _reminderChannel = AndroidNotificationDetails(
    'monetta_cart_reminders',
    'Recordatorios de bolsa',
    channelDescription: 'Recordatorios locales de artículos en tu bolsa.',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  final String timezone;
  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<NotificationRouteData?> initialize(
    void Function(NotificationRouteData route) onOpen,
  ) async {
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(timezone));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings(
        '@drawable/ic_stat_monetta',
      ),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final route = _decodeRoute(response.payload);
        if (route != null) onOpen(route);
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'monetta_remote',
            'Novedades de Monetta',
            description:
                'Alertas solicitadas y novedades que elegiste recibir.',
            importance: Importance.high,
          ),
        );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp != true) return null;
    return _decodeRoute(launch?.notificationResponse?.payload);
  }

  @override
  Future<void> showForeground(NotificationEnvelope message) {
    return _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 30),
      title: message.title,
      body: message.body,
      notificationDetails: const NotificationDetails(
        android: _remoteChannel,
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.route.toJson()),
    );
  }

  @override
  Future<void> scheduleCartReminder({
    required LocalCartReminderConfig config,
  }) {
    return _plugin.zonedSchedule(
      id: _cartReminderId,
      title: config.title,
      body: config.body,
      scheduledDate:
          tz.TZDateTime.now(tz.local).add(Duration(hours: config.delayHours)),
      notificationDetails: const NotificationDetails(
        android: _reminderChannel,
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: jsonEncode(const NotificationRouteData(type: 'home').toJson()),
    );
  }

  @override
  Future<void> cancelCartReminder() => _plugin.cancel(id: _cartReminderId);

  static NotificationRouteData? _decodeRoute(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final value = jsonDecode(payload);
      return value is Map<String, dynamic>
          ? NotificationRouteData.fromData(value)
          : null;
    } catch (_) {
      return null;
    }
  }
}
