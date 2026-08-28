library;

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

/// Initializes the default Firebase app at most once per isolate.
///
/// Notifications and the real-time catalog share this boundary. Keeping the
/// guard here prevents each feature from racing its own `initializeApp` call.
abstract final class FirebaseAppBootstrap {
  static final SingleFlightInitializer<FirebaseApp> _initialization =
      SingleFlightInitializer<FirebaseApp>();

  static Future<FirebaseApp> ensureInitialized(FirebaseOptions options) =>
      _initialization.run(() {
        if (Firebase.apps.isNotEmpty) return Future.value(Firebase.app());
        return Firebase.initializeApp(options: options);
      });
}

/// Memoizes one initialization Future. Concurrent callers receive the exact
/// same Future; failures clear it so a later reconnect can retry safely.
class SingleFlightInitializer<T> {
  Future<T>? _future;

  Future<T> run(Future<T> Function() initialize) {
    final current = _future;
    if (current != null) return current;

    final completer = Completer<T>();
    final attempt = completer.future;
    _future = attempt;
    Future<T>.sync(initialize).then(
      completer.complete,
      onError: (Object error, StackTrace stackTrace) {
        if (identical(_future, attempt)) _future = null;
        completer.completeError(error, stackTrace);
      },
    );
    return attempt;
  }
}
