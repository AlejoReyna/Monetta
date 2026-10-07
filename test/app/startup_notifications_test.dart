/// CHAR-08 and CHAR-09 (objective state, red until RF-14): notifications must
/// not hold the first paint hostage, and a notification tapped on a cold start
/// must still open its route once the navigator exists.
///
/// The app is mounted for real (`MonettaApp`) with only its platform edges
/// faked: path_provider, secure storage, the asset bundle (an empty bundled
/// catalog) and the default `http.Client`. The notification gateway and the
/// realtime catalog source are the injection points `MonettaApp` already has.
///
/// Time: the Drift background isolate and file I/O need the real event loop,
/// so the bootstrap phase yields to it through `tester.runAsync`. Everything
/// that is measured (the 9 s startup bound) runs on the simulated clock.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monetta_app/data/firestore/catalog_realtime_source.dart';
import 'package:monetta_app/data/notifications/firebase_notification_gateway.dart';
import 'package:monetta_app/data/notifications/notification_config.dart';
import 'package:monetta_app/data/notifications/notification_models.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/main.dart';

/// The vigente startup is bounded by `waitForInitialCatalog`'s 8 s timeout;
/// the objective keeps that bound and adds a 1 s margin.
const _startupBound = Duration(seconds: 9);

/// Simulated time given to a scenario before asserting its end state.
const _scenarioBudget = Duration(seconds: 10);

const _frameStep = Duration(milliseconds: 100);

const _handle = 'anillos';

final _usableConfig = NotificationConfig(
  enabled: true,
  apiBaseUrl: Uri.parse('https://notifications.example'),
  firebaseApiKey: 'test-api-key',
  firebaseAppId: '1:1234567890:android:abcdef',
  firebaseProjectId: 'monetta-test',
  firebaseMessagingSenderId: '1234567890',
  firebaseStorageBucket: '',
  iosBundleId: 'mx.monetta.monettaApp',
  timezone: 'America/Monterrey',
);

/// Gateway whose first-contact calls stay pending until [release] is called.
class _FakeGateway implements NotificationGateway {
  _FakeGateway({this.initialMessage});

  final NotificationEnvelope? initialMessage;
  final _permission = Completer<NotificationPermissionState>();
  final _appCheck = Completer<String?>();
  final _initial = Completer<NotificationEnvelope?>();
  int permissionStateCalls = 0;
  int takeInitialMessageCalls = 0;

  void release() {
    if (!_permission.isCompleted) {
      _permission.complete(NotificationPermissionState.notDetermined);
    }
    if (!_appCheck.isCompleted) _appCheck.complete('app-check');
    if (!_initial.isCompleted) _initial.complete(initialMessage);
  }

  @override
  Future<String?> appCheckToken() => _appCheck.future;

  @override
  Future<NotificationPermissionState> permissionState() {
    permissionStateCalls += 1;
    return _permission.future;
  }

  @override
  Future<NotificationEnvelope?> takeInitialMessage() {
    takeInitialMessageCalls += 1;
    return _initial.future;
  }

  @override
  Future<NotificationPermissionState> requestPermission() async =>
      NotificationPermissionState.notDetermined;

  @override
  Future<String?> registrationToken() async => 'push-token';

  @override
  Stream<String> get tokenChanges => const Stream.empty();

  @override
  Stream<NotificationEnvelope> get foregroundMessages => const Stream.empty();

  @override
  Stream<NotificationEnvelope> get openedMessages => const Stream.empty();

  @override
  void dispose() {}
}

/// A realtime source that never emits: the store stays in `connecting`, so
/// with an empty bundled catalog `waitForInitialCatalog` keeps waiting.
class _SilentRealtimeSource implements CatalogRealtimeSource {
  final controller = StreamController<List<CatalogRealtimeDocument>>();

  @override
  Stream<List<CatalogRealtimeDocument>> watchProducts() => controller.stream;
}

/// Everything a scenario needs: fakes plus the temp directory backing Drift.
class _Env {
  _Env({required this.gateway, required this.source, required this.dir});

  final _FakeGateway gateway;
  final _SilentRealtimeSource source;
  final Directory dir;
}

const _emptyCatalog = <String, Object?>{
  '_source': 'test',
  '_snapshot': '2026-10-06',
  'products': <Object?>[],
};

