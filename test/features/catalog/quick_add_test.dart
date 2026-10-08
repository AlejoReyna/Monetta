import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/catalog/product_card.dart';
import 'package:monetta_app/features/product/product_screen.dart';
import 'package:monetta_app/features/product/product_selection.dart';

import '../../support/product_screen_harness.dart';
import '../../support/quick_add_harness.dart';
import '../../support/scripted_catalog_store.dart';

// FICHA-T3, QUICK-01..03b, CART-03/04 on the card (BRIEF 2.6): the "+" of the
// Monetta cards. One buyable variant adds straight away; several open the
// quick view so the shopper picks explicitly; nothing is ever added silently.
//
// The "+" is measured on its tappable zone (`quick-add-<product.id>`, 48x48),
// not on the circle or the icon. Nothing here exists in `lib/` yet: every test
// that looks for the key is red until the control is built.

Finder _inMiniCart() => find.text('En tu bolsa');

Finder _closeQuickView() => find.byTooltip(kCloseQuickViewTooltip);

Finder _progress() =>
    find.byWidgetPredicate((widget) => widget is ProgressIndicator);

Finder _snackbarMessage() => find.descendant(
      of: find.byType(SnackBar),
      matching: find.text(kAddFailureMessage),
    );

/// Mounts one card on a scripted store holding [extra].
Future<ScriptedCatalogStore> _mountCard(
  WidgetTester tester,
  Product Function(ScriptedCatalogStore store) pick, {
  List<Product> extra = const [],
  VoidCallback? onQuickView,
  bool wireQuickView = true,
}) async {
  setPhoneView(tester);
  final store = await scriptedStore();
  addProducts(store, extra);
  final product = pick(store);
  await tester.pumpWidget(
    cardApp(
      store,
      product,
      onQuickView: onQuickView,
      wireQuickView: wireQuickView,
    ),
  );
  await tester.pump();
  return store;
}

