import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/notification_controller.dart';
import 'package:monetta_app/data/customer_auth/secure_token_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/notifications/firebase_notification_gateway.dart';
import 'package:monetta_app/data/notifications/notification_api_client.dart';
import 'package:monetta_app/data/notifications/notification_config.dart';
import 'package:monetta_app/data/notifications/notification_models.dart';

class _MemorySecureStore implements SecureTokenStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _NotificationGateway implements NotificationGateway {
  int permissionRequests = 0;

  @override
  Future<String?> appCheckToken() async => 'app-check';

  @override
  void dispose() {}

  @override
  Stream<NotificationEnvelope> get foregroundMessages => const Stream.empty();

  @override
  Stream<NotificationEnvelope> get openedMessages => const Stream.empty();

  @override
  Future<NotificationPermissionState> permissionState() async =>
      NotificationPermissionState.notDetermined;

  @override
  Future<String?> registrationToken() async => 'push-token';

  @override
  Future<NotificationPermissionState> requestPermission() async {
    permissionRequests++;
    return NotificationPermissionState.granted;
  }

  @override
  Future<NotificationEnvelope?> takeInitialMessage() async => null;

  @override
  Stream<String> get tokenChanges => const Stream.empty();
}

void main() {
  test('native permission consent registers announcements once', () async {
    final database = openTestDatabase();
    final catalog = CatalogStore(database: database);
    final secureStore = _MemorySecureStore();
    final gateway = _NotificationGateway();
    final requests = <http.Request>[];
    final api = NotificationApiClient(
      baseUrl: Uri.parse('https://notifications.example'),
      appCheckTokenProvider: gateway.appCheckToken,
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'POST' &&
            request.url.path == '/v1/device-installations') {
          return http.Response(
            jsonEncode({'credential': 'device-credential'}),
            201,
          );
        }
        return http.Response('{}', 200);
      }),
    );
    final controller = NotificationController(
      config: NotificationConfig(
        enabled: true,
        apiBaseUrl: Uri.parse('https://notifications.example'),
        firebaseApiKey: 'api-key',
        firebaseAppId: 'app-id',
        firebaseProjectId: 'project-id',
        firebaseMessagingSenderId: 'sender-id',
        firebaseStorageBucket: '',
        iosBundleId: 'mx.monetta.test',
        timezone: 'America/Monterrey',
      ),
      deviceId: 'device-1',
      catalogStore: catalog,
      secureStore: secureStore,
      gateway: gateway,
      apiClient: api,
      onOpenRoute: (_) {},
    );
    addTearDown(() async {
      controller.dispose();
      catalog.dispose();
      await database.close();
    });

    expect(await controller.requestSystemPermission(), isTrue);

    expect(gateway.permissionRequests, 1);
    expect(controller.permission, NotificationPermissionState.granted);
    expect(controller.preferences.announcements, isTrue);
    expect(controller.preferences.productAlerts, isFalse);
    expect(controller.preferences.personalizedOffers, isFalse);
    expect(
      requests.map((request) => '${request.method} ${request.url.path}'),
      [
        'POST /v1/device-installations',
        'PUT /v1/device-installations/me/push-endpoint',
        'PUT /v1/device-installations/me/preferences',
      ],
    );
    final preferenceBody =
        jsonDecode(requests.last.body) as Map<String, dynamic>;
    expect(preferenceBody['announcements'], isTrue);
    expect(preferenceBody['source'], 'permission_prompt');

    expect(await controller.requestSystemPermission(), isTrue);
    expect(gateway.permissionRequests, 1);
    expect(requests, hasLength(3));
  });
}
