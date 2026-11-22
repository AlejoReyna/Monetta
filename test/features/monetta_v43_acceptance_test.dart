import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/domain/editorial_content.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/about/about_monetta_screen.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/checkout/checkout_screen.dart';
import 'package:monetta_app/features/home/home_wholesale_banner.dart';
import 'package:monetta_app/features/product/product_screen.dart';
import 'package:monetta_app/features/product/quick_view.dart';
import 'package:monetta_app/main.dart';

import '../support/client_guide_capture.dart';
import '../support/product_screen_harness.dart';
import '../support/quick_add_harness.dart' show inSheet;

Product _offer() => syntheticProduct(
      title: 'Bolso Aurora QA',
      variants: const [
        ProductVariant(
          id: 'qa-cafe',
          title: 'Café',
          selectedOptions: {'Color': 'Café'},
          price: 1800,
          available: true,
        ),
        ProductVariant(
          id: 'qa-negro',
          title: 'Negro',
          selectedOptions: {'Color': 'Negro'},
          price: 1700,
          compareAtPrice: 2300,
          sixMsiInstallmentAmount: 283,
          available: true,
        ),
      ],
    );

void main() {
  setUpAll(mockPathProvider);

  testWidgets('AT-01 Ofertas abre la variante ofertada y conserva la consulta',
      (tester) async {
    final store = await loadedStore();
    addTearDown(store.dispose);
    final product = _offer();
    store.products = [product];
    await pumpClientGuide(
      tester,
      StoreScope(
        notifier: store,
        child: const CollectionScreen(title: 'Ofertas', offersCollection: true),
      ),
    );
    final search = find.byType(TextField).first;
    await tester.enterText(search, 'Aurora QA');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    final card = find.byKey(ValueKey('product-card-${product.id}'));
    expect(card, findsOneWidget);
    await captureClientGuide(tester, 'AT01-app-ofertas', fullContent: false);
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(inSheet(find.text('-26%', findRichText: true)), findsOneWidget);
    final viewProduct = find.text('Ver producto', findRichText: true);
    await tester.ensureVisible(viewProduct);
    await tester.tap(viewProduct);
    await tester.pumpAndSettle();
    expect(find.byType(ProductScreen), findsOneWidget);
    expect(find.text('-26%', findRichText: true), findsOneWidget);
    final semantics = tester.ensureSemantics();
    try {
      final swatch = find.bySemanticsLabel('Color Café');
      await tester.ensureVisible(swatch);
      await tester.tap(swatch);
      await tester.pumpAndSettle();
    } finally {
      semantics.dispose();
    }
    expect(find.text('-26%', findRichText: true), findsNothing);
    final context = tester.element(find.byType(ProductScreen));
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    expect(find.text('Aurora QA'), findsOneWidget);
  });

  testWidgets('AT-02 y AT-03 ficha, drawer editable y retorno a la variante',
      (tester) async {
    final store = await loadedStore();
    addTearDown(store.dispose);
    final product = _offer();
    final related = syntheticProduct(
      id: 'gid://shopify/Product/9013',
      title: 'Cartera Luz QA',
    );
    store.products = [product, related];
    await pumpClientGuide(
      tester,
      StoreScope(
        notifier: store,
        child:
            ProductScreen(productId: product.id, initialVariantId: 'qa-negro'),
      ),
      size: const Size(390, 844),
    );
    final add = find.byKey(kDockPrimaryKey);
    expect(add, findsOneWidget);
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(store.bagLines.single.variant.id, 'qa-negro');
    expect(find.text('Agregado al carrito'), findsOneWidget);
    await captureClientGuide(tester, 'AT02-app-agregado', fullContent: false);

    for (final quantity in [2, 3, 4, 3, 2]) {
      final name = quantity > store.bagQuantity ? 'Agregar uno' : 'Quitar uno';
      await tester.tap(find.byTooltip(name).first);
      await tester.pumpAndSettle();
      expect(store.bagQuantity, quantity);
    }
    await captureClientGuide(tester, 'AT03-app-carrito', fullContent: false);
    final plus = find.byKey(ValueKey('bag-recommendation-add-${related.id}'));
    await tester.ensureVisible(plus);
    await tester.pumpAndSettle();
    await tester.tap(plus);
    await tester.pumpAndSettle();
    expect(store.bagLines, hasLength(2));
    expect(find.byType(BagScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(BagScreen), findsNothing);
    expect(find.byKey(kDockPrimaryKey), findsOneWidget);
  });

  testWidgets('AT-04 B04 a 320 puntos y texto ampliado tiene una sola acción',
      (tester) async {
    var actions = 0;
    await pumpClientGuide(
      tester,
      Scaffold(
        body: Center(
          child: HomeWholesaleBanner(onOpenWholesale: () => actions += 1),
        ),
      ),
      size: const Size(320, 740),
      textScale: 2,
    );
    final action = find.byKey(const ValueKey('home-wholesale-button'));
    expect(action, findsOneWidget);
    await tester.tap(action);
    expect(actions, 1);
    expect(tester.takeException(), isNull);
    await captureClientGuide(tester, 'AT04-app-B04-320-texto200',
        fullContent: false);
  });

  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    testWidgets('AT-05 ficha y carrito con área segura a ${width.toInt()}',
        (tester) async {
      final store = await loadedStore();
      addTearDown(store.dispose);
      tester.view.padding = const FakeViewPadding(bottom: 24, top: 20);
      addTearDown(tester.view.resetPadding);
      final product = _offer();
      store.products = [product];
      await pumpClientGuide(
        tester,
        StoreScope(
          notifier: store,
          child: ProductScreen(
              productId: product.id, initialVariantId: 'qa-negro'),
        ),
        size: Size(width, 844),
      );
      expect(find.byKey(kDockPrimaryKey), findsOneWidget);
      await captureClientGuide(tester, 'AT05-app-ficha-${width.toInt()}',
          fullContent: false);
      await tester.ensureVisible(find.byKey(kDockPrimaryKey));
      await tester.tap(find.byKey(kDockPrimaryKey));
      await tester.pumpAndSettle();
      final drawer = find.byType(BagScreen);
      expect(drawer, findsOneWidget);
      final rect = tester.getRect(drawer);
      expect(rect.right, width);
      expect(rect.left, greaterThan(0));
      expect(tester.takeException(), isNull);
      await captureClientGuide(tester, 'AT05-app-carrito-${width.toInt()}',
          fullContent: false);
    });
  }

  testWidgets(
      'G09/G10 franja condicional 6 pagos sin intereses en PDP y QuickView',
      (tester) async {
    final store = await loadedStore();
    addTearDown(store.dispose);
    final product = _offer();
    store.products = [product];
    await pumpClientGuide(
      tester,
      StoreScope(
        notifier: store,
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showProductQuickView(
                  context,
                  product,
                  initialVariantId: 'qa-negro',
                ),
                child: const Text('abrir rapida'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir rapida'));
    await tester.pumpAndSettle();
    expect(
      inSheet(find.text('6 pagos sin intereses de \$283 mxn')),
      findsOneWidget,
    );
    final semantics = tester.ensureSemantics();
    try {
      await tester.tap(inSheet(find.bySemanticsLabel('Color Café')));
      await tester.pumpAndSettle();
    } finally {
      semantics.dispose();
    }
    expect(inSheet(find.byKey(const ValueKey('six-msi-line'))), findsNothing);
    await tester.tap(inSheet(find.bySemanticsLabel('Color Negro')));
    await tester.pumpAndSettle();
    final viewProduct = inSheet(find.text('Ver producto', findRichText: true));
    await tester.ensureVisible(viewProduct);
    await tester.tap(viewProduct);
    await tester.pumpAndSettle();
    expect(find.byType(ProductScreen), findsOneWidget);
    expect(find.text('6 pagos sin intereses de \$283 mxn'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Color Café'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('six-msi-line')), findsNothing);
  });

  testWidgets(
      'G12 reposición permanece oculta sin backend por variante y responde con callback',
      (tester) async {
    final store = await loadedStore();
    addTearDown(store.dispose);
    final soldOut = syntheticProduct(
      id: 'gid://shopify/Product/9901',
      title: 'Bolso Agotado QA',
      variants: const [
        ProductVariant(
          id: 'qa-soldout',
          title: 'Negro',
          price: 1900,
          available: false,
        ),
      ],
    );
    store.products = [soldOut];
    await pumpClientGuide(
      tester,
      StoreScope(
        notifier: store,
        child: ProductScreen(productId: soldOut.id),
      ),
    );
    expect(find.text('Avísame cuando vuelva'), findsNothing);

    ProductVariant? requested;
    await pumpClientGuide(
      tester,
      StoreScope(
        notifier: store,
        child: ProductScreen(
          productId: soldOut.id,
          onRestock: (_, v) => requested = v,
        ),
      ),
    );
    final btn = find.byKey(const ValueKey('create-restock-alert'));
    expect(btn, findsOneWidget);
    await tester.ensureVisible(btn);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(btn);
    await tester.pump();
    expect(requested?.id, 'qa-soldout');
  });

  testWidgets('AboutMonettaScreen no conserva copy de Compartir catálogo',
      (tester) async {
    await pumpClientGuide(
      tester,
      AboutMonettaScreen(
        content: MonettaEditorialContent.fallback.about,
        onOpenCatalog: () {},
        onOpenPartner: () {},
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('about-open-partner')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Comparte nuestros catálogos'), findsNothing);
    expect(
      find.text('Obtén precios especiales de mayoreo a partir de 3 piezas.'),
      findsOneWidget,
    );
    expect(find.text('CONOCER MAYOREO'), findsOneWidget);
  });
}
