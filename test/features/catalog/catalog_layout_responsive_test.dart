import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/navigation/monetta_bottom_navigation.dart';
import 'package:monetta_app/features/navigation/monetta_floating_bottom_navigation.dart';
import 'package:monetta_app/main.dart';

import '../../support/catalog_browse_fixtures.dart';

// RESP-01: the catalog, the collections and the bare bar mount without a
// layout error at every phone width and text scale of the matrix, with a
// bottom inset of 34 present in the view, and
// nothing is laid out below the bottom edge of the view.

const _widths = [320.0, 390.0, 430.0, 768.0];
const _scales = [1.0, 2.0];
const _height = 844.0;
const _inset = 34.0;

BrowseEntry _item(int i) => browseEntry(i, price: 1000.0 + i);

void _view(WidgetTester tester, double width) {
  addTearDown(tester.view.reset);
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, _height);
  tester.view.padding = const FakeViewPadding(bottom: _inset);
  tester.view.viewPadding = const FakeViewPadding(bottom: _inset);
}

Widget _app(Widget home, double scale) => MaterialApp(
      theme: buildLightTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: home,
    );

/// Both navigation variants stay within the view; the storefront one is flat.
void _expectContained(WidgetTester tester, {bool floating = true}) {
  expect(tester.takeException(), isNull);

  final surface = tester.getRect(find.byKey(const Key('bottom-nav-surface')));
  expect(surface.bottom, lessThanOrEqualTo(_height + 0.01));
  if (floating) {
    // The storefront bar is flat and full width: flush with the screen edge,
    // with its items kept above the system inset.
    expect(surface.bottom, closeTo(_height, 0.01), reason: 'flat bar');
    expect(surface.left, 0, reason: 'full width');
    for (final d in MonettaBottomDestination.values) {
      final item = tester.getRect(find.byKey(Key('bottom-nav-${d.name}')));
      expect(item.bottom, lessThanOrEqualTo(_height - _inset + 0.01));
    }
  } else {
    expect(surface.bottom, closeTo(_height, 0.01), reason: 'legacy docked bar');
  }
  for (final d in MonettaBottomDestination.values) {
    final rect = tester.getRect(find.byKey(Key('bottom-nav-${d.name}')));
    expect(
      rect.bottom,
      lessThanOrEqualTo(_height + 0.01),
      reason: '${d.name} ends inside the compact bar',
    );
    expect(rect.top, greaterThanOrEqualTo(surface.top - 0.01));
  }
}

void main() {
  for (final width in _widths) {
    for (final scale in _scales) {
      final label = 'width ${width.toInt()} at x$scale';

      testWidgets('RESP-01 catalog, $label', (tester) async {
        _view(tester, width);
        await tester.pumpWidget(
          _app(
            browseScreen([for (var i = 1; i <= 12; i++) _item(i)]),
            scale,
          ),
        );
        await tester.pump();

        _expectContained(tester);
        expect(find.byKey(const Key('catalog-filter-button')), findsOneWidget);
      });

      testWidgets('RESP-01 collection, $label', (tester) async {
        _view(tester, width);
        final store = CatalogStore(database: openTestDatabase());
        addTearDown(store.dispose);
        await store.loadFromAsset();
        await tester.pumpWidget(
          _app(
            StoreScope(
              notifier: store,
              child: const CollectionScreen(
                title: 'Bolsas',
                filter: CollectionFilter(category: 'bolsa'),
              ),
            ),
            scale,
          ),
        );
        await tester.pump();

        _expectContained(tester);
        expect(
          find.byKey(const Key('collection-filter-button')),
          findsOneWidget,
        );
      });

      testWidgets('RESP-01 legacy bottom bar alone, $label', (tester) async {
        _view(tester, width);
        await tester.pumpWidget(
          _app(
            Scaffold(
              body: const SizedBox.expand(),
              bottomNavigationBar: MonettaBottomNavigation(
                current: MonettaBottomDestination.catalog,
                bagCount: 12,
                onSelected: (_) {},
              ),
            ),
            scale,
          ),
        );
        await tester.pump();

        _expectContained(tester, floating: false);
      });
      testWidgets('RESP-01 floating bottom bar alone, $label', (tester) async {
        _view(tester, width);
        await tester.pumpWidget(
          _app(
            Scaffold(
              body: const SizedBox.expand(),
              bottomNavigationBar: MonettaFloatingBottomNavigation(
                current: MonettaBottomDestination.catalog,
                bagCount: 12,
                onSelected: (_) {},
              ),
            ),
            scale,
          ),
        );
        await tester.pump();
        _expectContained(tester);
      });
    }
  }
}
