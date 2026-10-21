import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/monetta_tokens.g.dart';
import 'package:monetta_app/app/shopper_copy.dart';
import 'package:monetta_app/features/boutique/boutique_tokens.dart';
import 'package:monetta_app/reco/events.dart';
import 'package:monetta_app/reco/explainer.dart';

import '../../support/product_screen_harness.dart';

// FICHA-T2, TYPE-01d (style guideline): the product name and the section
// headings of the ficha are the editorial serif (Playfair Display, w400); the
// earlier brief set them in the sans of the card names. The style handed to
// each `Text` is read directly, so the Ahem test font is irrelevant.

void _expectSans(TextStyle style, {required String reason}) {
  expect(style.fontFamily, kBoutiqueSansFamily, reason: '$reason: family');
  expect(style.fontFamilyFallback, kBoutiqueSansFallback,
      reason: '$reason: fallback chain');
  expect(style.fontWeight, FontWeight.w600, reason: '$reason: weight');
}

void _expectSerif(TextStyle style, {required String reason}) {
  expect(style.fontFamily, kBoutiqueSerifFamily, reason: '$reason: family');
  expect(
    style.fontFamilyFallback,
    kBoutiqueSerifFallback,
    reason: '$reason: fallback chain',
  );
  expect(style.fontWeight, FontWeight.w400, reason: '$reason: weight');
}

/// Scrolls to [heading] and checks it is a section heading (serif, w400, 23).
Future<void> _expectSectionHeading(
  WidgetTester tester,
  Finder heading, {
  required String reason,
}) async {
  await scrollTo(tester, heading);
  final style = styleOf(tester, heading);
  _expectSerif(style, reason: reason);
  expect(
    style.fontSize,
    MonettaTokens.sectionTitle.compact,
    reason: '$reason: size',
  );
}

void main() {
  setUpAll(mockPathProvider);

  group('TYPE-01d ficha Monetta', () {
    Future<({String name, String brand, String relatedName})> mount(
      WidgetTester tester,
    ) async {
      setPhoneView(tester);
      final store = await loadedStore();
      final (:product, :other) = productWithBrandRail(store);
      // A viewed piece fills the "Vistas hace un momento" rail.
      store.record(EventType.productView, productId: other.id);
      await pumpFicha(tester, store, product.id);
      return (
        name: shopperProductName(product.title),
        brand: store.facetsFor(product.id)!.brand!.value,
        relatedName: shopperProductName(other.title),
      );
    }

    testWidgets('TYPE-01d the main name is serif w400, 25', (tester) async {
      final ficha = await mount(tester);

      await scrollTo(tester, contentNameText(ficha.name));
      final style = styleOf(tester, contentNameText(ficha.name));
      _expectSerif(style, reason: 'main name');
      expect(style.fontSize, MonettaTokens.productName.compact);
    });

    testWidgets('TYPE-01d the three accordion labels are section headings',
        (tester) async {
      await mount(tester);

      for (final label in ['Descripción', 'Detalles', 'Envíos y cambios']) {
        await _expectSectionHeading(
          tester,
          find.text(label),
          reason: 'accordion "$label"',
        );
      }
    });

    testWidgets('TYPE-01d the rail headings are section headings',
        (tester) async {
      final ficha = await mount(tester);

      await _expectSectionHeading(
        tester,
        find.text('Más de ${brandLabel(ficha.brand)}'),
        reason: 'related rail',
      );
      await _expectSectionHeading(
        tester,
        find.text('Vistas hace un momento'),
        reason: 'viewed rail',
      );
    });

    testWidgets('TYPE-01d "Otras formas de comprar" is a section heading',
        (tester) async {
      await mount(tester);

      await _expectSectionHeading(
        tester,
        find.text('Otras formas de comprar'),
        reason: 'purchase section',
      );
    });
  });

  group('TYPE-01d ficha externa', () {
    final item = externalItem();
    final name = externalProductName(
      title: item.title,
      category: item.category,
    );

    Future<void> mount(WidgetTester tester) async {
      setPhoneView(tester);
      await pumpExternal(tester, item: item);
    }

    testWidgets('TYPE-01d the main name is serif w400, 25', (tester) async {
      await mount(tester);

      await scrollTo(tester, contentNameText(name));
      final style = styleOf(tester, contentNameText(name));
      _expectSerif(style, reason: 'main name');
      expect(style.fontSize, MonettaTokens.productName.compact);
    });

    testWidgets('TYPE-01d "Descripción del producto" is a section heading',
        (tester) async {
      await mount(tester);

      // Case-insensitive: the heading used to be set in capitals.
      final heading = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data?.toLowerCase() == 'descripción del producto',
      );
      await _expectSectionHeading(
        tester,
        heading,
        reason: 'Descripción del producto',
      );
    });

    testWidgets('TYPE-01d the header title is 18-20', (tester) async {
      await mount(tester);

      expect(headerTitle(), findsOneWidget);
      final style = styleOf(tester, headerTitle());
      _expectSans(style, reason: 'header title');
      expect(style.fontSize, inInclusiveRange(18, 20));
    });
  });
}
