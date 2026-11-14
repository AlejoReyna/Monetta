// The «tarjetas y barra» redesign, part B: the preview is a centred card over
// the dimmed screen (not a bottom sheet) and the product page is ordered and
// drawn like the reference. Also the part A follow-ups that live in the tile:
// one price line, the packshot blend and the mini card.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/shopper_copy.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/boutique/boutique_tokens.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/catalog/product_card.dart';
import 'package:monetta_app/features/catalog/product_tile.dart';
import 'package:monetta_app/features/product/product_screen.dart';
import 'package:monetta_app/features/product/product_selection.dart';
import 'package:monetta_app/reco/explainer.dart';
import 'package:monetta_app/reco/events.dart';

import '../../support/bundled_fonts.dart';
import '../../support/product_screen_harness.dart';
import '../../support/quick_add_harness.dart';

const _collection = CollectionScreen(
  title: 'Bolsas',
  filter: CollectionFilter(category: 'bolsa'),
);

final _priceFormat = RegExp(r'^\$[\d,]+(\.\d\d)? MXN$');

const _cardKey = Key('quick-view-card');

/// A piece on sale, so the preview and the cards carry a compare-at price.
Product _onSale([int index = 0]) => syntheticProduct(
      id: 'gid://shopify/Product/96$index',
      title: 'Bolsa de oferta número $index con nombre largo para dos líneas',
      variants: [
        ProductVariant(
          id: 'gid://shopify/ProductVariant/96$index',
          title: 'Default Title',
          price: 1299,
          compareAtPrice: 1999,
          available: true,
        ),
      ],
    );

/// A piece with [count] photographs (they never resolve in a test: the photo
/// falls back to its label, which is all the layout needs).
Product _withPhotos(int count) {
  final base = syntheticProduct(id: 'gid://shopify/Product/9701');
  return Product(
    id: base.id,
    handle: base.handle,
    title: 'Bolsa con fotos',
    vendor: '',
    productType: '',
    tags: const [],
    variants: base.variants,
    images: [
      for (var i = 0; i < count; i++) 'https://example.test/foto-$i.jpg',
    ],
    createdAt: base.createdAt,
    updatedAt: base.updatedAt,
  );
}

/// An in-stock bundled piece with a brand and at least [others] other pieces
/// of that brand, so the related rail has something to draw.
Product _withRelated(CatalogStore store, {int others = 4}) =>
    store.products.firstWhere((product) {
      if (!product.isInStock) return false;
      final brand = store.facetsFor(product.id)?.brand?.value;
      return brand != null &&
          store.moreFromBrand(brand, excluding: product.id).length >= others;
    });

Finder _inCard(Finder matching) =>
    find.descendant(of: find.byKey(_cardKey), matching: matching);

