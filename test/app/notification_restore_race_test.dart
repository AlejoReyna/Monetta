/// CHAR-10 (objective state, red until RF-14): asking for the system
/// permission while `restore()` is still reading the saved state must not
/// re-enable announcements the shopper had switched off.
///
/// `HomeScreen` calls `requestSystemPermission()` on its first frame. Once the
/// startup stops awaiting `restore()`, that call can land before
/// `permissionState()` answers, while `permission` still holds its initial
/// `notDetermined`.
library;

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

const _credentialKey = 'notification_device_credential_v1';
const _preferencesKey = 'notification_preferences_v1';

class _MemorySecureStore implements SecureTokenStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

/// `permissionState()` stays pending until [answer] completes.
class _PendingPermissionGateway implements NotificationGateway {
  final answer = Completer<NotificationPermissionState>();
  int permissionStateCalls = 0;
  int permissionRequests = 0;

  @override
  Future<NotificationPermissionState> permissionState() {
    permissionStateCalls += 1;
    return answer.future;
  }

  @override
  Future<NotificationPermissionState> requestPermission() async {
    permissionRequests += 1;
    return NotificationPermissionState.granted;
  }

  @override
  Future<String?> appCheckToken() async => 'app-check';

  @override
  Future<String?> registrationToken() async => 'push-token';

  @override
  Future<NotificationEnvelope?> takeInitialMessage() async => null;

  @override
  Stream<String> get tokenChanges => const Stream.empty();

  @override
  Stream<NotificationEnvelope> get foregroundMessages => const Stream.empty();

  @override
  Stream<NotificationEnvelope> get openedMessages => const Stream.empty();

  @override
  void dispose() {}
}

void main() {
  test(
    'CHAR-10 requestSystemPermission during restore() does not re-enable '
    'announcements the shopper had switched off',
    () async {
      final database = openTestDatabase();
      final catalog = CatalogStore(database: database);
      final secureStore = _MemorySecureStore()
        ..values[_credentialKey] = 'device-credential'
        ..values[_preferencesKey] = jsonEncode(
          const NotificationPreferences().toJson(source: 'settings'),
        );
      final gateway = _PendingPermissionGateway();
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
              200,
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

      // restore() starts and parks on the pending permissionState().
      final restoring = controller.restore();
      for (var i = 0; i < 50 && gateway.permissionStateCalls == 0; i += 1) {
        await pumpEventQueue();
      }
      expect(
        gateway.permissionStateCalls,
        1,
        reason: 'restore() must have reached permissionState() first',
      );
      expect(controller.preferences.announcements, isFalse);

      // The first-frame prompt arrives while the saved state is unread.
      bool? asked;
      unawaited(controller.requestSystemPermission().then((v) => asked = v));
      await pumpEventQueue();

      gateway.answer.complete(NotificationPermissionState.granted);
      await restoring;
      await pumpEventQueue();

      expect(
        gateway.permissionRequests,
        0,
        reason: 'the OS prompt must not be requested while restore() has not '
            'read the permission yet: permission still holds its initial '
            'notDetermined (notification_controller.dart:160)',
      );
      expect(
        controller.preferences.announcements,
        isFalse,
        reason: 'announcements were saved as off and must stay off '
            '(notification_controller.dart:170 turns them on)',
      );
      expect(asked, isTrue, reason: 'permission was granted once restored');
      final saved = jsonDecode(secureStore.values[_preferencesKey]!)
          as Map<String, dynamic>;
      expect(saved['announcements'], isFalse);
      final promptSyncs = requests.where((request) {
        if (request.method != 'PUT' ||
            request.url.path != '/v1/device-installations/me/preferences') {
          return false;
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return body['source'] == 'permission_prompt';
      });
      expect(promptSyncs, isEmpty);
    },
  );
}
