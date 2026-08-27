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
}
