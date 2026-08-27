library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/firebase/firebase_app_bootstrap.dart';

void main() {
  test('concurrent callers share the exact initialization Future', () async {
    final initializer = SingleFlightInitializer<int>();
    final completion = Completer<int>();
    var calls = 0;

    Future<int> initialize() {
      calls += 1;
      return completion.future;
    }

    final first = initializer.run(initialize);
    final second = initializer.run(initialize);
    expect(identical(first, second), isTrue);
    expect(calls, 1);

    completion.complete(42);
    expect(await first, 42);
    expect(await initializer.run(initialize), 42);
    expect(calls, 1);
  });

  test('a failed initialization is cleared so a later call can retry',
      () async {
    final initializer = SingleFlightInitializer<int>();
    var calls = 0;

    Future<int> initialize() async {
      calls += 1;
      if (calls == 1) throw StateError('temporary failure');
      return 7;
    }

    await expectLater(initializer.run(initialize), throwsStateError);
    expect(await initializer.run(initialize), 7);
    expect(calls, 2);
  });
}
