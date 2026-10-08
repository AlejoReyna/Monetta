import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/shopper_copy.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/checkout/checkout_screen.dart';
import 'package:monetta_app/features/product/product_selection.dart';

import '../../support/product_screen_harness.dart';

// FICHA-T2, RESP-02 / A11Y-01: the ficha under the
// width and text-scale matrix with a real bottom inset, and the accessibility
// contract of its header, dock and secondary actions.

const _widths = [320.0, 390.0, 430.0, 768.0];
const _scales = [1.0, 2.0];
const double _inset = 34;

Product _added(CatalogStore store, Product product) {
  addProducts(store, [product]);
  return product;
}

/// The Monetta scenarios of the matrix, each resolving to a product that is
/// on the store when the ficha is mounted.
final Map<String, Product Function(CatalogStore)> _scenarios = {
  'one variant': singleVariantAssetProduct,
  'several variants': (store) => store.products.firstWhere(
        (p) =>
            p.isInStock &&
            selectableVariants(p).length > 1 &&
            p.variants.every((v) => v.available),
      ),
  'long name': (store) =>
      _added(store, syntheticProduct(title: kLongProductName)),
  'sold out': (store) => _added(
        store,
        syntheticProduct(
          variants: [syntheticVariant(id: 'v-agotada', available: false)],
        ),
      ),
};

/// Common contract of both fichas once mounted: no layout error, the dock is
/// inside the view and anchored to the bottom edge, the title is not clipped,
/// and after scrolling to the end the last element of the content ends above
/// the dock.
Future<void> _expectMatrixContract(
  WidgetTester tester, {
  required double width,
}) async {
  final dock = find.byKey(kDockKey);
  expect(dock, findsOneWidget);
  expect(tester.takeException(), isNull);

  final rect = tester.getRect(dock);
  expect(rect.left, greaterThanOrEqualTo(-0.01));
  expect(rect.right, lessThanOrEqualTo(width + 0.01));
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, closeTo(kPhoneHeight, 0.01), reason: 'anchored below');
  expect(rect.height, greaterThanOrEqualTo(64 + _inset - 0.01));

  expect(headerTitle(), findsOneWidget);
  final bar = tester.getRect(appBarFinder());
  final title = tester.getRect(headerTitle());
  expect(title.left, greaterThanOrEqualTo(bar.left - 0.01));
  expect(title.right, lessThanOrEqualTo(bar.right + 0.01));
  expect(title.top, greaterThanOrEqualTo(bar.top - 0.01));
  expect(title.bottom, lessThanOrEqualTo(bar.bottom + 0.01));
  expect(lineCount(tester, headerTitle()), lessThanOrEqualTo(2));

  await scrollToEnd(tester);
  expect(tester.takeException(), isNull);
  expect(
    lastBuiltChildBottom(tester),
    lessThanOrEqualTo(tester.getRect(dock).top + 0.5),
    reason: 'the last element of the content ends above the dock',
  );
}

void main() {
  setUpAll(mockPathProvider);

  for (final width in _widths) {
    for (final scale in _scales) {
      final label = '${width.toInt()} wide x$scale';

      for (final MapEntry(key: name, value: pick) in _scenarios.entries) {
        testWidgets('RESP-02 ficha Monetta, $name, $label', (tester) async {
          setPhoneView(tester, width: width, inset: _inset);
          final store = await loadedStore();
          final product = pick(store);
          await pumpFicha(tester, store, product.id, scale: scale);

          await _expectMatrixContract(tester, width: width);
        });
      }
    }
  }

  group('A11Y-01', () {
    void expectButton(
      WidgetTester tester,
      Finder finder, {
      required String what,
    }) {
      expect(finder, findsOneWidget, reason: what);
      final size = tester.getSize(finder);
      expect(size.width, greaterThanOrEqualTo(48), reason: '$what: width');
      expect(size.height, greaterThanOrEqualTo(48), reason: '$what: height');
      final node = tester.getSemantics(finder);
      expect(accessibleName(node), isNotEmpty, reason: '$what: name');
      expect(
        node.getSemanticsData().flagsCollection.isButton,
        isTrue,
        reason: '$what: button role',
      );
    }

    testWidgets(
        'A11Y-01 back, heart, bag, dock button and secondary actions are '
        'named 48 px buttons', (tester) async {
      await withSemantics(tester, () async {
        setPhoneView(tester);
        final store = await loadedStore();
        final product = _added(store, syntheticProduct());
        await pumpFicha(tester, store, product.id);
        await tester.pump();

        expectButton(tester, find.byKey(kHeaderBackKey), what: 'back');
        expectButton(tester, find.byKey(kHeaderFavoriteKey), what: 'heart');
        expectButton(tester, inAppBar(find.byType(BagAction)), what: 'bag');
        expectButton(tester, find.byKey(kDockPrimaryKey), what: 'dock button');
        expect(
          accessibleName(tester.getSemantics(find.byKey(kDockPrimaryKey))),
          contains('Agregar al carrito'),
        );

        await scrollTo(tester, find.byKey(kBuyNowKey));
        expectButton(tester, find.byKey(kBuyNowKey), what: 'Comprar ahora');
        await scrollTo(tester, find.byKey(kApartarKey));
        expectButton(tester, find.byKey(kApartarKey), what: 'Apartar');
      });
    });

    testWidgets('A11Y-01 the reading order is header, content, dock',
        (tester) async {
      await withSemantics(tester, () async {
        setPhoneView(tester);
        final store = await loadedStore();
        final product = _added(store, syntheticProduct(title: 'Cartera'));
        await pumpFicha(tester, store, product.id);
        await tester.pump();

        expect(headerTitle(), findsOneWidget);
        expect(find.byKey(kDockPrimaryKey), findsOneWidget);
        final name = contentNameText(shopperProductName(product.title));
        await scrollTo(tester, name);
        final title = tester.getSemantics(headerTitle());
        final content = tester.getSemantics(name);
        final dock = tester.getSemantics(find.byKey(kDockPrimaryKey));

        final order = tester.semantics
            .simulatedAccessibilityTraversal()
            .map((node) => node.id);
        final position = {
          for (final (index, id) in order.indexed) id: index,
        };
        expect(position, contains(title.id), reason: 'header is traversable');
        expect(
          position,
          contains(content.id),
          reason: 'content is traversable',
        );
        expect(position, contains(dock.id), reason: 'dock is traversable');
        expect(position[title.id]!, lessThan(position[content.id]!));
        expect(position[content.id]!, lessThan(position[dock.id]!));
      });
    });
  });
}
