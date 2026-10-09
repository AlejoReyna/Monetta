import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/catalog/catalog_browse_screen.dart';

import '../../support/catalog_browse_fixtures.dart';
import '../../support/product_screen_harness.dart';
import '../../support/quick_add_harness.dart';

// CHAR-17 (RF-41 part C): the catalog browser follows the bag.
//
// `openCatalogBrowse` used to hand the screen the quantity the bag had at the
// moment of opening, so the badge of its bottom bar stayed frozen while the
// shopper added or removed pieces. The agreed rule: with a store above the
// screen the live quantity wins; without one the `bagCount` it was given.
//
// The "follows" cases are red until the screen subscribes to the store; the
// two characterization cases pin behaviour that must survive the fix.

final Finder _badge = find.byKey(const Key('bottom-nav-bag-badge'));

/// The number printed inside the badge of the bottom bar.
Finder _badgeText(String count) =>
    find.descendant(of: _badge, matching: find.text(count));

/// A host under the store with one button that opens the browser over
/// [products] through the production entry point.
Widget _openerApp(CatalogStore store, List<Product> products) => fichaApp(
      store,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => openCatalogBrowse(
                context,
                products: products,
                facetsById: store.facetsById,
              ),
              child: const Text('ABRIR CATALOGO'),
            ),
          ),
        ),
      ),
    );

Future<void> _openBrowser(WidgetTester tester) async {
  await tester.tap(find.text('ABRIR CATALOGO'));
  await tester.pumpAndSettle();
  expect(
    find.byType(CatalogBrowseScreen),
    findsOneWidget,
    reason: 'precondition: the browser is open',
  );
}

void main() {
  setUpAll(mockPathProvider);

  testWidgets(
      'CHAR-17 the browser opened with openCatalogBrowse follows the bag',
      (tester) async {
    setPhoneView(tester, height: 1600);
    final store = await loadedStore();
    final product = singleVariantAssetProduct(store);
    await tester.pumpWidget(_openerApp(store, [product]));
    await tester.pump();

    await _openBrowser(tester);
    expect(_badge, findsNothing, reason: 'an empty bag prints no counter');

    await store.addToBag(product);
    await tester.pump();
    expect(store.bagQuantity, 1, reason: 'precondition: the bag has 1 unit');
    expect(_badgeText('1'), findsOneWidget, reason: 'one unit added');

    await store.addToBag(product);
    await tester.pump();
    expect(store.bagQuantity, 2, reason: 'precondition: the bag has 2 units');
    expect(_badgeText('2'), findsOneWidget, reason: 'second unit added');

    await store.removeFromBag(product.variants.first.id);
    await tester.pump();
    expect(store.bagQuantity, 0, reason: 'precondition: the bag is empty');
    expect(
      _badge,
      findsNothing,
      reason: 'removing the line clears the counter',
    );
  });

  testWidgets('CHAR-17 the badge follows a quick add from the browser',
      (tester) async {
    setPhoneView(tester, height: 1600);
    final store = await loadedStore();
    final product = singleVariantAssetProduct(store);
    await tester.pumpWidget(_openerApp(store, [product]));
    await tester.pump();

    await _openBrowser(tester);
    expect(_badge, findsNothing, reason: 'an empty bag prints no counter');

    await tapQuickAdd(tester, product);
    await tester.pumpAndSettle();
    expect(store.bagQuantity, 1, reason: 'precondition: the "+" added a unit');
    expect(find.text('En tu bolsa'), findsOneWidget, reason: 'mini cart open');

    await dismissMiniCart(tester);
    expect(find.text('En tu bolsa'), findsNothing);
    expect(_badgeText('1'), findsOneWidget, reason: 'badge after quick add');
    await flush(tester);
  });

  testWidgets(
      'CHAR-17 without a store the badge shows the bagCount it was given',
      (tester) async {
    setPhoneView(tester, height: 1600);
    final entries = [browseEntry(1), browseEntry(2)];

    await tester.pumpWidget(
      externalApp(browseScreen(entries, bagCount: 2)),
    );
    await tester.pump();
    expect(_badgeText('2'), findsOneWidget);

    await tester.pumpWidget(
      externalApp(browseScreen(entries, bagCount: 0)),
    );
    await tester.pump();
    expect(_badge, findsNothing);
  });

  testWidgets('CHAR-17 the browser opened with items in the bag shows them',
      (tester) async {
    setPhoneView(tester, height: 1600);
    final store = await loadedStore();
    final product = singleVariantAssetProduct(store);
    await store.addToBag(product);
    await store.addToBag(product);
    expect(store.bagQuantity, 2, reason: 'precondition: 2 units in the bag');
    await tester.pumpWidget(_openerApp(store, [product]));
    await tester.pump();

    await _openBrowser(tester);

    expect(_badgeText('2'), findsOneWidget);
  });
}
