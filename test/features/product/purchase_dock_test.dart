import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/boutique/boutique_tokens.dart';
import 'package:monetta_app/features/checkout/checkout_screen.dart';
import 'package:monetta_app/features/product/product_selection.dart';
import 'package:monetta_app/reco/explainer.dart';

import '../../support/product_screen_harness.dart';
import '../../support/scripted_catalog_store.dart';

// FICHA-T2, CART-xx: the purchase dock of the ficha (one primary action, 64 px
// of content plus the real bottom inset applied once) and the secondary
// "Otras formas de comprar" section (BRIEF 2.5).

const double _inset = 34;
const String _addLabel = 'Agregar al carrito';
const String _pendingLabel = 'Agregando…';
const String _restockLabel = 'Avísame cuando vuelva';
const String _failureMessage = 'No pudimos agregar la pieza. Intenta de nuevo.';

Finder _dock() => find.byKey(kDockKey);
Finder _primary() => find.byKey(kDockPrimaryKey);
Finder _inPrimary(Finder matching) =>
    find.descendant(of: _primary(), matching: matching);
Finder _inMainList(Finder matching) =>
    find.descendant(of: mainList(), matching: matching);

/// A synthetic in-stock piece with one variant, mounted on a plain store.
Future<(CatalogStore, Product)> _mountSingle(
  WidgetTester tester, {
  double width = 390,
  double scale = 1.0,
  double inset = 0,
  bool settle = true,
}) async {
  setPhoneView(tester, width: width, inset: inset);
  final store = await loadedStore();
  final product = syntheticProduct();
  addProducts(store, [product]);
  await pumpFicha(tester, store, product.id, scale: scale, settle: settle);
  return (store, product);
}

/// Same, on a [ScriptedCatalogStore] so the add can be held or made to fail.
Future<(ScriptedCatalogStore, Product)> _mountScripted(
  WidgetTester tester, {
  List<ProductVariant>? variants,
}) async {
  setPhoneView(tester);
  final store =
      await loadStore(ScriptedCatalogStore(database: openTestDatabase()));
  final product = syntheticProduct(variants: variants);
  addProducts(store, [product]);
  await pumpFicha(tester, store, product.id);
  return (store, product);
}

