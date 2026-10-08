import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/shopper_copy.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/features/boutique/boutique_tokens.dart';
import 'package:monetta_app/features/catalog/catalog_browse_screen.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/catalog/product_card.dart';
import 'package:monetta_app/features/checkout/checkout_screen.dart';
import 'package:monetta_app/features/product/product_screen.dart';

import '../../support/product_screen_harness.dart';

// FICHA-T2, HDR-xx: the header of the ficha carries the identity of the
// product instead of the Monetta wordmark (BRIEF 2.4).
//
// The Ahem test font draws squares, so everything visual here is read from
// the style handed to the `Text`, from rects, or from the semantics tree.

typedef _Mount = Future<String> Function(
  WidgetTester tester,
  String title, {
  double width,
  double scale,
  bool settle,
});

/// Mounts a Monetta ficha for a synthetic product called [title]. Returns the
/// text the header must show for it.
Future<String> _mountMonetta(
  WidgetTester tester,
  String title, {
  double width = 390,
  double scale = 1.0,
  bool settle = true,
}) async {
  setPhoneView(tester, width: width);
  final store = await loadedStore();
  final product = syntheticProduct(title: title);
  addProducts(store, [product]);
  await pumpFicha(tester, store, product.id, scale: scale, settle: settle);
  return shopperProductName(title);
}

/// A home with one button that pushes [screen], to give the ficha somewhere
/// to go back to.
Widget _launcher(CatalogStore store, Widget screen) {
  Widget home() => Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => screen),
              ),
              child: const Text('ABRIR'),
            ),
          ),
        ),
      );
  return fichaApp(store, home());
}

void _expectInsideAppBar(WidgetTester tester, Rect rect) {
  final bar = tester.getRect(appBarFinder());
  expect(rect.left, greaterThanOrEqualTo(bar.left - 0.01), reason: 'left');
  expect(rect.top, greaterThanOrEqualTo(bar.top - 0.01), reason: 'top');
  expect(rect.right, lessThanOrEqualTo(bar.right + 0.01), reason: 'right');
  expect(rect.bottom, lessThanOrEqualTo(bar.bottom + 0.01), reason: 'bottom');
}

