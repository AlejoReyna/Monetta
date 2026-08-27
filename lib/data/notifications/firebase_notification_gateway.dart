/// Firebase/App Check boundary. No targeting decisions live in this class.
library;

import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../firebase/firebase_app_bootstrap.dart';
import 'notification_config.dart';
import 'notification_models.dart';

abstract interface class NotificationGateway {
  Future<String?> appCheckToken();
  Future<NotificationPermissionState> permissionState();
  Future<NotificationPermissionState> requestPermission();
  Future<String?> registrationToken();
  Stream<String> get tokenChanges;
  Stream<NotificationEnvelope> get foregroundMessages;
  Stream<NotificationEnvelope> get openedMessages;
  Future<NotificationEnvelope?> takeInitialMessage();
  void dispose();
}

class FirebaseNotificationGateway implements NotificationGateway {
  FirebaseNotificationGateway._(this._messaging) {
    _tokenSubscription = _messaging.onTokenRefresh.listen(_tokens.add);
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      (message) => _foreground.add(_envelope(message)),
    );
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _opened.add(_envelope(message)),
    );
  }

  final FirebaseMessaging _messaging;
  final _tokens = StreamController<String>.broadcast();
  final _foreground = StreamController<NotificationEnvelope>.broadcast();
  final _opened = StreamController<NotificationEnvelope>.broadcast();
  late final StreamSubscription<String> _tokenSubscription;
  late final StreamSubscription<RemoteMessage> _foregroundSubscription;
  late final StreamSubscription<RemoteMessage> _openedSubscription;

  static Future<FirebaseNotificationGateway?> initialize(
    NotificationConfig config,
  ) async {
    if (!config.isUsable) return null;
    await FirebaseAppBootstrap.ensureInitialized(config.firebaseOptions);
    const debugAppCheck = bool.fromEnvironment(
      'FIREBASE_APP_CHECK_DEBUG',
    );
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          debugAppCheck ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: debugAppCheck
          ? AppleProvider.debug
          : AppleProvider.appAttestWithDeviceCheckFallback,
    );
    FirebaseMessaging.onBackgroundMessage(
      monettaFirebaseMessagingBackgroundHandler,
    );
    final messaging = FirebaseMessaging.instance;
    await messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: false,
    );
    return FirebaseNotificationGateway._(messaging);
  }

  @override
  Future<String?> appCheckToken() => FirebaseAppCheck.instance.getToken();

  @override
  Future<NotificationPermissionState> permissionState() async {
    final settings = await _messaging.getNotificationSettings();
    return _permission(settings.authorizationStatus);
  }

  @override
  Future<NotificationPermissionState> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    return _permission(settings.authorizationStatus);
  }

  @override
  Future<String?> registrationToken() => _messaging.getToken();

  @override
  Stream<String> get tokenChanges => _tokens.stream;

  @override
  Stream<NotificationEnvelope> get foregroundMessages => _foreground.stream;

  @override
  Stream<NotificationEnvelope> get openedMessages => _opened.stream;

  @override
  Future<NotificationEnvelope?> takeInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : _envelope(message);
  }

  @override
  void dispose() {
    unawaited(_tokenSubscription.cancel());
    unawaited(_foregroundSubscription.cancel());
    unawaited(_openedSubscription.cancel());
    unawaited(_tokens.close());
    unawaited(_foreground.close());
    unawaited(_opened.close());
  }

  static NotificationEnvelope _envelope(RemoteMessage message) {
    return NotificationEnvelope(
      title: message.notification?.title,
      body: message.notification?.body,
      route: NotificationRouteData.fromData(message.data),
    );
  }

  static NotificationPermissionState _permission(
    AuthorizationStatus status,
  ) {
    return switch (status) {
      AuthorizationStatus.authorized => NotificationPermissionState.granted,
      AuthorizationStatus.provisional =>
        NotificationPermissionState.provisional,
      AuthorizationStatus.denied => NotificationPermissionState.denied,
      AuthorizationStatus.notDetermined =>
        NotificationPermissionState.notDetermined,
    };
  }
}

@pragma('vm:entry-point')
Future<void> monettaFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  if (Firebase.apps.isNotEmpty) return;
  final config = NotificationConfig.fromEnvironment();
  if (config.hasFirebaseOptions) {
    await FirebaseAppBootstrap.ensureInitialized(config.firebaseOptions);
  }
}
