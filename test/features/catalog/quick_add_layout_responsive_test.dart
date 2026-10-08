import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/shopper_copy.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/features/catalog/product_card.dart';
import 'package:monetta_app/features/product/product_selection.dart';

import '../../support/product_screen_harness.dart';
import '../../support/quick_add_harness.dart';

// FICHA-T3, RESP-03 and A11Y-02: the "+" of the cards and the quick view hold
// their layout across phone widths and text scales, and the sheet reads in a
// sensible order for a screen reader (close, content, then the pinned bar).
//
// Keys do not exist in `lib/` yet, so these are red until the control and the
// bar are built.

/// Phone-sized viewports, narrow to wide (the last one is a tablet).
final Map<double, double> _viewports = {
  320: 568,
  390: 844,
  430: 932,
  768: 1024,
};

void main() {
  setUpAll(mockPathProvider);

  group('RESP-03 widths x text scales', () {
    for (final entry in _viewports.entries) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
            'RESP-03 ${entry.key.toInt()} wide at text scale $scale: the grid '
            'keeps a 48x48 "+" inside every photo and the sheet shows its bar',
            (tester) async {
          setPhoneView(tester, width: entry.key, height: entry.value);
          final store = await scriptedStore();
          final several = chipProduct();
          addProducts(store, [several]);
          final singles = store.products
              .where((p) => p.isInStock && selectableVariants(p).isEmpty)
              .take(3);
          await tester.pumpWidget(
            gridApp(store, [several, ...singles], scale: scale),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
          final cards =
              tester.widgetList<ProductCard>(find.byType(ProductCard)).toList();
          expect(cards, isNotEmpty);
          for (final card in cards) {
            expectQuickAddFitsPhoto(tester, quickAddOf(card.product));
          }
          expect(find.byTooltip(kQuickViewTooltip), findsNothing);

          await tapQuickAdd(tester, several);
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byTooltip(kCloseQuickViewTooltip), findsOneWidget);
          final view = Rect.fromLTWH(0, 0, entry.key, entry.value);
          expect(actionsBar(), findsOneWidget);
          final bar = tester.getRect(actionsBar());
          final button = tester.getRect(primaryButton());
          expect(bar.bottom, closeTo(entry.value, 0.01), reason: 'bar at edge');
          expect(view.contains(bar.topLeft), isTrue, reason: 'bar $bar');
          expect(view.contains(button.topLeft), isTrue, reason: 'btn $button');
          expect(view.contains(button.bottomRight), isTrue);
          expect(inPrimary(find.text(kChooseLabel)), findsOneWidget);
        });
      }
    }
  });

  group('A11Y-02 the sheet reads close, content, then the bar', () {
    testWidgets(
        'A11Y-02 the order is close, gallery, name, price, options, '
        '"Ver producto", bar; buttons have a name and role', (tester) async {
      await withSemantics(tester, () async {
        // Tall enough to build the whole sheet, so the order is about the
        // tree and not about what fits.
        setPhoneView(tester, height: 1700);
        final store = await scriptedStore();
        final product = store.products.firstWhere(
          (p) =>
              p.images.length > 1 &&
              selectableVariants(p).length > 1 &&
              p.variants.every((v) => v.available),
        );
        await pumpQuickView(tester, store, product);

        final viewProduct = find.byKey(kQuickViewViewProductKey);
        expect(viewProduct, findsOneWidget);
        expect(primaryButton(), findsOneWidget);
        final close =
            tester.getSemantics(find.byTooltip(kCloseQuickViewTooltip));
        final gallery = tester.getSemantics(
          find.bySemanticsLabel(RegExp(r'^Foto 1 de ')),
        );
        final name = tester.getSemantics(
          inSheet(find.text(shopperProductName(product.title))),
        );
        final price = tester.getSemantics(
          inSheet(find.text(kMoney.format(selectionPrice(product, 0)))),
        );
        final options = tester.getSemantics(
          optionOf(product, selectableVariants(product).first),
        );
        final seeProduct = tester.getSemantics(viewProduct);
        final bar = tester.getSemantics(primaryButton());

        final order = tester.semantics
            .simulatedAccessibilityTraversal()
            .map((node) => node.id);
        final position = {
          for (final (index, id) in order.indexed) id: index,
        };
        final chain = {
          'close': close,
          'gallery': gallery,
          'name': name,
          'price': price,
          'options': options,
          'Ver producto': seeProduct,
          'bar': bar,
        };
        for (final entry in chain.entries) {
          expect(
            position,
            contains(entry.value.id),
            reason: '${entry.key} is part of the reading order',
          );
        }
        final ids = chain.values.map((node) => position[node.id]!).toList();
        expect(
          ids,
          orderedEquals([...ids]..sort()),
          reason: 'reading order: ${chain.keys.join(' < ')}; got $ids',
        );
        expect(ids.toSet(), hasLength(ids.length));

        expect(
          isButtonNode(tester, find.byTooltip(kCloseQuickViewTooltip)),
          isTrue,
        );
        expect(accessibleName(close), kCloseQuickViewTooltip);
        for (final (what, finder) in [
          ('Ver producto', viewProduct),
          ('primary action', primaryButton()),
        ]) {
          final node = tester.getSemantics(finder);
          expect(accessibleName(node), isNotEmpty, reason: '$what has a name');
          expect(isButtonNode(tester, finder), isTrue, reason: '$what role');
        }
        expect(
          accessibleName(tester.getSemantics(primaryButton())),
          contains(kAddLabel),
        );
        expect(
          accessibleName(tester.getSemantics(viewProduct)),
          contains(kViewProductLabel),
        );
      });
    });
  });
}
