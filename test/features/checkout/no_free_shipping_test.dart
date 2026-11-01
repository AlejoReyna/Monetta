/// SHIP-01 to SHIP-03: the app neither promises nor computes shipping by
/// amount, never invents a shipping cost, and its local total adds no
/// shipping. Where a shipping line exists it says "Se calcula en Shopify",
/// the same words the remote cart summary uses.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/shopify/cart/checkout_launcher.dart';
import 'package:monetta_app/features/checkout/checkout_screen.dart';
import 'package:monetta_app/features/checkout/mini_cart.dart';
import 'package:monetta_app/main.dart';

import '../../support/product_screen_harness.dart';

/// Case-insensitive "free" in any copy.
final RegExp _gratis = RegExp('gratis', caseSensitive: false);

const String _calculatedByShopify = 'Se calcula en Shopify';

/// One bag per case: below the old $1,499 threshold, exactly at it, and above.
typedef _BagCase = ({String name, double unitPrice, int quantity});

const List<_BagCase> _cases = [
  (name: 'below the old threshold', unitPrice: 500, quantity: 1),
  (name: 'exactly at the old threshold', unitPrice: 1499, quantity: 1),
  (name: 'above the old threshold', unitPrice: 800, quantity: 3),
];

double _subtotalOf(_BagCase bagCase) => bagCase.unitPrice * bagCase.quantity;

Future<CatalogStore> _storeWithBag(_BagCase bagCase) async {
  final store = await loadedStore();
  final variant = syntheticVariant(
    id: 'gid://shopify/ProductVariant/9101',
    price: bagCase.unitPrice,
  );
  final product = syntheticProduct(
    id: 'gid://shopify/Product/9101',
    title: 'Bolsa de prueba de envío',
    variants: [variant],
  );
  addProducts(store, [product]);
  await store.addToBag(product);
  if (bagCase.quantity > 1) {
    await store.updateBagQuantity(variant.id, bagCase.quantity);
  }
  expect(
    store.bagSubtotal,
    _subtotalOf(bagCase),
    reason: 'fixture bag must reach the intended subtotal',
  );
  return store;
}

Widget _app(CatalogStore store, Widget child) => MaterialApp(
      theme: buildTheme(),
      home: StoreScope(notifier: store, child: child),
    );

void _setSurface(WidgetTester tester, Size size) {
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
}

/// The texts of the row that holds [label], without the label itself.
List<String> _valuesOfRow(Finder scope, String label) {
  final labelFinder = find.descendant(of: scope, matching: find.text(label));
  expect(
    labelFinder,
    findsOneWidget,
    reason: 'row "$label" must exist exactly once',
  );
  final row = find.ancestor(of: labelFinder, matching: find.byType(Row)).first;
  return [
    for (final element
        in find.descendant(of: row, matching: find.byType(Text)).evaluate())
      if ((element.widget as Text).data != label)
        (element.widget as Text).data ?? '',
  ];
}

/// Every copy that mentions "gratis", from text and from semantics.
void _expectNoFreeShippingCopy(WidgetTester tester) {
  expect(
    find.textContaining(_gratis),
    findsNothing,
    reason: 'no visible text may mention "gratis"',
  );
  expect(
    find.bySemanticsLabel(_gratis),
    findsNothing,
    reason: 'no semantics label may mention "gratis"',
  );
}

void main() {
  setUpAll(mockPathProvider);

  group('SHIP-01 bag', () {
    for (final (layout, size) in const [
      ('narrow layout', Size(390, 2600)),
      ('wide layout', Size(1200, 1600)),
    ]) {
      for (final bagCase in _cases) {
        testWidgets(
          'SHIP-01 bag has no free-shipping bar and the local summary leaves '
          'shipping to Shopify ($layout, ${bagCase.name})',
          (tester) async {
            _setSurface(tester, size);
            await withSemantics(tester, () async {
              final store = await _storeWithBag(bagCase);

              await tester.pumpWidget(_app(store, const BagScreen()));
              await tester.pump();

              expect(find.text('Mi bolsa'), findsOneWidget);
              expect(
                find.byKey(const ValueKey('free-shipping-incentive')),
                findsNothing,
              );
              expect(find.byType(LinearProgressIndicator), findsNothing);
              _expectNoFreeShippingCopy(tester);

              final summary = find.byKey(const ValueKey('bag-order-summary'));
              expect(summary, findsOneWidget);
              final subtotal = kMoney.format(_subtotalOf(bagCase));
              expect(_valuesOfRow(summary, 'Subtotal'), [subtotal]);
              expect(_valuesOfRow(summary, 'Envío'), [_calculatedByShopify]);
              expect(_valuesOfRow(summary, 'Total estimado'), [subtotal]);
              expect(
                find.descendant(of: summary, matching: find.text('Total')),
                findsNothing,
                reason: 'the local figure is an estimate and must say so',
              );
            });
          },
        );
      }
    }
  });

  group('SHIP-02 mini cart', () {
    for (final bagCase in _cases) {
      testWidgets(
        'SHIP-02 mini cart has no free-shipping copy or progress bar '
        '(${bagCase.name})',
        (tester) async {
          _setSurface(tester, const Size(390, 1200));
          await withSemantics(tester, () async {
            final store = await _storeWithBag(bagCase);

            await tester.pumpWidget(_app(store, const MiniCartSheet()));
            await tester.pump();

            expect(find.text('En tu bolsa'), findsOneWidget);
            expect(find.byType(LinearProgressIndicator), findsNothing);
            _expectNoFreeShippingCopy(tester);
          });
        },
      );
    }
  });

  group('SHIP-03 local checkout', () {
    Future<void> pumpCheckout(WidgetTester tester, CatalogStore store) async {
      await tester.pumpWidget(
        _app(
          store,
          CheckoutFlowScreen(
            launchSecureCheckout: (_) async => const CheckoutCancelled(),
          ),
        ),
      );
      await tester.pump();
    }

    void expectTotals(_BagCase bagCase) {
      // The summary has no key; it is the only place with these row labels.
      final scope = find.byType(Scaffold).first;
      final subtotal = kMoney.format(_subtotalOf(bagCase));
      expect(_valuesOfRow(scope, 'Subtotal'), [subtotal]);
      expect(_valuesOfRow(scope, 'Envío estimado'), [_calculatedByShopify]);
      expect(_valuesOfRow(scope, 'Total estimado'), [subtotal]);
    }

    for (final bagCase in _cases) {
      testWidgets(
        'SHIP-03 checkout shows no delivery amount and a calculated '
        'total (${bagCase.name})',
        (tester) async {
          _setSurface(tester, const Size(390, 2400));
          final store = await _storeWithBag(bagCase);
          await pumpCheckout(tester, store);

          expect(find.byKey(const ValueKey('checkout-pay-button')), findsOne);
          _expectNoFreeShippingCopy(tester);
          expect(find.textContaining('Estimado previo'), findsNothing);
          expectTotals(bagCase);
        },
      );
    }
  });
}
