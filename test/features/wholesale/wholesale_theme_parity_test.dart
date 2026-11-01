import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/boutique/client_guide_sections.dart';
import 'package:monetta_app/features/boutique/guide_art.dart';
import 'package:monetta_app/features/wholesale/wholesale_screen.dart';
import 'package:monetta_app/main.dart';

import '../../support/client_guide_capture.dart';

/// Mirrors `clamp(min, width / divisor, max)` from the theme's
/// `monetta-guia.css`.
double _clamp(double width, double divisor, double min, double max) =>
    math.min(max, math.max(min, width / divisor));

Future<void> _pumpWholesale(WidgetTester tester, Size size) async {
  final db = openTestDatabase();
  final store = CatalogStore(database: db);
  addTearDown(() async {
    store.dispose();
    await db.close();
  });
  await pumpClientGuide(
    tester,
    StoreScope(
      notifier: store,
      child: WholesaleScreen(openUri: (_) async => true),
    ),
    size: size,
  );
}

/// Position of [finder] inside the scrolled content, independent of how far
/// the list is currently scrolled.
double _contentY(WidgetTester tester, Finder finder, ScrollableState scroll) =>
    tester.getTopLeft(finder.first).dy + scroll.position.pixels;

void main() {
  for (final (width, expected) in <(double, double)>[
    (390, _clamp(390, 2.667, 120, 204)),
    (440, _clamp(440, 2.667, 120, 204)),
    (1180, _clamp(1180, 4, 168, 336)),
  ]) {
    testWidgets(
        'WHOLESALE-HERO the first banner follows the theme clamp at ${width.toInt()} px wide',
        (tester) async {
      await _pumpWholesale(tester, Size(width, 1000));

      final hero = find.byType(GuideHero).first;
      expect(hero, findsOneWidget);
      expect(tester.getSize(hero).height, closeTo(expected, 1));
    });
  }

  testWidgets(
      'WHOLESALE-STEPS each step is a numbered card with the theme icon',
      (tester) async {
    await _pumpWholesale(tester, const Size(390, 1000));
    final scrollFinder = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('¿Cómo comprar?'),
      200,
      scrollable: scrollFinder,
    );
    await tester.pumpAndSettle();

    const icons = <IconData>[
      Icons.shopping_bag_outlined,
      Icons.add,
      Icons.account_balance_wallet_outlined,
    ];
    const titles = <String>[
      'Elige tus productos',
      'Agrega mínimo 3 piezas',
      'Liquida o aparta',
    ];
    final badgeLefts = <double>[];
    for (var n = 1; n <= 3; n++) {
      final badge = find.byKey(Key('wholesale-step-n-$n'));
      expect(badge, findsOneWidget, reason: 'step $n number badge');
      expect(
        find.descendant(of: badge, matching: find.text('$n')),
        findsOneWidget,
        reason: 'step $n shows its number',
      );
      final badgeBox = tester.getRect(badge);
      badgeLefts.add(badgeBox.left);

      // The icon of this step is the closest one below the number.
      final iconRects = <Rect>[
        for (final element in find.byIcon(icons[n - 1]).evaluate())
          tester.getRect(find.byElementPredicate((e) => e == element)),
      ].where((rect) => rect.top >= badgeBox.bottom - 1).toList()
        ..sort((a, b) => a.top.compareTo(b.top));
      expect(iconRects, isNotEmpty, reason: 'icon of step $n below its number');
      final iconRect = iconRects.first;
      expect(
        (iconRect.center.dx - badgeBox.center.dx).abs(),
        lessThan(2),
        reason: 'step $n: number and icon share a centre line',
      );

      final title = find.text(titles[n - 1]);
      expect(title, findsOneWidget);
      expect(tester.getTopLeft(title).dy, greaterThan(iconRect.top));
      expect(badgeBox.top, lessThan(iconRect.top));
      expect(badgeBox.top, lessThan(tester.getTopLeft(title).dy));
    }
    // Steps keep their order left to right (or top to bottom in one column).
    expect(badgeLefts[1], greaterThanOrEqualTo(badgeLefts[0]));
  });

  testWidgets(
      'WHOLESALE-ORDER sections follow the theme: steps, bags, perfumes, services, doubts, note, rail',
      (tester) async {
    await _pumpWholesale(tester, const Size(390, 1000));
    final scrollFinder = find.byType(Scrollable).first;
    final scroll = tester.state<ScrollableState>(scrollFinder);

    final anchors = <String, Finder>{
      '¿Cómo comprar?': find.text('¿Cómo comprar?'),
      'BOLSOS Y CARTERAS': find.text('BOLSOS Y CARTERAS'),
      'PERFUMES': find.text('PERFUMES'),
      'servicios': find.byType(ClientGuideServices),
      '¿Tienes dudas?': find.byKey(const ValueKey('wholesale-quote-bottom')),
      'nota': find.text(
        'Precios del catálogo de menudeo; cotización de mayoreo pendiente.',
      ),
      'Productos que te pueden interesar':
          find.textContaining('Productos que te pueden interesar'),
    };

    final positions = <String, double>{};
    for (final entry in anchors.entries) {
      await tester.scrollUntilVisible(
        entry.value.first,
        300,
        scrollable: scrollFinder,
      );
      await tester.pump();
      positions[entry.key] = _contentY(tester, entry.value, scroll);
    }

    var previous = double.negativeInfinity;
    String? previousName;
    for (final entry in positions.entries) {
      expect(
        entry.value,
        greaterThan(previous),
        reason: '${entry.key} must come after $previousName',
      );
      previous = entry.value;
      previousName = entry.key;
    }
  });

  // Wide screens (theme `@media (min-width: 768px)`). A tall surface keeps the
  // whole page built so every rect can be measured without scrolling.
  // The banner is a GuideHero (theme) or, until it is migrated, the editorial
  // overlay that wraps the same photo, title and button.
  Finder heroOf(String category) => find
      .ancestor(
        of: find.byKey(ValueKey('wholesale-catalog-$category')),
        matching: find.byWidgetPredicate(
          (widget) => widget is GuideHero || widget is ClientGuideEditorial,
        ),
      )
      .first;

  for (final width in <double>[1180, 951]) {
    testWidgets(
        'WHOLESALE-WIDE-BANNERS the bag and perfume banners sit side by side at ${width.toInt()} px wide',
        (tester) async {
      await _pumpWholesale(tester, Size(width, 6000));

      final bags = heroOf('bolsa');
      final perfumes = heroOf('perfume');
      expect(bags, findsOneWidget);
      expect(perfumes, findsOneWidget);
      final bagsRect = tester.getRect(bags);
      final perfumesRect = tester.getRect(perfumes);
      final expectedHeight = _clamp(width, 3.2, 260, 420);

      expect(perfumesRect.top, closeTo(bagsRect.top, 1), reason: 'same row');
      expect(bagsRect.left, lessThan(perfumesRect.left));
      expect(bagsRect.width, closeTo(width / 2, 2));
      expect(perfumesRect.width, closeTo(width / 2, 2));
      expect(bagsRect.height, closeTo(expectedHeight, 1));
      expect(perfumesRect.height, closeTo(expectedHeight, 1));
    });
  }

  testWidgets('WHOLESALE-WIDE-BANNERS the banners stay stacked at 390 px wide',
      (tester) async {
    await _pumpWholesale(tester, const Size(390, 6000));

    final bagsRect = tester.getRect(heroOf('bolsa'));
    final perfumesRect = tester.getRect(heroOf('perfume'));
    expect(perfumesRect.top, greaterThan(bagsRect.bottom - 1));
  });

  testWidgets(
      'WHOLESALE-WIDE-STEPS the steps grid is capped at 880 px wide from 768 px',
      (tester) async {
    await _pumpWholesale(tester, const Size(1180, 6000));

    Rect card(int n) => tester.getRect(
          find
              .ancestor(
                of: find.byKey(Key('wholesale-step-n-$n')),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
    final grid = card(1).expandToInclude(card(2)).expandToInclude(card(3));
    expect(card(3).right - card(1).left, lessThanOrEqualTo(880));
    expect(grid.width, lessThanOrEqualTo(880));
    // The three cards still share one row.
    expect(card(2).top, closeTo(card(1).top, 1));
    expect(card(3).top, closeTo(card(1).top, 1));
  });

  testWidgets(
      'WHOLESALE-WIDE-TYPE step titles are 18 px and bodies 14 px from 768 px',
      (tester) async {
    Future<(double, double)> sizes(double width) async {
      await _pumpWholesale(tester, Size(width, 6000));
      double sizeOf(String text) =>
          tester.widget<Text>(find.text(text)).style!.fontSize!;
      return (
        sizeOf('Elige tus productos'),
        sizeOf('Bolsas, carteras y perfumes.')
      );
    }

    final wide = await sizes(1180);
    expect(wide.$1, 18);
    expect(wide.$2, 14);

    final narrow = await sizes(390);
    expect(narrow.$1, lessThan(wide.$1));
    expect(narrow.$2, lessThan(wide.$2));
  });
}
