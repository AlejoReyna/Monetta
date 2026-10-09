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
    'SHIP-04 ficha has no free-shipping copy, names shipping to all Mexico '
    'and keeps the plain availability line',
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

      expect(find.textContaining(_freeShippingCopy), findsNothing);
      expect(find.text('Envío a todo México'), findsOneWidget);
      expect(find.text('Disponible · envío 3 a 5 días'), findsOneWidget);
      expect(find.textContaining('Entrega estimada'), findsWidgets);

      // The accordion hides its copy until opened: open it and look again.
      await scrollTo(tester, find.text('Envíos y cambios'));
      await tester.tap(find.text('Envíos y cambios'));
      await tester.pump();
      expect(
        find.textContaining('Envío a todo México en 3 a 5 días hábiles'),
        findsOneWidget,
        reason: 'the shipping accordion must be open for this check',
      );
      expect(find.textContaining(_freeShippingCopy), findsNothing);
      expect(
        find.textContaining(RegExp('gratis', caseSensitive: false)),
        findsNothing,
      );
    },
  );
}
