import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/checkout/checkout_screen.dart';
import 'package:monetta_app/features/product/product_selection.dart';
import 'package:monetta_app/main.dart';

import '../../support/product_screen_harness.dart';
import '../../support/scripted_catalog_store.dart';

// FICHA-T2, CART-05: the shared purchase helper of `product_selection.dart`
// guards stock (BRIEF 3). These tests use only the functions that exist today
// (`addSelectionToBag`, `addToBagAndShowMiniCart`, `buyNowOpenBag`); the new
// `tryAddSelectionToBag` result type is pinned in
// `product_selection_try_add_test.dart`, which cannot compile until it exists.

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

Product _soldOut() => syntheticProduct(
      variants: [syntheticVariant(id: 'v-agotada', available: false)],
    );

void main() {
  group('CART-05 addSelectionToBag (signature kept)', () {
    testWidgets('CART-05 adds one unit and returns the chosen variant id',
        (tester) async {
      final product = syntheticProduct(variants: chipVariants());
      final (store, context) = await _mount(tester, product);

      final id = await addSelectionToBag(context, product, 1);

      expect(id, 'v-mediana');
      expect(store.addCalls, 1);
      expect(store.bagQuantity, 1);
      expect(store.bagLines.single.variant.id, 'v-mediana');
    });

    testWidgets('CART-05 a sold-out variant is not added and returns null',
        (tester) async {
      final product = _soldOut();
      final (store, context) = await _mount(tester, product);

      final id = await addSelectionToBag(context, product, 0);

      expect(id, isNull);
      expect(store.addCalls, 0, reason: 'the stock guard is in the helper');
      expect(store.bagQuantity, 0);
    });

    testWidgets('CART-05 a piece without variants leaves the bag untouched',
        (tester) async {
      final product = syntheticProduct(variants: const []);
      final (store, context) = await _mount(tester, product);

      final id = await addSelectionToBag(context, product, 0);

      expect(id, isNull);
      expect(store.bagQuantity, 0);
    });

    testWidgets('CART-05 a failing store yields null instead of throwing',
        (tester) async {
      final product = syntheticProduct();
      final (store, context) = await _mount(tester, product);
      store.failWith = StateError('storage unavailable');

      final id = await addSelectionToBag(context, product, 0);

      expect(id, isNull);
      expect(store.bagQuantity, 0);
    });
  });

  group('CART-05 the callers go through the guard', () {
    testWidgets(
        'CART-05 addToBagAndShowMiniCart adds and confirms an available '
        'variant', (tester) async {
      final product = syntheticProduct();
      final (store, context) = await _mount(tester, product);

      unawaited(addToBagAndShowMiniCart(context, product, 0));
      await tester.pumpAndSettle();

      expect(store.bagQuantity, 1);
      expect(find.text('En tu bolsa'), findsOneWidget);
    });

    testWidgets(
        'CART-05 addToBagAndShowMiniCart shows no mini cart for a sold-out '
        'variant', (tester) async {
      final product = _soldOut();
      final (store, context) = await _mount(tester, product);

      unawaited(addToBagAndShowMiniCart(context, product, 0));
      await tester.pumpAndSettle();

      expect(store.addCalls, 0);
      expect(store.bagQuantity, 0);
      expect(find.text('En tu bolsa'), findsNothing);
    });

    testWidgets('CART-05 buyNowOpenBag adds and opens the bag', (tester) async {
      final product = syntheticProduct();
      final (store, context) = await _mount(tester, product);

      unawaited(buyNowOpenBag(context, product, 0));
      await tester.pumpAndSettle();

      expect(store.bagQuantity, 1);
      expect(find.byType(BagScreen), findsOneWidget);
    });

    testWidgets('CART-05 buyNowOpenBag does not open the bag when sold out',
        (tester) async {
      final product = _soldOut();
      final (store, context) = await _mount(tester, product);

      unawaited(buyNowOpenBag(context, product, 0));
      await tester.pumpAndSettle();

      expect(store.addCalls, 0);
      expect(store.bagQuantity, 0);
      expect(find.byType(BagScreen), findsNothing);
    });

    testWidgets(
        'CART-05 buyNowOpenBag does not open the bag when the add fails',
        (tester) async {
      final product = syntheticProduct();
      final (store, context) = await _mount(tester, product);
      store.failWith = StateError('storage unavailable');

      unawaited(buyNowOpenBag(context, product, 0));
      await tester.pumpAndSettle();

      expect(store.bagQuantity, 0);
      expect(find.byType(BagScreen), findsNothing);
    });
  });
}
