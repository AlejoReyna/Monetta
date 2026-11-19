import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/checkout/checkout_screen.dart'
    show CheckoutFlowScreen;
import 'package:monetta_app/features/product/product_selection.dart';
import 'package:monetta_app/main.dart';

import '../../support/product_screen_harness.dart';
import '../../support/scripted_catalog_store.dart';

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
        home: Scaffold(
          body: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    ),
  );
  return (store, captured);
}

void main() {
  testWidgets(
      'buyNowContinueToCheckout adds the unit and surfaces checkout guard without CartScope',
      (tester) async {
    final product = syntheticProduct();
    final (store, context) = await _mount(tester, product);

    unawaited(buyNowContinueToCheckout(context, product, 0));
    await tester.pumpAndSettle();

    expect(store.bagQuantity, 1);
    expect(find.byType(CheckoutFlowScreen), findsNothing);
  });

  testWidgets('buyNowContinueToCheckout does not add a sold-out variant',
      (tester) async {
    final product = syntheticProduct(
      variants: [syntheticVariant(id: 'v-agotada', available: false)],
    );
    final (store, context) = await _mount(tester, product);

    unawaited(buyNowContinueToCheckout(context, product, 0));
    await tester.pumpAndSettle();

    expect(store.bagQuantity, 0);
  });
}