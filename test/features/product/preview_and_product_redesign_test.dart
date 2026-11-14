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
const _railKey = Key('product-rail');

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

  group('PREVIEW-02 closing', () {
    testWidgets('PREVIEW-02 «‹», «×» and the scrim all close the preview',
        (tester) async {
      setPhoneView(tester);
      final store = await scriptedStore();
      addTearDown(store.dispose);
      final product = store.products.firstWhere((p) => p.isInStock);

      for (final close in [
        () => tester.tap(find.byKey(const Key('quick-view-back'))),
        () => tester.tap(find.byKey(const Key('quick-view-close'))),
        () => tester.tapAt(const Offset(6, 6)),
      ]) {
        await pumpQuickView(tester, store, product);
        expect(find.byKey(_cardKey), findsOneWidget);
        await close();
        await tester.pumpAndSettle();
        expect(find.byKey(_cardKey), findsNothing);
        expect(store.addCalls, 0);
      }
    });

    testWidgets('PREVIEW-02 the controls have a name, a role and 48x48',
        (tester) async {
      await withSemantics(tester, () async {
        setPhoneView(tester);
        final store = await scriptedStore();
        addTearDown(store.dispose);
        await pumpQuickView(tester, store, store.products.first);

        for (final (key, name) in [
          ('quick-view-back', 'Regresar'),
          ('quick-view-close', 'Cerrar vista previa'),
        ]) {
          final control = find.byKey(Key(key));
          expect(control, findsOneWidget);
          expect(find.byTooltip(name), findsOneWidget);
          expect(isButtonNode(tester, control), isTrue, reason: name);
          final size = tester.getSize(control);
          expect(size.width, greaterThanOrEqualTo(48 - 0.01), reason: name);
          expect(size.height, greaterThanOrEqualTo(48 - 0.01), reason: name);
        }
      });
    });
  });

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

    testWidgets('PREVIEW-03 colour pieces say «Colores» and not the choice',
        (tester) async {
      setPhoneView(tester);
      final store = await scriptedStore();
      addTearDown(store.dispose);
      final product = swatchProduct();
      addProducts(store, [product]);
      await pumpQuickView(tester, store, product);

      expect(find.text('Colores'), findsOneWidget);
      expect(find.textContaining('Color: '), findsNothing);
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

    testWidgets('PREVIEW-03 no thumbnails with one photo, at most four',
        (tester) async {
      setPhoneView(tester);
      final store = await scriptedStore();
      addTearDown(store.dispose);
      for (final (count, expected) in [(1, 0), (3, 3), (6, 4)]) {
        final product = _withPhotos(count);
        addProducts(store, [product]);
        await pumpQuickView(tester, store, product);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith('thumb-'),
          ),
          findsNWidgets(expected),
          reason: '$count photos',
        );
        if (expected > 1) {
          final sides = {
            for (var i = 0; i < expected; i++)
              tester.getSize(find.byKey(ValueKey('thumb-$i'))),
          };
          expect(sides, hasLength(1), reason: 'equal thumbnails');
          expect(sides.single.width, sides.single.height);
        }
        await tester.tapAt(const Offset(6, 6));
        await tester.pumpAndSettle();
      }
    });
  });

  group('PREVIEW-04 the exact variant is added (invariant 4)', () {
    testWidgets(
        'PREVIEW-04 «Agregar al carrito» adds the variant chosen, once, then '
        'closes and confirms', (tester) async {
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
      expect(find.byKey(_cardKey), findsNothing);
      expect(find.text('En tu bolsa'), findsOneWidget);
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

    testWidgets(
        'PREVIEW-04 the swatch is a 30pt disc in a 48pt target, the '
        'chosen one ringed in ink', (tester) async {
      setPhoneView(tester);
      final store = await scriptedStore();
      addTearDown(store.dispose);
      final product = swatchProduct();
      addProducts(store, [product]);
      await pumpQuickView(tester, store, product);

      final first = optionOf(product, selectableVariants(product).first);
      final second = optionOf(product, selectableVariants(product)[1]);
      expect(tester.getSize(first), const Size(48, 48));
      final disc = find
          .descendant(
            of: first,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Container &&
                  widget.constraints?.maxWidth == 30 &&
                  widget.constraints?.maxHeight == 30,
            ),
          )
          .first;
      expect(tester.getSize(disc), const Size(30, 30));

      Color ringOf(Finder swatch) {
        final ring = find
            .descendant(
              of: swatch,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Container &&
                    widget.decoration is BoxDecoration &&
                    (widget.decoration! as BoxDecoration).shape ==
                        BoxShape.circle &&
                    (widget.decoration! as BoxDecoration).border != null &&
                    widget.padding != null,
              ),
            )
            .first;
        return ((tester.widget<Container>(ring).decoration! as BoxDecoration)
                .border! as Border)
            .top
            .color;
      }

      final ink = tester.element(first).boutique.ink;
      expect(ringOf(first), ink, reason: 'the chosen one wears the ring');
      expect(ringOf(second), Colors.transparent);
    });
  });

  group('PRODUCT-01 the product page like the reference', () {
    testWidgets(
        'PRODUCT-01 a square gallery with no rule indicator, four thumbnails '
        'at most, accordions closed', (tester) async {
      setPhoneView(tester, height: 1800);
      final store = await loadedStore();
      addTearDown(store.dispose);
      final product = _withPhotos(6);
      addProducts(store, [product]);
      await pumpFicha(tester, store, product.id);

      final gallery = tester.getRect(find.byType(PageView));
      expect(gallery.width, closeTo(gallery.height, 0.01), reason: 'square');
      expect(gallery.left, BoutiqueSpace.gutter, reason: 'side margin');
      expect(gallery.width, 390 - 2 * BoutiqueSpace.gutter);

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is AnimatedContainer && widget.constraints?.maxHeight == 2,
        ),
        findsNothing,
        reason: 'no rule indicator when there are thumbnails',
      );
      final thumbs = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('thumb-'),
      );
      expect(thumbs, findsNWidgets(4));
      final rects = [
        for (var i = 0; i < 4; i++)
          tester.getRect(find.byKey(ValueKey('thumb-$i'))),
      ];
      expect(rects.first.left, BoutiqueSpace.gutter);
      expect(rects.last.right, closeTo(390 - BoutiqueSpace.gutter, 0.01));
      expect({for (final r in rects) r.width.toStringAsFixed(2)}, hasLength(1));

      final turns = tester
          .widgetList<AnimatedRotation>(find.byType(AnimatedRotation))
          .map((rotation) => rotation.turns)
          .toList();
      expect(turns, [0, 0, 0], reason: 'the three accordions start closed');
      expect(find.textContaining('Envío a todo México'), findsNothing);
    });

    testWidgets('PRODUCT-01 one photo has neither rules nor thumbnails',
        (tester) async {
      setPhoneView(tester, height: 1800);
      final store = await loadedStore();
      addTearDown(store.dispose);
      final product = _withPhotos(1);
      addProducts(store, [product]);
      await pumpFicha(tester, store, product.id);

      expect(find.byKey(const ValueKey('thumb-0')), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is AnimatedContainer && widget.constraints?.maxHeight == 2,
        ),
        findsNothing,
      );
      expect(find.byKey(const Key('product-gallery-prev')), findsNothing);
    });

    testWidgets(
        'PRODUCT-01 vertical order: price, options, trust row, add, buy now, '
        'availability, Descripción', (tester) async {
      setPhoneView(tester, height: 1800);
      final store = await loadedStore();
      addTearDown(store.dispose);
      final product = store.products.firstWhere(
        (p) =>
            p.isInStock &&
            hasReliableColorOptions(p) &&
            selectableVariants(p).length > 1 &&
            p.variants.every((v) => v.available),
      );
      await pumpFicha(tester, store, product.id);

      final steps = <(String, Finder)>[
        ('price', find.byKey(const Key('product-price'))),
        ('options', find.byType(ProductOptionSelector)),
        ('trust row', find.byKey(const Key('product-trust-row'))),
        ('add', find.byKey(kDockPrimaryKey)),
        ('buy now', find.byKey(kBuyNowKey)),
        ('availability', find.textContaining('Disponible')),
        ('apartado', find.text(kApartadoSentence)),
        ('Descripción', find.text('Descripción')),
        ('Detalles', find.text('Detalles')),
        ('Envíos', find.text('Envíos y devoluciones')),
        ('WhatsApp', find.text('Escribir por WhatsApp')),
        ('Otras formas', find.byKey(kPurchaseSectionKey)),
      ];
      var previous = -1.0;
      for (final (name, finder) in steps) {
        final offset = await contentOffsetOf(tester, finder);
        expect(offset, greaterThan(previous), reason: '$name comes after');
        previous = offset;
      }
      // The related rail is the last block.
      final related = find.text('Productos relacionados');
      if (related.evaluate().isNotEmpty ||
          store
              .moreFromBrand(
                store.facetsFor(product.id)!.brand!.value,
                excluding: product.id,
              )
              .isNotEmpty) {
        final offset = await contentOffsetOf(tester, related);
        expect(offset, greaterThan(previous), reason: 'related last');
      }
    });

    testWidgets(
        'PRODUCT-01 the color label carries the choice and the buttons are '
        '52pt pills', (tester) async {
      setPhoneView(tester, height: 1800);
      final store = await loadedStore();
      addTearDown(store.dispose);
      final product = store.products.firstWhere(
        (p) =>
            p.isInStock &&
            hasReliableColorOptions(p) &&
            selectableVariants(p).length > 1 &&
            p.variants.every((v) => v.available),
      );
      await pumpFicha(tester, store, product.id);

      final first = selectableVariants(product).first;
      await scrollTo(tester, find.byType(ProductOptionSelector));
      expect(find.text('Color: ${first.title}'), findsOneWidget);

      for (final key in [kDockPrimaryKey, kBuyNowKey]) {
        await scrollTo(tester, find.byKey(key));
        expect(tester.getSize(find.byKey(key)).height, 52, reason: '$key');
      }
      final palette = tester.element(find.byKey(kBuyNowKey)).boutique;
      final label = tester.widget<Text>(
        find.descendant(
          of: find.byKey(kBuyNowKey),
          matching: find.text('Comprar ahora'),
        ),
      );
      expect(label.style!.color, palette.ink);
      expect(label.style!.fontWeight, FontWeight.w400);
      expect(label.style!.fontSize, 15);
    });

    testWidgets('PRODUCT-01 «Agregar a bolsa» keeps adding the exact variant',
        (tester) async {
      setPhoneView(tester, height: 1800);
      final store = await scriptedStore();
      addTearDown(store.dispose);
      final product = swatchProduct();
      addProducts(store, [product]);
      await pumpFicha(tester, store, product.id);

      final second = selectableVariants(product)[1];
      await scrollTo(tester, optionOf(product, second));
      await tester.tap(optionOf(product, second));
      await tester.pump();
      await scrollTo(tester, find.byKey(kDockPrimaryKey));
      await tester.tap(find.byKey(kDockPrimaryKey));
      await tester.pumpAndSettle();

      expect(store.addCalls, 1);
      expect(store.bagLines.single.variant.id, second.id);
      await flush(tester);
    });
  });

  group('PRODUCT-02 related pieces: four mini cards across', () {
    testWidgets('PRODUCT-02 at 390 four mini cards are fully visible',
        (tester) async {
      setPhoneView(tester, height: 1800);
      final store = await loadedStore();
      addTearDown(store.dispose);
      final product = _withRelated(store, others: 5);
      await pumpFicha(tester, store, product.id);
      await scrollTo(tester, find.byKey(_railKey));

      final tiles = tester
          .widgetList<MonettaProductTile>(
            find.descendant(
              of: find.byKey(_railKey),
              matching: find.byType(MonettaProductTile),
            ),
          )
          .toList();
      expect(tiles.length, greaterThanOrEqualTo(4));
      expect(
        tiles.every((tile) => tile.density == ProductTileDensity.mini),
        isTrue,
      );
      final rects = [
        for (var i = 0; i < 4; i++)
          tester.getRect(find.byType(MonettaProductTile).at(i)),
      ];
      const screen = Rect.fromLTWH(0, 0, 390, 1800);
      const gutter = BoutiqueSpace.gutter;
      final width = (390 - 2 * gutter - 3 * 8) / 4;
      for (final (i, rect) in rects.indexed) {
        expect(screen.contains(rect.topLeft), isTrue, reason: 'card $i $rect');
        expect(rect.right, lessThanOrEqualTo(390 - gutter + 0.01));
        expect(rect.width, closeTo(width, 0.01), reason: 'card $i');
      }
      expect(rects.first.left, closeTo(gutter, 0.01));
      expect(rects[3].right, closeTo(390 - gutter, 0.01));
      // Square photo, no pill, a 40pt heart.
      final first = find.byType(MonettaProductTile).first;
      final photo = tester.getRect(
        find.descendant(of: first, matching: find.byType(AspectRatio)).first,
      );
      expect(photo.width, closeTo(photo.height, 0.01));
      expect(
        find.descendant(of: first, matching: find.text('VER PRODUCTO')),
        findsNothing,
      );
      expect(
        tester
            .getSize(
              find
                  .descendant(of: first, matching: find.byType(IconButton))
                  .first,
            )
            .width,
        40,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('PRODUCT-02 tapping a mini card opens the preview',
        (tester) async {
      setPhoneView(tester, height: 1800);
      final store = await loadedStore();
      addTearDown(store.dispose);
      final product = _withRelated(store, others: 5);
      await pumpFicha(tester, store, product.id);
      await scrollTo(tester, find.byKey(_railKey));

      await tester.tap(find.byType(MonettaProductTile).first);
      await tester.pumpAndSettle();
      expect(find.byKey(_cardKey), findsOneWidget);
    });

    testWidgets(
        'PRODUCT-02 with text scale 2.0 the rail falls back to the compact '
        'card at about 40 % of the width', (tester) async {
      setPhoneView(tester, height: 1800);
      final store = await loadedStore();
      addTearDown(store.dispose);
      final product = _withRelated(store, others: 5);
      await pumpFicha(tester, store, product.id, scale: 2);
      await scrollTo(tester, find.byKey(_railKey));

      final tiles = tester
          .widgetList<MonettaProductTile>(
            find.descendant(
              of: find.byKey(_railKey),
              matching: find.byType(MonettaProductTile),
            ),
          )
          .toList();
      expect(tiles, isNotEmpty);
      expect(
        tiles.every((tile) => tile.density == ProductTileDensity.compact),
        isTrue,
      );
      final width = tester.getSize(find.byType(MonettaProductTile).first).width;
      expect(width / 390, closeTo(0.4, 0.01));
      expect(tester.takeException(), isNull);
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
        'CARD-05 one price line: with sale pieces around, the gap between '
        'the price and «VER PRODUCTO» stays small and nothing overflows',
        (tester) async {
      await tester.runAsync(loadBundledFonts);
      final store = await scriptedStore();
      addTearDown(store.dispose);
      // Bundled pieces on sale with a brand (the caption reserves a brand
      // line), plus a synthetic one without a brand.
      final sale = store.products
          .where(
            (p) =>
                p.isOnSale &&
                p.isInStock &&
                store.facetsFor(p.id)?.brand != null,
          )
          .take(6)
          .toList();
      expect(sale.length, greaterThanOrEqualTo(2), reason: 'precondition');
      final products = [...sale, _onSale()];
      expect(tilePriceLinesFor(products), 1, reason: 'no second line');

      for (final scale in [1.0, 1.3, 2.0]) {
        setPhoneView(tester, height: 2400);
        await tester.pumpWidget(
          fichaApp(
            store,
            Scaffold(
              body: ProductCardGrid(
                products: products,
                padding: const EdgeInsets.all(20),
              ),
            ),
            scale: scale,
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'scale $scale');
        if (scale != 1.0) continue;

        var measured = 0;
        for (final tile in tester.widgetList<MonettaProductTile>(
          find.byType(MonettaProductTile),
        )) {
          final data = tile.data;
          final scope = find.byWidget(tile);
          final name = find.descendant(
            of: scope,
            matching: find.text(data.title),
          );
          if (data.brand == null || tester.getSize(name.last).height < 26) {
            continue; // the gap is measured on two-line names
          }
          final price = tester.getRect(
            find
                .ancestor(
                  of: find.descendant(
                    of: scope,
                    matching: find.text(data.priceLabel),
                  ),
                  matching: find.byType(FittedBox),
                )
                .first,
          );
          final pill = tester.getRect(
            find.descendant(
              of: scope,
              matching: find.byType(TileViewProductButton),
            ),
          );
          expect(
            pill.top - price.bottom,
            lessThanOrEqualTo(12),
            reason: data.title,
          );
          expect(pill.top - price.bottom, greaterThanOrEqualTo(0));
          // The struck compare-at price shares the line with the price.
          if (data.compareAtLabel case final before?) {
            final struck = tester.getRect(
              find.descendant(of: scope, matching: find.text(before)),
            );
            expect(struck.center.dy, closeTo(price.center.dy, 4));
          }
          measured++;
        }
        expect(measured, greaterThan(0), reason: 'a two-line name was found');
      }
    });

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
