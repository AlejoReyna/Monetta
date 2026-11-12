import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/checkout/checkout_screen.dart';
import 'package:monetta_app/features/product/product_selection.dart';
import 'package:monetta_app/features/product/product_screen.dart';
import '../../support/product_screen_harness.dart';
import '../../support/scripted_catalog_store.dart';

// FICHA-T2, CART-xx: the purchase dock of the ficha (one primary action, 64 px
// of content plus the real bottom inset applied once) and the secondary
// "Otras formas de comprar" section (BRIEF 2.5).

const double _inset = 34;
const String _addLabel = 'AGREGAR A BOLSA';
const String _pendingLabel = 'AGREGANDO…';
const Key _bottomNavKey = Key('bottom-nav-surface');
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
  final store = await loadStore(
    ScriptedCatalogStore(database: openTestDatabase()),
  );
  final product = syntheticProduct(variants: variants);
  addProducts(store, [product]);
  await pumpFicha(tester, store, product.id);
  return (store, product);
}

void main() {
  setUpAll(mockPathProvider);

  group('CART-01 the purchase actions', () {
    testWidgets(
      'CART-01 the bottom nav is docked and the primary action is in the list',
      (tester) async {
        await _mountSingle(tester, settle: false);

        expect(find.byKey(_bottomNavKey), findsOneWidget);
        final nav = tester.getRect(find.byKey(_bottomNavKey));
        expect(nav.bottom, closeTo(kPhoneHeight, 0.01));
        expect(nav.left, closeTo(0, 0.01));
        expect(nav.width, closeTo(390, 0.01));
        expect(_dock(), findsNothing);
        expect(_primary(), findsOneWidget);
        expect(tester.getSize(_primary()).height, greaterThanOrEqualTo(48));
        expect(_inPrimary(find.text(_addLabel)), findsOneWidget);
        expect(find.text('COMPRAR AHORA'), findsOneWidget);

        final before = tester.getRect(find.byKey(_bottomNavKey));
        await scrollToEnd(tester);
        expect(tester.getRect(find.byKey(_bottomNavKey)), before);
      },
    );

    testWidgets(
      'CART-01 with a 34 inset the nav stays docked to the edge',
      (tester) async {
        await _mountSingle(tester, inset: _inset, settle: false);

        final nav = tester.getRect(find.byKey(_bottomNavKey));
        expect(nav.bottom, closeTo(kPhoneHeight, 0.01));
        expect(nav.height, greaterThan(_inset));
        expect(_primary(), findsOneWidget);
        expect(tester.getSize(_primary()).height, greaterThanOrEqualTo(48));
      },
    );

    testWidgets('CART-01 the nav paints down to the edge', (
      tester,
    ) async {
      await _mountSingle(tester, inset: _inset);

      final nav = tester.getRect(find.byKey(_bottomNavKey));
      expect(nav.bottom, closeTo(kPhoneHeight, 0.01));
      expect(nav.left, closeTo(0, 0.01));
      expect(nav.right, closeTo(390, 0.01));
      expect(nav.top, lessThan(kPhoneHeight - _inset));
    });

    testWidgets(
      'CART-01b the nav holds no price or availability; the content does',
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

        expect(find.byKey(_bottomNavKey), findsOneWidget);
        for (final text in [r'$', 'Disponible', 'Agotado']) {
          expect(
            find.descendant(
              of: find.byKey(_bottomNavKey),
              matching: find.textContaining(text),
            ),
            findsNothing,
            reason: 'the nav must not show "$text"',
          );
        }
        expect(
          find.descendant(
            of: find.byKey(_bottomNavKey),
            matching: find.byType(ProductOptionSelector),
          ),
          findsNothing,
        );

        expect(
          _inMainList(
            find.text(formatShopperPrice(selectionPrice(product, 0))),
          ),
          findsWidgets,
        );
        expect(_inMainList(find.textContaining('Disponible')), findsOneWidget);
        expect(_inMainList(find.byType(ProductOptionSelector)), findsOneWidget);
      },
    );

    for (final width in [320.0, 390.0]) {
      testWidgets(
        'CART-01c at x2 and ${width.toInt()} wide the label is not truncated',
        (tester) async {
          await _mountSingle(tester, width: width, scale: 2.0, inset: _inset);

          expect(find.byKey(_bottomNavKey), findsOneWidget);
          expect(tester.takeException(), isNull);
          expect(tester.getSize(_primary()).height, greaterThanOrEqualTo(48));
          final label = _inPrimary(find.text(_addLabel));
          expect(label, findsOneWidget);
          expect(paragraphOf(tester, label).didExceedMaxLines, isFalse);
          expect(
            tester.getRect(find.byKey(_bottomNavKey)).bottom,
            closeTo(kPhoneHeight, 0.01),
          );
        },
      );
    }
  });

  group('G10/G10-A purchase continuation', () {
    Future<void> openMethods(WidgetTester tester) async {
      final heading = find.text('Otras formas de comprar');
      tester.state<ScrollableState>(mainScrollable()).position.jumpTo(0);
      await tester.pump();
      for (var i = 0; i < 15 && heading.hitTestable().evaluate().isEmpty; i++) {
        await tester.drag(mainList(), const Offset(0, -150));
        await tester.pump();
      }
      await tester.tap(heading.hitTestable());
      await tester.pump();
    }

    testWidgets('accordions follow required order and WhatsApp is lazy',
        (tester) async {
      setPhoneView(tester);
      final store = await loadedStore();
      final (:product, other: _) = productWithBrandRail(store);
      await tester.pumpWidget(
        fichaApp(
          store,
          ProductScreen(
            productId: product.id,
            shippingPolicy: 'Política de envíos de prueba.',
            returnsPolicy: 'Política de cambios de prueba.',
          ),
        ),
      );
      await tester.pump();
      final description =
          await contentOffsetOf(tester, find.text('Descripción'));
      final methods =
          await contentOffsetOf(tester, find.text('Otras formas de comprar'));
      final shipping = await contentOffsetOf(tester, find.text('Envíos'));
      final returns =
          await contentOffsetOf(tester, find.text('Cambios y devoluciones'));
      expect(description, lessThan(methods));
      expect(methods, lessThan(shipping));
      expect(shipping, lessThan(returns));
      expect(find.byKey(kApartarKey), findsNothing);
      await openMethods(tester);
      expect(find.byKey(kApartarKey), findsOneWidget);
      expect(
        find.text(
          'Enviar una solicitud no confirma el apartado ni realiza un cobro.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(kBuyNowKey), findsOneWidget);
    });
    testWidgets(
        'Comprar ahora adds chosen variant and preserves other bag lines',
        (tester) async {
      setPhoneView(tester);
      final store = await loadedStore();
      final product = syntheticProduct(variants: chipVariants());
      addProducts(store, [product]);
      await store.addToBag(product, variantId: 'v-chica');
      await pumpFicha(tester, store, product.id);
      await selectOption(tester, 'Talla mediana');
      await scrollTo(tester, find.byKey(kBuyNowKey));
      await tester.tap(find.byKey(kBuyNowKey));
      await tester.pumpAndSettle();
      expect(store.bagQuantity, 2);
      expect(
        store.bagLines.map((line) => line.variant.id).toSet(),
        {'v-chica', 'v-mediana'},
      );
      expect(find.byType(BagScreen), findsOneWidget);
    });
    testWidgets(
        'lazy apartado opens contextual WhatsApp without fabricated deposit terms',
        (tester) async {
      setPhoneView(tester);
      final launches = mockUrlLauncher();
      final store = await loadedStore();
      final product = syntheticProduct(title: 'Cartera Mini');
      addProducts(store, [product]);
      await pumpFicha(tester, store, product.id);
      final eventsBefore = store.eventCount;
      expect(launches, isEmpty);
      expect(find.byKey(kApartarKey), findsNothing);
      await openMethods(tester);
      await scrollTo(tester, find.byKey(kApartarKey));
      await tester.tap(find.byKey(kApartarKey));
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
      expect(message, contains('Cartera Mini'));
      expect(message, contains('Variante: ${product.variants.single.id}'));
      expect(message, contains('Precio: ${formatShopperPrice(product.price)}'));
      expect(message, contains('Código: MN-'));
      expect(message, isNot(contains('anticipo es')));
      expect(message, isNot(contains('20 días')));
      expect(store.eventCount, eventsBefore + 1);
    });
  });

  group('CART-03 pending and failing adds', () {
    testWidgets(
      'CART-03 while the add is pending the button says so and a second '
      'tap adds nothing',
      (tester) async {
        final (store, _) = await _mountScripted(tester);
        expect(_primary(), findsOneWidget);
        final hold = Completer<void>();
        store.hold = hold;

        await scrollTo(tester, _primary());
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
        expect(find.text('Agregado al carrito'), findsOneWidget);
        expect(find.text('En tu bolsa'), findsNothing);
        expect(_inPrimary(find.text(_addLabel)), findsOneWidget);

        await tester.tap(_primary());
        await tester.pumpAndSettle();
        expect(store.addCalls, 2, reason: 'the button is enabled again');
        expect(store.bagQuantity, 2);
      },
    );

    testWidgets(
      'CART-03b a failing add shows the message, keeps the choice and '
      'retries exactly once',
      (tester) async {
        final (store, _) = await _mountScripted(
          tester,
          variants: chipVariants(),
        );
        await selectOption(tester, 'Talla mediana');
        expect(_primary(), findsOneWidget);

        store.failWith = StateError('storage unavailable');
        await scrollTo(tester, _primary());
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
      },
    );
  });

  group('G12 availability capability gate', () {
    testWidgets(
        'exhausted product hides add/buy/unsupported restock and keeps details',
        (tester) async {
      setPhoneView(tester);
      final store = await loadedStore();
      final product = syntheticProduct(
        variants: [syntheticVariant(id: 'v-agotada', available: false)],
      );
      addProducts(store, [product]);
      await pumpFicha(tester, store, product.id);
      expect(_primary(), findsNothing);
      expect(find.byKey(kRestockKey), findsNothing);
      expect(find.text(_restockLabel), findsNothing);
      expect(find.byKey(kBuyNowKey), findsNothing);
      expect(find.text('AGOTADO'), findsOneWidget);
      expect(store.bagQuantity, 0);
      expect(find.text('Otras formas de comprar'), findsOneWidget);
    });
    testWidgets('available option restores add and sends exactly that variant',
        (tester) async {
      setPhoneView(tester);
      final store = await loadedStore();
      final product = syntheticProduct(
        variants: chipVariants(available: [false, true, true]),
      );
      addProducts(store, [product]);
      await pumpFicha(tester, store, product.id);
      await selectOption(tester, 'Talla chica');
      expect(_primary(), findsNothing);
      expect(find.byKey(kRestockKey), findsNothing);
      await selectOption(tester, 'Talla mediana');
      expect(_inPrimary(find.text(_addLabel)), findsOneWidget);
      await scrollTo(tester, _primary());
      await tester.tap(_primary());
      await tester.pumpAndSettle();
      expect(store.bagQuantity, 1);
      expect(store.bagLines.single.variant.id, 'v-mediana');
    });
  });

  group('CART-04c the external dock', () {
    testWidgets('CART-04c the dock is 64 high and holds the merchant button', (
      tester,
    ) async {
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
      'and nothing Monetta-checkout is offered',
      (tester) async {
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
      },
    );
  });
}