void main() {
  setUpAll(mockPathProvider);

  group('CART-01 the dock', () {
    testWidgets(
        'CART-01 without inset the dock is 64 high with a 48 button, there '
        'from the first frame, and does not move', (tester) async {
      await _mountSingle(tester, settle: false);

      expect(_dock(), findsOneWidget);
      final before = tester.getRect(_dock());
      expect(before.height, closeTo(64, 0.01));
      expect(before.bottom, closeTo(kPhoneHeight, 0.01));
      expect(before.left, closeTo(0, 0.01));
      expect(before.width, closeTo(390, 0.01));
      expect(_primary(), findsOneWidget);
      expect(tester.getSize(_primary()).height, closeTo(48, 0.01));
      expect(_inPrimary(find.text(_addLabel)), findsOneWidget);

      await scrollToEnd(tester);
      expect(tester.getRect(_dock()), before);
    });

    testWidgets(
        'CART-01 with a 34 inset the dock is 98 high, docked to the edge, '
        'and the button ends 8 above the inset', (tester) async {
      await _mountSingle(tester, inset: _inset, settle: false);

      expect(_dock(), findsOneWidget);
      final dock = tester.getRect(_dock());
      expect(dock.height, closeTo(64 + _inset, 0.01));
      expect(dock.bottom, closeTo(kPhoneHeight, 0.01));
      final button = tester.getRect(_primary());
      expect(button.height, closeTo(48, 0.01));
      expect(button.bottom, closeTo(kPhoneHeight - _inset - 8, 0.01));
      expect(button.top, closeTo(dock.top + 8, 0.01));

      await scrollToEnd(tester);
      expect(tester.getRect(_dock()), dock);
    });

    testWidgets('CART-01 the dock paints the bar colour down to the edge',
        (tester) async {
      await _mountSingle(tester, inset: _inset);

      expect(_dock(), findsOneWidget);
      final bar = BoutiquePalette.of(tester.element(_dock())).bar;
      final dock = tester.getRect(_dock());
      final painted = <Rect>[];
      final fills = find.descendant(
        of: _dock(),
        matching: find.byWidgetPredicate((widget) {
          if (widget is ColoredBox) return widget.color == bar;
          if (widget is DecoratedBox) {
            final decoration = widget.decoration;
            return decoration is BoxDecoration && decoration.color == bar;
          }
          return false;
        }),
        matchRoot: true,
      );
      for (final element in fills.evaluate()) {
        final box = element.renderObject! as RenderBox;
        painted.add(box.localToGlobal(Offset.zero) & box.size);
      }
      expect(
        painted.any(
          (rect) =>
              (rect.bottom - dock.bottom).abs() < 0.01 &&
              (rect.top - dock.top).abs() < 0.01,
        ),
        isTrue,
        reason: 'one surface in the bar colour spans the whole dock, inset '
            'included; painted: $painted',
      );
    });

    testWidgets(
        'CART-01b the dock holds no price or availability; the content does',
        (tester) async {
      setPhoneView(tester);
      final store = await loadedStore();
      final product = store.products.firstWhere(
        (p) =>
            p.isInStock &&
            selectableVariants(p).length > 1 &&
            p.variants.every((v) => v.available),
      );
      await pumpFicha(tester, store, product.id);

      expect(_dock(), findsOneWidget);
      for (final text in [r'$', 'Disponible', 'Agotado']) {
        expect(
          find.descendant(of: _dock(), matching: find.textContaining(text)),
          findsNothing,
          reason: 'the dock must not show "$text"',
        );
      }
      expect(
        find.descendant(
          of: _dock(),
          matching: find.byType(ProductOptionSelector),
        ),
        findsNothing,
      );

      expect(
        _inMainList(find.text(kMoney.format(selectionPrice(product, 0)))),
        findsWidgets,
      );
      expect(_inMainList(find.textContaining('Disponible')), findsOneWidget);
      expect(_inMainList(find.byType(ProductOptionSelector)), findsOneWidget);
    });

    for (final width in [320.0, 390.0]) {
      testWidgets(
          'CART-01c at x2 and ${width.toInt()} wide the dock grows and the '
          'label is not truncated', (tester) async {
        await _mountSingle(tester, width: width, scale: 2.0, inset: _inset);

        expect(_dock(), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(_dock()).height,
          greaterThan(64 + _inset),
          reason: 'the dock grows with the text scale',
        );
        expect(tester.getSize(_primary()).height, greaterThanOrEqualTo(48));
        final label = _inPrimary(find.text(_addLabel));
        expect(label, findsOneWidget);
        expect(paragraphOf(tester, label).didExceedMaxLines, isFalse);
        expect(tester.getRect(_dock()).bottom, closeTo(kPhoneHeight, 0.01));
      });
    }
  });

  group('CART-02 the secondary purchase section', () {
    testWidgets(
        'CART-02 sits after the accordions and the WhatsApp link and before '
        '"Más de ...", with the secondary actions', (tester) async {
      setPhoneView(tester);
      final store = await loadedStore();
      final (:product, other: _) = productWithBrandRail(store);
      final brand = store.facetsFor(product.id)!.brand!.value;
      await pumpFicha(tester, store, product.id);

      final section = find.byKey(kPurchaseSectionKey);
      final whatsapp = await contentOffsetOf(
        tester,
        find.text('Escribir por WhatsApp'),
      );
      final lastAccordion = await contentOffsetOf(
        tester,
        find.text('Envíos y cambios'),
      );
      final sectionTop = await contentOffsetOf(tester, section);
      final related = await contentOffsetOf(
        tester,
        find.text('Más de ${brandLabel(brand)}'),
      );
      expect(sectionTop, greaterThan(whatsapp));
      expect(sectionTop, greaterThan(lastAccordion));
      expect(sectionTop, lessThan(related));

      await scrollTo(tester, section);
      final heading = find.descendant(
        of: section,
        matching: find.text('Otras formas de comprar'),
      );
      expect(heading, findsOneWidget);
      final style = styleOf(tester, heading);
      expect(style.fontFamily, kBoutiqueSerifFamily);
      expect(style.fontWeight, FontWeight.w400);
      expect(style.fontSize, kBoutiqueSectionHeadingSize);

      final buyNow =
          find.descendant(of: section, matching: find.byKey(kBuyNowKey));
      final apartar =
          find.descendant(of: section, matching: find.byKey(kApartarKey));
      expect(buyNow, findsOneWidget);
      expect(apartar, findsOneWidget);
      expect(
        find.descendant(of: buyNow, matching: find.text('Comprar ahora')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: apartar, matching: find.text('Apartar')),
        findsOneWidget,
      );

      expect(_dock(), findsOneWidget);
      expect(
        find.descendant(of: _dock(), matching: find.byKey(kBuyNowKey)),
        findsNothing,
      );
      expect(
        find.descendant(of: _dock(), matching: find.byKey(kApartarKey)),
        findsNothing,
      );
      expect(
        find.descendant(of: _dock(), matching: find.text('Comprar ahora')),
        findsNothing,
      );
      expect(
        find.descendant(of: _dock(), matching: find.text('Apartar')),
        findsNothing,
      );
    });

    testWidgets(
        'CART-02b "Comprar ahora" adds one unit of the chosen variant and '
        'opens the bag', (tester) async {
      setPhoneView(tester);
      final store = await loadedStore();
      final product = syntheticProduct(variants: chipVariants());
      addProducts(store, [product]);
      await pumpFicha(tester, store, product.id);
      await selectOption(tester, 'Talla mediana');

      final buyNow = find.byKey(kBuyNowKey);
      await scrollTo(tester, buyNow);
      await tester.tap(buyNow);
      await tester.pumpAndSettle();

      expect(store.bagQuantity, 1);
      expect(store.bagLines.single.variant.id, 'v-mediana');
      expect(find.byType(BagScreen), findsOneWidget);
    });

    testWidgets(
        'CART-02b "Apartar" opens the WhatsApp request and records the event',
        (tester) async {
      setPhoneView(tester);
      final launches = mockUrlLauncher();
      final store = await loadedStore();
      final product = syntheticProduct(title: 'Cartera Mini');
      addProducts(store, [product]);
      await pumpFicha(tester, store, product.id);
      final eventsBefore = store.eventCount;

      final apartar = find.byKey(kApartarKey);
      await scrollTo(tester, apartar);
      await tester.tap(apartar);
      await tester.pumpAndSettle();

      expect(launches, hasLength(1));
      expect(launches.single.method, 'launch');
      final url = Uri.parse(
        (launches.single.arguments as Map<Object?, Object?>)['url']! as String,
      );
      expect(url.scheme, 'https');
      expect(url.host, 'wa.me');
      expect(url.path, '/528261066868');
      final message = url.queryParameters['text']!;
      expect(message, contains('*Cartera Mini*'));
      expect(message, contains('Precio: \$1299.00 MXN'));
      expect(
        message,
        contains('https://monetta.mx/products/${product.handle}'),
      );
      expect(message, contains('Código: MN-'));
      expect(store.eventCount, eventsBefore + 1);
    });
  });

  group('CART-03 pending and failing adds', () {
    testWidgets(
        'CART-03 while the add is pending the button says so and a second '
        'tap adds nothing', (tester) async {
      final (store, _) = await _mountScripted(tester);
      expect(_primary(), findsOneWidget);
      final hold = Completer<void>();
      store.hold = hold;

      await tester.tap(_primary());
      await tester.pump();
      expect(store.addCalls, 1);
      expect(_inPrimary(find.text(_pendingLabel)), findsOneWidget);
      expect(_inPrimary(find.text(_addLabel)), findsNothing);

      await tester.tap(_primary(), warnIfMissed: false);
      await tester.pump();
      expect(store.addCalls, 1, reason: 'a pending add is not repeated');
      expect(store.bagQuantity, 0);
      expect(find.text('En tu bolsa'), findsNothing);

      store.hold = null;
      hold.complete();
      await tester.pumpAndSettle();
      expect(store.addCalls, 1);
      expect(store.bagQuantity, 1);
      expect(find.text('En tu bolsa'), findsOneWidget);

      await tester.tapAt(const Offset(195, 40));
      await tester.pumpAndSettle();
      expect(find.text('En tu bolsa'), findsNothing);
      expect(_inPrimary(find.text(_addLabel)), findsOneWidget);

      await tester.tap(_primary());
      await tester.pumpAndSettle();
      expect(store.addCalls, 2, reason: 'the button is enabled again');
      expect(store.bagQuantity, 2);
    });

    testWidgets(
        'CART-03b a failing add shows the message, keeps the choice and '
        'retries exactly once', (tester) async {
      final (store, _) = await _mountScripted(
        tester,
        variants: chipVariants(),
      );
      await selectOption(tester, 'Talla mediana');
      expect(_primary(), findsOneWidget);

      store.failWith = StateError('storage unavailable');
      await tester.tap(_primary());
      await tester.pumpAndSettle();
      expect(find.text(_failureMessage), findsOneWidget);
      expect(store.bagQuantity, 0);
      expect(store.bagLines, isEmpty);
      expect(find.text('En tu bolsa'), findsNothing);
      expect(store.addCalls, 1);

      store.failWith = null;
      await tester.tap(_primary());
      await tester.pumpAndSettle();
      expect(store.addCalls, 2);
      expect(store.bagQuantity, 1, reason: 'one unit, not two');
      expect(
        store.bagLines.single.variant.id,
        'v-mediana',
        reason: 'the variant picked before the failure is still the one',
      );
    });
  });

  group('CART-04 availability', () {
    testWidgets(
        'CART-04 a fully sold-out piece offers the restock alert and only '
        '"Apartar"', (tester) async {
      setPhoneView(tester);
      final store = await loadedStore();
      final product = syntheticProduct(
        variants: [syntheticVariant(id: 'v-agotada', available: false)],
      );
      addProducts(store, [product]);
      await pumpFicha(tester, store, product.id);

      expect(_primary(), findsOneWidget);
      expect(find.byKey(kRestockKey), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(kRestockKey), matching: _primary()),
        findsOneWidget,
        reason: 'the restock key wraps the primary button',
      );
      expect(_inPrimary(find.text(_restockLabel)), findsOneWidget);
      expect(find.text(_addLabel, skipOffstage: false), findsNothing);
      expect(_inMainList(find.textContaining('Agotado')), findsWidgets);
      expect(
        find.descendant(of: _dock(), matching: find.textContaining('Agotado')),
        findsNothing,
      );

      await tester.tap(_primary());
      await tester.pump();
      expect(store.bagQuantity, 0);
      expect(
        find.text('Los avisos todavía no están disponibles en esta versión.'),
        findsOneWidget,
      );

      await scrollTo(tester, find.byKey(kApartarKey));
      expect(find.byKey(kApartarKey), findsOneWidget);
      expect(find.byKey(kBuyNowKey), findsNothing);
      expect(find.text('Comprar ahora'), findsNothing);
    });

    testWidgets(
        'CART-04b with a sold-out variant selected the dock offers the '
        'alert; with an available one it adds exactly that variant',
        (tester) async {
      setPhoneView(tester);
      final store = await loadedStore();
      final product = syntheticProduct(
        variants: chipVariants(available: [false, true, true]),
      );
      addProducts(store, [product]);
      await pumpFicha(tester, store, product.id);

      await selectOption(tester, 'Talla chica');
      expect(_primary(), findsOneWidget);
      expect(_inPrimary(find.text(_restockLabel)), findsOneWidget);
      expect(find.text(_addLabel, skipOffstage: false), findsNothing);

      await selectOption(tester, 'Talla mediana');
      expect(_inPrimary(find.text(_addLabel)), findsOneWidget);
      expect(find.byKey(kRestockKey), findsNothing);

      await tester.tap(_primary());
      await tester.pumpAndSettle();
      expect(store.bagQuantity, 1);
      expect(store.bagLines.single.variant.id, 'v-mediana');
    });
  });

  group('CART-04c the external dock', () {
    testWidgets('CART-04c the dock is 64 high and holds the merchant button',
        (tester) async {
      setPhoneView(tester);
      await pumpExternal(tester);

      expect(_dock(), findsOneWidget);
      final dock = tester.getRect(_dock());
      expect(dock.height, closeTo(64, 0.01));
      expect(dock.bottom, closeTo(kPhoneHeight, 0.01));
      final button = find.descendant(
        of: _dock(),
        matching: find.widgetWithText(FilledButton, 'VER EN COACH'),
      );
      expect(button, findsOneWidget);
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    });

    testWidgets('CART-04c with a 34 inset the dock is 98 high', (tester) async {
      setPhoneView(tester, inset: _inset);
      await pumpExternal(tester);

      expect(_dock(), findsOneWidget);
      final dock = tester.getRect(_dock());
      expect(dock.height, closeTo(64 + _inset, 0.01));
      expect(dock.bottom, closeTo(kPhoneHeight, 0.01));
    });

    testWidgets(
        'CART-04c the button opens the detail URL of the chosen variant, '
        'and nothing Monetta-checkout is offered', (tester) async {
      setPhoneView(tester);
      final item = externalItem();
      final opened = <Uri>[];
      await pumpExternal(
        tester,
        item: item,
        openLink: (uri) async {
          opened.add(uri);
          return true;
        },
      );

      expect(_dock(), findsOneWidget);
      final button = find.descendant(
        of: _dock(),
        matching: find.widgetWithText(FilledButton, 'VER EN COACH'),
      );
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(opened, [Uri.parse(item.variants[0].detailUrl)]);

      await tester.ensureVisible(find.text('Brass/Toffee'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Brass/Toffee'));
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(opened.last, Uri.parse(item.variants[1].detailUrl));
      expect(opened, hasLength(2));

      expect(find.textContaining('Agregar'), findsNothing);
      expect(find.byKey(kPurchaseSectionKey), findsNothing);
      expect(find.byKey(kHeaderFavoriteKey), findsNothing);
      expect(find.byType(BagAction), findsNothing);
      expect(find.byIcon(Icons.favorite_border), findsNothing);
    });
  });
}