/// Installs the platform edges `MonettaApp` touches while booting.
void _installPlatformFakes(WidgetTester tester, Directory dir) {
  final messenger = tester.binding.defaultBinaryMessenger;

  // path_provider: Drift's `monetta.sqlite` and the search-history file.
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => dir.path,
  );

  // flutter_secure_storage: in-memory.
  final secure = <String, String>{};
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async {
      final arguments = (call.arguments as Map?)?.cast<String, Object?>();
      final key = arguments?['key'] as String?;
      switch (call.method) {
        case 'write':
          secure[key!] = arguments!['value']! as String;
          return null;
        case 'read':
          return secure[key];
        case 'delete':
          secure.remove(key);
          return null;
        case 'containsKey':
          return secure.containsKey(key);
        case 'readAll':
          return Map<String, String>.of(secure);
        case 'deleteAll':
          secure.clear();
          return null;
      }
      return null;
    },
  );

  // flutter_local_notifications: `PluginLocalNotificationScheduler` is built
  // whenever a gateway exists. In tests the Android implementation is not
  // registered, so register it and answer its channel with "nothing launched
  // the app".
  AndroidFlutterLocalNotificationsPlugin.registerWith();
  messenger.setMockMethodCallHandler(
    const MethodChannel('dexterous.com/flutter/local_notifications'),
    (call) async => switch (call.method) {
      'initialize' => true,
      _ => null,
    },
  );

  // Asset bundle: the bundled catalog is empty; every other asset is served
  // by the real bundle. `CatalogStore` caches assets in statics per isolate,
  // so every scenario in this file must use the same (empty) catalog.
  final emptyCatalog = ByteData.sublistView(
    Uint8List.fromList(utf8.encode(jsonEncode(_emptyCatalog))),
  );
  messenger.setMockMessageHandler('flutter/assets', (message) async {
    if (message != null) {
      final key = utf8.decode(
        message.buffer
            .asUint8List(message.offsetInBytes, message.lengthInBytes),
      );
      if (key.endsWith('assets/catalog/catalog.json')) return emptyCatalog;
    }
    return messenger.delegate.send('flutter/assets', message);
  });

  addTearDown(() {
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      null,
    );
    messenger.setMockMessageHandler('flutter/assets', null);
  });
}

/// Runs [body] with a mounted-ready environment. Wraps the whole scenario in
/// `http.runWithClient`, so the `NotificationApiClient` that `MonettaApp`
/// builds for itself talks to an in-memory server instead of the network.
/// With [serviceDown] the notification service is unreachable: every request
/// fails with a transport error.
Future<void> _scenario(
  WidgetTester tester,
  _FakeGateway gateway,
  Future<void> Function(_Env env) body, {
  bool serviceDown = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final dir = Directory.systemTemp.createTempSync('monetta_startup_');
  _installPlatformFakes(tester, dir);
  final env = _Env(gateway: gateway, source: _SilentRealtimeSource(), dir: dir);

  final server = MockClient((request) async {
    if (serviceDown) {
      throw http.ClientException('notification service unreachable');
    }
    if (request.method == 'GET' &&
        request.url.path == '/v1/notification-config') {
      return http.Response('{}', 200);
    }
    return http.Response('{}', 404);
  });

  try {
    await http.runWithClient(() => body(env), () => server);
  } finally {
    // Unmount: disposes the app state (controllers, listeners, timers).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
    unawaited(env.source.controller.close());
    await tester.runAsync(() async {
      // Let the Drift background isolate drain before the temp dir goes away.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Best effort: the OS temp dir is reclaimed anyway.
      }
    });
  }
}

/// Advances the simulated clock by [total] in [_frameStep] frames, yielding
/// to the real event loop between frames so isolate answers are delivered.
Future<void> _advance(WidgetTester tester, Duration total) async {
  var elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump(_frameStep);
    elapsed += _frameStep;
  }
}

