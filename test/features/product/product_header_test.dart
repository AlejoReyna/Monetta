import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/shopper_copy.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/features/catalog/catalog_browse_screen.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/catalog/product_card.dart';
import 'package:monetta_app/features/catalog/search_screen.dart';
import 'package:monetta_app/features/checkout/checkout_screen.dart';
import 'package:monetta_app/features/product/product_screen.dart';

import '../../support/product_screen_harness.dart';

Widget _launcher(CatalogStore store, Widget screen) => fichaApp(
      store,
      Builder(
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
      ),
    );

void main() {
  setUpAll(mockPathProvider);

  for (final width in [320.0, 390.0, 430.0, 768.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'brand header stays centred and clear of four icons at $width x$scale',
          (tester) async {
        setPhoneView(tester, width: width);
        final store = await loadedStore();
        final product = syntheticProduct(title: kLongProductName);
        addProducts(store, [product]);
        await pumpFicha(tester, store, product.id, scale: scale);
        expect(tester.takeException(), isNull);
        expect(inAppBar(find.byType(MonettaWordmark)), findsOneWidget);
        expect(
          inAppBar(find.text(shopperProductName(product.title))),
          findsNothing,
        );
        final mark = tester.getRect(headerTitle());
        final bar = tester.getRect(appBarFinder());
        expect(mark.center.dx, closeTo(width / 2, .5));
        expect(mark.left, greaterThanOrEqualTo(bar.left));
        expect(mark.right, lessThanOrEqualTo(bar.right));
        expect(mark.top, greaterThanOrEqualTo(bar.top));
        expect(mark.bottom, lessThanOrEqualTo(bar.bottom));
        for (final action in [
          find.byKey(kHeaderBackKey),
          find.byKey(const Key('product-header-search')),
          find.byKey(const Key('product-header-account')),
          inAppBar(find.byType(BagAction)),
        ]) {
          expect(action, findsOneWidget);
          expect(tester.getSize(action).width, greaterThanOrEqualTo(48));
          expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
          expect(mark.overlaps(tester.getRect(action)), isFalse);
        }
      });
    }
  }

  testWidgets(
      'the full product name remains in the content and for screen readers',
      (tester) async {
    await withSemantics(tester, () async {
      setPhoneView(tester);
      final store = await loadedStore();
      final product = syntheticProduct(title: kLongProductName);
      addProducts(store, [product]);
      await pumpFicha(tester, store, product.id);
      final content = contentNameText(shopperProductName(product.title));
      await scrollTo(tester, content);
      expect(content, findsOneWidget);
      expect(tester.widget<Text>(content).maxLines, isNull);
      expect(paragraphOf(tester, content).didExceedMaxLines, isFalse);
      expect(tester.getSemantics(headerTitle()).label, contains('Monetta'));
    });
  });

  testWidgets('back returns to the preceding route', (tester) async {
    setPhoneView(tester);
    final store = await loadedStore();
    final product = syntheticProduct();
    addProducts(store, [product]);
    await tester
        .pumpWidget(_launcher(store, ProductScreen(productId: product.id)));
    await tester.tap(find.text('ABRIR'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(kHeaderBackKey));
    await tester.pumpAndSettle();
    expect(find.byType(ProductScreen), findsNothing);
    expect(find.text('ABRIR'), findsOneWidget);
  });

  testWidgets('the photo heart still toggles the wishlist', (tester) async {
    setPhoneView(tester);
    final store = await loadedStore();
    final product = singleVariantAssetProduct(store);
    await pumpFicha(tester, store, product.id);
    final heart = find.byKey(kHeaderFavoriteKey);
    expect(heart, findsOneWidget);
    expect(inAppBar(heart), findsNothing);
    await tester.tap(heart);
    await tester.pump();
    expect(store.wishlist.contains(product.id), isTrue);
    expect(find.byTooltip('Quitar de guardados'), findsOneWidget);
    await tester.tap(heart);
    await tester.pump();
    expect(store.wishlist.contains(product.id), isFalse);
    expect(find.byTooltip('Guardar'), findsOneWidget);
  });

  testWidgets('header search opens the search experience', (tester) async {
    setPhoneView(tester);
    final store = await loadedStore();
    final product = singleVariantAssetProduct(store);
    await pumpFicha(tester, store, product.id);
    await tester.tap(find.byKey(const Key('product-header-search')));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('search-query-field')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('search-back-button')));
    await tester.pumpAndSettle();
    expect(find.byType(ProductScreen), findsOneWidget);
  });

  testWidgets('header bag opens the bag', (tester) async {
    setPhoneView(tester);
    final store = await loadedStore();
    final product = singleVariantAssetProduct(store);
    await pumpFicha(tester, store, product.id);
    await tester.tap(inAppBar(find.byType(BagAction)));
    await tester.pumpAndSettle();
    expect(find.byType(BagScreen), findsOneWidget);
  });

  testWidgets('the wordmark remains fixed on scroll', (tester) async {
    setPhoneView(tester);
    final store = await loadedStore();
    final product = singleVariantAssetProduct(store);
    await pumpFicha(tester, store, product.id);
    final before = tester.getRect(headerTitle());
    await scrollToEnd(tester);
    expect(tester.getRect(headerTitle()), before);
  });

  for (final collection in [false, true]) {
    testWidgets(
        'returning from a product restores ${collection ? 'collection' : 'catalog'} heading',
        (tester) async {
      setPhoneView(tester, height: 1600);
      final store = await loadedStore();
      final product = singleVariantAssetProduct(store);
      final screen = collection
          ? const CollectionScreen(
              title: 'Bolsas',
              filter: CollectionFilter(category: 'bolsa'),
            )
          : CatalogBrowseScreen(
              products: [product],
              facetsById: store.facetsById,
            );
      await tester.pumpWidget(fichaApp(store, screen));
      await tester.pump();
      final title = collection ? 'Bolsas' : 'Productos';
      expect(find.text(title), findsOneWidget);
      await tester.tap(find.byType(MonettaProductTile).first);
      await tester.pumpAndSettle();
      expect(find.byType(ProductScreen), findsOneWidget);
      await tester.tap(find.byKey(kHeaderBackKey));
      await tester.pumpAndSettle();
      expect(find.byType(ProductScreen), findsNothing);
      expect(find.text(title), findsOneWidget);
    });
  }
}
