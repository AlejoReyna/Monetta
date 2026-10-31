/// UI-03 (objective state): Bolsa and Checkout mount and scroll to their end
/// without any `FlutterError` at 375x812 and 440x956, with the text scale at
/// 1.0, 1.3 and 1.5 under the E-T1 / D-12 policy and the real Inter and
/// Playfair Display faces. See `text_scale_matrix.dart`.
///
/// The bag holds three lines, two of them the longest titles of the asset
/// catalog. Checkout walks both of its steps: contact and review.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/checkout/checkout_screen.dart';

import '../../support/text_scale_matrix.dart';

/// In-stock asset products, longest title first.
List<Product> _longestInStock(CatalogStore store) =>
    store.products.where((p) => p.isInStock).toList()
      ..sort((a, b) => b.title.length.compareTo(a.title.length));

Future<void> _fillBag(CatalogStore store) async {
  final products = _longestInStock(store);
  // Two long names and one shorter piece.
  await store.addToBag(products[0]);
  await store.addToBag(products[1]);
  await store.addToBag(products.last);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useBundledFonts();

  registerTextScaleMatrix(
    'Bolsa',
    (tester, store) async {
      await _fillBag(store);
      expect(store.bagLines.length, greaterThanOrEqualTo(2));
      return const BagScreen();
    },
    anchor: (store) => find.text('Mi bolsa'),
  );

  registerTextScaleMatrix(
    'Checkout',
    (tester, store) async {
      await _fillBag(store);
      return const CheckoutFlowScreen();
    },
    anchor: (store) => find.text('SEGURO'),
    afterScroll: (tester) async {
      // Step 2: contact details, then the review.
      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(2));
      await tester.enterText(fields.at(0), 'ana@example.com');
      await tester.enterText(fields.at(1), '8112345678');
      // Focusing a field scrolls its caret into view with a short animation.
      await pumpFrames(tester, 5);
      await tester.ensureVisible(find.text('REVISAR PEDIDO'));
      await pumpFrames(tester, 5);
      await tester.tap(find.text('REVISAR PEDIDO'));
      await pumpFrames(tester, 12);
      expect(find.text('Todo listo'), findsOneWidget);
    },
  );
}