void main() {
  setUpAll(mockPathProvider);

  final subjects = <String, _Mount>{
    'ficha Monetta': _mountMonetta,
  };

  for (final MapEntry(key: label, value: mount) in subjects.entries) {
    group('HDR $label', () {
      testWidgets('HDR-01 the AppBar carries the product name as its title',
          (tester) async {
        final expected = await mount(tester, 'Cartera');

        expect(headerTitle(), findsOneWidget);
        expect(tester.widget<Text>(headerTitle()).data, expected);
      });

      testWidgets('HDR-01 no MonettaWordmark inside the AppBar',
          (tester) async {
        await mount(tester, 'Cartera');

        expect(appBarFinder(), findsOneWidget);
        expect(inAppBar(find.byType(MonettaWordmark)), findsNothing);
      });

      testWidgets('HDR-01b the title is set like the card names',
          (tester) async {
        await mount(tester, 'Cartera');

        final style = styleOf(tester, headerTitle());
        expect(style.fontFamily, kBoutiqueSansFamily);
        expect(style.fontFamilyFallback, kBoutiqueSansFallback);
        expect(style.fontWeight, FontWeight.w600);
        expect(style.fontSize, inInclusiveRange(18, 20));
        expect(style.height, inInclusiveRange(1.2, 1.3));
        final text = tester.widget<Text>(headerTitle());
        expect(text.maxLines, 2);
        expect(text.overflow, TextOverflow.ellipsis);
        expect(text.textAlign, TextAlign.center);
      });

      testWidgets('HDR-02 a short name is centred on the view', (tester) async {
        await mount(tester, 'Cartera');

        expect(headerTitle(), findsOneWidget);
        expect(tester.getCenter(headerTitle()).dx, closeTo(390 / 2, 1));
      });

      for (final width in [320.0, 390.0, 430.0]) {
        for (final scale in [1.0, 2.0]) {
          testWidgets(
              'HDR-02b a long name at ${width.toInt()} wide x$scale neither '
              'overlaps the actions nor gets clipped', (tester) async {
            await mount(tester, kLongProductName, width: width, scale: scale);

            expect(headerTitle(), findsOneWidget);
            expect(tester.takeException(), isNull);
            final title = tester.getRect(headerTitle());
            _expectInsideAppBar(tester, title);
            expect(lineCount(tester, headerTitle()), lessThanOrEqualTo(2));

            final actions = [
              find.byKey(kHeaderBackKey),
              find.byKey(kHeaderFavoriteKey),
              inAppBar(find.byType(BagAction)),
            ];
            for (final action in actions) {
              if (action.evaluate().isEmpty) continue;
              expect(
                title.overlaps(tester.getRect(action)),
                isFalse,
                reason:
                    '${action.describeMatch(Plurality.one)} must not overlap the title',
              );
            }
          });
        }
      }

      testWidgets(
          'HDR-02c the complete name stays in the content and for screen '
          'readers', (tester) async {
        await withSemantics(tester, () async {
          final expected = await mount(tester, kLongProductName);
          await tester.pump();

          final content = contentNameText(expected);
          await scrollTo(tester, content);
          expect(content, findsOneWidget);
          expect(tester.widget<Text>(content).maxLines, isNull);
          expect(paragraphOf(tester, content).didExceedMaxLines, isFalse);

          expect(headerTitle(), findsOneWidget);
          final node = tester.getSemantics(headerTitle());
          expect(node.label, contains(expected));
          expect(node.getSemanticsData().flagsCollection.isHeader, isTrue);
        });
      });

      testWidgets(
          'HDR-05 the title is there on the first frame and does not move',
          (tester) async {
        await mount(tester, 'Cartera', settle: false);

        expect(headerTitle(), findsOneWidget);
        final before = tester.getRect(headerTitle());
        await scrollToEnd(tester);
        expect(tester.getRect(headerTitle()), before);
      });
    });
  }

  group('HDR ficha Monetta actions', () {
    testWidgets('HDR-03 the back button pops to the previous route',
        (tester) async {
      setPhoneView(tester);
      final store = await loadedStore();
      final product = syntheticProduct();
      addProducts(store, [product]);
      await tester.pumpWidget(
        _launcher(store, ProductScreen(productId: product.id)),
      );
      await tester.tap(find.text('ABRIR'));
      await tester.pumpAndSettle();

      final back = find.byKey(kHeaderBackKey);
      expect(back, findsOneWidget);
      expect(inAppBar(find.byTooltip('Volver')), findsOneWidget);
      expect(tester.getSize(back).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(back).height, greaterThanOrEqualTo(48));

      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(find.byType(ProductScreen), findsNothing);
      expect(find.text('ABRIR'), findsOneWidget);
    });

    testWidgets('HDR-03 the heart toggles the wishlist and its tooltip',
        (tester) async {
      setPhoneView(tester);
      final store = await loadedStore();
      final product = singleVariantAssetProduct(store);
      await pumpFicha(tester, store, product.id);

      final heart = find.byKey(kHeaderFavoriteKey);
      expect(heart, findsOneWidget);
      expect(tester.getSize(heart).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(heart).height, greaterThanOrEqualTo(48));
      expect(inAppBar(find.byTooltip('Guardar')), findsOneWidget);

      await tester.tap(heart);
      await tester.pump();
      expect(store.wishlist.contains(product.id), isTrue);
      expect(inAppBar(find.byTooltip('Quitar de guardados')), findsOneWidget);
      expect(inAppBar(find.byTooltip('Guardar')), findsNothing);

      await tester.tap(heart);
      await tester.pump();
      expect(store.wishlist.contains(product.id), isFalse);
      expect(inAppBar(find.byTooltip('Guardar')), findsOneWidget);
    });

    testWidgets('HDR-03 the bag action opens the bag (kept as is)',
        (tester) async {
      setPhoneView(tester);
      final store = await loadedStore();
      final product = singleVariantAssetProduct(store);
      await pumpFicha(tester, store, product.id);

      final bag = inAppBar(find.byType(BagAction));
      expect(bag, findsOneWidget);
      expect(tester.getSize(bag).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(bag).height, greaterThanOrEqualTo(48));
      expect(
        inAppBar(
          find.byWidgetPredicate(
            (widget) =>
                widget is Tooltip &&
                (widget.message ?? '').startsWith('Mi bolsa'),
          ),
        ),
        findsOneWidget,
      );

      await tester.tap(bag);
      await tester.pumpAndSettle();
      expect(find.byType(BagScreen), findsOneWidget);
    });

    testWidgets(
        'HDR-04 switching to another piece shows its name, and popping '
        'restores the first', (tester) async {
      setPhoneView(tester);
      final store = await loadedStore();
      final (:product, :other) = productWithBrandRail(store);
      final nameA = shopperProductName(product.title);
      final nameB = shopperProductName(other.title);
      await tester.pumpWidget(
        _launcher(store, ProductScreen(productId: product.id)),
      );
      await tester.tap(find.text('ABRIR'));
      await tester.pumpAndSettle();

      expect(headerTitle(), findsOneWidget);
      expect(tester.widget<Text>(headerTitle()).data, nameA);

      final card = find.byWidgetPredicate(
        (widget) => widget is ProductCard && widget.product.id == other.id,
      );
      await scrollTo(tester, card);
      await tester.tap(card.first);
      await tester.pumpAndSettle();

      expect(headerTitle(), findsOneWidget);
      expect(tester.widget<Text>(headerTitle()).data, nameB);
      expect(inAppBar(find.text(nameA)), findsNothing);

      await tester.tap(find.byKey(kHeaderBackKey));
      await tester.pumpAndSettle();
      expect(headerTitle(), findsOneWidget);
      expect(tester.widget<Text>(headerTitle()).data, nameA);
    });
  });

  group('HDR-06 each screen restores its own title on return', () {
    testWidgets('CatalogBrowseScreen keeps "Productos" after a ficha',
        (tester) async {
      setPhoneView(tester, height: 1600);
      final store = await loadedStore();
      final product = singleVariantAssetProduct(store);
      await tester.pumpWidget(
        fichaApp(
          store,
          CatalogBrowseScreen(
            products: [product],
            facetsById: store.facetsById,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Productos'), findsOneWidget);

      await tester.tap(find.byType(MonettaProductTile).first);
      await tester.pumpAndSettle();
      expect(find.byType(ProductScreen), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(ProductScreen),
          matching: find.byTooltip('Volver'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProductScreen), findsNothing);
      expect(find.text('Productos'), findsOneWidget);
    });

    testWidgets('CollectionScreen keeps its banner title after a ficha',
        (tester) async {
      setPhoneView(tester, height: 1600);
      final store = await loadedStore();
      await tester.pumpWidget(
        fichaApp(
          store,
          const CollectionScreen(
            title: 'Bolsas',
            filter: CollectionFilter(category: 'bolsa'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Bolsas'), findsOneWidget);

      await tester.tap(find.byType(ProductCard).first);
      await tester.pumpAndSettle();
      expect(find.byType(ProductScreen), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(ProductScreen),
          matching: find.byTooltip('Volver'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProductScreen), findsNothing);
      expect(find.text('Bolsas'), findsOneWidget);
    });
  });
}
