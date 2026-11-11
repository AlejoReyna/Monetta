// The «tarjetas y barra» redesign: ONE rounded warm card for every product
// surface (photo, favourite, brand, name, price and the «VER PRODUCTO» pill),
// tap = quick view, pill = product page, no "+", and the flat bottom bar with
// «Categorías», a shopping cart and no underline.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/monetta_tokens.g.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/media/monetta_image.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/boutique/boutique_tokens.dart';
import 'package:monetta_app/features/catalog/browse_detail_layout.dart';
import 'package:monetta_app/features/catalog/catalog_browse_screen.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/catalog/product_card.dart';
import 'package:monetta_app/features/catalog/product_tile.dart';
import 'package:monetta_app/features/catalog/search_history.dart';
import 'package:monetta_app/features/catalog/search_screen.dart';
import 'package:monetta_app/features/home/home_boutique_sections.dart';
import 'package:monetta_app/features/navigation/monetta_bottom_navigation.dart';
import 'package:monetta_app/features/product/product_screen.dart';
import 'package:monetta_app/main.dart';

import '../../support/bundled_fonts.dart';
import '../../support/product_screen_harness.dart';
import '../../support/quick_add_harness.dart';

/// Android 14 style scaling: not one multiplier. Small type doubles, large
/// type only grows by a constant.
class _StepTextScaler extends TextScaler {
  const _StepTextScaler();

  @override
  double scale(double fontSize) =>
      fontSize <= 16 ? fontSize * 2 : fontSize + 16;

  @override
  double get textScaleFactor => 2;
}

Widget _withScaler(CatalogStore store, Widget home, TextScaler scaler) =>
    StoreScope(
      notifier: store,
      child: MaterialApp(
        theme: buildTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scaler),
          child: child!,
        ),
        home: home,
      ),
    );

const _collection = CollectionScreen(
  title: 'Bolsas',
  filter: CollectionFilter(category: 'bolsa'),
);

bool _isQuickAddKey(Widget widget) =>
    widget.key is ValueKey<String> &&
    (widget.key! as ValueKey<String>).value.startsWith('quick-add-');

/// A pattern of an optional outline path followed by [circles] circles.
PaintPattern _paintsPathAndCircles(int circles, {bool outline = true}) {
  final pattern = paints;
  if (outline) pattern.path();
  for (var i = 0; i < circles; i++) {
    pattern.circle();
  }
  return pattern;
}

/// The first tile of the screen that prints a brand line.
Finder _brandedTile(WidgetTester tester) {
  final tiles =
      tester.widgetList<MonettaProductTile>(find.byType(MonettaProductTile));
  final index = tiles.toList().indexWhere((tile) => tile.data.brand != null);
  expect(index, isNonNegative, reason: 'some card carries a brand');
  return find.byType(MonettaProductTile).at(index);
}

final _priceFormat = RegExp(r'^\$[\d,]+(\.\d\d)? MXN$');

/// A piece on sale: its compare-at price shows struck through next to the
/// price, or under it when the card is narrow.
Product syntheticOnSale([int index = 0]) => syntheticProduct(
      id: 'gid://shopify/Product/95$index',
      title: 'Bolsa de oferta número $index',
      variants: [
        ProductVariant(
          id: 'gid://shopify/ProductVariant/95$index',
          title: 'Default Title',
          price: 1299,
          compareAtPrice: 1999,
          available: true,
        ),
      ],
    );

