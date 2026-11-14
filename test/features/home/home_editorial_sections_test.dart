import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/domain/home_content.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/main.dart';

void main() {
  testWidgets(
      'the brands grid shows the catalog brands with their logo artwork', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = CatalogStore(database: openTestDatabase());
    addTearDown(store.dispose);
    await store.loadFromAsset();

    await tester.pumpWidget(
      MaterialApp(
        home: StoreScope(
          notifier: store,
          child: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();

    final brandsSection = find.byKey(
      const ValueKey('home-section-brands'),
    );
    final homeScroll = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .first;
    await tester.scrollUntilVisible(
      brandsSection,
      700,
      scrollable: homeScroll,
    );
    await tester.pump();

    // All twelve configured brands, each with its bundled logo, including
    // those the bundled catalog has no product of yet (Rhode, Olaplex...).
    for (final brand in HomeContent.fallback.brands) {
      expect(
        find.byKey(ValueKey('home-brand-${brand.handle}')),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(
        of: brandsSection,
        matching: find.byType(SlideTransition),
      ),
      findsNWidgets(12),
    );
    expect(
      find.byKey(const ValueKey('home-brand-entrance-coach')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-brand-entrance-michael-kors')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: brandsSection, matching: find.byType(Image)),
      findsNWidgets(12),
    );
  });
}
