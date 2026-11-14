// v4.1 G03 replaces the obsolete seven-tile grid with the exact owner tree.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/features/catalog/categories_screen.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/catalog/product_card.dart';
import 'package:monetta_app/features/catalog/category_tree.dart';
import 'v41_discovery_fixture.dart';
import 'v41_discovery_test.dart' show mountDiscovery, tapVisible;

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
        'owner taxonomy expands in-flow and retains state on return at text $scale',
        (tester) async {
      final store = await discoveryStore();
      await mountDiscovery(
        tester,
        const CategoriesScreen(),
        store,
        scale: scale,
      );
      final first = find.byKey(const PageStorageKey('category-bags'));
      final second = find.byKey(const PageStorageKey('category-wallets'));
      final before = tester.getTopLeft(second).dy;
      await tapVisible(tester, first);
      expect(tester.getTopLeft(second).dy, greaterThan(before));
      await tapVisible(
        tester,
        find.byKey(const PageStorageKey('category-bags-women')),
      );
      for (final text in ['Crossbody', 'Tote', 'De mano', 'De hombro']) {
        expect(find.text(text), findsOneWidget);
      }
      await tapVisible(tester, find.byKey(const Key('category-open-bags')));
      final collection =
          tester.widget<CollectionScreen>(find.byType(CollectionScreen));
      expect(collection.filter.category, 'bolsa');
      expect(
        tester.widgetList<ProductCard>(find.byType(ProductCard)).every(
              (card) =>
                  store.facetsFor(card.product.id)?.category?.value == 'bolsa',
            ),
        isTrue,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Crossbody'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'an explicit gender binding keeps its configured collection membership',
      (tester) async {
    final store = await discoveryStore();
    await mountDiscovery(
      tester,
      const CategoriesScreen(
        bindings: {
          'bags-men': CollectionFilter(collectionHandle: 'configured-bags'),
        },
      ),
      store,
    );
    await tapVisible(tester, find.byKey(const PageStorageKey('category-bags')));
    await tapVisible(tester, find.byKey(const Key('category-bags-men')));
    expect(
      tester
          .widget<CollectionScreen>(find.byType(CollectionScreen))
          .filter
          .collectionHandle,
      'configured-bags',
    );
    expect(
      tester.widgetList<ProductCard>(find.byType(ProductCard)).every(
            (card) =>
                card.product.collectionHandles.contains('configured-bags'),
          ),
      isTrue,
    );
  });
  test('all node IDs are unique and hierarchy order is unchanged', () {
    final ids = <String>[];
    void visit(CategoryNode n) {
      ids.add(n.id);
      for (final c in n.children) {
        visit(c);
      }
    }

    for (final node in categoryTree) {
      visit(node);
    }
    expect(ids.toSet().length, ids.length);
    expect(
      categoryTree[1].children[0].children.map((n) => n.label),
      ['Muñequeras', 'Carteras', 'Tarjeteros'],
    );
  });
}
