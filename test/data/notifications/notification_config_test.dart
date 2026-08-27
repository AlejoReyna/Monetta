import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/notifications/notification_config.dart';

void main() {
  group('NotificationConfig.selectFirebaseValue', () {
    test('selects the Android value when present', () {
      expect(
        NotificationConfig.selectFirebaseValue(
          platform: TargetPlatform.android,
          fallbackValue: 'legacy',
          androidValue: 'android',
          iosValue: 'ios',
        ),
        'android',
      );
    });

    test('selects the iOS value when present', () {
      expect(
        NotificationConfig.selectFirebaseValue(
          platform: TargetPlatform.iOS,
          fallbackValue: 'legacy',
          androidValue: 'android',
          iosValue: 'ios',
        ),
        'ios',
      );
    });

    test('keeps the legacy value for missing or unsupported platforms', () {
      expect(
        NotificationConfig.selectFirebaseValue(
          platform: TargetPlatform.android,
          fallbackValue: 'legacy',
          androidValue: '',
          iosValue: 'ios',
        ),
        'legacy',
      );
      expect(
        NotificationConfig.selectFirebaseValue(
          platform: TargetPlatform.macOS,
          fallbackValue: 'legacy',
          androidValue: 'android',
          iosValue: 'ios',
        ),
        'legacy',
      );
    });
  });
}
