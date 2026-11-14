import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/features/product/product_screen.dart';
import 'package:monetta_app/features/product/product_selection.dart';

import '../../support/product_screen_harness.dart';
import '../../support/quick_add_harness.dart';

void main() {
  setUpAll(mockPathProvider);

  group('PREVIEW-GUIDE quick view (slide 12)', () {
    testWidgets('no «Comprar ahora»; thumbnails, add and ver producto stay',
        (tester) async {
      setPhoneView(tester, height: 1700);
      final store = await loadedStore();
      addTearDown(store.dispose);
      final product = store.products.firstWhere(
        (p) =>
            p.isInStock &&
            p.images.length > 1 &&
            store.facetsFor(p.id)?.brand != null,
      );
      await pumpQuickView(tester, store, product);

      expect(find.text('Comprar ahora'), findsNothing);
      expect(find.byKey(const Key('quick-view-buy-now')), findsNothing);
      expect(find.text('Agregar al carrito'), findsOneWidget);
      expect(find.byKey(const Key('quick-view-view-product')), findsOneWidget);
      expect(find.text('Ver producto'), findsOneWidget);
      // Brand in the serif; the stock line only says whether it is available,
      // never an invented quantity.
      expect(find.byKey(const Key('quick-view-brand')), findsOneWidget);
      expect(find.textContaining('Últimas'), findsNothing);
      expect(find.text('Stock'), findsOneWidget);
      expect(find.byKey(const Key('quick-view-stock')), findsOneWidget);
    });

    testWidgets('the -N% badge shows with a real compare-at price',
        (tester) async {
      setPhoneView(tester, height: 1700);
      final store = await loadedStore();
      addTearDown(store.dispose);
      final sale = store.products.firstWhere(
        (p) => p.isOnSale && p.isInStock && selectableVariants(p).isNotEmpty,
      );
      await pumpQuickView(tester, store, sale);
      final percent = (sale.discountFraction * 100).round();
      expect(find.byKey(const ValueKey('discount-badge')), findsOneWidget);
      expect(find.text('-$percent%'), findsOneWidget);
    });

    testWidgets('no badge without a discount', (tester) async {
      setPhoneView(tester, height: 1700);
      final store = await loadedStore();
      addTearDown(store.dispose);
      final plain = store.products.firstWhere(
        (p) => p.isInStock && !p.isOnSale,
      );
      await pumpQuickView(tester, store, plain);
      expect(find.byKey(const ValueKey('discount-badge')), findsNothing);
    });

    testWidgets('«COLORES» swatches when the variants are colours',
        (tester) async {
      setPhoneView(tester, height: 1700);
      final store = await loadedStore();
      addTearDown(store.dispose);
      // The bundled catalog has no multi-colour piece: a synthetic one whose
      // variants are plain colour words.
      final colored = syntheticProduct(
        id: 'gid://shopify/Product/9101',
        title: 'Bolsa de colores',
        variants: [
          syntheticVariant(
            id: 'v-negro',
            title: 'Negro',
            selectedOptions: const {'Color': 'Negro'},
          ),
          syntheticVariant(
            id: 'v-beige',
            title: 'Beige',
            selectedOptions: const {'Color': 'Beige'},
          ),
        ],
      );
      addProducts(store, [colored]);
      expect(hasReliableColorOptions(colored), isTrue);
      await pumpQuickView(tester, store, colored);
      // The heading carries the choice: «Color: Negro» (UI v4.1).
      expect(find.textContaining('Color'), findsWidgets);
      expect(find.text('Comprar ahora'), findsNothing);
    });
  });

  group('FICHA-GUIDE product page (slide 13)', () {
    testWidgets('three guarantees, two purchase buttons, no reviews',
        (tester) async {
      setPhoneView(tester, height: 1700);
      final store = await loadedStore();
      addTearDown(store.dispose);
      final product = store.products.firstWhere(
        (p) => p.isInStock && p.images.length > 1,
      );
      await pumpFicha(tester, store, product.id);
      expect(find.byType(ProductScreen), findsOneWidget);

      final row = find.byKey(const Key('product-trust-row'));
      expect(row, findsOneWidget);
      // UI v4.1 services, with the delivered copy.
      for (final text in [
        'ENVÍO GRATIS',
        '5 - 7 días hábiles',
        'Producto Original',
        'Importado desde E.U.A',
        'Paga a Meses',
        'Sin Intereses',
      ]) {
        expect(
          find.descendant(of: row, matching: find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
      expect(
        find.descendant(of: row, matching: find.byType(SvgPicture)),
        findsNWidgets(3),
      );

      // The same two buttons, in order, with the same keys as before.
      final add = find.byKey(kDockPrimaryKey);
      final buy = find.byKey(kBuyNowKey);
      final addLabel = find.descendant(
        of: add,
        matching: find.text('Agregar al carrito'),
      );
      final buyLabel = find.descendant(
        of: buy,
        matching: find.text('Comprar ahora'),
      );
      expect(addLabel, findsOneWidget);
      expect(buyLabel, findsOneWidget);
      expect(
        tester.getTopLeft(add).dy,
        lessThan(tester.getTopLeft(buy).dy),
      );
      // No stars and no reviews: there is no data behind them.
      expect(find.textContaining('reseñas'), findsNothing);
      expect(find.byIcon(Icons.star), findsNothing);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      // The WhatsApp apartado lives in «Otras formas de comprar».
      expect(find.text('Otras formas de comprar'), findsOneWidget);
    });
  });
}
