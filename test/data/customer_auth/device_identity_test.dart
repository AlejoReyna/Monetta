import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/customer_auth/device_identity.dart';
import 'package:monetta_app/data/customer_auth/secure_token_store.dart';
import 'package:monetta_app/data/local/account_store.dart';
import 'package:monetta_app/data/local/database.dart';

class _UnavailableSecureStore implements SecureTokenStore {
  @override
  Future<void> delete(String key) =>
      Future<void>.error(StateError('Keychain unavailable'));

  @override
  Future<String?> read(String key) =>
      Future<String?>.error(StateError('Keychain unavailable'));

  @override
  Future<void> write(String key, String value) =>
      Future<void>.error(StateError('Keychain unavailable'));
}

void main() {
  late AppDatabase database;

  setUp(() => database = openTestDatabase());
  tearDown(() => database.close());

  test('keeps startup usable when secure storage is unavailable', () async {
    final deviceId = await ensureDeviceId(
      secureStore: _UnavailableSecureStore(),
      deviceStore: DeviceStore(database),
      platform: 'ios',
      appVersion: '0.1.0',
    );

    expect(deviceId, isNotEmpty);
    expect(await DeviceStore(database).byId(deviceId), isNotNull);
  });
}
