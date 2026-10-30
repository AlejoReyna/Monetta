/// Web-parity pass: «Colecciones» opens on «Bolsas», every card offers «VER
/// COLECCIÓN», the cards rise in one after the other (unless animations are
/// off) and from the wide breakpoint they sit in one row.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/home/home_boutique_sections.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/main.dart';

// Handles of the three default collection cards, in order.
const List<String> _handles = ['guess', 'carteras-1', 'relojes'];
const List<String> _titles = ['Bolsas', 'Carteras', 'Relojes'];

Finder _card(String handle) =>
    find.byKey(ValueKey('home-collection-card-$handle'));

/// Opacity of the reveal wrapper around a card (the nearest `Opacity` above it).
double _opacityOf(WidgetTester tester, String handle) => tester
    .widget<Opacity>(
      find.ancestor(of: _card(handle), matching: find.byType(Opacity)).first,
    )
    .opacity;

Future<void> _pumpHome(
  WidgetTester tester, {
  required Size size,
  bool disableAnimations = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final store = CatalogStore(database: openTestDatabase());
  addTearDown(store.dispose);
  await store.loadFromAsset();
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: disableAnimations,
        ),
        child: child!,
      ),
      home: StoreScope(notifier: store, child: const HomeScreen()),
    ),
  );
  // The first frame only schedules the section's visibility check.
  await tester.pump();
}

void main() {
  testWidgets('opens centred on Bolsas, the first card, not the middle one', (
    tester,
  ) async {
    await _pumpHome(tester, size: const Size(390, 3000));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    final track = tester.widget<PageView>(
      find.byKey(const ValueKey('home-collections-track')),
    );
    expect(track.controller!.page, 0);
    expect(tester.getCenter(_card('guess')).dx, closeTo(390 / 2, 1));
    expect(
      find.descendant(of: _card('guess'), matching: find.text('Bolsas')),
      findsOneWidget,
    );
    // The next card peeks in from the right; the middle one is not centred.
    expect(
      tester.getCenter(_card('carteras-1')).dx,
      greaterThan(390 / 2 + 100),
    );
  });

  testWidgets('every card carries the «VER COLECCIÓN» pill and its title', (
    tester,
  ) async {
    await _pumpHome(tester, size: const Size(390, 3000));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    final track = find.byKey(const ValueKey('home-collections-track'));
    for (var i = 0; i < _handles.length; i++) {
      // The track builds the cards near the one in view; walk to this one.
      while (_card(_handles[i]).evaluate().isEmpty) {
        await tester.drag(track, const Offset(-200, 0));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
      }
      expect(
        find.descendant(
          of: _card(_handles[i]),
          matching: find.text('VER COLECCIÓN'),
        ),
        findsOneWidget,
        reason: _titles[i],
      );
      expect(
        find.descendant(
          of: _card(_handles[i]),
          matching: find.text(_titles[i]),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('the cards rise in one after the other', (tester) async {
    await _pumpHome(tester, size: const Size(900, 3000));
    // Nothing is shown before the section starts its reveal.
    expect(_opacityOf(tester, 'guess'), 0);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 150));
    final first = _opacityOf(tester, 'guess');
    final second = _opacityOf(tester, 'carteras-1');
    final third = _opacityOf(tester, 'relojes');
    expect(first, greaterThan(0));
    expect(first, lessThan(1));
    expect(second, lessThan(first), reason: 'the second card starts later');
    expect(third, lessThanOrEqualTo(second));

    // 420 ms for one card plus two 120 ms staggers.
    await tester.pump(const Duration(milliseconds: 700));
    for (final handle in _handles) {
      expect(_opacityOf(tester, handle), 1, reason: handle);
    }
  });

  testWidgets('on a phone the track reveals its first card the same way', (
    tester,
  ) async {
    await _pumpHome(tester, size: const Size(390, 3000));
    expect(_opacityOf(tester, 'guess'), 0);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 150));
    expect(_opacityOf(tester, 'guess'), inExclusiveRange(0, 1));

    await tester.pump(const Duration(milliseconds: 700));
    expect(_opacityOf(tester, 'guess'), 1);
  });

  testWidgets('with animations disabled the cards are fully visible at once', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      size: const Size(900, 3000),
      disableAnimations: true,
    );

    for (final handle in _handles) {
      expect(_opacityOf(tester, handle), 1, reason: handle);
    }
    // Not shifted down either: the rise offset is zero.
    final shift = tester.widget<Transform>(
      find.ancestor(of: _card('guess'), matching: find.byType(Transform)).first,
    );
    expect(shift.transform.getTranslation().y, closeTo(0, 0.001));
  });

  testWidgets('from the wide breakpoint the cards sit in one row', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      size: Size(kHomeWideBreakpoint, 3000),
      disableAnimations: true,
    );

    expect(find.byKey(const ValueKey('home-collections-row')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-collections-track')), findsNothing);
    final tops = [for (final h in _handles) tester.getTopLeft(_card(h)).dy];
    expect(tops[1], closeTo(tops[0], 0.5));
    expect(tops[2], closeTo(tops[0], 0.5));
    final lefts = [for (final h in _handles) tester.getTopLeft(_card(h)).dx];
    expect(lefts[1], greaterThan(lefts[0]));
    expect(lefts[2], greaterThan(lefts[1]));
    // All three fit inside the viewport, and the first is Bolsas.
    expect(tester.getTopRight(_card('relojes')).dx, lessThanOrEqualTo(768));
  });

  testWidgets('just under the wide breakpoint it is still the swipe track', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      size: Size(kHomeWideBreakpoint - 1, 3000),
      disableAnimations: true,
    );

    expect(
      find.byKey(const ValueKey('home-collections-track')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('home-collections-row')), findsNothing);
  });
}