void main() {
  setUp(mockPathProvider);

  group('PREVIEW-01 the preview is a centred card, not a bottom sheet', () {
    testWidgets(
        'PREVIEW-01 tapping a card opens quick-view-card centred, narrower '
        'than the screen and at most 440, with no BottomSheet', (tester) async {
      setPhoneView(tester, height: 1600);
      final store = await scriptedStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(fichaApp(store, _collection));
      await tester.pump();

      await tester.tap(
        find
            .descendant(
              of: find.byType(MonettaProductTile).first,
              matching: find.byType(AspectRatio),
            )
            .first,
      );
      await tester.pumpAndSettle();

      final card = find.byKey(_cardKey);
      expect(card, findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(DraggableScrollableSheet), findsNothing);
      final rect = tester.getRect(card);
      expect(rect.center.dx, closeTo(390 / 2, 1));
      expect(rect.width, lessThanOrEqualTo(440));
      expect(rect.width, lessThan(390));
      expect(rect.width / 390, closeTo(0.79, 0.01));
      expect(rect.left, greaterThanOrEqualTo(28 - 0.01));
      expect(tester.takeException(), isNull);
    });

    testWidgets('PREVIEW-01 on a wide screen the card stops at 440',
        (tester) async {
      setPhoneView(tester, width: 900, height: 900);
      final store = await scriptedStore();
      addTearDown(store.dispose);
      await pumpQuickView(tester, store, store.products.first);

      final rect = tester.getRect(find.byKey(_cardKey));
      expect(rect.width, 440);
      expect(rect.center.dx, closeTo(450, 1));
    });

    testWidgets('PREVIEW-01 the card sits on the dimmed screen: a scrim',
        (tester) async {
      setPhoneView(tester);
      final store = await scriptedStore();
      addTearDown(store.dispose);
      await pumpQuickView(tester, store, store.products.first);

      final barrier = tester
          .widgetList<ModalBarrier>(find.byType(ModalBarrier))
          .where((barrier) => barrier.color != null)
          .toList();
      expect(barrier, isNotEmpty);
      final scrim = tester.element(find.byKey(_cardKey)).monettaColors.scrim;
      expect(barrier.last.color, scrim);
      expect(barrier.last.dismissible, isTrue);
      expect(barrier.last.semanticsLabel, 'Cerrar vista previa');
    });
  });

  group('PREVIEW-02 closing', () {});

  group('PREVIEW-03 content', () {
    testWidgets(
        'PREVIEW-03 brand, name, a "\$… MXN" price, Stock «Disponible» and '
        'never «Últimas»', (tester) async {
      setPhoneView(tester);
      final store = await scriptedStore();
      addTearDown(store.dispose);
      final product = _withRelated(store, others: 1);
      await pumpQuickView(tester, store, product);

      final brand = store.facetsFor(product.id)!.brand!.value;
      expect(
        tester.widget<Text>(find.byKey(const Key('quick-view-brand'))).data,
        brandLabel(brand),
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('quick-view-name'))).data,
        shopperProductName(product.title),
      );
      final price =
          tester.widget<Text>(find.byKey(const Key('quick-view-price'))).data!;
      expect(price, matches(_priceFormat));
      expect(price, formatShopperPrice(selectionPrice(product, 0)));

      expect(find.text('Stock'), findsOneWidget);
      final stock = find.byKey(const Key('quick-view-stock'));
      expect(
        find.descendant(of: stock, matching: find.text('Disponible')),
        findsOneWidget,
      );
      expect(find.textContaining('Últimas'), findsNothing);
    });

    testWidgets('PREVIEW-03 a sold-out piece says «Agotado» in the sale tint',
        (tester) async {
      setPhoneView(tester);
      final store = await scriptedStore();
      addTearDown(store.dispose);
      final product = soldOutProduct();
      addProducts(store, [product]);
      await pumpQuickView(tester, store, product);

      final stock = find.byKey(const Key('quick-view-stock'));
      expect(
        find.descendant(of: stock, matching: find.text('Agotado')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: stock, matching: find.text('Disponible')),
        findsNothing,
      );
      final palette = tester.element(stock).boutique;
      final decoration =
          tester.widget<Container>(stock).decoration! as BoxDecoration;
      expect(decoration.color, palette.saleSurface);
      expect(find.textContaining('Últimas'), findsNothing);
    });

    testWidgets(
        'PREVIEW-03 a sale piece shows the struck compare-at price and the '
        '-X% pill on the price line when they fit', (tester) async {
      await tester.runAsync(loadBundledFonts);
      // 440 wide: the card holds the three runs on one line (at 390 a
      // four-digit price wraps the pill under it, which the Wrap allows).
      setPhoneView(tester, width: 440, height: 956);
      final store = await scriptedStore();
      addTearDown(store.dispose);
      final product = _onSale();
      addProducts(store, [product]);
      await pumpQuickView(tester, store, product);

      final price = tester.getRect(find.byKey(const Key('quick-view-price')));
      final pill = tester.getRect(find.byKey(const ValueKey('discount-badge')));
      expect(find.text('-35%'), findsOneWidget);
      expect(find.text(formatShopperPrice(1999)), findsOneWidget);
      expect(
        (pill.center.dy - price.center.dy).abs(),
        lessThan(8),
        reason: 'the same line when it fits',
      );
    });
  });

  group('PREVIEW-04 the exact variant is added (invariant 4)', () {
    testWidgets(
        'PREVIEW-04 «Agregar al carrito» adds the variant chosen, once, then '
        'stays open and confirms', (tester) async {
      setPhoneView(tester);
      final store = await scriptedStore();
      addTearDown(store.dispose);
      final product = swatchProduct();
      addProducts(store, [product]);
      await pumpQuickView(tester, store, product);

      final second = selectableVariants(product)[1];
      expect(second.id, isNot(selectableVariants(product).first.id));
      await pickVariant(tester, product, second);
      expect(store.addCalls, 0, reason: 'choosing adds nothing');
      expect(selectionMarks(), findsOneWidget);

      await tester.tap(find.byKey(kQuickViewPrimaryKey));
      await tester.pumpAndSettle();

      expect(store.addCalls, 1);
      expect(store.bagLines, hasLength(1));
      expect(store.bagLines.single.variant.id, second.id);
      expect(store.bagLines.single.quantity, 1);
      // UI v4.1: the quick view stays open and confirms; the cart stays shut.
      expect(find.byKey(_cardKey), findsOneWidget);
      expect(find.text('Agregado al carrito'), findsOneWidget);
      expect(find.text('En tu bolsa'), findsNothing);
      await flush(tester);
    });

    testWidgets('PREVIEW-04 «VER PRODUCTO» opens the ficha with that variant',
        (tester) async {
      setPhoneView(tester, height: 1000);
      final store = await scriptedStore();
      addTearDown(store.dispose);
      final product = swatchProduct();
      addProducts(store, [product]);
      await pumpQuickView(tester, store, product);
      await pickVariant(tester, product, selectableVariants(product)[2]);

      await revealInSheet(tester, find.byKey(kQuickViewViewProductKey));
      await tester.tap(find.byKey(kQuickViewViewProductKey));
      await tester.pumpAndSettle();

      expect(find.byType(ProductScreen), findsOneWidget);
      expect(find.byKey(_cardKey), findsNothing);
      expect(
        tester
            .widget<ProductOptionSelector>(find.byType(ProductOptionSelector))
            .selectedIndex,
        2,
      );
      expect(store.addCalls, 0);
    });
  });

  group('PREVIEW-05 / PRODUCT-03 no overflow', () {
    const sizes = [Size(320, 568), Size(390, 844), Size(440, 956)];
    const scales = [1.0, 1.3, 2.0];

    for (final size in sizes) {
      for (final scale in scales) {
        final name = '${size.width.toInt()}x${size.height.toInt()} x$scale';

        testWidgets('PREVIEW-05 the preview at $name', (tester) async {
          setPhoneView(tester, width: size.width, height: size.height);
          final store = await scriptedStore();
          addTearDown(store.dispose);
          final sale = _onSale();
          final several = swatchProduct();
          final chips = chipProduct();
          addProducts(store, [sale, several, chips]);
          final pieces = [
            sale,
            several,
            chips,
            _withRelated(store),
            soldOutProduct(),
          ];
          addProducts(store, [pieces.last]);
          for (final product in pieces) {
            await pumpQuickView(tester, store, product, scale: scale);
            expect(find.byKey(_cardKey), findsOneWidget);
            expect(tester.takeException(), isNull, reason: product.title);
            final card = tester.getRect(find.byKey(_cardKey));
            expect(
              Rect.fromLTWH(0, 0, size.width, size.height).contains(
                card.bottomRight,
              ),
              isTrue,
              reason: 'the card stays on screen: $card',
            );
            await tester.tapAt(const Offset(2, 2));
            await tester.pumpAndSettle();
          }
        });

        testWidgets('PRODUCT-03 the product page at $name', (tester) async {
          setPhoneView(tester, width: size.width, height: size.height);
          final store = await loadedStore();
          addTearDown(store.dispose);
          final product = _withRelated(store);
          store.record(
            EventType.productView,
            productId: store.products.firstWhere((p) => p.id != product.id).id,
          );
          addProducts(store, [_withPhotos(5), _onSale(1), soldOutProduct()]);
          for (final id in [
            product.id,
            _withPhotos(5).id,
            _onSale(1).id,
            soldOutProduct().id,
          ]) {
            await pumpFicha(tester, store, id, scale: scale);
            expect(tester.takeException(), isNull, reason: id);
            await scrollToEnd(tester);
            expect(tester.takeException(), isNull, reason: '$id (end)');
          }
        });
      }
    }
  });

  group('CARD-05 follow-ups of part A in the tile', () {
    testWidgets(
        'CARD-05 PackshotBlend lifts the photo 3 % and multiplies it onto '
        'the ground in the light theme; the dark theme keeps it as shot',
        (tester) async {
      const ground = Color(0xFFF3EADF);
      Widget host(ThemeData theme) => MaterialApp(
            theme: theme,
            home: const PackshotBlend(
              ground: ground,
              child: SizedBox(width: 10, height: 10),
            ),
          );

      await tester.pumpWidget(host(buildLightTheme()));
      final filters = tester
          .widgetList<ColorFiltered>(find.byType(ColorFiltered))
          .map((f) => f.colorFilter)
          .toList();
      expect(filters, hasLength(2));
      // Outer: multiply with the ground. Inner: brightness ×1.03.
      expect(filters.first, const ColorFilter.mode(ground, BlendMode.multiply));
      expect(filters.last, kPackshotLiftFilter);

      await tester.pumpWidget(host(buildDarkTheme()));
      await tester.pumpAndSettle();
      expect(find.byType(ColorFiltered), findsNothing);
    });

    testWidgets(
        'CARD-05 the card photo, the preview and the thumbnails all go '
        'through PackshotBlend', (tester) async {
      setPhoneView(tester);
      final store = await scriptedStore();
      addTearDown(store.dispose);
      await pumpQuickView(tester, store, _withPhotos(3));
      // Gallery page + three thumbnails.
      expect(_inCard(find.byType(PackshotBlend)), findsAtLeastNWidgets(4));
    });
  });
}
