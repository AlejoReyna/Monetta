import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/shopper_copy.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/boutique/boutique_tokens.dart';
import 'package:monetta_app/features/product/product_selection.dart';

import '../../support/product_screen_harness.dart';
import '../../support/quick_add_harness.dart';
import '../../support/scripted_catalog_store.dart';

// FICHA-T3, QUICK-04..05, CART-03 and TYPE-01e on the quick view (BRIEF 2.6),
// for the centred preview card: the purchase action always stays inside the
// card, which keeps clear of the safe area and the keyboard and scrolls inside
// when it does not fit; the labels are the uppercase guide actions, a pending
// or failed add is visible, and the piece name is set in the sans of the
// cards.

const double _inset = 34;

Finder _close() => find.byTooltip(kCloseQuickViewTooltip);

Finder _sheetScroller() => inSheet(
      find.byWidgetPredicate(
        (widget) => widget is Scrollable && widget.axis == Axis.vertical,
      ),
    );

Finder _inMiniCart() => find.text('En tu bolsa');

/// Mounts a host with the sheet of [product] open, on a scripted store.
Future<(ScriptedCatalogStore, Product)> _open(
  WidgetTester tester, {
  Product? product,
  double width = 390,
  double height = kPhoneHeight,
  double inset = 0,
  double scale = 1.0,
  bool requireChoice = false,
}) async {
  setPhoneView(tester, width: width, height: height, inset: inset);
  final store = await scriptedStore();
  final piece = product ?? chipProduct();
  addProducts(store, [piece]);
  await pumpQuickView(
    tester,
    store,
    piece,
    scale: scale,
    requireChoice: requireChoice,
  );
  expect(_close(), findsOneWidget, reason: 'the sheet is open');
  return (store, piece);
}

