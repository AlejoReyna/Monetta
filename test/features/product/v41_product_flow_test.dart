// Deterministic local commerce/photography fixtures; no live service success.
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/media/monetta_image.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/catalog/product_card.dart';
import 'package:monetta_app/features/catalog/product_controls.dart';
import 'package:monetta_app/features/product/product_screen.dart';
import 'package:monetta_app/features/product/product_selection.dart';
import 'package:monetta_app/features/product/product_zoom.dart';
import 'package:monetta_app/features/product/quick_view.dart';
import 'package:monetta_app/reco/events.dart';
import '../../support/product_screen_harness.dart';
import '../../support/scripted_catalog_store.dart';
import '../../support/v41_product_fixture.dart';

Future<ScriptedCatalogStore> mount(
  WidgetTester tester, {
  Widget Function(Product)? home,
}) async {
  setPhoneView(tester);
  final db = openTestDatabase();
  final store = ScriptedCatalogStore(database: db);
  addTearDown(() async {
    store.dispose();
    await db.close();
  });
  await store.loadFromAsset();
  final product = v41Product();
  store.products = [product];
  await tester.pumpWidget(
    fichaApp(
      store,
      home?.call(product) ??
          Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(width: 300, child: ProductCard(product: product)),
            ),
          ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(mockPathProvider);
  setUp(() {
    debugMonettaFixtureImage =
        MemoryImage(File('test/support/fixture_product.jpg').readAsBytesSync());
  });
  tearDown(() {
    debugMonettaFixtureImage = null;
  });

  testWidgets(
      'independent heart/options carry actual variant card → quick → PDP → add and return',
      (tester) async {
    final store = await mount(tester);
    await tester.tap(find.byType(ProductFavoriteButton));
    await tester.pumpAndSettle();
    expect(store.wishlist, contains(v41Product().id));
    expect(find.byKey(const Key('quick-view-card')), findsNothing);
    await tester.tap(find.byTooltip('Elegir opción'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blanco / 36').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quick-view-card')), findsNothing);
    expect(
      tester
          .widget<MonettaProductTile>(find.byType(MonettaProductTile))
          .data
          .priceLabel,
      '\$1,600 MXN',
    );
    await tester.tap(find.byType(MonettaImage).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quick-view-back')), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const Key('quick-view-price'))).data,
      '\$1,600 MXN',
    );
    expect(
      tester.widget<MonettaImage>(find.byType(MonettaImage).first).url,
      contains('white.jpg'),
    );
    await reveal(tester, find.byKey(const Key('quick-view-view-product')));
    await tester.tap(find.byKey(const Key('quick-view-view-product')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quick-view-card')), findsNothing);
    expect(
      tester.widget<ProductScreen>(find.byType(ProductScreen)).initialVariantId,
      'gid://shopify/ProductVariant/9103',
    );
    await reveal(tester, find.byKey(const Key('purchase-dock-primary')));
    await tester.tap(find.byKey(const Key('purchase-dock-primary')));
    await tester.pumpAndSettle();
    expect(
      store.bagLines.single.variant.id,
      'gid://shopify/ProductVariant/9103',
    );
    expect(find.text('Agregado al carrito'), findsOneWidget);
    expect(find.text('En tu bolsa'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ProductScreen), findsNothing);
    expect(find.byKey(const Key('quick-view-card')), findsNothing);
    expect(
      tester
          .widget<MonettaProductTile>(find.byType(MonettaProductTile))
          .data
          .priceLabel,
      '\$1,600 MXN',
    );
  });

  testWidgets(
      'unavailable combination cannot add or inherit another compare-at/image',
      (tester) async {
    final store = await mount(tester);
    final context = tester.element(find.byType(ProductCard));
    unawaited(showProductQuickView(context, store.products.single));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('37'));
    await tester.tap(find.text('37'));
    await tester.pumpAndSettle();
    expect(find.byType(ProductSoldOutBadge), findsOneWidget);
    expect(find.byKey(const Key('quick-view-primary')), findsNothing);
    expect(find.text('Avísame cuando vuelva'), findsNothing);
    expect(find.byKey(const ValueKey('discount-badge')), findsNothing);
    await tester
        .tap(find.bySemanticsLabel('Color Blanco, no disponible').first);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('product-combination-unavailable')),
      findsOneWidget,
    );
    expect(selectedVariant(store.products.single, -1), isNull);
    expect(store.addCalls, 0);
    await tester.tap(find.text('36'));
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const Key('quick-view-primary')));
    store.failWith = StateError('fixture failure');
    await tester.tap(find.byKey(const Key('quick-view-primary')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quick-view-error')), findsOneWidget);
    expect(store.bagQuantity, 0);
    store.failWith = null;
    store.hold = Completer<void>();
    await tester.tap(find.byKey(const Key('quick-view-primary')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('quick-view-primary')));
    await tester.pump();
    expect(
      store.addCalls,
      2,
      reason: 'one failed attempt and one in-flight attempt',
    );
    store.hold!.complete();
    await tester.pumpAndSettle();
    expect(
      store.bagLines.single.variant.id,
      'gid://shopify/ProductVariant/9103',
    );
    expect(find.byKey(const Key('quick-view-card')), findsOneWidget);
  });

  testWidgets(
      'legacy index supported, stable id wins, exhausted/missing ids stay unavailable',
      (tester) async {
    final store = await mount(
      tester,
      home: (p) => ProductScreen(
        productId: p.id,
        initialVariantIndex: 0,
        initialVariantId: p.variants[1].id,
      ),
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('product-price'))).data,
      '\$1,400 MXN',
    );
    expect(find.byType(ProductSoldOutBadge), findsOneWidget);
    expect(find.byKey(const Key('purchase-dock-primary')), findsNothing);
    expect(find.text('Avísame cuando vuelva'), findsNothing);
    expect(selectionCompareAt(store.products.single, 1), isNull);
    expect(variantIndexForId(store.products.single, null, fallback: 2), 2);
    expect(
      variantIndexForId(store.products.single, 'withdrawn', fallback: 0),
      -1,
    );
  });

  testWidgets(
      'escape closes quick view and restores originating keyboard focus',
      (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await mount(
      tester,
      home: (product) => Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            focusNode: focus,
            onPressed: () => showProductQuickView(context, product),
            child: const Text('Abrir'),
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quick-view-card')), findsNothing);
    expect(focus.hasFocus, true);
  });

  testWidgets(
      'zoom exposes enlarge/reduce/reset and multiple photos with focus return',
      (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await mount(
      tester,
      home: (p) => Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            focusNode: focus,
            onPressed: () => showProductZoom(
              context,
              images: [
                'https://cdn.shopify.com/fixture/1.jpg',
                'https://cdn.shopify.com/fixture/2.jpg',
              ],
              initialPage: 0,
              title: p.title,
            ),
            child: const Text('Zoom'),
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.tap(find.text('Zoom'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ampliar'));
    await tester.pump();
    expect(find.text('150%'), findsOneWidget);
    await tester.tap(find.byTooltip('Reducir'));
    await tester.pump();
    expect(find.text('100%'), findsOneWidget);
    await tester.tap(find.byTooltip('Ampliar'));
    await tester.tap(find.text('Restablecer'));
    await tester.pump();
    expect(find.text('100%'), findsOneWidget);
    await tester.tap(find.byTooltip('Foto siguiente'));
    await tester.pump();
    expect(find.text('Foto 2 de 2'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('product-zoom-dialog')), findsNothing);
    expect(focus.hasFocus, true);
  });
  testWidgets(
      'featured direct-PDP entry preserves selected variant without quick view',
      (tester) async {
    final store = await mount(
      tester,
      home: (p) => Scaffold(
        body: SingleChildScrollView(
          child: ProductCard(
            product: p,
            initialVariantId: p.variants.last.id,
            openDirectly: true,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(MonettaImage).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quick-view-card')), findsNothing);
    expect(
      tester.widget<ProductScreen>(find.byType(ProductScreen)).initialVariantId,
      store.products.single.variants.last.id,
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('product-price'))).data,
      '\$1,600 MXN',
    );
  });

  testWidgets(
      'quick photo transition and catalog reorder use selected ID for purchase',
      (tester) async {
    final store = await mount(tester);
    final old = store.products.single;
    final context = tester.element(find.byType(ProductCard));
    unawaited(
      showProductQuickView(
        context,
        old,
        initialVariantId: old.variants.last.id,
      ),
    );
    await tester.pumpAndSettle();
    store.products = [
      Product(
        id: old.id,
        handle: old.handle,
        title: old.title,
        vendor: old.vendor,
        productType: old.productType,
        tags: old.tags,
        variants: old.variants.reversed.toList(),
        images: old.images,
        createdAt: old.createdAt,
        updatedAt: old.updatedAt,
        descriptionHtml: old.descriptionHtml,
      ),
    ];
    store.record(EventType.galleryInteraction, productId: old.id);
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const Key('quick-view-primary')));
    await tester.tap(find.byKey(const Key('quick-view-primary')));
    await tester.pumpAndSettle();
    expect(store.bagLines.single.variant.id, old.variants.last.id);
    final photo = find
        .descendant(
          of: find.byKey(const Key('quick-view-card')),
          matching: find.byType(MonettaImage),
        )
        .first;
    await reveal(tester, photo);
    await tester.tap(photo);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quick-view-card')), findsNothing);
    expect(
      tester.widget<ProductScreen>(find.byType(ProductScreen)).initialVariantId,
      old.variants.last.id,
    );
  });
}
