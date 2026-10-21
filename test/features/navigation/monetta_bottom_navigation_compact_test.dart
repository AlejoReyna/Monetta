import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/domain/catalog_item.dart';
import 'package:monetta_app/features/catalog/catalog_browse_screen.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/catalog/product_card.dart';
import 'package:monetta_app/features/navigation/monetta_bottom_navigation.dart';
import 'package:monetta_app/main.dart';

// Contract of the compact bottom bar (FICHA-T1, BRIEF 2.1): 56 px of
// interactive content plus the real bottom inset, applied once, with the
// surface painted under the inset. Destinations stay >= 48x48 and the bar
// grows (never clips) with large text.
//
// Text note: FlutterTest renders every glyph one em wide, so the bar's
// fit-to-column logic is active even at scale 1.0 on phone-width columns.

const _destinations = MonettaBottomDestination.values;
const _viewHeight = 844.0;

final _surface = find.byKey(const Key('bottom-nav-surface'));

Finder _dest(MonettaBottomDestination d) =>
    find.byKey(Key('bottom-nav-${d.name}'));
Finder _icon(MonettaBottomDestination d) =>
    find.byKey(Key('bottom-nav-${d.name}-icon'));
Finder _label(MonettaBottomDestination d) =>
    find.byKey(Key('bottom-nav-${d.name}-label'));

/// Fixed phone-sized view; 1 logical px == 1 physical px.
void _view(
  WidgetTester tester, {
  double width = 390,
  double height = _viewHeight,
  double inset = 0,
}) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, height);
  tester.view.padding = FakeViewPadding(bottom: inset);
  tester.view.viewPadding = FakeViewPadding(bottom: inset);
  addTearDown(tester.view.reset);
}

Widget _withScale(double scale, Widget child) => MaterialApp(
      theme: buildLightTheme(),
      builder: (context, home) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
        ),
        child: home!,
      ),
      home: child,
    );