void main() {
  setUpAll(mockPathProvider);

  group('QUICK-04 the purchase action stays inside the centred card', () {
    testWidgets(
        'QUICK-04 the card keeps clear of the safe area and holds the actions, '
        'and the button is visible without scrolling', (tester) async {
      await _open(tester, inset: _inset);

      final card = tester.getRect(quickViewSheet());
      expect(card.bottom, lessThanOrEqualTo(kPhoneHeight - _inset + 0.01));
      expect(card.top, greaterThanOrEqualTo(0));
      expect(actionsBar(), findsOneWidget);
      final bar = tester.getRect(actionsBar());
      expect(card.contains(bar.topLeft), isTrue, reason: 'bar inside the card');
      expect(card.contains(bar.bottomRight), isTrue);

      expect(primaryButton(), findsOneWidget);
      final button = tester.getRect(primaryButton());
      expect(button.height, greaterThanOrEqualTo(52 - 0.01));
      expect(button.bottom, lessThanOrEqualTo(card.bottom));
      expect(button.top, greaterThanOrEqualTo(card.top));
      expect(
        primaryButton().hitTestable(),
        findsOneWidget,
        reason: 'nothing covers the button: a tap would reach it',
      );
    });

    testWidgets(
        'QUICK-04 on a 320x568 phone the card scrolls inside and the button '
        'is still reachable and adds', (tester) async {
      final (store, _) = await _open(tester, width: 320, height: 568);

      final cardBefore = tester.getRect(quickViewSheet());
      expect(cardBefore.height, lessThanOrEqualTo(568));
      final position = tester.state<ScrollableState>(_sheetScroller()).position;
      expect(position.maxScrollExtent, greaterThan(0), reason: 'it scrolls');
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();

      expect(
        tester.getRect(quickViewSheet()),
        cardBefore,
        reason: 'the card itself stays put while its content scrolls',
      );
      await tester.tap(primaryButton());
      await tester.pumpAndSettle();
      expect(store.bagQuantity, 1, reason: 'the button is reachable');
      await flush(tester);
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'QUICK-04 at 320x568 and text scale $scale the button is reachable '
          'inside the card', (tester) async {
        final (store, _) = await _open(
          tester,
          width: 320,
          height: 568,
          scale: scale,
        );

        expect(tester.takeException(), isNull);
        const view = Rect.fromLTWH(0, 0, 320, 568);
        final card = tester.getRect(quickViewSheet());
        expect(view.contains(card.topLeft), isTrue, reason: 'card $card');
        expect(view.contains(card.bottomRight), isTrue);

        await revealInSheet(tester, primaryButton());
        final button = tester.getRect(primaryButton());
        expect(card.contains(button.topLeft), isTrue, reason: 'button $button');
        expect(card.contains(button.bottomRight), isTrue);
        expect(
          primaryButton().hitTestable(),
          findsOneWidget,
          reason: 'nothing covers the button: a tap would reach it',
        );
        expect(store.addCalls, 0);
      });
    }
  });

  group('QUICK-04b the keyboard', () {
    testWidgets(
        'QUICK-04b with a 300 keyboard the card ends above it and the safe '
        'inset is not counted twice', (tester) async {
      setPhoneView(tester, inset: _inset);
      // A phone with the keyboard up reports no bottom padding (the keyboard
      // covers the home indicator) but keeps the view padding.
      tester.view.padding = FakeViewPadding.zero;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      final store = await scriptedStore();
      final product = chipProduct();
      addProducts(store, [product]);
      await pumpQuickView(tester, store, product);
      expect(_close(), findsOneWidget);

      const keyboardTop = kPhoneHeight - 300;
      final card = tester.getRect(quickViewSheet());
      expect(
        card.bottom,
        lessThanOrEqualTo(keyboardTop + 0.01),
        reason: 'the card ends above the keyboard',
      );
      expect(
        card.bottom,
        greaterThan(keyboardTop - 40),
        reason: 'and sits right on it, with the 16 of air only',
      );
      expect(card.top, greaterThanOrEqualTo(0));
    });
  });

  group('QUICK-05 labels and prices', () {
    testWidgets('QUICK-05 the guide labels are the uppercase commerce actions',
        (tester) async {
      await _open(tester);

      expect(inPrimary(find.text(kAddLabel)), findsOneWidget);
      final viewProduct = find.byKey(kQuickViewViewProductKey);
      await revealInSheet(tester, viewProduct);
      expect(
        find.descendant(
          of: viewProduct,
          matching: find.text(kViewProductLabel),
        ),
        findsOneWidget,
      );
      expect(find.text('AGREGAR A LA BOLSA'), findsNothing);
      expect(find.text('AVÍSAME CUANDO VUELVA'), findsNothing);
    });

    testWidgets(
        'G09/G12 hides unsupported exact-variant restock and prevents add',
        (tester) async {
      final (store, _) = await _open(tester, product: soldOutProduct());

      expect(primaryButton(), findsNothing);
      expect(find.text(kRestockLabel), findsNothing);
      expect(find.text(kAddLabel), findsNothing);
      expect(store.addCalls, 0);
      expect(store.bagQuantity, 0);
    });

    testWidgets(
        'QUICK-05 opened to choose, the sheet shows the piece price; after '
        'choosing it shows the price of that variant', (tester) async {
      final product = swatchProduct();
      await _open(tester, product: product, requireChoice: true);

      expect(
        inSheet(find.text(formatShopperPrice(product.price))),
        findsOneWidget,
        reason: 'before choosing: the lowest price of the piece',
      );
      final third = selectableVariants(product)[2];
      expect(third.price, isNot(product.price), reason: 'precondition');

      await pickVariant(tester, product, third);

      expect(
        inSheet(find.text(formatShopperPrice(third.price))),
        findsOneWidget,
      );
      expect(
        inSheet(find.text(formatShopperPrice(product.price))),
        findsNothing,
      );
    });
  });

  group('CART-03 pending and failing adds in the sheet', () {
    testWidgets(
        'CART-03 while pending the primary button says "Agregando…", is '
        'disabled, and a second tap adds nothing', (tester) async {
      await withSemantics(tester, () async {
        final (store, product) = await _open(tester);
        await pickVariant(tester, product, selectableVariants(product)[1]);
        final hold = Completer<void>();
        store.hold = hold;

        expect(primaryButton(), findsOneWidget);
        await tester.tap(primaryButton());
        await tester.pump();
        expect(store.addCalls, 1);
        expect(inPrimary(find.text(kPendingLabel)), findsOneWidget);
        expect(inPrimary(find.text(kAddLabel)), findsNothing);
        expect(enabledStateOf(tester, primaryButton()), Tristate.isFalse);

        await tester.tap(primaryButton(), warnIfMissed: false);
        await tester.pump();
        expect(store.addCalls, 1, reason: 'a pending add is not repeated');
        expect(store.bagQuantity, 0);

        store.hold = null;
        hold.complete();
        await tester.pumpAndSettle();
        expect(store.addCalls, 1);
        expect(store.bagLines.single.variant.id, 'v-mediana');
        expect(store.bagLines.single.quantity, 1);
        expect(
          _close(),
          findsOneWidget,
          reason: 'G09 confirms in the same layer',
        );
        expect(find.text('Agregado al carrito'), findsOneWidget);
        expect(_inMiniCart(), findsNothing);
        await flush(tester);
      });
    });

    testWidgets(
        'CART-03 a failing add keeps the sheet open and the choice, shows the '
        'inline message, and a retry adds exactly one unit', (tester) async {
      await withSemantics(tester, () async {
        final (store, product) = await _open(tester);
        final second = selectableVariants(product)[1];
        await pickVariant(tester, product, second);

        store.failWith = StateError('storage unavailable');
        expect(primaryButton(), findsOneWidget);
        await tester.tap(primaryButton());
        await tester.pumpAndSettle();

        expect(_close(), findsOneWidget, reason: 'the sheet stays open');
        expect(store.addCalls, 1);
        expect(store.bagQuantity, 0);
        expect(_inMiniCart(), findsNothing);
        final error = find.byKey(kQuickViewErrorKey);
        expect(error, findsOneWidget);
        expect(
          find.descendant(
            of: error,
            matching: find.text(kAddFailureMessage),
            matchRoot: true,
          ),
          findsOneWidget,
        );
        expect(
          tester.getRect(error).bottom,
          lessThanOrEqualTo(kPhoneHeight),
          reason: 'the message is on screen',
        );
        expect(selectionMarks(), findsOneWidget, reason: 'choice kept');
        expect(inPrimary(find.text(kAddLabel)), findsOneWidget);
        expect(isEnabledControl(tester, primaryButton()), isTrue);

        store.failWith = null;
        await tester.tap(primaryButton());
        await tester.pumpAndSettle();
        expect(store.addCalls, 2);
        expect(store.bagQuantity, 1, reason: 'one unit, not two');
        expect(store.bagLines.single.variant.id, second.id);
        expect(_close(), findsOneWidget);
        expect(find.text('Agregado al carrito'), findsOneWidget);
        expect(error, findsNothing);
        await flush(tester);
      });
    });
  });

  group('TYPE-01e the piece name', () {
    testWidgets(
        'v4.1 the brand is DM Sans w600 18 and the name DM Sans '
        'w400 15 in ink', (tester) async {
      final (_, product) = await _open(tester);

      final palette = tester.element(quickViewSheet()).boutique;
      final name = find.byKey(const Key('quick-view-name'));
      expect(
        tester.widget<Text>(name).data,
        shopperProductName(product.title),
      );
      final style = styleOf(tester, name);
      expect(style.fontFamily, kBoutiqueSansFamily, reason: 'family');
      expect(style.fontWeight, FontWeight.w400);
      expect(style.fontSize, 15);
      expect(style.color, palette.ink, reason: 'not the light grey');

      final brand = find.byKey(const Key('quick-view-brand'));
      if (brand.evaluate().isNotEmpty) {
        final brandStyle = styleOf(tester, brand);
        expect(brandStyle.fontFamily, kBoutiqueSansFamily);
        expect(brandStyle.fontWeight, FontWeight.w600);
        expect(brandStyle.fontSize, 18);
      }
    });
  });
}
