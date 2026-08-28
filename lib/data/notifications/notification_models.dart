/// Small, provider-neutral models used by notification UI and infrastructure.
library;

import 'dart:convert';

enum NotificationPermissionState {
  notDetermined('not_determined'),
  provisional('provisional'),
  granted('granted'),
  denied('denied');

  const NotificationPermissionState(this.wireValue);
  final String wireValue;

  bool get canReceive => this == granted || this == provisional;
}

class NotificationPreferences {
  const NotificationPreferences({
    this.productAlerts = false,
    this.personalizedOffers = false,
    this.announcements = false,
    this.quietStart = 21,
    this.quietEnd = 9,
  });

  final bool productAlerts;
  final bool personalizedOffers;
  final bool announcements;
  final int quietStart;
  final int quietEnd;

  bool get anyEnabled => productAlerts || personalizedOffers || announcements;

  NotificationPreferences copyWith({
    bool? productAlerts,
    bool? personalizedOffers,
    bool? announcements,
    int? quietStart,
    int? quietEnd,
  }) {
    return NotificationPreferences(
      productAlerts: productAlerts ?? this.productAlerts,
      personalizedOffers: personalizedOffers ?? this.personalizedOffers,
      announcements: announcements ?? this.announcements,
      quietStart: quietStart ?? this.quietStart,
      quietEnd: quietEnd ?? this.quietEnd,
    );
  }

  Map<String, Object> toJson({required String source}) => {
        'productAlerts': productAlerts,
        'personalizedOffers': personalizedOffers,
        'announcements': announcements,
        'quietStart': quietStart,
        'quietEnd': quietEnd,
        'policyVersion': '2026-08-25',
        'source': source,
      };

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      productAlerts: json['productAlerts'] == true,
      personalizedOffers: json['personalizedOffers'] == true,
      announcements: json['announcements'] == true,
      quietStart: _hour(json['quietStart'], 21),
      quietEnd: _hour(json['quietEnd'], 9),
    );
  }

  static int _hour(Object? value, int fallback) {
    return value is int && value >= 0 && value <= 23 ? value : fallback;
  }
}

class NotificationRouteData {
  const NotificationRouteData({
    required this.type,
    this.productKey,
    this.collectionHandle,
    this.deliveryId,
  });

  final String type;
  final String? productKey;
  final String? collectionHandle;
  final String? deliveryId;

  factory NotificationRouteData.fromData(Map<String, dynamic> data) {
    final rawRoute = data['route'];
    Map<String, dynamic> route = data;
    if (rawRoute is String && rawRoute.isNotEmpty) {
      try {
        final decoded = _decodeObject(rawRoute);
        if (decoded != null) route = decoded;
      } catch (_) {
        // A malformed provider payload falls back to the home route.
      }
    } else if (rawRoute is Map) {
      route = Map<String, dynamic>.from(rawRoute);
    }
    return NotificationRouteData(
      type: route['type'] is String ? route['type'] as String : 'home',
      productKey: route['productKey'] as String?,
      collectionHandle: route['handle'] as String?,
      deliveryId: (data['deliveryId'] ?? data['delivery_id']) as String?,
    );
  }

  static Map<String, dynamic>? _decodeObject(String value) {
    // Kept in a helper to keep JSON parsing at this infrastructure boundary.
    final decoded = jsonDecode(value);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  Map<String, Object?> toJson() => {
        'type': type,
        if (productKey != null) 'productKey': productKey,
        if (collectionHandle != null) 'handle': collectionHandle,
        if (deliveryId != null) 'deliveryId': deliveryId,
      };
}

class NotificationEnvelope {
  const NotificationEnvelope({
    required this.title,
    required this.body,
    required this.route,
  });

  final String? title;
  final String? body;
  final NotificationRouteData route;
}

class LocalCartReminderConfig {
  const LocalCartReminderConfig({
    required this.enabled,
    required this.delayHours,
    required this.title,
    required this.body,
  });

  final bool enabled;
  final int delayHours;
  final String title;
  final String body;

  static const disabled = LocalCartReminderConfig(
    enabled: false,
    delayHours: 20,
    title: 'Tu selección sigue aquí',
    body: 'Vuelve a Monetta cuando estés lista para continuar.',
  );
}

class NotificationException implements Exception {
  const NotificationException(this.message);
  final String message;

  @override
  String toString() => message;
}
