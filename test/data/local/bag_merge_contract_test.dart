/// CONTRACT-07: the guest -> account merge contract (RF-53, E4).
///
/// Both sign-in paths (`customer_session_repository.dart:132` and
/// `system_account_session_repository.dart:110`) route through the same
/// `BagStore.mergeDeviceItemsIntoAccount` primitive, so this file pins that
/// primitive on a real Drift database: sums with a cap of 10, repetition and
/// concurrency converge, and a mid-merge failure rolls everything back. The
/// rollback and product-attribution cases already hold and guard the rewrite;
/// the sum cases are red until the store stops replacing.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/local/bag_store.dart';
import 'package:monetta_app/data/local/database.dart';

Map<String, int> _quantities(List<BagLineRow> rows) => {
      for (final row in rows) row.variantId: row.quantity,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late BagStore bag;

  setUp(() {
    db = openTestDatabase();
    bag = BagStore(db);
  });

  tearDown(() => db.close());

  test('CONTRACT-07 the merge sums with a cap of 10 (customer account)',
      () async {
    await bag.upsert(
      productId: 'p1',
      variantId: 'v1',
      quantity: 3,
      accountId: 'A',
    );
    await bag.upsert(productId: 'p1', variantId: 'v1', quantity: 2);

    await bag.mergeDeviceItemsIntoAccount('A');
    expect(_quantities(await bag.all(accountId: 'A')), {'v1': 5});

    await bag.upsert(productId: 'p1', variantId: 'v1', quantity: 9);
    await bag.mergeDeviceItemsIntoAccount('A');
    expect(_quantities(await bag.all(accountId: 'A')), {'v1': 10});
    expect(await bag.all(), isEmpty);
  });

  test('CONTRACT-07 the merge sums the same way for a system account id',
      () async {
    await bag.upsert(
      productId: 'p1',
      variantId: 'v1',
      quantity: 1,
      accountId: 'sys_9f2',
    );
    await bag.upsert(productId: 'p1', variantId: 'v1', quantity: 4);

    await bag.mergeDeviceItemsIntoAccount('sys_9f2');

    expect(_quantities(await bag.all(accountId: 'sys_9f2')), {'v1': 5});
    expect(await bag.all(), isEmpty);
  });

  test('CONTRACT-07 repeated merges accumulate until the cap', () async {
    await bag.upsert(
      productId: 'p1',
      variantId: 'v1',
      quantity: 6,
      accountId: 'A',
    );

    await bag.upsert(productId: 'p1', variantId: 'v1', quantity: 2);
    await bag.mergeDeviceItemsIntoAccount('A');
    expect(_quantities(await bag.all(accountId: 'A')), {'v1': 8});

    await bag.upsert(productId: 'p1', variantId: 'v1', quantity: 5);
    await bag.mergeDeviceItemsIntoAccount('A');
    expect(_quantities(await bag.all(accountId: 'A')), {'v1': 10});

    // Nothing left to merge: a no-op, not a reset.
    await bag.mergeDeviceItemsIntoAccount('A');
    expect(_quantities(await bag.all(accountId: 'A')), {'v1': 10});
  });

  test('CONTRACT-07 concurrent merges converge to a single sum', () async {
    await bag.upsert(
      productId: 'p1',
      variantId: 'v1',
      quantity: 3,
      accountId: 'A',
    );
    await bag.upsert(productId: 'p1', variantId: 'v1', quantity: 2);

    await Future.wait([
      bag.mergeDeviceItemsIntoAccount('A'),
      bag.mergeDeviceItemsIntoAccount('A'),
    ]);

    expect(_quantities(await bag.all(accountId: 'A')), {'v1': 5});
    expect(await bag.all(), isEmpty);
  });

  test('CONTRACT-07 a failing merge rolls everything back', () async {
    await bag.upsert(
      productId: 'p1',
      variantId: 'v1',
      quantity: 3,
      accountId: 'A',
    );
    await bag.upsert(productId: 'p1', variantId: 'v1', quantity: 2);
    await db.customStatement(
      'CREATE TRIGGER fail_merge BEFORE INSERT ON bag_lines '
      "BEGIN SELECT RAISE(ABORT, 'merge failed'); END",
    );

    await expectLater(
      bag.mergeDeviceItemsIntoAccount('A'),
      throwsA(
        predicate<Object>((e) => e.toString().contains('merge failed')),
      ),
    );
    expect(_quantities(await bag.all(accountId: 'A')), {'v1': 3});
    expect(_quantities(await bag.all()), {'v1': 2});
  });

  test('CONTRACT-07 the variant wins by key on a product conflict', () async {
    await bag.upsert(
      productId: 'p-account',
      variantId: 'v1',
      quantity: 2,
      accountId: 'A',
    );
    await bag.upsert(productId: 'p-guest', variantId: 'v1', quantity: 1);

    await bag.mergeDeviceItemsIntoAccount('A');

    // Only the product attribution is pinned here; the summed quantity is
    // covered by the other cases. This already holds and must survive.
    final account = await bag.all(accountId: 'A');
    expect(account.single.productId, 'p-guest');
  });
}
