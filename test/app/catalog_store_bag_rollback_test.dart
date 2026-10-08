/// CART-06: `CatalogStore.addToBag` mutates memory before it persists, so a
/// failed write must be undone (BRIEF 5) or the shopper sees a phantom unit.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/local/bag_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/domain/product.dart';

const _first = 'gid://shopify/ProductVariant/R1';
const _second = 'gid://shopify/ProductVariant/R2';

Product _product() => Product(
      id: 'gid://shopify/Product/rollback-1',
      handle: 'rollback-1',
      title: 'Bolsa Rollback',
      vendor: 'Monetta',
      productType: 'Bolsa',
      tags: const [],
      images: const [],
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
      variants: const [
        ProductVariant(
          id: _first,
          title: 'Negro',
          price: 100,
          available: true,
        ),
        ProductVariant(
          id: _second,
          title: 'Beige',
          price: 200,
          available: true,
        ),
      ],
    );

Future<(CatalogStore, AppDatabase, Product)> _loaded() async {
  final db = openTestDatabase();
  final store = CatalogStore(database: db);
  await store.loadFromAsset();
  final product = _product();
  store.products = [...store.products, product];
  return (store, db, product);
}

/// Makes every bag write fail while the database stays open, and lets the
/// test undo it.
Future<void> _breakBagTable(AppDatabase db) =>
    db.customStatement('ALTER TABLE bag_lines RENAME TO bag_lines_away');

Future<void> _repairBagTable(AppDatabase db) =>
    db.customStatement('ALTER TABLE bag_lines_away RENAME TO bag_lines');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'CART-06 a failed write against a closed database leaves no phantom '
      'unit', () async {
    final (store, db, product) = await _loaded();
    await db.close();

    await expectLater(
      store.addToBag(product, variantId: _first),
      throwsA(anything),
    );

    expect(store.bagQuantity, 0);
    expect(store.bagLines, isEmpty);
  });

  test('CART-06 a failed write is undone and the next add counts from zero',
      () async {
    final (store, db, product) = await _loaded();
    addTearDown(db.close);

    await _breakBagTable(db);
    await expectLater(
      store.addToBag(product, variantId: _first),
      throwsA(anything),
    );
    expect(store.bagQuantity, 0);
    expect(store.bagLines, isEmpty);

    await _repairBagTable(db);
    await store.addToBag(product, variantId: _first);
    expect(store.bagQuantity, 1, reason: 'one unit, not two');
    expect(store.bagLines.single.variant.id, _first);
    final rows = await BagStore(db).all();
    expect(rows.single.quantity, 1);
  });

  test('CART-06 a failed write only takes back its own unit', () async {
    final (store, db, product) = await _loaded();
    addTearDown(db.close);
    await store.addToBag(product, variantId: _first);

    await _breakBagTable(db);
    await expectLater(
      store.addToBag(product, variantId: _first),
      throwsA(anything),
    );

    expect(store.bagQuantity, 1);
    expect(store.bagLines.single.quantity, 1);
    await _repairBagTable(db);
    final rows = await BagStore(db).all();
    expect(rows.single.quantity, 1);
  });

  test('CART-06 a failed write of one variant does not touch another',
      () async {
    final (store, db, product) = await _loaded();
    addTearDown(db.close);
    await store.addToBag(product, variantId: _first);

    await _breakBagTable(db);
    await expectLater(
      store.addToBag(product, variantId: _second),
      throwsA(anything),
    );

    expect(store.bagQuantity, 1);
    expect(store.bagLines.map((line) => line.variant.id), [_first]);
  });

  test(
      'CART-06 a late failure of account A never touches the bag of account B '
      '(invariant 9)', () async {
    final (store, db, product) = await _loaded();
    addTearDown(db.close);
    await BagStore(db).upsert(
      productId: product.id,
      variantId: _first,
      quantity: 3,
      accountId: 'B',
    );
    await store.setAccountScope('A');
    // Only the writes of account A are refused; reads and B's rows still work.
    await db.customStatement(
      'CREATE TRIGGER refuse_a_writes BEFORE INSERT ON bag_lines '
      "WHEN NEW.account_id = 'A' "
      "BEGIN SELECT RAISE(ABORT, 'write refused'); END",
    );

    final pending = expectLater(
      store.addToBag(product, variantId: _first),
      throwsA(anything),
    );
    await store.setAccountScope('B');
    await pending;

    expect(store.bagQuantity, 3, reason: 'B keeps exactly its own bag');
    expect(store.bagLines.single.variant.id, _first);
    expect(store.bagLines.single.quantity, 3);
    final rows = await BagStore(db).all(accountId: 'B');
    expect(rows.single.quantity, 3);
  });

  test('CART-06 (vigente) concurrent adds of the same variant both count',
      () async {
    final (store, db, product) = await _loaded();
    addTearDown(db.close);

    await Future.wait([
      store.addToBag(product, variantId: _first),
      store.addToBag(product, variantId: _first),
    ]);

    expect(store.bagQuantity, 2);
    final rows = await BagStore(db).all();
    expect(rows.single.quantity, 2);
  });
}
