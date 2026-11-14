/// SHIP-04: the product page promises no free shipping by amount, in the
/// shipping card, the availability line or the shipping accordion.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/features/product/product_screen.dart';
import 'package:monetta_app/main.dart';

import '../../support/product_screen_harness.dart';

final RegExp _freeShippingCopy = RegExp(
  'gratis desde|envío gratis',
  caseSensitive: false,
);

Future<void> _pumpFicha(
  WidgetTester tester,
  CatalogStore store,
  String productId,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: StoreScope(
        notifier: store,
        child: ProductScreen(productId: productId),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(mockPathProvider);

  testWidgets(
    'SHIP-04 the ficha says ENVÍO GRATIS only in the UI v4.1 services row '
    '(approved copy; checkout still requires an account) and never a '
    'threshold by amount',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1.0;

      final store = await loadedStore();
      final product = store.products.firstWhere(
        (item) => item.isInStock && item.images.length > 1,
      );
      await _pumpFicha(tester, store, product.id);

      expect(find.textContaining(RegExp('gratis desde', caseSensitive: false)),
          findsNothing);
      final services = find.byKey(const Key('product-trust-row'));
      await scrollTo(tester, services);
      final anywhere = find.textContaining(_freeShippingCopy);
      final inServices = find.descendant(of: services, matching: anywhere);
      expect(inServices, findsOneWidget);
      expect(anywhere.evaluate().length, inServices.evaluate().length);
      expect(find.text('Disponible'), findsOneWidget);
    },
  );
}
