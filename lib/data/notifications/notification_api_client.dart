/// HTTP client for anonymous installations and notification preferences.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'interest_profile_snapshot.dart';
import 'notification_models.dart';

class NotificationApiClient {
  NotificationApiClient({
    required this.baseUrl,
    required this.appCheckTokenProvider,
    http.Client? client,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final Uri baseUrl;
  final Future<String?> Function() appCheckTokenProvider;
  final http.Client _client;
  final bool _ownsClient;

  Future<String> registerInstallation({
    required String deviceId,
    required String platform,
    required String locale,
    required String timezone,
    required String appVersion,
    String? existingCredential,
  }) async {
    final appCheck = await appCheckTokenProvider();
    if (appCheck == null || appCheck.isEmpty) {
      throw const NotificationException(
        'No pudimos verificar esta instalación.',
      );
    }
    final response = await _send(
      'POST',
      '/v1/device-installations',
      credential: existingCredential,
      extraHeaders: {'X-Firebase-AppCheck': appCheck},
      body: {
        'deviceId': deviceId,
        'platform': platform,
        'locale': locale,
        'timezone': timezone,
        'appVersion': appVersion,
      },
      acceptedStatuses: const {200, 201},
    );
    final root = _object(response.bodyBytes);
    final credential = root['credential'];
    if (credential is! String || credential.isEmpty) {
      throw const NotificationException('Respuesta inválida del servicio.');
    }
    return credential;
  }

  Future<void> putPushEndpoint({
    required String credential,
    required String registrationId,
    required NotificationPermissionState permissionState,
  }) async {
    await _send(
      'PUT',
      '/v1/device-installations/me/push-endpoint',
      credential: credential,
      body: {
        'registrationKind': 'token',
        'registrationId': registrationId,
        'permissionState': permissionState.wireValue,
      },
    );
  }

  Future<void> putPreferences({
    required String credential,
    required NotificationPreferences preferences,
    required String source,
  }) async {
    await _send(
      'PUT',
      '/v1/device-installations/me/preferences',
      credential: credential,
      body: preferences.toJson(source: source),
    );
  }

  Future<void> putInterestProfile({
    required String credential,
    required InterestProfileSnapshot profile,
  }) async {
    await _send(
      'PUT',
      '/v1/device-installations/me/interest-profile',
      credential: credential,
      body: profile.toJson(),
    );
  }

  Future<String> createProductAlert({
    required String credential,
    required String productKey,
    String kind = 'restock',
  }) async {
    final response = await _send(
      'POST',
      '/v1/product-alerts',
      credential: credential,
      body: {'productKey': productKey, 'kind': kind},
      acceptedStatuses: const {201},
    );
    final root = _object(response.bodyBytes);
    final alert = root['alert'];
    if (alert is! Map<String, dynamic> || alert['id'] is! String) {
      throw const NotificationException('Respuesta inválida del servicio.');
    }
    return alert['id'] as String;
  }

  Future<void> recordOpen({
    required String credential,
    required String deliveryId,
  }) =>
      recordInteraction(
        credential: credential,
        deliveryId: deliveryId,
        event: 'opened',
      );

  Future<void> recordInteraction({
    required String credential,
    required String deliveryId,
    required String event,
  }) async {
    final now = DateTime.now().toUtc();
    await _send(
      'POST',
      '/v1/notification-interactions',
      credential: credential,
      extraHeaders: {
        'Idempotency-Key': '$event:$deliveryId',
      },
      body: {
        'deliveryId': deliveryId,
        'event': event,
        'occurredAt': now.toIso8601String(),
      },
      acceptedStatuses: const {200, 201},
    );
  }

  Future<LocalCartReminderConfig> fetchConfig() async {
    final response = await _send('GET', '/v1/notification-config');
    final root = _object(response.bodyBytes);
    final value = root['localCartReminder'];
    if (value is! Map<String, dynamic>) {
      return LocalCartReminderConfig.disabled;
    }
    return LocalCartReminderConfig(
      enabled: value['enabled'] == true,
      delayHours: value['delayHours'] is num
          ? (value['delayHours'] as num).toInt().clamp(1, 168)
          : 20,
      title: value['title'] is String
          ? value['title'] as String
          : LocalCartReminderConfig.disabled.title,
      body: value['body'] is String
          ? value['body'] as String
          : LocalCartReminderConfig.disabled.body,
    );
  }

  Future<http.Response> _send(
    String method,
    String path, {
    String? credential,
    Map<String, String>? extraHeaders,
    Map<String, Object?>? body,
    Set<int> acceptedStatuses = const {200},
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (credential != null) 'Authorization': 'Device $credential',
      if (body != null) 'Content-Type': 'application/json',
      ...?extraHeaders,
    };
    final uri = baseUrl.resolve(path);
    final encoded = body == null ? null : jsonEncode(body);
    final response = switch (method) {
      'GET' => await _client.get(uri, headers: headers),
      'POST' => await _client.post(uri, headers: headers, body: encoded),
      'PUT' => await _client.put(uri, headers: headers, body: encoded),
      _ => throw NotificationException('Método no soportado: $method'),
    };
    if (!acceptedStatuses.contains(response.statusCode)) {
      final error = _error(response.bodyBytes);
      throw NotificationException(
        error == 'installation_already_registered'
            ? 'Esta instalación ya está registrada. Reinstala la app para renovar su identidad.'
            : 'El servicio de notificaciones no respondió (${response.statusCode}).',
      );
    }
    return response;
  }

  static Map<String, dynamic> _object(List<int> bytes) {
    final value = jsonDecode(utf8.decode(bytes));
    if (value is! Map<String, dynamic>) {
      throw const NotificationException('Respuesta inválida del servicio.');
    }
    return value;
  }

  static String? _error(List<int> bytes) {
    try {
      return _object(bytes)['error'] as String?;
    } catch (_) {
      return null;
    }
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
