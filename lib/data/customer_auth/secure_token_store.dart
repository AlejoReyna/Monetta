/// A minimal key-value seam over `flutter_secure_storage`, injected the same
/// way `data/local`'s Drift connection is — so tests exercise the real
/// session logic against an in-memory fake instead of a platform channel
/// (the Keychain/Keystore backing has nothing left to prove in this app's
/// tests; `flutter_secure_storage` is a widely used, independently tested
/// plugin).
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SecureTokenStore {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
}

class FlutterSecureTokenStore implements SecureTokenStore {
  const FlutterSecureTokenStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