/// Bootstrap: lets the real-async work (Drift isolate, file I/O) run with the
/// simulated clock frozen, until the app has either shown the home or reached
/// the notification gateway. The iteration cap is only a guard against a
/// hung bootstrap; it is not a measured quantity.
Future<void> _bootstrap(WidgetTester tester, _FakeGateway gateway) async {
  for (var i = 0; i < 1500; i += 1) {
    if (find.byType(HomeScreen).evaluate().isNotEmpty) return;
    if (gateway.permissionStateCalls > 0) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  fail('Startup never reached the notification gateway nor the home.');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'CHAR-08 the home paints within the bounded startup while notification '
    'init is pending, and notifications finish initializing afterwards',
    (tester) async {
      final gateway = _FakeGateway();
      await _scenario(tester, gateway, (env) async {
        await tester.pumpWidget(
          MonettaApp(
            notificationConfig: _usableConfig,
            gateway: gateway,
            realtimeCatalogSource: env.source,
          ),
        );
        await _bootstrap(tester, gateway);
        await _advance(tester, _startupBound);

        // (a) The first paint does not wait for permissionState(),
        // appCheckToken() or takeInitialMessage().
        expect(
          find.byType(HomeScreen),
          findsOneWidget,
          reason: 'HomeScreen must be mounted within $_startupBound of '
              'simulated time even though the notification gateway has not '
              'answered (today _load awaits NotificationController.restore()).',
        );

        // (b) Completing the gateway initializes notifications later, with
        // no app restart.
        final controller = NotificationScope.of(
          tester.element(find.byType(HomeScreen)),
        );
        expect(controller.ready, isFalse);
        gateway.release();
        await _advance(tester, const Duration(seconds: 1));

        expect(controller.ready, isTrue);
        expect(controller.lastError, isNull);
        expect(gateway.takeInitialMessageCalls, 1);
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets(
    'CHAR-09 a notification tapped on a cold start opens its collection once '
    'when the navigator exists, with the home underneath',
    (tester) async {
      final gateway = _FakeGateway(
        initialMessage: const NotificationEnvelope(
          title: 'Novedades',
          body: 'Anillos nuevos',
          route: NotificationRouteData(
            type: 'collection',
            collectionHandle: _handle,
          ),
        ),
      )..release();
      await _scenario(tester, gateway, (env) async {
        await tester.pumpWidget(
          MonettaApp(
            notificationConfig: _usableConfig,
            gateway: gateway,
            realtimeCatalogSource: env.source,
          ),
        );
        // The gateway answers immediately, so the initial route is delivered
        // to the app while the catalog wait keeps the navigator unmounted.
        await _bootstrap(tester, gateway);
        await _advance(tester, _scenarioBudget);

        expect(gateway.takeInitialMessageCalls, 1);
        expect(
          find.byType(CollectionScreen, skipOffstage: false),
          findsOneWidget,
          reason: 'the tapped collection route must open exactly once after '
              'the navigator mounts (today it is dropped at '
              'main.dart _openNotificationRoute: currentState == null).',
        );
        final screen = tester.widget<CollectionScreen>(
          find.byType(CollectionScreen),
        );
        expect(screen.filter.collectionHandle, _handle);
        expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);

        // One pop returns to the home: the route was not stacked twice.
        Navigator.of(tester.element(find.byType(CollectionScreen))).pop();
        await _advance(tester, const Duration(seconds: 1));
        final remaining = find.byType(CollectionScreen, skipOffstage: false);
        expect(remaining, findsNothing);
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets(
    'CHAR-09 a cold-start notification still opens its collection when the '
    'notification service is unreachable',
    (tester) async {
      final gateway = _FakeGateway(
        initialMessage: const NotificationEnvelope(
          title: 'Novedades',
          body: 'Anillos nuevos',
          route: NotificationRouteData(
            type: 'collection',
            collectionHandle: _handle,
          ),
        ),
      )..release();
      await _scenario(
        tester,
        gateway,
        (env) async {
          await tester.pumpWidget(
            MonettaApp(
              notificationConfig: _usableConfig,
              gateway: gateway,
              realtimeCatalogSource: env.source,
            ),
          );
          await _bootstrap(tester, gateway);
          await _advance(tester, _scenarioBudget);

          expect(
            gateway.takeInitialMessageCalls,
            1,
            reason: 'a failing GET /v1/notification-config must not stop the '
                'initial message from being read (today the catch in '
                'NotificationController.restore() skips takeInitialMessage).',
          );
          expect(
            find.byType(CollectionScreen, skipOffstage: false),
            findsOneWidget,
            reason: 'the tapped collection route must open exactly once even '
                'when the notification service is down.',
          );
          final screen = tester.widget<CollectionScreen>(
            find.byType(CollectionScreen),
          );
          expect(screen.filter.collectionHandle, _handle);
          expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
        serviceDown: true,
      );
    },
  );

  testWidgets(
    'CHAR-09 (vigente) without an initial route, an unreachable notification '
    'service leaves notifications ready with an error recorded',
    (tester) async {
      final gateway = _FakeGateway()..release();
      await _scenario(
        tester,
        gateway,
        (env) async {
          await tester.pumpWidget(
            MonettaApp(
              notificationConfig: _usableConfig,
              gateway: gateway,
              realtimeCatalogSource: env.source,
            ),
          );
          await _bootstrap(tester, gateway);
          await _advance(tester, _scenarioBudget);

          final controller = NotificationScope.of(
            tester.element(find.byType(HomeScreen)),
          );
          expect(controller.ready, isTrue);
          expect(controller.lastError, isNotNull);
          expect(
            find.byType(CollectionScreen, skipOffstage: false),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
        serviceDown: true,
      );
    },
  );
}
