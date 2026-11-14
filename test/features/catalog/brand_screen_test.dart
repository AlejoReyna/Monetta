// G05-A uses the same scoped query/filter/sort surface as collections.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/features/catalog/brand_screen.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/catalog/product_card.dart';
import 'v41_discovery_fixture.dart';
import 'v41_discovery_test.dart' show mountDiscovery, tapVisible;

void main() {
  for (final brand in ['coach', 'guess']) {
    testWidgets(
        '$brand uses actual membership through query, filters, clear and order',
        (tester) async {
      final store = await discoveryStore();
      await mountDiscovery(tester, BrandScreen(brandSlug: brand), store);
      void check() {
        final cards = tester.widgetList<ProductCard>(find.byType(ProductCard));
        expect(cards, isNotEmpty);
        expect(
          cards.every(
            (c) => store.facetsFor(c.product.id)?.brand?.value == brand,
          ),
          isTrue,
        );
      }

      check();
      await tapVisible(
        tester,
        find.byKey(const Key('collection-filter-button')),
      );
      // Fixed destination brand cannot be replaced from the filter panel.
      expect(
        find.byKey(
          Key(
            'collection-filter-brand-${brand == 'coach' ? 'guess' : 'coach'}',
          ),
        ),
        findsNothing,
      );
      await tapVisible(
        tester,
        find.byKey(const Key('collection-filter-offers')),
      );
      await tapVisible(
        tester,
        find.byKey(const Key('collection-filter-apply')),
      );
      check();
      await tapVisible(
        tester,
        find.byKey(const Key('collection-clear-inline')),
      );
      check();
      await tapVisible(tester, find.byKey(const Key('collection-sort-button')));
      await tapVisible(tester, find.byKey(const Key('collection-sort-oldest')));
      await tapVisible(tester, find.byKey(const Key('collection-sort-apply')));
      check();
      expect(
        tester
            .widget<CollectionScreen>(find.byType(CollectionScreen))
            .filter
            .brand,
        brand,
      );
    });
  }
  testWidgets(
      'unknown brand shows empty rather than a different brand fallback',
      (tester) async {
    final store = await discoveryStore();
    await mountDiscovery(
      tester,
      const BrandScreen(brandSlug: 'missing'),
      store,
    );
    expect(find.text('Sin resultados'), findsOneWidget);
    expect(find.byType(ProductCard), findsNothing);
  });
  testWidgets('owner story exists only when supplied', (tester) async {
    final store = await discoveryStore();
    await mountDiscovery(
      tester,
      const BrandScreen(brandSlug: 'guess', story: 'Texto de la dueña.'),
      store,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('brand-story')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Texto de la dueña.'), findsOneWidget);
    expect(find.text('Sobre la marca'), findsOneWidget);
  });
}
