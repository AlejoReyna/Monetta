/// RF-41: the `Command` that ViewModel actions are built on.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/command.dart';

void main() {
  test('RF-41 Command0 reports running, then completed with its value',
      () async {
    final gate = Completer<int>();
    final command = Command0<int>(() => gate.future);
    final seen = <String>[];
    command.addListener(() {
      seen.add('running=${command.running} completed=${command.completed}');
    });

    final run = command.execute();
    expect(command.running, isTrue);
    expect(command.completed, isFalse);
    expect(command.error, isNull);

    gate.complete(7);
    await run;

    expect(command.running, isFalse);
    expect(command.completed, isTrue);
    expect(command.value, 7);
    expect(command.error, isNull);
    expect(seen, <String>[
      'running=true completed=false',
      'running=false completed=true',
    ]);
  });

  test('RF-41 Command0 records the error instead of throwing it', () async {
    final command = Command0<void>(() async => throw StateError('boom'));

    await command.execute();

    expect(command.running, isFalse);
    expect(command.completed, isFalse);
    expect(command.error, isA<StateError>());
    expect(command.stackTrace, isNotNull);
  });

  test('RF-41 Command0 records an action that throws before returning a future',
      () async {
    final command = Command0<void>(() => throw StateError('sync'));

    await command.execute();

    expect(command.error, isA<StateError>());
    expect(command.running, isFalse);
  });

  test('RF-41 Command0 ignores execute while it is running', () async {
    final gate = Completer<void>();
    var calls = 0;
    final command = Command0<void>(() {
      calls++;
      return gate.future;
    });

    final first = command.execute();
    final second = command.execute();
    expect(calls, 1);

    gate.complete();
    await Future.wait(<Future<void>>[first, second]);
    expect(calls, 1);

    await command.execute();
    expect(calls, 2, reason: 'it can run again once it has finished');
  });

  test('RF-41 Command1 passes its argument to the action', () async {
    final received = <String>[];
    final command = Command1<String, String>((value) async {
      received.add(value);
      return value.toUpperCase();
    });

    await command.execute('uno');
    await command.execute('dos');

    expect(received, <String>['uno', 'dos']);
    expect(command.value, 'DOS');
    expect(command.completed, isTrue);
  });

  test('RF-41 Command1 starts the next run with a clean outcome', () async {
    var fail = true;
    final command = Command1<void, int>((_) async {
      if (fail) throw StateError('first');
    });

    await command.execute(1);
    expect(command.error, isNotNull);

    fail = false;
    final run = command.execute(2);
    expect(command.error, isNull);
    expect(command.completed, isFalse);
    await run;
    expect(command.completed, isTrue);
    expect(command.error, isNull);
  });

  test('RF-41 Command clearResult forgets the last outcome', () async {
    final command = Command0<int>(() async => 1);
    await command.execute();
    expect(command.completed, isTrue);

    var notified = 0;
    command.addListener(() => notified++);
    command.clearResult();

    expect(command.completed, isFalse);
    expect(command.value, isNull);
    expect(notified, 1);

    command.clearResult();
    expect(notified, 1, reason: 'nothing to forget, nothing to announce');
  });

  test('RF-41 Command finishing after dispose does not notify', () async {
    final gate = Completer<void>();
    final command = Command0<void>(() => gate.future);
    final run = command.execute();

    command.dispose();
    gate.complete();

    // A notification on a disposed notifier would throw here.
    await expectLater(run, completes);
  });
}
