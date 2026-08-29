import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monetta_app/data/notifications/notification_api_client.dart';
import 'package:monetta_app/data/notifications/notification_models.dart';

void main() {
  test('installation registration is App Check attested and rotates credential',
      () async {
    late http.Request captured;
    final client = NotificationApiClient(
      baseUrl: Uri.parse('https://accounts.example/'),
      appCheckTokenProvider: () async => 'app-check-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'deviceId': 'device-1', 'credential': 'new-credential'}),
          200,
        );
      }),
    );

    final credential = await client.registerInstallation(
      deviceId: 'device-1',
      platform: 'ios',
      locale: 'es-MX',
      timezone: 'America/Monterrey',
      appVersion: '0.1.0',
      existingCredential: 'old-credential',
    );

    expect(credential, 'new-credential');
    expect(captured.url.path, '/v1/device-installations');
    expect(captured.headers['x-firebase-appcheck'], 'app-check-token');
    expect(captured.headers['authorization'], 'Device old-credential');
  });

  test('preferences use the anonymous device credential, not a customer id',
      () async {
    late http.Request captured;
    final client = NotificationApiClient(
      baseUrl: Uri.parse('https://accounts.example/'),
      appCheckTokenProvider: () async => null,
      client: MockClient((request) async {
        captured = request;
        return http.Response('{}', 200);
      }),
    );

    await client.putPreferences(
      credential: 'device-secret',
      preferences: const NotificationPreferences(productAlerts: true),
      source: 'product_alert',
    );

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(captured.headers['authorization'], 'Device device-secret');
    expect(body['productAlerts'], isTrue);
    expect(body, isNot(contains('customerId')));
  });
}