void main() {
  setUp(mockPathProvider);

  group('CARD-01 anatomy: one warm rounded card', () {
    testWidgets(
        'CARD-01 the collection card holds photo, brand, name, price and '
        '«VER PRODUCTO» in ONE rounded warm container, with no "+"',
        (tester) async {
      setPhoneView(tester, height: 1600);
      final store = await scriptedStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(fichaApp(store, _collection));
      await tester.pump();

      final tile = _brandedTile(tester);
      final palette = tester.element(tile).boutique;
      final data = tester.widget<MonettaProductTile>(tile).data;

      final grounds = find.descendant(
        of: tile,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color == palette.surfaceDeep,
        ),
      );
      expect(grounds, findsOneWidget, reason: 'a single container, no frame');
      expect(palette.surfaceDeep, MonettaTokens.surfaceWarm);
      final decoration =
          tester.widget<DecoratedBox>(grounds).decoration as BoxDecoration;
      expect(decoration.borderRadius, kProductCardRadius);
      expect(kProductCardRadius, const BorderRadius.all(Radius.circular(6)));

      for (final inside in [
        find.byType(MonettaImage),
        find.text(data.brand!),
        find.text(data.title),
        find.text(data.priceLabel),
        find.text('VER PRODUCTO'),
        find.byTooltip('Guardar'),
      ]) {
        expect(
          find.descendant(of: grounds, matching: inside),
          findsWidgets,
          reason: '$inside lives inside the card',
        );
      }
      expect(data.priceLabel, matches(_priceFormat));

      expect(find.byWidgetPredicate(_isQuickAddKey), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'CARD-01 brand and price are Playfair Display bold, the name '
        'Playfair regular in ink; the pill is Inter 400 13 on the action '
        'colour', (tester) async {
      setPhoneView(tester, height: 1600);
      final store = await scriptedStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(fichaApp(store, _collection));
      await tester.pump();

      final tile = _brandedTile(tester);
      final palette = tester.element(tile).boutique;
      final data = tester.widget<MonettaProductTile>(tile).data;
      TextStyle styleOf(String text) => tester
          .widget<Text>(
            find.descendant(of: tile, matching: find.text(text)).first,
          )
          .style!;

      final brand = styleOf(data.brand!);
      expect(brand.fontFamily, kBoutiqueSerifFamily);
      expect(brand.fontWeight, FontWeight.w700);
      expect(brand.fontSize, 15);
      expect(brand.color, palette.ink);

      final name = styleOf(data.title);
      expect(name.fontFamily, kBoutiqueSerifFamily);
      expect(name.fontWeight, FontWeight.w400);
      expect(name.fontSize, 14);
      expect(name.color, palette.ink);

      final price = styleOf(data.priceLabel);
      expect(price.fontFamily, kBoutiqueSerifFamily);
      expect(price.fontWeight, FontWeight.w700);
      expect(price.fontSize, 15);

      final pill = styleOf('VER PRODUCTO');
      expect(pill.fontFamily, kBoutiqueSansFamily);
      expect(pill.fontWeight, FontWeight.w400);
      expect(pill.fontSize, 13);
      expect(pill.letterSpacing, 0.5);
      expect(pill.color, palette.onAction);
      final button = find.descendant(
        of: tile,
        matching: find.byType(TileViewProductButton),
      );
      expect(tester.getSize(button).height, 40);
      expect(
        tester
            .widget<Material>(
              find.descendant(of: button, matching: find.byType(Material)),
            )
            .color,
        palette.action,
      );
    });

    testWidgets('CARD-01 the photo is square and the grid gaps are 8 and 8',
        (tester) async {
      setPhoneView(tester, height: 1600);
      final store = await scriptedStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(fichaApp(store, _collection));
      await tester.pump();

      final tile = find.byType(MonettaProductTile).first;
      final photo = tester.getRect(
        find.descendant(of: tile, matching: find.byType(AspectRatio)).first,
      );
      expect(photo.width, closeTo(photo.height, 0.01));
      final card = tester.getRect(tile);
      expect(photo.left - card.left, 12, reason: 'inner padding');
      expect(card.right - photo.right, 12, reason: 'inner padding');

      final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 2);
      expect(delegate.crossAxisSpacing, 8);
      expect(delegate.mainAxisSpacing, 8);
    });

    testWidgets('CARD-01 the full catalog draws the card, never edgeToEdge',
        (tester) async {
      setPhoneView(tester, height: 1600);
      final store = await scriptedStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(
        fichaApp(store, CatalogBrowseScreen(items: store.catalogItems)),
      );
      await tester.pump();

      final tiles = tester
          .widgetList<MonettaProductTile>(find.byType(MonettaProductTile));
      expect(tiles, isNotEmpty);
      expect(
        tiles.every((tile) => tile.variant == ProductTileVariant.card),
        isTrue,
      );
      expect(find.byWidgetPredicate(_isQuickAddKey), findsNothing);
      expect(find.text('VER PRODUCTO'), findsWidgets);
    });
  });

  group('CARD-02 interaction', () {
    testWidgets(
        'CARD-02 tapping the photo opens the quick view, the pill opens the '
        'ficha, the card reads as a button with its hint', (tester) async {
      setPhoneView(tester, height: 1600);
      final store = await scriptedStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(fichaApp(store, _collection));
      await tester.pump();

      final semantics = tester.ensureSemantics();
      final tile = find.byType(MonettaProductTile).first;
      final hinted = find.descendant(
        of: tile,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.hint == 'Abre la vista previa',
        ),
      );
      final node = tester.getSemantics(hinted.first);
      expect(node.getSemanticsData().hint, 'Abre la vista previa');
      expect(find.bySemanticsLabel('Ver producto'), findsWidgets);
      semantics.dispose();

      await tester.tap(
        find.descendant(of: tile, matching: find.byType(AspectRatio)).first,
      );
      await tester.pumpAndSettle();
      expect(find.text(kAddLabel), findsOneWidget);
      expect(find.byType(ProductScreen), findsNothing);

      // Close the sheet and open the ficha from the pill.
      await tester.tapAt(const Offset(8, 40));
      await tester.pumpAndSettle();
      expect(find.text(kAddLabel), findsNothing);

      await tester.tap(
        find.descendant(of: tile, matching: find.text('VER PRODUCTO')).first,
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProductScreen), findsOneWidget);
    });

    testWidgets('CARD-02 a long press opens the quick view as well',
        (tester) async {
      setPhoneView(tester, height: 1600);
      final store = await scriptedStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(fichaApp(store, _collection));
      await tester.pump();

      await tester.longPress(find.byType(MonettaProductTile).first);
      await tester.pumpAndSettle();
      expect(find.text(kAddLabel), findsOneWidget);
    });

    testWidgets(
        'CARD-02 the quick view opened from a card adds the EXACT variant, '
        'once (invariant 4)', (tester) async {
      setPhoneView(tester, height: 1600);
      final store = await scriptedStore();
      addTearDown(store.dispose);
      final product = singleNamedVariantProduct();
      addProducts(store, [product]);
      await tester.pumpWidget(
        fichaApp(
          store,
          Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 420,
                child: ProductCard(key: cardKey(product), product: product),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byWidgetPredicate(_isQuickAddKey), findsNothing);

      await tester.tap(find.byType(AspectRatio).first);
      await tester.pumpAndSettle();
      expect(store.addCalls, 0, reason: 'opening the sheet adds nothing');
      final primary = find.byKey(kQuickViewPrimaryKey);
      expect(primary, findsOneWidget);
      await tester.tap(primary);
      await tester.pumpAndSettle();

      expect(store.addCalls, 1);
      expect(store.bagLines, hasLength(1));
      expect(store.bagLines.single.variant.id, 'v-negro-unica');
      expect(store.bagLines.single.quantity, 1);
      await flush(tester);
    });

    testWidgets(
        'CARD-02 with a detail pane (BrowseDetailScope) tapping the card '
        'selects the product in the pane, no quick view (D-A3)',
        (tester) async {
      setPhoneView(tester, width: 900, height: 900);
      final store = await scriptedStore();
      addTearDown(store.dispose);
      final product = store.products.firstWhere((p) => p.isInStock);
      final selected = <(String, int)>[];
      await tester.pumpWidget(
        fichaApp(
          store,
          Scaffold(
            body: BrowseDetailScope(
              selectedId: null,
              select: (p, index) => selected.add((p.id, index)),
              register: (_, __, [___]) {},
              child: Center(
                child: SizedBox(
                  width: 220,
                  height: 420,
                  child: ProductCard(product: product),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(AspectRatio).first);
      await tester.pumpAndSettle();
      expect(selected, [(product.id, 0)]);
      expect(find.text(kAddLabel), findsNothing);

      await tester.tap(find.text('VER PRODUCTO'));
      await tester.pumpAndSettle();
      expect(selected.length, 2, reason: 'the pill selects in the pane too');
      expect(find.byType(ProductScreen), findsNothing);
    });

    testWidgets('CARD-02 an explicit onTap still wins', (tester) async {
      setPhoneView(tester);
      final store = await scriptedStore();
      addTearDown(store.dispose);
      final product = store.products.firstWhere((p) => p.isInStock);
      var taps = 0;
      await tester.pumpWidget(
        fichaApp(
          store,
          Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 420,
                child: ProductCard(product: product, onTap: () => taps++),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(AspectRatio).first);
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(find.text(kAddLabel), findsNothing);
    });
  });

  group('CARD-03 formatShopperPrice', () {
    test('CARD-03 thousands separator, no .00, cents only when present', () {
      expect(formatShopperPrice(6299), r'$6,299 MXN');
      expect(formatShopperPrice(1299.5), r'$1,299.50 MXN');
      expect(formatShopperPrice(0.99), r'$0.99 MXN');
      expect(formatShopperPrice(1000000), r'$1,000,000 MXN');
      expect(formatShopperPrice(599), r'$599 MXN');
      expect(formatShopperPrice(1299.0), r'$1,299 MXN');
    });

    test('CARD-03 kMoney is untouched (the bag and the checkout use it)', () {
      expect(kMoney.format(1299), r'$ 1,299.00');
    });
  });

  group('CARD-04 no overflow at 320/390/440 and 1.0/1.3/2.0', () {
    const widths = [320.0, 390.0, 440.0];
    const scales = <(String, TextScaler)>[
      ('1.0', TextScaler.noScaling),
      ('1.3', TextScaler.linear(1.3)),
      ('2.0', TextScaler.linear(2)),
      ('android 2.0 (non linear)', _StepTextScaler()),
    ];

    for (final width in widths) {
      for (final (label, scaler) in scales) {
        testWidgets('CARD-04 collection at $width x$label', (tester) async {
          setPhoneView(tester, width: width, height: 1400);
          final store = await scriptedStore();
          addTearDown(store.dispose);
          await tester.pumpWidget(_withScaler(store, _collection, scaler));
          await tester.pump();
          expect(find.byType(MonettaProductTile), findsWidgets);
          expect(tester.takeException(), isNull);
        });

        testWidgets('CARD-04 search results at $width x$label', (tester) async {
          setPhoneView(tester, width: width, height: 1400);
          final store = await scriptedStore();
          addTearDown(store.dispose);
          await tester.pumpWidget(
            _withScaler(store, SearchScreen(history: SearchHistory()), scaler),
          );
          await tester.pump();
          await tester.enterText(
            find.byKey(const ValueKey('search-query-field')),
            'bolso',
          );
          await tester.pump();
          await tester.testTextInput.receiveAction(TextInputAction.search);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('search-result-grid')),
            findsOneWidget,
          );
          expect(find.byType(MonettaProductTile), findsWidgets);
          expect(tester.takeException(), isNull);
        });

        testWidgets('CARD-04 Home rail at $width x$label', (tester) async {
          setPhoneView(tester, width: width, height: 900);
          final store = await scriptedStore();
          addTearDown(store.dispose);
          // A sale piece too: its compare-at price may wrap under the price.
          final products = [
            ...store.products.take(5),
            syntheticOnSale(),
          ];
          await tester.pumpWidget(
            _withScaler(
              store,
              Scaffold(
                body: ListView(
                  children: [
                    HomeNewArrivalsRail(products: products, onOpenAll: () {}),
                  ],
                ),
              ),
              scaler,
            ),
          );
          await tester.pump();
          expect(find.byType(MonettaProductTile), findsWidgets);
          expect(tester.takeException(), isNull);
        });

        testWidgets('CARD-04 full catalog at $width x$label', (tester) async {
          setPhoneView(tester, width: width, height: 1400);
          final store = await scriptedStore();
          addTearDown(store.dispose);
          await tester.pumpWidget(
            _withScaler(
              store,
              CatalogBrowseScreen(items: store.catalogItems),
              scaler,
            ),
          );
          await tester.pump();
          expect(find.byType(MonettaProductTile), findsWidgets);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets(
        'CARD-04 a two-line sale price keeps the row grid honest (no '
        'overflow with compare-at prices)', (tester) async {
      setPhoneView(tester, height: 1000);
      final store = await scriptedStore();
      addTearDown(store.dispose);
      final products = [for (var i = 0; i < 4; i++) syntheticOnSale(i)];
      await tester.pumpWidget(
        fichaApp(
          store,
          Scaffold(
            body: ProductCardGrid(
              products: products,
              padding: const EdgeInsets.all(20),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(MonettaProductTile), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('NAV-12 the flat bar of the redesign', () {
    Future<void> pumpBar(
      WidgetTester tester, {
      MonettaBottomDestination current = MonettaBottomDestination.catalog,
      double width = 390,
    }) async {
      // Real Inter: the square-glyph test font is wider than any phone label
      // and would push the bar to two rows.
      await tester.runAsync(loadBundledFonts);
      setPhoneView(tester, width: width);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            bottomNavigationBar: MonettaBottomNavigation(
              current: current,
              bagCount: 0,
              onSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets(
        'NAV-12 labels read Inicio, Categorías, Carrito, Cuenta in order, '
        'and the selected one is not underlined', (tester) async {
      await pumpBar(tester);

      final labels = [
        for (final name in ['home', 'catalog', 'bag', 'account'])
          tester.widget<Text>(find.byKey(Key('bottom-nav-$name-label'))).data,
      ];
      expect(labels, ['Inicio', 'Categorías', 'Carrito', 'Cuenta']);
      expect(find.text('Catálogo'), findsNothing);

      final xs = [
        for (final name in ['home', 'catalog', 'bag', 'account'])
          tester.getCenter(find.byKey(Key('bottom-nav-$name'))).dx,
      ];
      expect(xs, [...xs]..sort(), reason: 'left to right, in that order');
      final rows = <double>{
        for (final name in ['home', 'catalog', 'bag', 'account'])
          tester.getCenter(find.byKey(Key('bottom-nav-$name'))).dy,
      };
      expect(rows, hasLength(1), reason: 'one row of four');

      for (final name in ['home', 'catalog', 'bag', 'account']) {
        final style = tester
            .widget<Text>(find.byKey(Key('bottom-nav-$name-label')))
            .style!;
        expect(style.decoration, isNot(TextDecoration.underline), reason: name);
      }
      final selected = tester
          .widget<Text>(find.byKey(const Key('bottom-nav-catalog-label')))
          .style!;
      expect(selected.fontWeight, FontWeight.w600);
      final idle = tester
          .widget<Text>(find.byKey(const Key('bottom-nav-home-label')))
          .style!;
      expect(idle.fontWeight, FontWeight.w400);
    });

    testWidgets('NAV-12 the Carrito glyph is a cart: a basket and two wheels',
        (tester) async {
      await pumpBar(tester);

      RenderObject glyph(String name) => tester.renderObject(
            find.descendant(
              of: find.byKey(Key('bottom-nav-$name-icon')),
              matching: find.byType(CustomPaint),
            ),
          );

      // Basket outline, then exactly two wheels.
      expect(glyph('bag'), _paintsPathAndCircles(2));
      expect(glyph('bag'), isNot(_paintsPathAndCircles(3)));
      // The house has a rectangular door: one outline, no arc, no circle.
      expect(glyph('home'), _paintsPathAndCircles(0));
      expect(glyph('home'), isNot(_paintsPathAndCircles(1)));
      // Four rounded cells for the categories.
      final cells = paints;
      for (var i = 0; i < 4; i++) {
        cells.rrect();
      }
      expect(glyph('catalog'), cells);
      // The person is one head: a single circle.
      expect(glyph('account'), _paintsPathAndCircles(1, outline: false));
      expect(
        glyph('account'),
        isNot(_paintsPathAndCircles(2, outline: false)),
      );
    });
  });
}