Future<void> _pumpBar(
  WidgetTester tester, {
  double width = 390,
  double inset = 0,
  double scale = 1.0,
  int bagCount = 0,
  MonettaBottomDestination current = MonettaBottomDestination.home,
  ValueChanged<MonettaBottomDestination>? onSelected,
}) async {
  _view(tester, width: width, inset: inset);
  await tester.pumpWidget(
    _withScale(
      scale,
      Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: MonettaBottomNavigation(
          current: current,
          bagCount: bagCount,
          onSelected: onSelected ?? (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
}

CatalogItem _item(int i) => CatalogItem(
      sourceScopedId: 'monetta:$i',
      source: CatalogSourceType.monettaShopify,
      merchant: 'Monetta',
      title: 'Monetta Item $i',
      brand: 'Guess',
      category: null,
      imageUrl: null,
      price: Money(amount: 1000.0 + i, currency: Currency.mxn),
      availability: CatalogAvailability.inStock,
      detailUrl: 'https://monetta.mx/products/item-$i',
      marketRestriction: MarketRestriction.mexico,
      lastObservedAt: DateTime.utc(2026, 8, 10),
      purchaseMode: PurchaseMode.monettaCheckout,
      shopifyProductId: '$i',
    );

Future<CatalogStore> _loadedStore() async {
  final store = CatalogStore(database: openTestDatabase());
  await store.loadFromAsset();
  return store;
}

/// Scrolls the page's vertical scrollable to its very end. The grids are
/// lazy, so the extent is re-read until it stops moving.
Future<void> _scrollToEnd(WidgetTester tester) async {
  final scrollable = find
      .byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      )
      .first;
  for (var i = 0; i < 12; i++) {
    final position = tester.state<ScrollableState>(scrollable).position;
    final before = position.maxScrollExtent;
    position.jumpTo(before);
    await tester.pumpAndSettle();
    if (tester.state<ScrollableState>(scrollable).position.maxScrollExtent ==
        before) {
      break;
    }
  }
  final position = tester.state<ScrollableState>(scrollable).position;
  expect(position.pixels, position.maxScrollExtent);
}

/// The lowest bottom edge among everything [finder] matches.
double _lowestBottom(WidgetTester tester, Finder finder) {
  var lowest = double.negativeInfinity;
  for (var i = 0; i < finder.evaluate().length; i++) {
    final bottom = tester.getRect(finder.at(i)).bottom;
    if (bottom > lowest) lowest = bottom;
  }
  return lowest;
}

void main() {
  testWidgets('NAV-01 at scale 1.0 the surface and every destination are 56 px',
      (tester) async {
    await _pumpBar(tester);

    expect(tester.takeException(), isNull);
    expect(tester.getSize(_surface).height, 56, reason: 'bar surface');
    for (final d in _destinations) {
      expect(tester.getSize(_dest(d)).height, 56, reason: '${d.name} height');
    }
  });

  group('NAV-02 the safe area is added once and painted under', () {
    for (final (inset, expectedHeight) in [
      (0.0, 56.0),
      (20.0, 76.0),
      (34.0, 90.0),
    ]) {
      testWidgets('NAV-02 inset ${inset.toInt()} -> ${expectedHeight.toInt()}',
          (tester) async {
        await _pumpBar(tester, inset: inset);

        final surface = tester.getRect(_surface);
        expect(surface.height, expectedHeight, reason: '56 + inset, once');
        expect(surface.bottom, _viewHeight, reason: 'docked to the bottom');
        expect(surface.left, 0);
        expect(surface.right, 390);

        for (final d in _destinations) {
          final rect = tester.getRect(_dest(d));
          expect(
            rect.bottom,
            closeTo(_viewHeight - inset, 0.01),
            reason: '${d.name} stops above the inset',
          );
          expect(rect.height, 56, reason: '${d.name} keeps 56 of content');
        }

        // The surface color is painted by the surface itself, so it also
        // fills the area under the inset.
        final decorated = tester.widget<DecoratedBox>(_surface);
        final colors =
            tester.element(find.byType(MonettaBottomNavigation)).monettaColors;
        expect(
          (decorated.decoration as BoxDecoration).color,
          colors.navigationSurface,
        );
        expect(tester.getRect(_surface).bottom, _viewHeight);
      });
    }
  });

  group('NAV-03 destinations keep working (vigente)', () {
    testWidgets('NAV-03 tapping each destination reports that destination',
        (tester) async {
      final taps = <MonettaBottomDestination>[];
      await _pumpBar(tester, onSelected: taps.add);

      for (final d in _destinations) {
        await tester.tap(_dest(d));
        await tester.pump();
      }
      expect(taps, _destinations);
    });

    testWidgets('NAV-03 the cart badge reads 3, caps at 9+ and hides at 0',
        (tester) async {
      final badge = find.byKey(const Key('bottom-nav-bag-badge'));

      await _pumpBar(tester, bagCount: 3);
      expect(
        find.descendant(of: badge, matching: find.text('3')),
        findsOneWidget,
      );

      await _pumpBar(tester, bagCount: 12);
      expect(
        find.descendant(of: badge, matching: find.text('9+')),
        findsOneWidget,
      );

      await _pumpBar(tester);
      expect(badge, findsNothing);
    });

    testWidgets('NAV-03 semantics: item count, selected state, label weight',
        (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await _pumpBar(
          tester,
          bagCount: 3,
          current: MonettaBottomDestination.catalog,
        );

        final cart = find.semantics.byLabel('Carrito, 3 artículos');
        expect(cart, findsOneWidget);
        expect(
          cart.evaluate().single,
          isSemantics(
            label: 'Carrito, 3 artículos',
            isButton: true,
            hasTapAction: true,
            isSelected: false,
          ),
        );

        expect(
          find.semantics.byLabel('Categorías').evaluate().single,
          isSemantics(
            label: 'Categorías',
            isButton: true,
            hasTapAction: true,
            isSelected: true,
          ),
        );
        for (final other in ['Inicio', 'Cuenta']) {
          expect(
            find.semantics.byLabel(other).evaluate().single,
            isSemantics(
              label: other,
              isButton: true,
              hasTapAction: true,
              isSelected: false,
            ),
            reason: other,
          );
        }

        for (final d in _destinations) {
          final style = tester.widget<Text>(_label(d)).style!;
          expect(
            style.fontWeight,
            d == MonettaBottomDestination.catalog
                ? FontWeight.w600
                : FontWeight.w400,
            reason: '${d.name} label weight',
          );
        }
      } finally {
        handle.dispose();
      }
    });
  });

  group('NAV-01b destinations are at least 48x48 (guard, passes today)', () {
    for (final width in [320.0, 390.0, 430.0, 768.0]) {
      testWidgets('NAV-01b width ${width.toInt()}', (tester) async {
        await _pumpBar(tester, width: width, inset: 34);

        expect(tester.takeException(), isNull);
        for (final d in _destinations) {
          final size = tester.getSize(_dest(d));
          expect(size.width, greaterThanOrEqualTo(48), reason: d.name);
          expect(size.height, greaterThanOrEqualTo(48), reason: d.name);
        }
      });
    }

    testWidgets('NAV-01b at 768 the content stays capped at 480',
        (tester) async {
      await _pumpBar(tester, width: 768, inset: 34);

      final first = tester.getRect(_dest(MonettaBottomDestination.home));
      final last = tester.getRect(_dest(MonettaBottomDestination.account));
      expect(last.right - first.left, lessThanOrEqualTo(480 + 0.01));
    });
  });

  group('NAV-01c glyph and label metrics', () {
    testWidgets('NAV-01c icon is 24x24', (tester) async {
      await _pumpBar(tester);

      for (final d in _destinations) {
        expect(tester.getSize(_icon(d)), const Size(24, 24), reason: d.name);
      }
    });

    testWidgets('NAV-01c label base size is 12-13 (guard, passes today)',
        (tester) async {
      await _pumpBar(tester);

      for (final d in _destinations) {
        final size = tester.widget<Text>(_label(d)).style!.fontSize!;
        expect(size, inInclusiveRange(12, 13), reason: d.name);
      }
    });

    testWidgets('NAV-01c icon-to-label gap is 2-4 px rect to rect',
        (tester) async {
      await _pumpBar(tester);

      for (final d in _destinations) {
        final gap =
            tester.getRect(_label(d)).top - tester.getRect(_icon(d)).bottom;
        expect(gap, inInclusiveRange(2, 4), reason: '${d.name} gap');
      }
    });
  });

  group('NAV-05 large text never clips; the content drives the height', () {
    for (final width in [320.0, 390.0]) {
      testWidgets(
          'NAV-05 texto grande: contenido sin recortar, altura dirigida por el '
          'contenido (ancho ${width.toInt()})', (tester) async {
        const inset = 34.0;

        // Control: at scale 1.0 the bar is exactly 56 + inset.
        await _pumpBar(tester, width: width, inset: inset);
        expect(tester.getSize(_surface).height, 56 + inset, reason: 'x1.0');

        await _pumpBar(tester, width: width, inset: inset, scale: 2.0);
        expect(tester.takeException(), isNull);

        final surface = tester.getRect(_surface);
        expect(
          surface.height,
          greaterThanOrEqualTo(56 + inset),
          reason: 'never below the 56 px floor plus the inset',
        );
        expect(surface.bottom, _viewHeight);

        // The height is decided by the real content: the bar is at least as
        // tall as the tallest icon + gap + label stack, measured from rects.
        var tallestStack = 0.0;
        for (final d in _destinations) {
          final icon = tester.getRect(_icon(d));
          final label = tester.getRect(_label(d));
          final stack = icon.height + (label.top - icon.bottom) + label.height;
          if (stack > tallestStack) tallestStack = stack;
        }
        expect(
          surface.height,
          greaterThanOrEqualTo(inset + tallestStack),
          reason: 'the content ($tallestStack) must fit in the bar',
        );

        for (final d in _destinations) {
          final dest = tester.getRect(_dest(d));
          final label = tester.getRect(_label(d));
          expect(dest.height, greaterThanOrEqualTo(48), reason: d.name);
          expect(
            label.left,
            greaterThanOrEqualTo(dest.left - 0.5),
            reason: '${d.name} label left',
          );
          expect(
            label.right,
            lessThanOrEqualTo(dest.right + 0.5),
            reason: '${d.name} label right',
          );
          expect(
            label.top,
            greaterThanOrEqualTo(dest.top - 0.5),
            reason: '${d.name} label top',
          );
          expect(
            label.bottom,
            lessThanOrEqualTo(dest.bottom + 0.5),
            reason: '${d.name} label bottom',
          );
          expect(dest.bottom, lessThanOrEqualTo(_viewHeight - inset + 0.01));

          final rich = find.descendant(
            of: _label(d),
            matching: find.byType(RichText),
          );
          final paragraph = tester.renderObject<RenderParagraph>(rich.first);
          expect(
            paragraph.didExceedMaxLines,
            isFalse,
            reason: '${d.name} label is clipped',
          );
        }
      });
    }
  });

  group('NAV-04 (vigente) the last row clears the bar', () {
    testWidgets('NAV-04 (vigente) catalog: last tile ends above the bar',
        (tester) async {
      _view(tester, inset: 34);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: CatalogBrowseScreen(
            items: [for (var i = 1; i <= 30; i++) _item(i)],
          ),
        ),
      );
      await tester.pump();
      await _scrollToEnd(tester);

      final barTop = tester.getRect(_surface).top;
      final tiles = find.byType(MonettaProductTile);
      expect(tiles, findsWidgets);
      expect(
        _lowestBottom(tester, tiles),
        lessThanOrEqualTo(barTop + 0.01),
      );
      expect(
        tester.getRect(find.text('Monetta Item 30')).bottom,
        lessThanOrEqualTo(barTop + 0.01),
        reason: 'the last product name is reachable above the bar',
      );
    });

    testWidgets('NAV-04 (vigente) collection: last card ends above the bar',
        (tester) async {
      _view(tester, inset: 34);
      final store = await _loadedStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: StoreScope(
            notifier: store,
            child: const CollectionScreen(
              title: 'Bolsas',
              filter: CollectionFilter(category: 'bolsa'),
            ),
          ),
        ),
      );
      await tester.pump();
      await _scrollToEnd(tester);

      final barTop = tester.getRect(_surface).top;
      final cards = find.byType(ProductCard);
      expect(cards, findsWidgets);
      expect(
        _lowestBottom(tester, cards),
        lessThanOrEqualTo(barTop + 0.01),
      );
    });

    testWidgets('NAV-04b the catalog bar measures 90 with an inset of 34',
        (tester) async {
      _view(tester, inset: 34);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: CatalogBrowseScreen(items: [_item(1), _item(2), _item(3)]),
        ),
      );
      await tester.pump();

      final surface = tester.getRect(_surface);
      expect(surface.height, 90);
      expect(surface.bottom, _viewHeight);
    });

    testWidgets('NAV-04b the collection bar measures 90 with an inset of 34',
        (tester) async {
      _view(tester, inset: 34);
      final store = await _loadedStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: StoreScope(
            notifier: store,
            child: const CollectionScreen(
              title: 'Bolsas',
              filter: CollectionFilter(category: 'bolsa'),
            ),
          ),
        ),
      );
      await tester.pump();

      final surface = tester.getRect(_surface);
      expect(surface.height, 90);
      expect(surface.bottom, _viewHeight);
    });
  });
}
