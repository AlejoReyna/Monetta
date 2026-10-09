library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/repositories/catalog_write_coordinator.dart';

void main() {
  test('Firestore live blocks every queued delta writer', () async {
    final coordinator = CatalogWriteCoordinator(expectsFirestore: true);
    await coordinator.runFirestoreWrite(() async => 'firestore');

    var deltaWrites = 0;
    final result = await coordinator.runDeltaWrite(
      write: () async {
        deltaWrites += 1;
        return 'delta';
      },
      blocked: () => 'blocked',
    );

    expect(coordinator.authority, CatalogAuthority.firestoreLive);
    expect(result, 'blocked');
    expect(deltaWrites, 0);
  });

  test('fallback and reconnect writes are serialized; Firestore wins',
      () async {
    final coordinator = CatalogWriteCoordinator(expectsFirestore: true)
      ..markFirestoreUnavailable();
    final releaseDelta = Completer<void>();
    final order = <String>[];
    var activeWriters = 0;
    var maximumWriters = 0;

    final delta = coordinator.runDeltaWrite(
      write: () async {
        activeWriters += 1;
        maximumWriters = activeWriters;
        order.add('delta-start');
        await releaseDelta.future;
        order.add('delta-end');
        activeWriters -= 1;
        return 'delta';
      },
      blocked: () => 'blocked',
    );
    await Future<void>.delayed(Duration.zero);

    final firestore = coordinator.runFirestoreWrite(() async {
      activeWriters += 1;
      if (activeWriters > maximumWriters) maximumWriters = activeWriters;
      order.add('firestore');
      activeWriters -= 1;
      return 'firestore';
    });
    releaseDelta.complete();

    expect(await delta, 'delta');
    expect(await firestore, 'firestore');
    expect(maximumWriters, 1);
    expect(order, ['delta-start', 'delta-end', 'firestore']);
    expect(coordinator.authority, CatalogAuthority.firestoreLive);
  });

  test(
      'CHAR-14b queued delta policy is checked after Firestore gains authority',
      () async {
    final coordinator = CatalogWriteCoordinator(expectsFirestore: true)
      ..markFirestoreUnavailable();
    final started = Completer<void>();
    final release = Completer<void>();
    final firestore = coordinator.runFirestoreWrite(() async {
      started.complete();
      await release.future;
    });
    await started.future;
    expect(coordinator.allowsDelta, isTrue);
    var writes = 0;
    final focusedPolicy = coordinator.runDeltaWrite(
      write: () async {
        writes++;
        return true;
      },
      blocked: () => false,
    );
    release.complete();
    await firestore;
    expect(await focusedPolicy, isFalse);
    expect(writes, 0);
    expect(coordinator.authority, CatalogAuthority.firestoreLive);
  });

  test('CHAR-14b status writes serialize without changing Firestore authority',
      () async {
    final coordinator = CatalogWriteCoordinator(expectsFirestore: true);
    final started = Completer<void>();
    final release = Completer<void>();
    final order = <String>[];
    final firestore = coordinator.runFirestoreWrite(() async {
      started.complete();
      await release.future;
      order.add('firestore');
    });
    await started.future;
    final status = coordinator.runCacheWrite(() async => order.add('status'));
    expect(order, isEmpty);
    release.complete();
    await firestore;
    await status;
    expect(order, ['firestore', 'status']);
    expect(coordinator.authority, CatalogAuthority.firestoreLive);
  });

  test('CHAR-14b a failed cache writer releases the queue for the next write',
      () async {
    final coordinator = CatalogWriteCoordinator(expectsFirestore: false);
    final failed = coordinator.runCacheWrite<void>(() async {
      throw StateError('write failed');
    });
    final next = coordinator.runDeltaWrite(
      write: () async => 'written',
      blocked: () => 'blocked',
    );
    await expectLater(failed, throwsStateError);
    expect(await next, 'written');
    expect(coordinator.authority, CatalogAuthority.localOnly);
  });
}
