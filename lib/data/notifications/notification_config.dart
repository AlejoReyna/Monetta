/// Build-time configuration for first-party notification delivery.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class NotificationConfig {
  const NotificationConfig({
    required this.enabled,
    required this.apiBaseUrl,
    required this.firebaseApiKey,
    required this.firebaseAppId,
    required this.firebaseProjectId,
    required this.firebaseMessagingSenderId,
    required this.firebaseStorageBucket,
    required this.iosBundleId,
    required this.timezone,
  });

  final bool enabled;
  final Uri? apiBaseUrl;
  final String firebaseApiKey;
  final String firebaseAppId;
  final String firebaseProjectId;
  final String firebaseMessagingSenderId;
  final String firebaseStorageBucket;
  final String iosBundleId;
  final String timezone;

  bool get isUsable => enabled && apiBaseUrl != null && hasFirebaseOptions;

  /// Firebase client configuration is shared by notifications and Firestore.
  /// It must not depend on notification delivery being enabled.
  bool get hasFirebaseOptions =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseProjectId.isNotEmpty &&
      firebaseMessagingSenderId.isNotEmpty;

  FirebaseOptions get firebaseOptions => FirebaseOptions(
        apiKey: firebaseApiKey,
        appId: firebaseAppId,
        messagingSenderId: firebaseMessagingSenderId,
        projectId: firebaseProjectId,
        storageBucket:
            firebaseStorageBucket.isEmpty ? null : firebaseStorageBucket,
        iosBundleId: iosBundleId,
      );

  factory NotificationConfig.fromEnvironment({
    String? fallbackBaseUrl,
    TargetPlatform? targetPlatform,
  }) {
    const enabled = bool.fromEnvironment('NOTIFICATIONS_ENABLED');
    const notificationBaseUrl = String.fromEnvironment(
      'NOTIFICATIONS_API_BASE_URL',
    );
    const fallbackFirebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const fallbackFirebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
    const androidFirebaseApiKey =
        String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
    const androidFirebaseAppId =
        String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
    const iosFirebaseApiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');
    const iosFirebaseAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
    const appEnvironment = String.fromEnvironment('APP_ENV');
    final rawBaseUrl =
        notificationBaseUrl.isEmpty ? fallbackBaseUrl : notificationBaseUrl;
    final platform = targetPlatform ?? defaultTargetPlatform;
    return NotificationConfig(
      enabled: enabled,
      apiBaseUrl: rawBaseUrl == null || rawBaseUrl.isEmpty
          ? null
          : Uri.tryParse(rawBaseUrl),
      firebaseApiKey: selectFirebaseValue(
        platform: platform,
        fallbackValue: fallbackFirebaseApiKey,
        androidValue: androidFirebaseApiKey,
        iosValue: iosFirebaseApiKey,
      ),
      firebaseAppId: selectFirebaseValue(
        platform: platform,
        fallbackValue: fallbackFirebaseAppId,
        androidValue: androidFirebaseAppId,
        iosValue: iosFirebaseAppId,
      ),
      firebaseProjectId: const String.fromEnvironment('FIREBASE_PROJECT_ID'),
      firebaseMessagingSenderId:
          const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
      firebaseStorageBucket:
          const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
      iosBundleId: appEnvironment == 'staging'
          ? 'mx.monetta.monettaApp.staging'
          : 'mx.monetta.monettaApp',
      timezone: const String.fromEnvironment(
        'NOTIFICATIONS_TIMEZONE',
        defaultValue: 'America/Monterrey',
      ),
    );
  }

  /// Selects a platform-specific Firebase option while keeping the original
  /// single-value dart-define compatible with existing builds.
  @visibleForTesting
  static String selectFirebaseValue({
    required TargetPlatform platform,
    required String fallbackValue,
    required String androidValue,
    required String iosValue,
  }) {
    return switch (platform) {
      TargetPlatform.android when androidValue.isNotEmpty => androidValue,
      TargetPlatform.iOS when iosValue.isNotEmpty => iosValue,
      _ => fallbackValue,
    };
  }

  static const disabled = NotificationConfig(
    enabled: false,
    apiBaseUrl: null,
    firebaseApiKey: '',
    firebaseAppId: '',
    firebaseProjectId: '',
    firebaseMessagingSenderId: '',
    firebaseStorageBucket: '',
    iosBundleId: 'mx.monetta.monettaApp',
    timezone: 'America/Monterrey',
  );
}
