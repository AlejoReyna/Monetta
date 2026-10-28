import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/product/product_screen.dart';
import 'package:monetta_app/main.dart';

void main() {
  testWidgets(
    'a live catalog refresh that drops the open product shows an '
    'unavailable state instead of throwing StateError',
    (tester) async {
      final store = CatalogStore(database: openTestDatabase());
      await store.loadFromAsset();
      final product = store.products.firstWhere((p) => p.isInStock);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: StoreScope(
            notifier: store,
            child: ProductScreen(productId: product.id),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('AGREGAR A BOLSA'), findsOneWidget);

      // Simulate the realtime / delta sync replacing the catalog without
      // the product (unpublished in Shopify while the shopper is on it).
      store.products =
          store.products.where((p) => p.id != product.id).toList();
      store.notifyListeners();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('product-unavailable')), findsOneWidget);
      expect(find.text('Este producto ya no está disponible.'), findsOneWidget);
      expect(find.text('AGREGAR A BOLSA'), findsNothing);
    },
  );
}
