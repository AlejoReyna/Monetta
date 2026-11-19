import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/domain/home_content.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/main.dart';

void main() {
  testWidgets('the brands rail shows configured brands with their logo artwork',
      (
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

    final rail = find.descendant(
      of: find.byKey(const ValueKey('home-brands-rail')),
      matching: find.byType(Scrollable),
    );
    await tester.ensureVisible(rail);
    await tester.pump();
    expect(tester.widget<Scrollable>(rail).axis, Axis.horizontal);
    for (final brand in guideBrandsFor(HomeContent.fallback.brands)) {
      final tile = find.byKey(ValueKey('home-brand-${brand.handle}'));
      await tester.scrollUntilVisible(tile, 150, scrollable: rail);
      expect(find.descendant(of: tile, matching: find.byType(Image)),
          findsOneWidget);
    }
  });
}