void main() {
  setUpAll(mockPathProvider);

  group('QUICK-01 the "+" replaces the eye on buyable cards', () {
    for (final entry in <(String, Product Function(ScriptedCatalogStore))>[
      ('single-variant', singleVariantAssetProduct),
      ('multi-variant', chipAssetProduct),
    ]) {
      testWidgets(
          'QUICK-01 a ${entry.$1} card shows the 48x48 "+" at the photo '
          'corner, named for the piece, and no eye', (tester) async {
        await withSemantics(tester, () async {
          final store = await _mountCard(tester, entry.$2);
          final product = entry.$2(store);
          final plus = quickAddOf(product);

          expectQuickAddGeometry(tester, plus);
          expect(find.text('AGOTADO'), findsNothing);

          final node = tester.getSemantics(plus);
          expect(node.label, addLabelFor(store, product));
          expect(isButtonNode(tester, plus), isTrue, reason: 'button role');
          expect(isEnabledControl(tester, plus), isTrue, reason: 'enabled');
          expect(
            find.byTooltip(kQuickViewTooltip),
            findsNothing,
            reason: 'never both controls on one card',
          );
        });
      });
    }

    testWidgets(
        'QUICK-01 a fully sold-out piece has no "+" and keeps the eye, which '
        'still opens the quick view callback', (tester) async {
      var quickViews = 0;
      final soldOut = soldOutProduct();
      final store = await _mountCard(
        tester,
        (_) => soldOut,
        extra: [soldOut],
        onQuickView: () => quickViews++,
      );

      expect(quickAddOf(soldOut), findsNothing);
      expect(find.text('AGOTADO'), findsOneWidget);
      expect(find.byTooltip(kQuickViewTooltip), findsOneWidget);
      await tester.tap(find.byTooltip(kQuickViewTooltip));
      await tester.pump();
      expect(quickViews, 1);
      expect(store.addCalls, 0);
      expect(store.bagQuantity, 0);
    });

    testWidgets(
        'QUICK-01 a sold-out piece on a surface without quick view has '
        'neither control', (tester) async {
      final soldOut = soldOutProduct();
      await _mountCard(
        tester,
        (_) => soldOut,
        extra: [soldOut],
        wireQuickView: false,
      );

      expect(quickAddOf(soldOut), findsNothing);
      expect(find.byTooltip(kQuickViewTooltip), findsNothing);
    });

    testWidgets(
        'QUICK-01 ProductCardGrid: every buyable card has its "+", the '
        'sold-out one keeps the eye', (tester) async {
      setPhoneView(tester);
      final store = await scriptedStore();
      final soldOut = soldOutProduct();
      addProducts(store, [soldOut]);
      final single = singleVariantAssetProduct(store);
      final several = chipAssetProduct(store);
      await tester.pumpWidget(gridApp(store, [single, several, soldOut]));
      await tester.pump();

      for (final product in [single, several]) {
        expectQuickAddGeometry(tester, quickAddOf(product));
      }
      expect(quickAddOf(soldOut), findsNothing);
      expect(find.byTooltip(kQuickViewTooltip), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(cardKey(soldOut)),
          matching: find.byTooltip(kQuickViewTooltip),
        ),
        findsOneWidget,
        reason: 'the eye belongs to the sold-out card',
      );
    });

    testWidgets('QUICK-01 CollectionScreen: every card has its "+", no eye',
        (tester) async {
      setPhoneView(tester, height: 1600);
      final store = await scriptedStore();
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

      final cards = tester.widgetList<ProductCard>(find.byType(ProductCard));
      expect(cards, isNotEmpty);
      for (final card in cards) {
        expect(
          quickAddOf(card.product),
          findsOneWidget,
          reason: '${card.product.title} is buyable',
        );
      }
      expectQuickAddGeometry(tester, quickAddOf(cards.first.product));
      expect(find.byTooltip(kQuickViewTooltip), findsNothing);
    });

    group('CatalogBrowseScreen', () {
      Future<(ScriptedCatalogStore, List<Product>, Product, Product)> mount(
        WidgetTester tester, {
        bool withStore = true,
      }) async {
        setPhoneView(tester, height: 1600);
        final store = await scriptedStore();
        final soldOut = soldOutProduct();
        addProducts(store, [soldOut]);
        final single = singleVariantAssetProduct(store);
        final several = chipAssetProduct(store);
        final items = [soldOut, single, several];
        await tester.pumpWidget(catalogApp(withStore ? store : null, items));
        await tester.pump();
        return (store, items, single, several);
      }

      testWidgets(
          'QUICK-01 a Monetta card has its "+" keyed by the Shopify id; '
          'sold-out pieces have none', (tester) async {
        await withSemantics(tester, () async {
          final (store, items, single, several) = await mount(tester);
          final soldOutId = items.first.id;

          for (final product in [single, several]) {
            final plus = find.byKey(quickAddKey(product.id));
            expectQuickAddGeometry(tester, plus);
            expect(
              tester.getSemantics(plus).label,
              addLabelFor(store, product),
            );
          }
          expect(find.byKey(quickAddKey(soldOutId)), findsNothing);
          expect(find.text('AGOTADO'), findsOneWidget);
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget.key is ValueKey<String> &&
                  (widget.key! as ValueKey<String>)
                      .value
                      .startsWith('quick-add-'),
            ),
            findsNWidgets(2),
            reason: 'only the two buyable Monetta pieces carry a "+"',
          );
        });
      });

      testWidgets(
          'QUICK-01 without a StoreScope the catalog mounts without "+" and '
          'without exceptions (characterization)', (tester) async {
        final (_, items, _, _) = await mount(tester, withStore: false);

        expect(tester.takeException(), isNull);
        expect(find.byType(MonettaProductTile), findsWidgets);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>)
                    .value
                    .startsWith('quick-add-'),
          ),
          findsNothing,
        );
        expect(items, isNotEmpty);
      });
    });
  });

  group('QUICK-01b the controls of a card stay separate', () {
    testWidgets(
        'QUICK-01b tapping the "+" of a several-variant card opens neither '
        'the ficha nor changes favourites', (tester) async {
      final store = await _mountCard(tester, chipAssetProduct);
      final product = chipAssetProduct(store);
      final wishlistBefore = Set<String>.of(store.wishlist);

      await tapQuickAdd(tester, product);
      await tester.pumpAndSettle();

      expect(find.byType(ProductScreen), findsNothing);
      expect(store.wishlist, wishlistBefore);
      expect(store.wishlist.contains(product.id), isFalse);
    });

    testWidgets(
        'QUICK-01b tapping the "+" of a single-variant card opens neither '
        'the ficha nor changes favourites', (tester) async {
      final store = await _mountCard(tester, singleVariantAssetProduct);
      final product = singleVariantAssetProduct(store);
      final wishlistBefore = Set<String>.of(store.wishlist);

      await tapQuickAdd(tester, product);
      await tester.pumpAndSettle();

      expect(find.byType(ProductScreen), findsNothing);
      expect(store.wishlist, wishlistBefore);
      await flush(tester);
    });

    testWidgets(
        'QUICK-01b tapping the card body still opens the ficha and adds '
        'nothing (characterization)', (tester) async {
      final store = await _mountCard(tester, singleVariantAssetProduct);
      final product = singleVariantAssetProduct(store);

      await tester.tap(cardName(store, product));
      await tester.pumpAndSettle();

      expect(find.byType(ProductScreen), findsOneWidget);
      expect(store.addCalls, 0);
      expect(store.bagQuantity, 0);
    });

    testWidgets(
        'QUICK-01b tapping the heart saves the piece and adds nothing '
        '(characterization)', (tester) async {
      final store = await _mountCard(tester, singleVariantAssetProduct);
      final product = singleVariantAssetProduct(store);

      await tester.tap(find.byTooltip('Guardar'));
      await tester.pumpAndSettle();

      expect(store.wishlist.contains(product.id), isTrue);
      expect(store.addCalls, 0);
      expect(store.bagQuantity, 0);
      expect(find.byType(ProductScreen), findsNothing);
      expect(_closeQuickView(), findsNothing);
    });

    testWidgets(
        'QUICK-01b a long press still calls onQuickView and nothing else '
        '(characterization)', (tester) async {
      var quickViews = 0;
      final store = await _mountCard(
        tester,
        singleVariantAssetProduct,
        onQuickView: () => quickViews++,
      );
      final product = singleVariantAssetProduct(store);

      await tester.longPress(cardName(store, product));
      await tester.pumpAndSettle();

      expect(quickViews, 1);
      expect(find.byType(ProductScreen), findsNothing);
      expect(store.addCalls, 0);
    });
  });

  group('QUICK-02 one buyable variant adds directly', () {
    testWidgets(
        'QUICK-02 a Default Title piece: one tap adds exactly that variant '
        'once and confirms with the mini cart', (tester) async {
      final store = await _mountCard(tester, singleVariantAssetProduct);
      final product = singleVariantAssetProduct(store);

      await tapQuickAdd(tester, product);
      await tester.pumpAndSettle();

      expect(store.addCalls, 1);
      expect(store.bagLines, hasLength(1));
      expect(store.bagLines.single.variant.id, product.variants.single.id);
      expect(store.bagLines.single.quantity, 1);
      expect(_inMiniCart(), findsOneWidget);
      expect(_closeQuickView(), findsNothing, reason: 'no sheet to choose in');
      await flush(tester);
    });

    testWidgets(
        'QUICK-02 a piece with one non-default variant ("Negro") also adds '
        'that variant directly', (tester) async {
      final named = singleNamedVariantProduct();
      expect(selectableVariants(named), hasLength(1), reason: 'precondition');
      final store = await _mountCard(tester, (_) => named, extra: [named]);

      await tapQuickAdd(tester, named);
      await tester.pumpAndSettle();

      expect(store.addCalls, 1);
      expect(store.bagLines.single.variant.id, 'v-negro-unica');
      expect(store.bagLines.single.quantity, 1);
      expect(_inMiniCart(), findsOneWidget);
      expect(_closeQuickView(), findsNothing);
      await flush(tester);
    });

    testWidgets(
        'QUICK-02 the catalog "+" of a single-variant piece adds it directly',
        (tester) async {
      setPhoneView(tester, height: 1600);
      final store = await scriptedStore();
      final product = singleVariantAssetProduct(store);
      await tester.pumpWidget(catalogApp(store, [product]));
      await tester.pump();

      await tapQuickAdd(tester, product);
      await tester.pumpAndSettle();

      expect(store.addCalls, 1);
      expect(store.bagLines.single.variant.id, product.variants.single.id);
      expect(_inMiniCart(), findsOneWidget);
      await flush(tester);
    });
  });

  group('QUICK-03 several variants open the quick view to choose', () {
    Future<void> choiceFlow(
      WidgetTester tester,
      Product Function(ScriptedCatalogStore store) pick, {
      List<Product> extra = const [],
    }) async {
      await withSemantics(tester, () async {
        final store = await _mountCard(tester, pick, extra: extra);
        final product = pick(store);
        final selectable = selectableVariants(product);
        expect(selectable.length, greaterThan(1), reason: 'precondition');
        final second = selectable[1];

        await tapQuickAdd(tester, product);
        await tester.pumpAndSettle();

        // Nothing was added silently: the sheet is the only effect.
        expect(_closeQuickView(), findsOneWidget);
        expect(store.addCalls, 0);
        expect(store.bagQuantity, 0);

        // Open without a preselected variant.
        await revealInSheet(tester, optionOf(product, second));
        expect(selectionMarks(), findsNothing, reason: 'no option is marked');
        expect(
          find.descendant(
            of: inSheet(find.byType(ListView)),
            matching: find.text(kChooseLabel),
          ),
          findsOneWidget,
          reason: 'guide text in the content',
        );
        expect(primaryButton(), findsOneWidget);
        expect(inPrimary(find.text(kChooseLabel)), findsOneWidget);
        expect(
          enabledStateOf(tester, primaryButton()),
          Tristate.isFalse,
          reason: 'the primary action is disabled until a choice is made',
        );
        await tester.tap(primaryButton(), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(store.addCalls, 0, reason: 'a disabled button adds nothing');
        expect(_closeQuickView(), findsOneWidget);

        // Choose the second variant, not the first.
        await pickVariant(tester, product, second);
        expect(selectionMarks(), findsOneWidget);
        expect(inPrimary(find.text(kAddLabel)), findsOneWidget);
        expect(inPrimary(find.text(kChooseLabel)), findsNothing);
        expect(isEnabledControl(tester, primaryButton()), isTrue);

        await tester.tap(primaryButton());
        await tester.pumpAndSettle();

        expect(store.addCalls, 1);
        expect(store.bagLines, hasLength(1));
        expect(store.bagLines.single.variant.id, second.id);
        expect(store.bagLines.single.quantity, 1);
        expect(_closeQuickView(), findsNothing, reason: 'the sheet closed');
        expect(_inMiniCart(), findsOneWidget);
        await flush(tester);
      });
    }

    testWidgets(
        'QUICK-03 swatch piece (synthetic): explicit choice, exact '
        'second variant', (tester) async {
      final product = swatchProduct();
      expect(hasReliableColorOptions(product), isTrue, reason: 'precondition');
      await choiceFlow(tester, (_) => product, extra: [product]);
    });

    testWidgets(
        'QUICK-03 text-chip piece (synthetic): explicit choice, '
        'exact second variant', (tester) async {
      final product = chipProduct();
      expect(hasReliableColorOptions(product), isFalse, reason: 'precondition');
      await choiceFlow(tester, (_) => product, extra: [product]);
    });

    testWidgets(
        'QUICK-03 swatch piece of the bundled catalog: explicit '
        'choice, exact second variant', (tester) async {
      await choiceFlow(tester, reliableAssetProduct);
    });

    testWidgets(
        'QUICK-03 text-chip piece of the bundled catalog: explicit '
        'choice, exact second variant', (tester) async {
      await choiceFlow(tester, chipAssetProduct);
    });

    testWidgets(
        'QUICK-03 the catalog "+" of a several-variant piece also opens the '
        'quick view and adds nothing', (tester) async {
      setPhoneView(tester, height: 1600);
      final store = await scriptedStore();
      final product = chipAssetProduct(store);
      await tester.pumpWidget(catalogApp(store, [product]));
      await tester.pump();

      await tapQuickAdd(tester, product);
      await tester.pumpAndSettle();

      expect(_closeQuickView(), findsOneWidget);
      expect(store.addCalls, 0);
      expect(store.bagQuantity, 0);
      expect(selectionMarks(), findsNothing);
      expect(inPrimary(find.text(kChooseLabel)), findsOneWidget);
    });
  });

  group('QUICK-03b the choice made in the sheet travels to the ficha', () {
    testWidgets(
        'QUICK-03b choosing the second variant and tapping "Ver producto" '
        'opens the ficha with that variant selected', (tester) async {
      final product = chipProduct();
      final store = await _mountCard(tester, (_) => product, extra: [product]);
      final second = selectableVariants(product)[1];

      await tapQuickAdd(tester, product);
      await tester.pumpAndSettle();
      await pickVariant(tester, product, second);

      final viewProduct = find.byKey(kQuickViewViewProductKey);
      await revealInSheet(tester, viewProduct);
      expect(
        find.descendant(
          of: viewProduct,
          matching: find.text(kViewProductLabel),
        ),
        findsOneWidget,
      );
      await tester.tap(viewProduct);
      await tester.pumpAndSettle();

      expect(find.byType(ProductScreen), findsOneWidget);
      expect(_closeQuickView(), findsNothing);
      await scrollTo(tester, find.byType(ProductOptionSelector));
      expect(
        tester
            .widget<ProductOptionSelector>(find.byType(ProductOptionSelector))
            .selectedIndex,
        1,
      );
      expect(store.addCalls, 0);
    });

    testWidgets(
        'QUICK-03b a long press keeps today\'s quick view: first variant '
        'preselected and "Agregar al carrito" enabled', (tester) async {
      await withSemantics(tester, () async {
        final product = chipProduct();
        final store = await _mountCard(
          tester,
          (_) => product,
          extra: [product],
        );

        await tester.longPress(cardName(store, product));
        await tester.pumpAndSettle();

        expect(_closeQuickView(), findsOneWidget);
        expect(selectionMarks(), findsOneWidget, reason: 'variant 0 is marked');
        expect(inPrimary(find.text(kAddLabel)), findsOneWidget);
        expect(isEnabledControl(tester, primaryButton()), isTrue);

        await tester.tap(primaryButton());
        await tester.pumpAndSettle();
        expect(store.bagLines.single.variant.id, 'v-chica');
        await flush(tester);
      });
    });
  });

  group('CART-03 pending and failing adds on the card', () {
    testWidgets(
        'CART-03 while the add is pending the "+" shows progress and is '
        'disabled, a second tap adds nothing, and it frees up afterwards',
        (tester) async {
      await withSemantics(tester, () async {
        final store = await _mountCard(tester, singleVariantAssetProduct);
        final product = singleVariantAssetProduct(store);
        final plus = quickAddOf(product);
        final hold = Completer<void>();
        store.hold = hold;

        await tapQuickAdd(tester, product);
        await tester.pump();
        expect(store.addCalls, 1);
        expect(
          find.descendant(of: plus, matching: _progress()),
          findsOneWidget,
          reason: 'progress indicator inside the control',
        );
        expect(enabledStateOf(tester, plus), Tristate.isFalse);

        await tester.tap(plus, warnIfMissed: false);
        await tester.pump();
        expect(store.addCalls, 1, reason: 'a pending add is not repeated');
        expect(store.bagQuantity, 0);
        expect(_inMiniCart(), findsNothing);
        expect(
          find.byType(ProductScreen),
          findsNothing,
          reason: 'the tap on the pending control is absorbed, not passed '
              'through to the card',
        );

        store.hold = null;
        hold.complete();
        await tester.pumpAndSettle();
        expect(store.addCalls, 1);
        expect(store.bagQuantity, 1);
        expect(store.bagLines.single.variant.id, product.variants.single.id);
        expect(_inMiniCart(), findsOneWidget);

        await dismissMiniCart(tester);
        await flush(tester);
        expect(find.descendant(of: plus, matching: _progress()), findsNothing);
        expect(isEnabledControl(tester, plus), isTrue);
        await tester.tap(plus);
        await tester.pumpAndSettle();
        expect(store.addCalls, 2, reason: 'enabled again');
        expect(store.bagQuantity, 2);
        await flush(tester);
      });
    });

    testWidgets(
        'CART-03 a failing add shows the message, leaves the bag alone, '
        'frees the "+" and a retry adds exactly one unit', (tester) async {
      await withSemantics(tester, () async {
        final store = await _mountCard(tester, singleVariantAssetProduct);
        final product = singleVariantAssetProduct(store);
        final plus = quickAddOf(product);

        store.failWith = StateError('storage unavailable');
        await tapQuickAdd(tester, product);
        await tester.pumpAndSettle();

        expect(_snackbarMessage(), findsOneWidget);
        expect(store.addCalls, 1);
        expect(store.bagQuantity, 0);
        expect(store.bagLines, isEmpty);
        expect(_inMiniCart(), findsNothing);
        expect(find.descendant(of: plus, matching: _progress()), findsNothing);
        expect(isEnabledControl(tester, plus), isTrue);

        store.failWith = null;
        await tester.tap(plus);
        await tester.pumpAndSettle();
        expect(store.addCalls, 2);
        expect(store.bagQuantity, 1, reason: 'one unit, not two');
        expect(store.bagLines.single.variant.id, product.variants.single.id);
        await flush(tester);
      });
    });
  });

  group('CART-04 availability on the card', () {
    testWidgets(
        'CART-04 a partly sold-out piece keeps its "+" and opens the sheet',
        (tester) async {
      final store = await _mountCard(tester, partialAssetProduct);
      final product = partialAssetProduct(store);

      expectQuickAddGeometry(tester, quickAddOf(product));
      await tapQuickAdd(tester, product);
      await tester.pumpAndSettle();

      expect(_closeQuickView(), findsOneWidget);
      expect(store.addCalls, 0);
      expect(store.bagQuantity, 0);
    });

    testWidgets(
        'CART-04 choosing the sold-out variant turns the primary action into '
        '"Avísame cuando vuelva" and adds nothing', (tester) async {
      final product = chipProduct(available: const [true, false, true]);
      expect(product.isInStock, isTrue, reason: 'precondition: still sells');
      final store = await _mountCard(tester, (_) => product, extra: [product]);
      final soldOutVariant = selectableVariants(product)[1];

      await tapQuickAdd(tester, product);
      await tester.pumpAndSettle();
      await pickVariant(tester, product, soldOutVariant);

      expect(inPrimary(find.text(kRestockLabel)), findsOneWidget);
      expect(find.text(kAddLabel), findsNothing);

      await tester.tap(primaryButton());
      await tester.pumpAndSettle();
      expect(store.addCalls, 0);
      expect(store.bagQuantity, 0);
      expect(_inMiniCart(), findsNothing);
    });
  });
}
