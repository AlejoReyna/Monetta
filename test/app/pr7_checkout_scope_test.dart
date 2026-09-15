import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/shopify_checkout_coordinator.dart';
import 'package:monetta_app/data/local/bag_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/shopify/cart/cart_session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final next in <String?>['B', null]) {
    test(
        'R5 delayed A completion after switch to $next preserves active bag and added quantities',
        () async {
      final db = openTestDatabase();
      final store = CatalogStore(database: db, shopDomain: 'shop.example');
      addTearDown(store.dispose);
      await store.loadFromAsset();
      final product = store.products.firstWhere((p) => p.isInStock);
      final variant = product.variants.firstWhere((v) => v.available).id;
      await store.setAccountScope('A');
      await store.addToBag(product, variantId: variant);
      final purchase = CheckoutPurchase(
        scope: const CartSessionScope.authenticated(
          shopDomain: 'shop.example',
          localAccountId: 'A',
        ),
        operationId: 'purchase-1',
        quantities: {variant: 1},
      );
      await store.addToBag(product, variantId: variant);
      await store.setAccountScope(next);
      await store.addToBag(product, variantId: variant);
      await store.applyCheckoutPurchase(purchase);
      expect(store.bagQuantity, 1);
      expect((await BagStore(db).all(accountId: next)).single.quantity, 1);
      expect((await BagStore(db).all(accountId: 'A')).single.quantity, 1);
      await store.applyCheckoutPurchase(purchase);
      expect((await BagStore(db).all(accountId: 'A')).single.quantity, 1);
      await store.setAccountScope('A');
      expect(store.bagQuantity, 1);
    });
  }
  test(
      'R5 transaction failure rolls back subtraction; retry once and lower quantity clamps to zero',
      () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final bag = BagStore(db);
    await bag.upsert(
      productId: 'p',
      variantId: 'v',
      quantity: 1,
      accountId: 'A',
    );
    await bag.upsert(
      productId: 'q',
      variantId: 'new',
      quantity: 3,
      accountId: 'A',
    );
    await db.customStatement(
      "CREATE TRIGGER fail_receipt BEFORE INSERT ON checkout_receipts BEGIN SELECT RAISE(ABORT, 'disk failure simulation'); END",
    );
    Future<void> apply() => bag.applyPurchase(
          operationId: 'op',
          shopDomain: 'shop',
          accountId: 'A',
          quantities: {'v': 2},
        );
    await expectLater(apply(), throwsA(anything));
    expect((await bag.all(accountId: 'A')).first.quantity, 1);
    await db.customStatement('DROP TRIGGER fail_receipt');
    await apply();
    await apply();
    expect((await bag.all(accountId: 'A')).single.variantId, 'new');
    expect((await bag.all(accountId: 'A')).single.quantity, 3);
  });
}
