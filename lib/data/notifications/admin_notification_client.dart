/// Owner-authenticated HTTP client for campaigns, reports and automation.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'notification_models.dart';

class NotificationCampaignSummary {
  const NotificationCampaignSummary({
    required this.id,
    required this.title,
    required this.status,
    required this.eligibleCount,
    required this.acceptedCount,
    required this.openedCount,
    required this.failedCount,
  });

  final String id;
  final String title;
  final String status;
  final int eligibleCount;
  final int acceptedCount;
  final int openedCount;
  final int failedCount;

  factory NotificationCampaignSummary.fromJson(Map<String, dynamic> json) {
    return NotificationCampaignSummary(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? ''}',
      status: '${json['status'] ?? 'draft'}',
      eligibleCount: _integer(json['eligibleCount']),
      acceptedCount: _integer(json['acceptedCount']),
      openedCount: _integer(json['openedCount']),
      failedCount: _integer(json['failedCount']),
    );
  }

  static int _integer(Object? value) => value is num ? value.toInt() : 0;
}

class NotificationAdminOverview {
  const NotificationAdminOverview({
    required this.activeEndpoints,
    required this.grantedEndpoints,
    required this.personalizedProfiles,
    required this.queuedDeliveries,
    required this.recentCampaigns,
  });

  final int activeEndpoints;
  final int grantedEndpoints;
  final int personalizedProfiles;
  final int queuedDeliveries;
  final List<NotificationCampaignSummary> recentCampaigns;

  static const empty = NotificationAdminOverview(
    activeEndpoints: 0,
    grantedEndpoints: 0,
    personalizedProfiles: 0,
    queuedDeliveries: 0,
    recentCampaigns: [],
  );

  factory NotificationAdminOverview.fromJson(Map<String, dynamic> json) {
    final campaigns = json['recentCampaigns'];
    return NotificationAdminOverview(
      activeEndpoints: _integer(json['activeEndpoints']),
      grantedEndpoints: _integer(json['grantedEndpoints']),
      personalizedProfiles: _integer(json['personalizedProfiles']),
      queuedDeliveries: _integer(json['queuedDeliveries']),
      recentCampaigns: campaigns is List
          ? campaigns
              .whereType<Map<String, dynamic>>()
              .map(NotificationCampaignSummary.fromJson)
              .toList()
          : const [],
    );
  }

  static int _integer(Object? value) => value is num ? value.toInt() : 0;
}

class NotificationAutomationRule {
  const NotificationAutomationRule({
    required this.key,
    required this.enabled,
    required this.configuration,
  });

  final String key;
  final bool enabled;
  final Map<String, dynamic> configuration;

  factory NotificationAutomationRule.fromJson(Map<String, dynamic> json) {
    final configuration = json['configuration'];
    return NotificationAutomationRule(
      key: '${json['key'] ?? ''}',
      enabled: json['enabled'] == true,
      configuration:
          configuration is Map<String, dynamic> ? configuration : const {},
    );
  }

  NotificationAutomationRule copyWith({bool? enabled}) {
    return NotificationAutomationRule(
      key: key,
      enabled: enabled ?? this.enabled,
      configuration: configuration,
    );
  }
}

class CampaignDraftInput {
  const CampaignDraftInput({
    required this.title,
    required this.body,
    required this.purpose,
    required this.segment,
    required this.route,
    this.imageUrl,
  });

  final String title;
  final String body;
  final String purpose;
  final Map<String, Object> segment;
  final Map<String, Object> route;
  final String? imageUrl;

  Map<String, Object?> toJson() => {
        'kind': 'manual',
        'title': title,
        'body': body,
        'purpose': purpose,
        'segment': segment,
        'route': route,
        'imageUrl': imageUrl,
      };
}

class CampaignPreview {
  const CampaignPreview({required this.id, required this.eligible});
  final String id;
  final int eligible;
}

class AdminNotificationClient {
  AdminNotificationClient({
    required this.baseUrl,
    required this.accessTokenProvider,
    http.Client? client,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final Uri baseUrl;
  final Future<String?> Function() accessTokenProvider;
  final http.Client _client;
  final bool _ownsClient;

  Future<NotificationAdminOverview> overview() async {
    final response = await _send('GET', '/admin/notifications/overview');
    return NotificationAdminOverview.fromJson(_object(response.bodyBytes));
  }

  Future<List<NotificationAutomationRule>> rules() async {
    final response = await _send('GET', '/admin/notification-rules');
    final rows = _object(response.bodyBytes)['rules'];
    return rows is List
        ? rows
            .whereType<Map<String, dynamic>>()
            .map(NotificationAutomationRule.fromJson)
            .toList()
        : const [];
  }

  Future<CampaignPreview> createAndPreview(CampaignDraftInput input) async {
    final created = await _send(
      'POST',
      '/admin/notification-campaigns',
      body: input.toJson(),
      acceptedStatuses: const {201},
    );
    final campaign = _object(created.bodyBytes)['campaign'];
    if (campaign is! Map<String, dynamic> || campaign['id'] is! String) {
      throw const NotificationException('Respuesta de campaña inválida.');
    }
    final id = campaign['id'] as String;
    final preview = await _send(
      'POST',
      '/admin/notification-campaigns/$id/preview',
    );
    return CampaignPreview(
      id: id,
      eligible: (_object(preview.bodyBytes)['eligible'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> scheduleNow(String campaignId) async {
    await _send(
      'POST',
      '/admin/notification-campaigns/$campaignId/schedule',
      body: {'scheduledAt': DateTime.now().toUtc().toIso8601String()},
      acceptedStatuses: const {202},
    );
  }

  Future<void> sendTest(String campaignId, String deviceId) async {
    await _send(
      'POST',
      '/admin/notification-campaigns/$campaignId/test',
      body: {'deviceId': deviceId},
      acceptedStatuses: const {202},
    );
  }

  Future<void> setRule(NotificationAutomationRule rule) async {
    await _send(
      'PATCH',
      '/admin/notification-rules/${Uri.encodeComponent(rule.key)}',
      body: {
        'enabled': rule.enabled,
        'configuration': rule.configuration,
      },
    );
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    Set<int> acceptedStatuses = const {200},
  }) async {
    final token = await accessTokenProvider();
    if (token == null || token.isEmpty) {
      throw const NotificationException(
        'La sesión del dueño no está disponible.',
      );
    }
    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };
    final encoded = body == null ? null : jsonEncode(body);
    final response = switch (method) {
      'GET' => await _client.get(baseUrl.resolve(path), headers: headers),
      'POST' => await _client.post(
          baseUrl.resolve(path),
          headers: headers,
          body: encoded,
        ),
      'PATCH' => await _client.patch(
          baseUrl.resolve(path),
          headers: headers,
          body: encoded,
        ),
      _ => throw NotificationException('Método no soportado: $method'),
    };
    if (!acceptedStatuses.contains(response.statusCode)) {
      throw NotificationException(
        'El panel de notificaciones no respondió (${response.statusCode}).',
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

  void close() {
    if (_ownsClient) _client.close();
  }
}
