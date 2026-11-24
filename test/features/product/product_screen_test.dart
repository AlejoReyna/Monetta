import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/media/monetta_image.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/product/product_screen.dart';
import 'package:monetta_app/main.dart';

import '../../support/bundled_fonts.dart';
import '../../support/product_screen_harness.dart';

Future<CatalogStore> _loadedStore() async {
  final store = CatalogStore(database: openTestDatabase());
  await store.loadFromAsset();
  return store;
}

void main() {
  testWidgets('product hero covers the complete detail viewport', (
    tester,
  ) async {
    final store = await _loadedStore();
    final product = store.products.firstWhere(
      (item) => item.isInStock && item.images.isNotEmpty,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: StoreScope(
          notifier: store,
          child: ProductScreen(productId: product.id),
        ),
      ),
    );

    final heroImage = find.descendant(
      of: find.byType(InteractiveViewer),
      matching: find.byType(MonettaImage),
    );
    expect(heroImage, findsOneWidget);
    // Package C (Fig.07): the photo is contained so handles and straps are
    // never cropped — `cover` is the bug this asserts against.
    expect(tester.widget<MonettaImage>(heroImage).fit, BoxFit.contain);
  });

  testWidgets('product page sells with facts, not internal facets', (
    tester,
  ) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    final product = store.products.firstWhere((item) => item.isInStock);

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

    expect(find.text(product.title), findsWidgets);
    expect(find.text('Agregar al carrito'), findsOneWidget);
    expect(find.text('Comprar ahora'), findsOneWidget);
    // UI v4.1: apartados wait for confirmed rules; the ficha offers none.
    expect(find.text('Apartar'), findsNothing);
    expect(find.text('Gama'), findsNothing);
    expect(find.text('extracted'), findsNothing);
    expect(find.textContaining('Popular ahora'), findsNothing);
  });

  testWidgets('add to bag confirms on the ficha without opening the cart', (
    tester,
  ) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    final product = store.products.firstWhere((item) => item.isInStock);

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

    await tester.ensureVisible(find.text('Agregar al carrito'));
    await tester.pump();
    await tester.tap(find.text('Agregar al carrito'));
    await tester.pumpAndSettle();

    expect(store.bagQuantity, 1);
    // UI v4.1: «Agregar conserva PDP» — the confirmation stays on the page.
    expect(find.text('Agregado al carrito'), findsOneWidget);
    expect(find.text('En tu bolsa'), findsNothing);
    expect(find.byType(ProductScreen), findsOneWidget);
  });

  testWidgets('cashback estimate sits beside the price with exact copy', (
    tester,
  ) async {
    await tester.runAsync(loadBundledFonts);
    setPhoneView(tester, width: 390, inset: 0);

    final store = await _loadedStore();
    final product = syntheticProduct(
      id: 'gid://shopify/Product/9914',
      title: 'Bolsa Cashback Test',
      variants: [
        syntheticVariant(id: 'v-1400', price: 1400, available: true),
      ],
    );
    addProducts(store, [product]);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: StoreScope(
          notifier: store,
          child: ProductScreen(
            productId: product.id,
            showRewardsEstimate: true,
          ),
        ),
      ),
    );
    await tester.pump();

    final priceFinder = find.byKey(const Key('product-price'));
    final cashbackFinder = find.byKey(const ValueKey('rewards-estimate'));
    expect(priceFinder, findsOneWidget);
    expect(cashbackFinder, findsOneWidget);
    expect(
      find.text('Con esta compra ganarás \$14 en cashback'),
      findsOneWidget,
    );
    expect(find.textContaining('Podrías ganar'), findsNothing);
    expect(find.textContaining('no es saldo liberado'), findsNothing);

    final priceRect = tester.getRect(priceFinder);
    final cashbackRect = tester.getRect(cashbackFinder);
    expect(cashbackRect.left, greaterThan(priceRect.right));
    expect((cashbackRect.center.dy - priceRect.center.dy).abs(), lessThan(8));
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'inline cashback has no overflow at ${width.toInt()}px ${scale}x',
        (tester) async {
          await tester.runAsync(loadBundledFonts);
          setPhoneView(tester, width: width, inset: 0);

          final store = await _loadedStore();
          final product = syntheticProduct(
            id: 'gid://shopify/Product/9915-${width.toInt()}-${scale.toInt()}',
            title: 'Bolsa Escala Test',
            variants: [
              const ProductVariant(
                id: 'v-sale',
                title: 'Default Title',
                price: 12016.75,
                compareAtPrice: 18500,
                available: true,
              ),
            ],
          );
          addProducts(store, [product]);

          await tester.pumpWidget(
            MaterialApp(
              theme: buildTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                ),
                child: child!,
              ),
              home: StoreScope(
                notifier: store,
                child: ProductScreen(
                  productId: product.id,
                  showRewardsEstimate: true,
                ),
              ),
            ),
          );
          await tester.pump();

          expect(
            find.text('Con esta compra ganarás \$120 en cashback'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'inline cashback hides when disabled, out of stock, or under \$1',
    (tester) async {
      setPhoneView(tester, width: 390, inset: 0);
      final store = await _loadedStore();
      final outOfStock = syntheticProduct(
        id: 'gid://shopify/Product/9916',
        title: 'Bolsa Agotada',
        variants: [
          syntheticVariant(id: 'v-oos', price: 1400, available: false),
        ],
      );
      final cheap = syntheticProduct(
        id: 'gid://shopify/Product/9917',
        title: 'Accesorio Menor',
        variants: [
          syntheticVariant(id: 'v-cheap', price: 40, available: true),
        ],
      );
      final zero = syntheticProduct(
        id: 'gid://shopify/Product/9918',
        title: 'Sin Precio',
        variants: [
          syntheticVariant(id: 'v-zero', price: 0, available: true),
        ],
      );
      final disabled = syntheticProduct(
        id: 'gid://shopify/Product/9919',
        title: 'Bolsa Oculta',
        variants: [
          syntheticVariant(id: 'v-ok', price: 1400, available: true),
        ],
      );
      addProducts(store, [outOfStock, cheap, zero, disabled]);

      for (final (product, show) in [
        (disabled, false),
        (outOfStock, true),
        (cheap, true),
        (zero, true),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            home: StoreScope(
              notifier: store,
              child: ProductScreen(
                productId: product.id,
                showRewardsEstimate: show,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byKey(const ValueKey('rewards-estimate')), findsNothing);
        expect(find.textContaining('\$0 en cashback'), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
