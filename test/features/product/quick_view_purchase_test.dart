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

// FICHA-T3, QUICK-04..05, CART-03 and TYPE-01e on the quick view (BRIEF 2.6):
// the purchase action is pinned at the bottom of the sheet (outside the
// scrolling list, inset applied once, keyboard respected), the labels are the
// sentence-case ones, a pending or failed add is visible, and the piece name is
// set in the sans of the cards.
//
// `Key('quick-view-primary')` and `Key('quick-view-actions')` do not exist in
// `lib/` yet, so the tests that look for them are red until they do.

const double _inset = 34;

Finder _close() => find.byTooltip(kCloseQuickViewTooltip);

Finder _sheetList() => inSheet(find.byType(ListView));

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

  group('QUICK-04 the purchase action is pinned to the bottom', () {
    testWidgets(
        'QUICK-04 the bar is outside the scrolling list, paints under the '
        'inset, and the button is visible above it without scrolling',
        (tester) async {
      await _open(tester, inset: _inset);

      expect(actionsBar(), findsOneWidget);
      expect(
        find.descendant(of: find.byType(ListView), matching: actionsBar()),
        findsNothing,
        reason: 'the bar must not scroll with the content',
      );
      final bar = tester.getRect(actionsBar());
      expect(
        bar.bottom,
        closeTo(kPhoneHeight, 0.01),
        reason: 'bar to the edge',
      );

      expect(primaryButton(), findsOneWidget);
      final button = tester.getRect(primaryButton());
      expect(button.height, greaterThanOrEqualTo(48 - 0.01));
      expect(
        button.bottom,
        lessThanOrEqualTo(kPhoneHeight - _inset + 0.01),
        reason: 'the button ends above the inset',
      );
      expect(button.top, greaterThanOrEqualTo(0));
      expect(bar.contains(button.center), isTrue, reason: 'inside the bar');
    });

    testWidgets(
        'QUICK-04 on a 320x568 phone the bar stays put while the content '
        'scrolls, and the button still adds', (tester) async {
      final (store, _) = await _open(tester, width: 320, height: 568);

      expect(actionsBar(), findsOneWidget);
      final barBefore = tester.getRect(actionsBar());
      final buttonBefore = tester.getRect(primaryButton());
      expect(barBefore.bottom, closeTo(568, 0.01));
      expect(buttonBefore.top, greaterThanOrEqualTo(0));

      final name = find.text(shopperProductName('Bolsa de tallas'));
      final nameBefore = tester.getTopLeft(name.first).dy;
      await tester.drag(_sheetList(), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(name.first).dy,
        isNot(closeTo(nameBefore, 0.01)),
        reason: 'the content did scroll',
      );
      expect(tester.getRect(actionsBar()), barBefore);
      expect(tester.getRect(primaryButton()), buttonBefore);

      await tester.tap(primaryButton());
      await tester.pumpAndSettle();
      expect(store.bagQuantity, 1, reason: 'the button is reachable');
      await flush(tester);
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'QUICK-04 at 320x568 and text scale $scale the bar is on screen '
          'and its button is reachable', (tester) async {
        final (store, _) = await _open(
          tester,
          width: 320,
          height: 568,
          scale: scale,
        );

        expect(tester.takeException(), isNull);
        expect(actionsBar(), findsOneWidget);
        const view = Rect.fromLTWH(0, 0, 320, 568);
        final bar = tester.getRect(actionsBar());
        final button = tester.getRect(primaryButton());
        expect(view.contains(bar.topLeft), isTrue, reason: 'bar top $bar');
        expect(bar.bottom, closeTo(568, 0.01));
        expect(view.contains(button.topLeft), isTrue, reason: 'button $button');
        expect(view.contains(button.bottomRight), isTrue);
        expect(
          tester.getSize(_sheetList()).height,
          greaterThan(48),
          reason: 'the content keeps some room above the bar',
        );

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
        'QUICK-04b with a 300 keyboard the bar ends above it and the safe '
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

      expect(actionsBar(), findsOneWidget);
      const keyboardTop = kPhoneHeight - 300;
      final bar = tester.getRect(actionsBar());
      final button = tester.getRect(primaryButton());
      expect(
        bar.bottom,
        lessThanOrEqualTo(keyboardTop + 0.01),
        reason: 'the bar ends above the keyboard',
      );
      expect(
        bar.bottom,
        greaterThan(keyboardTop - 1),
        reason: 'and sits right on it',
      );
      expect(button.bottom, lessThanOrEqualTo(bar.bottom));
      expect(
        bar.bottom - button.bottom,
        lessThanOrEqualTo(16),
        reason: 'the 34 safe inset is not added on top of the keyboard',
      );
      expect(button.top, greaterThanOrEqualTo(0));
    });
  });

  group('QUICK-05 labels and prices', () {
    testWidgets('QUICK-05 the sentence-case labels replace the upper-case ones',
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
      expect(find.text('VER PRODUCTO'), findsNothing);
      expect(find.text('AVÍSAME CUANDO VUELVA'), findsNothing);
    });

    testWidgets(
        'QUICK-05 a sold-out piece offers "Avísame cuando vuelva" and no add',
        (tester) async {
      final (store, _) = await _open(tester, product: soldOutProduct());

      expect(inPrimary(find.text(kRestockLabel)), findsOneWidget);
      expect(find.text(kAddLabel), findsNothing);
      await tester.tap(primaryButton());
      await tester.pumpAndSettle();
      expect(store.addCalls, 0);
      expect(store.bagQuantity, 0);
    });

    testWidgets(
        'QUICK-05 opened to choose, the sheet shows the piece price; after '
        'choosing it shows the price of that variant', (tester) async {
      final product = swatchProduct();
      await _open(tester, product: product, requireChoice: true);

      expect(
        inSheet(find.text(kMoney.format(product.price))),
        findsOneWidget,
        reason: 'before choosing: the lowest price of the piece',
      );
      final third = selectableVariants(product)[2];
      expect(third.price, isNot(product.price), reason: 'precondition');

      await pickVariant(tester, product, third);

      expect(inSheet(find.text(kMoney.format(third.price))), findsOneWidget);
      expect(inSheet(find.text(kMoney.format(product.price))), findsNothing);
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
        expect(_close(), findsNothing, reason: 'success closes the sheet');
        expect(_inMiniCart(), findsOneWidget);
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
        expect(_close(), findsNothing);
        expect(error, findsNothing);
        await flush(tester);
      });
    });
  });

  group('TYPE-01e the piece name', () {
    testWidgets(
        'TYPE-01e the main name of the sheet is the editorial serif, '
        'w400, 25', (tester) async {
      final (_, product) = await _open(tester);

      final name = inSheet(
        find.text(shopperProductName(product.title)),
      );
      final style = styleOf(tester, name);
      expect(style.fontFamily, kBoutiqueSerifFamily, reason: 'family');
      expect(
        style.fontFamilyFallback,
        kBoutiqueSerifFallback,
        reason: 'fallback chain',
      );
      expect(style.fontWeight, FontWeight.w400);
      expect(style.fontSize, kBoutiqueProductNameSize);
    });
  });
}
