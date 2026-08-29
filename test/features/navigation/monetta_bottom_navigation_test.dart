import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/features/navigation/monetta_bottom_navigation.dart';

void main() {
  testWidgets('premium navigation keeps all four destinations actionable',
      (tester) async {
    MonettaBottomDestination? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: MonettaBottomNavigation(
            current: MonettaBottomDestination.home,
            bagCount: 2,
            onSelected: (destination) => selected = destination,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('bottom-nav-home')), findsOneWidget);
    expect(find.byKey(const Key('bottom-nav-catalog')), findsOneWidget);
    expect(find.byKey(const Key('bottom-nav-bag')), findsOneWidget);
    expect(find.byKey(const Key('bottom-nav-account')), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('bottom-nav-catalog')));
    expect(selected, MonettaBottomDestination.catalog);
  });

  testWidgets('active indicator slides while destinations stay in place',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: _NavigationHarness()),
    );

    final indicator = find.byKey(const Key('bottom-nav-selection-indicator'));
    final home = find.byKey(const Key('bottom-nav-home'));
    final catalog = find.byKey(const Key('bottom-nav-catalog'));
    final initialHomeCenter = tester.getCenter(home);
    final initialCatalogCenter = tester.getCenter(catalog);
    final initialIndicatorCenter = tester.getCenter(indicator);

    expect(initialIndicatorCenter.dx, closeTo(initialHomeCenter.dx, 0.01));

    final activeFill = tester.widget<DecoratedBox>(
      find.byKey(const Key('bottom-nav-selection-fill')),
    );
    expect(
      (activeFill.decoration as BoxDecoration).color,
      const Color(0xFFE7E5E0),
    );

    await tester.tap(catalog);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));

    final movingIndicatorCenter = tester.getCenter(indicator);
    expect(movingIndicatorCenter.dx, greaterThan(initialHomeCenter.dx));
    expect(movingIndicatorCenter.dx, lessThan(initialCatalogCenter.dx));
    expect(tester.getCenter(home), initialHomeCenter);
    expect(tester.getCenter(catalog), initialCatalogCenter);

    await tester.pumpAndSettle();

    expect(
      tester.getCenter(indicator).dx,
      closeTo(initialCatalogCenter.dx, 0.01),
    );
  });

  testWidgets('navigation surface is docked edge-to-edge at the bottom',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(padding: EdgeInsets.only(bottom: 24)),
          child: _NavigationHarness(),
        ),
      ),
    );

    final surface = find.byKey(const Key('bottom-nav-surface'));
    final surfaceRect = tester.getRect(surface);

    expect(surfaceRect.left, 0);
    expect(surfaceRect.right, 800);
    expect(surfaceRect.bottom, 600);
    expect(surfaceRect.height, 70);
  });
}

class _NavigationHarness extends StatefulWidget {
  const _NavigationHarness();

  @override
  State<_NavigationHarness> createState() => _NavigationHarnessState();
}

class _NavigationHarnessState extends State<_NavigationHarness> {
  var current = MonettaBottomDestination.home;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const SizedBox.expand(),
      bottomNavigationBar: MonettaBottomNavigation(
        current: current,
        bagCount: 0,
        onSelected: (destination) => setState(() => current = destination),
      ),
    );
  }
}
