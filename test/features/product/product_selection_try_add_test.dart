import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/product/product_selection.dart';
import 'package:monetta_app/main.dart';

import '../../support/product_screen_harness.dart';
import '../../support/scripted_catalog_store.dart';

// FICHA-T2, CART-05: `tryAddSelectionToBag` and its result type (BRIEF 3).
//
// Kept apart on purpose: the symbols do not exist yet, so this file does not
// compile until the helper lands. Everything that can run today lives in
// `product_selection_purchase_test.dart`.

Future<(ScriptedCatalogStore, BuildContext)> _mount(
  WidgetTester tester,
  Product product,
) async {
  setPhoneView(tester);
  final store =
      await loadStore(ScriptedCatalogStore(database: openTestDatabase()));
  addProducts(store, [product]);
  late BuildContext captured;
  await tester.pumpWidget(
    StoreScope(
      notifier: store,
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  return (store, captured);
}

void main() {
  testWidgets('CART-05 added carries the chosen variant id and adds one unit',
      (tester) async {
    final product = syntheticProduct(variants: chipVariants());
    final (store, context) = await _mount(tester, product);

    final result = await tryAddSelectionToBag(context, product, 2);

    expect(result.status, BagAddStatus.added);
    expect(result.variantId, 'v-grande');
    expect(result.error, isNull);
    expect(store.addCalls, 1);
    expect(store.bagQuantity, 1);
    expect(store.bagLines.single.variant.id, 'v-grande');
  });

  testWidgets('CART-05 soldOut never reaches the store', (tester) async {
    final product = syntheticProduct(
      variants: [syntheticVariant(id: 'v-agotada', available: false)],
    );
    final (store, context) = await _mount(tester, product);

    final result = await tryAddSelectionToBag(context, product, 0);

    expect(result.status, BagAddStatus.soldOut);
    expect(store.addCalls, 0);
    expect(store.bagQuantity, 0);
  });

  testWidgets('CART-05 a sold-out choice among available ones is soldOut too',
      (tester) async {
    final product = syntheticProduct(
      variants: chipVariants(available: [true, false, true]),
    );
    final (store, context) = await _mount(tester, product);

    final result = await tryAddSelectionToBag(context, product, 1);

    expect(result.status, BagAddStatus.soldOut);
    expect(store.addCalls, 0);
    expect(store.bagQuantity, 0);
  });

  testWidgets('CART-05 unavailable leaves the bag alone', (tester) async {
    final product = syntheticProduct(variants: const []);
    final (store, context) = await _mount(tester, product);

    final result = await tryAddSelectionToBag(context, product, 0);

    expect(result.status, BagAddStatus.unavailable);
    expect(store.bagQuantity, 0);
  });

  testWidgets('CART-05 failed carries the error and leaves the bag empty',
      (tester) async {
    final product = syntheticProduct();
    final (store, context) = await _mount(tester, product);
    final error = StateError('storage unavailable');
    store.failWith = error;

    final result = await tryAddSelectionToBag(context, product, 0);

    expect(result.status, BagAddStatus.failed);
    expect(result.error, same(error));
    expect(store.addCalls, 1);
    expect(store.bagQuantity, 0);
  });
}
