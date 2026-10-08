/// CHAR-04: characterization of the guest -> account bag merge.
///
/// `BagStore.mergeDeviceItemsIntoAccount` does not add quantities: for a
/// variant present in both scopes, the guest row replaces the account row, and
/// no cap is applied (`CatalogStore.updateBagQuantity` caps at 10, this path
/// does not). These tests pin that behaviour so RF-50 (E4: add with a cap of
/// 10) has to change them explicitly.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
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

  test(
      'CHAR-04 (vigente, cambia en RF-50 según E4) la cantidad del invitado '
      'reemplaza a la de la cuenta en vez de sumarse', () async {
    await bag.upsert(
      productId: 'p-account',
      variantId: 'v1',
      quantity: 2,
      accountId: 'A',
    );
    await bag.upsert(productId: 'p-guest', variantId: 'v1', quantity: 1);

    await bag.mergeDeviceItemsIntoAccount('A');

    final account = await bag.all(accountId: 'A');
    expect(_quantities(account), {'v1': 1});
    expect(
      account.single.productId,
      'p-guest',
      reason: 'the guest row replaces the whole account row',
    );
    expect(await bag.all(), isEmpty, reason: 'the guest has no lines left');
  });

  test(
      'CHAR-04 (vigente, cambia en RF-50 según E4) la fusión no aplica '
      'ningún tope: V x15 del invitado sustituye a V x3 de la cuenta',
      () async {
    await bag.upsert(productId: 'p1', variantId: 'v1', quantity: 15);
    await bag.upsert(
      productId: 'p1',
      variantId: 'v1',
      quantity: 3,
      accountId: 'A',
    );

    await bag.mergeDeviceItemsIntoAccount('A');

    expect(_quantities(await bag.all(accountId: 'A')), {'v1': 15});
    expect(await bag.all(), isEmpty);
  });

  test(
      'CHAR-04 (vigente, cambia en RF-50 según E4) la fusión añade las '
      'variantes sólo del invitado, conserva las sólo de la cuenta y no toca '
      'a otra cuenta', () async {
    await bag.upsert(productId: 'p1', variantId: 'v1', quantity: 1);
    await bag.upsert(productId: 'p3', variantId: 'v3', quantity: 4);
    await bag.upsert(
      productId: 'p1',
      variantId: 'v1',
      quantity: 2,
      accountId: 'A',
    );
    await bag.upsert(
      productId: 'p2',
      variantId: 'v2',
      quantity: 5,
      accountId: 'A',
    );
    await bag.upsert(
      productId: 'p1',
      variantId: 'v1',
      quantity: 7,
      accountId: 'B',
    );

    await bag.mergeDeviceItemsIntoAccount('A');

    expect(_quantities(await bag.all(accountId: 'A')), {
      'v1': 1,
      'v2': 5,
      'v3': 4,
    });
    expect(_quantities(await bag.all(accountId: 'B')), {'v1': 7});
    expect(await bag.all(), isEmpty);
  });

  test(
      'CHAR-04 (vigente, cambia en RF-50 según E4) lo que ve la app: tras la '
      'fusión y setAccountScope, bagLines y bagQuantity reflejan la cantidad '
      'del invitado', () async {
    final store = CatalogStore(database: db, shopDomain: 'monetta.mx');
    await store.loadFromAsset();
    await store.syncWithShopify();

    final withVariants = store.products
        .where((product) => product.variants.isNotEmpty)
        .take(2)
        .toList();
    expect(withVariants, hasLength(2));
    final shared = withVariants[0];
    final other = withVariants[1];
    final sharedVariant = shared.variants.first.id;
    final otherVariant = other.variants.first.id;

    // Account A already had lines: the shared variant x3 and another x1.
    await bag.upsert(
      productId: shared.id,
      variantId: sharedVariant,
      quantity: 3,
      accountId: 'A',
    );
    await bag.upsert(
      productId: other.id,
      variantId: otherVariant,
      quantity: 1,
      accountId: 'A',
    );

    // The guest adds the shared variant twice through the store.
    await store.addToBag(shared, variantId: sharedVariant);
    await store.addToBag(shared, variantId: sharedVariant);
    expect(store.bagQuantity, 2);

    await bag.mergeDeviceItemsIntoAccount('A');
    await store.setAccountScope('A');

    final byVariant = {
      for (final line in store.bagLines) line.variant.id: line.quantity,
    };
    expect(byVariant, {sharedVariant: 2, otherVariant: 1});
    expect(
      store.bagQuantity,
      3,
      reason: 'the guest quantity (2) replaced the account quantity (3)',
    );

    await store.setAccountScope(null);
    expect(store.bagLines, isEmpty, reason: 'the guest bag is now empty');
    expect(store.bagQuantity, 0);

    await pumpEventQueue();
    store.dispose();
  });
}
