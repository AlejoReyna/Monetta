// Correction 5 G05/G05-A: actual delivered banners and small native context.
// The superseded guide-photo/studio-fallback geometry is not a v4.1 baseline.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/features/boutique/guide_art.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'v41_discovery_fixture.dart';
import 'v41_discovery_test.dart' show mountDiscovery;

void main() {
  for (final (filter, banner) in [
    (const CollectionFilter(category: 'bolsa'), 'B08'),
    (const CollectionFilter(category: 'cartera'), 'B21'),
    (const CollectionFilter(category: 'bolsa', silhouette: 'tote'), 'B19'),
    (const CollectionFilter(brand: 'coach'), 'B28'),
    (const CollectionFilter(brand: 'marc_jacobs'), 'B26'),
    (const CollectionFilter(brand: 'tory_burch'), 'B25'),
  ]) {
    testWidgets(
        'destination resolves delivered $banner without title reconstruction',
        (tester) async {
      final store = await discoveryStore();
      await mountDiscovery(
        tester,
        CollectionScreen(title: 'Contexto', filter: filter),
        store,
      );
      expect(tester.widget<GuideBanner>(find.byType(GuideBanner)).id, banner);
      expect(guideAsset('banner:$banner'), isNotNull);
      final title = tester.widget<Text>(find.text('Contexto'));
      expect(title.style?.fontSize, 15);
      expect(
        find.descendant(
          of: find.byType(GuideBanner),
          matching: find.byType(FittedBox),
        ),
        findsNothing,
      );
    });
  }
  testWidgets(
      'no matching approved banner leaves the collection context readable',
      (tester) async {
    final store = await discoveryStore();
    await mountDiscovery(
      tester,
      const CollectionScreen(title: 'Colección sin banner'),
      store,
    );
    expect(find.byType(GuideBanner), findsNothing);
    expect(find.text('Colección sin banner'), findsOneWidget);
  });
}
