import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/monetta_tokens.g.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/features/navigation/monetta_bottom_navigation.dart';
import '../../support/bundled_fonts.dart';

// Target-state tests for the docked, flat bottom navigation (NAV-02..NAV-11,
// the Home clearance test lives in home_bottom_clearance_test.dart). NAV-01 is
// the characterization of the destinations that must keep working.
//
// Text note: FlutterTest renders every glyph one em wide, so "Catálogo" at
// 13 px is 104 px wide. On phone-width columns the fit-to-column logic is
// therefore already active at text scale 1.0.

const _destinations = MonettaBottomDestination.values;
const _labels = {
  MonettaBottomDestination.home: 'Inicio',
  MonettaBottomDestination.catalog: 'Categorías',
  MonettaBottomDestination.bag: 'Carrito',
  MonettaBottomDestination.account: 'Cuenta',
};

const _lightActive = MonettaTokens.navigationActive;
const _lightInactive = MonettaTokens.navigationInactive;
const _darkActive = Color(0xFFF5F2EC);
const _darkInactive = Color(0xFF8E8A85);

void main() {
  testWidgets(
      'NAV-01 premium navigation keeps all four destinations actionable',
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
    expect(find.text('Carrito'), findsOneWidget);
    expect(find.text('Bolsa'), findsNothing);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('bottom-nav-catalog')));
    expect(selected, MonettaBottomDestination.catalog);
  });

  testWidgets('NAV-02 there is no selection capsule', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_Harness(current: MonettaBottomDestination.home));
    await tester.pump();

    expect(
      find.byKey(const Key('bottom-nav-selection-indicator')),
      findsNothing,
    );
    expect(find.byKey(const Key('bottom-nav-selection-fill')), findsNothing);

    final bar = find.byType(MonettaBottomNavigation);
    expect(find.descendant(of: bar, matching: find.byType(Hero)), findsNothing);
    expect(
      find.descendant(of: bar, matching: find.byType(AnimatedPositioned)),
      findsNothing,
    );

    // Moving the selection must not bring a capsule back either.
    await tester.tap(find.byKey(const Key('bottom-nav-catalog')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(find.byKey(const Key('bottom-nav-selection-fill')), findsNothing);
    expect(find.descendant(of: bar, matching: find.byType(Hero)), findsNothing);
  });

  group('NAV-03 selection is color only, identical on icon and label', () {
    for (final dark in [false, true]) {
      final active = dark ? _darkActive : _lightActive;
      final inactive = dark ? _darkInactive : _lightInactive;
      testWidgets('NAV-03 colors per state (${dark ? 'dark' : 'light'} theme)',
          (tester) async {
        _phone(tester);
        for (final current in _destinations) {
          await tester.pumpWidget(
            _Harness(current: current, theme: _theme(dark: dark)),
          );
          await tester.pumpAndSettle();

          for (final d in _destinations) {
            final expected = d == current ? active : inactive;
            expect(
              _iconColor(tester, d),
              expected,
              reason: '${d.name} icon, current=${current.name}',
            );
            expect(
              _labelStyle(tester, d).color,
              expected,
              reason: '${d.name} label, current=${current.name}',
            );
          }
        }
      });

      testWidgets(
          'NAV-03 contrast of the rendered colors (${dark ? 'dark' : 'light'})',
          (tester) async {
        _phone(tester);
        await tester.pumpWidget(
          _Harness(
            current: MonettaBottomDestination.home,
            theme: _theme(dark: dark),
          ),
        );
        await tester.pumpAndSettle();

        final surface = _surfaceDecoration(tester).color!;
        final renderedActive =
            _iconColor(tester, MonettaBottomDestination.home);
        final renderedInactive =
            _iconColor(tester, MonettaBottomDestination.catalog);

        expect(
          _contrast(renderedInactive, surface),
          greaterThanOrEqualTo(4.5),
          reason: 'inactive on the surface',
        );
        expect(
          _contrast(renderedActive, renderedInactive),
          greaterThanOrEqualTo(3.0),
          reason: 'active against inactive',
        );
      });
    }

    testWidgets(
        'NAV-03 label typography: 12-13 px, 1.25 line height, w600/w400',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_Harness(current: MonettaBottomDestination.bag));
      await tester.pumpAndSettle();

      for (final d in _destinations) {
        final style = _labelStyle(tester, d);
        expect(
          style.fontWeight,
          d == MonettaBottomDestination.bag ? FontWeight.w600 : FontWeight.w400,
          reason: '${d.name} weight',
        );
        expect(
          style.fontSize,
          inInclusiveRange(12, 13),
          reason: '${d.name} size',
        );
        expect(style.height, 1.25, reason: '${d.name} line height');
      }
    });
  });

  group('NAV-04 animation is color only and lasts 180 ms', () {
    testWidgets('NAV-04 colors cross-fade, positions never move',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_Harness(current: MonettaBottomDestination.home));
      await tester.pumpAndSettle();

      final before = _anchors(tester);
      for (final d in _destinations) {
        expect(tester.getSize(_icon(d)), const Size(24, 24), reason: d.name);
      }
      expect(_iconColor(tester, MonettaBottomDestination.home), _lightActive);
      expect(
        _iconColor(tester, MonettaBottomDestination.catalog),
        _lightInactive,
      );

      await tester.tap(find.byKey(const Key('bottom-nav-catalog')));
      await tester.pump();

      // First frame: nothing has moved on yet.
      _expectPair(tester, MonettaBottomDestination.home, _lightActive);
      _expectPair(tester, MonettaBottomDestination.catalog, _lightInactive);
      _expectAnchors(tester, before, 'first frame');

      await tester.pump(const Duration(milliseconds: 90));
      for (final d in [
        MonettaBottomDestination.home,
        MonettaBottomDestination.catalog,
      ]) {
        final icon = _iconColor(tester, d);
        final label = _labelStyle(tester, d).color!;
        expect(icon, label, reason: '${d.name} icon and label share a color');
        _expectBetween(icon, _lightInactive, _lightActive, d.name);
      }
      for (final d in _destinations) {
        expect(tester.getSize(_icon(d)), const Size(24, 24), reason: d.name);
      }
      _expectAnchors(tester, before, 'at 90 ms');

      await tester.pump(const Duration(milliseconds: 200));
      _expectPair(tester, MonettaBottomDestination.home, _lightInactive);
      _expectPair(tester, MonettaBottomDestination.catalog, _lightActive);
      _expectAnchors(tester, before, 'after settling');
      for (final d in _destinations) {
        expect(tester.getSize(_icon(d)), const Size(24, 24), reason: d.name);
      }
    });

    for (final accessible in [false, true]) {
      testWidgets(
          'NAV-04 ${accessible ? 'accessibleNavigation' : 'disableAnimations'} '
          'snaps to the final colors in one frame', (tester) async {
        _phone(tester);
        await tester.pumpWidget(
          _Harness(
            current: MonettaBottomDestination.home,
            disableAnimations: !accessible,
            accessibleNavigation: accessible,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('bottom-nav-catalog')));
        await tester.pump();

        _expectPair(tester, MonettaBottomDestination.home, _lightInactive);
        _expectPair(tester, MonettaBottomDestination.catalog, _lightActive);
      });
    }
  });

  group('NAV-05 four equal columns', () {
    // width -> (content left edge, column width)
    const cases = [
      (390.0, 10.0, 92.5),
      (320.0, 10.0, 75.0),
      (800.0, 160.0, 120.0),
    ];
    for (final (width, left, column) in cases) {
      testWidgets('NAV-05 width ${width.toInt()}: columns of $column',
          (tester) async {
        _phone(tester, width: width);
        await tester.pumpWidget(
          _Harness(current: MonettaBottomDestination.home),
        );
        await tester.pump();

        var previousX = double.negativeInfinity;
        for (final d in _destinations) {
          final i = d.index;
          final expectedX = left + column * (i + 0.5);
          final icon = tester.getRect(_icon(d));
          final label = tester.getRect(_label(d));
          final dest = tester.getRect(_dest(d));

          expect(
            icon.center.dx,
            closeTo(expectedX, 0.01),
            reason: '${d.name} icon center',
          );
          expect(
            label.center.dx,
            closeTo(expectedX, 0.01),
            reason: '${d.name} label center',
          );
          expect(
            dest.width,
            closeTo(column, 0.01),
            reason: '${d.name} column width',
          );
          expect(
            icon.center.dx,
            greaterThan(previousX),
            reason: 'left-to-right order',
          );
          previousX = icon.center.dx;
        }
      });
    }

    testWidgets('NAV-05 order is Home, Catálogo, Carrito, Cuenta',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_Harness(current: MonettaBottomDestination.home));
      await tester.pump();

      final byX = [..._destinations]..sort(
          (a, b) => tester
              .getCenter(_icon(a))
              .dx
              .compareTo(tester.getCenter(_icon(b)).dx),
        );
      expect(byX, [
        MonettaBottomDestination.home,
        MonettaBottomDestination.catalog,
        MonettaBottomDestination.bag,
        MonettaBottomDestination.account,
      ]);
      expect(
        [for (final d in byX) _labelText(tester, d)],
        ['Inicio', 'Categorías', 'Carrito', 'Cuenta'],
      );
    });
  });

  group('NAV-06 measures and surface', () {
    testWidgets('NAV-06 docked edge to edge, 56 px tall without safe area',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_Harness(current: MonettaBottomDestination.home));
      await tester.pump();

      final surface = tester.getRect(_surface);
      expect(surface.left, 0);
      expect(surface.right, 390);
      expect(surface.bottom, 844);
      expect(surface.height, 56);
    });

    testWidgets('NAV-06 safe area is honored in full: 34 -> 90 px',
        (tester) async {
      _phone(tester, bottomInset: 34);
      await tester.pumpWidget(_Harness(current: MonettaBottomDestination.home));
      await tester.pump();

      final surface = tester.getRect(_surface);
      expect(surface.left, 0);
      expect(surface.right, 390);
      expect(surface.bottom, 844);
      expect(surface.height, 90);
      for (final d in _destinations) {
        final rect = tester.getRect(_dest(d));
        expect(
          rect.bottom,
          lessThanOrEqualTo(844 - 34 + 0.01),
          reason: '${d.name} sits above the home indicator',
        );
        expect(rect.top, greaterThanOrEqualTo(surface.top - 0.01));
      }
    });

    testWidgets('NAV-06 destinations are at least 48x48', (tester) async {
      _phone(tester, bottomInset: 34);
      await tester.pumpWidget(_Harness(current: MonettaBottomDestination.home));
      await tester.pump();

      for (final d in _destinations) {
        final size = tester.getSize(_dest(d));
        expect(size.width, greaterThanOrEqualTo(48), reason: d.name);
        expect(size.height, greaterThanOrEqualTo(48), reason: d.name);
      }
    });

    testWidgets('NAV-06 icon box is 24x24 and 2-4 px above the label',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_Harness(current: MonettaBottomDestination.home));
      await tester.pump();

      for (final d in _destinations) {
        final icon = tester.getRect(_icon(d));
        final label = tester.getRect(_label(d));
        expect(icon.size, const Size(24, 24), reason: '${d.name} icon box');
        expect(
          label.top - icon.bottom,
          inInclusiveRange(2, 4),
          reason: '${d.name} icon-to-label gap',
        );
      }
    });

    for (final dark in [false, true]) {
      testWidgets(
          'NAV-06 flat surface: light grey/dark, no shadow, hairline top border '
          '(${dark ? 'dark' : 'light'})', (tester) async {
        _phone(tester);
        await tester.pumpWidget(
          _Harness(
            current: MonettaBottomDestination.home,
            theme: _theme(dark: dark),
          ),
        );
        await tester.pump();

        final decoration = _surfaceDecoration(tester);
        expect(
          decoration.color,
          dark ? MonettaColors.dark.surface : MonettaTokens.bar,
        );
        expect(decoration.boxShadow ?? const <BoxShadow>[], isEmpty);
        final border = decoration.border;
        if (border != null) {
          expect((border as Border).top.width, lessThanOrEqualTo(0.5));
        }
      });
    }
  });

  group('NAV-07 cart badge', () {
    testWidgets('NAV-07 shows the count, caps at 9+, hides at zero',
        (tester) async {
      _phone(tester);
      final badge = find.byKey(const Key('bottom-nav-bag-badge'));

      await tester.pumpWidget(
        _Harness(
          current: MonettaBottomDestination.home,
          bagCount: 2,
        ),
      );
      await tester.pump();
      expect(badge, findsOneWidget);
      expect(
        find.descendant(of: badge, matching: find.text('2')),
        findsOneWidget,
      );

      await tester.pumpWidget(
        _Harness(
          current: MonettaBottomDestination.home,
          bagCount: 12,
        ),
      );
      await tester.pump();
      expect(
        find.descendant(of: badge, matching: find.text('9+')),
        findsOneWidget,
      );
      expect(find.text('12'), findsNothing);

      await tester.pumpWidget(
        _Harness(
          current: MonettaBottomDestination.home,
          bagCount: 0,
        ),
      );
      await tester.pump();
      expect(badge, findsNothing);
    });

    testWidgets('NAV-07 hangs off the top-right corner of the cart icon',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _Harness(
          current: MonettaBottomDestination.home,
          bagCount: 12,
        ),
      );
      await tester.pump();

      final icon = tester.getRect(_icon(MonettaBottomDestination.bag));
      final badge =
          tester.getRect(find.byKey(const Key('bottom-nav-bag-badge')));
      final dest = tester.getRect(_dest(MonettaBottomDestination.bag));

      expect(badge.center.dx, greaterThan(icon.center.dx));
      expect(badge.center.dy, lessThan(icon.center.dy));
      final upperRightQuadrant = Rect.fromLTRB(
        icon.center.dx,
        icon.top,
        icon.right,
        icon.center.dy,
      );
      expect(
        badge.overlaps(upperRightQuadrant),
        isTrue,
        reason: 'badge $badge vs icon quadrant $upperRightQuadrant',
      );
      expect(
        dest.contains(badge.topLeft) && dest.contains(badge.bottomRight),
        isTrue,
        reason: 'badge $badge stays inside its column $dest',
      );
    });

    testWidgets('NAV-07 the badge does not move the icon', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _Harness(
          current: MonettaBottomDestination.home,
          bagCount: 0,
        ),
      );
      await tester.pump();
      final without = tester.getRect(_icon(MonettaBottomDestination.bag));

      await tester.pumpWidget(
        _Harness(
          current: MonettaBottomDestination.home,
          bagCount: 2,
        ),
      );
      await tester.pump();
      expect(tester.getRect(_icon(MonettaBottomDestination.bag)), without);
    });

    testWidgets('NAV-07 the badge ignores the text scale', (tester) async {
      _phone(tester);
      final badge = find.byKey(const Key('bottom-nav-bag-badge'));

      await tester.pumpWidget(
        _Harness(
          current: MonettaBottomDestination.home,
          bagCount: 2,
        ),
      );
      await tester.pump();
      expect(badge, findsOneWidget);
      final atOne = tester.getSize(badge);

      await tester.pumpWidget(
        _Harness(
          current: MonettaBottomDestination.home,
          bagCount: 2,
          textScale: 2.0,
        ),
      );
      await tester.pump();
      expect(tester.getSize(badge), atOne);
    });
  });

  group('NAV-08 semantics', () {
    testWidgets('NAV-08 one button per destination, selected only the current',
        (tester) async {
      _phone(tester);
      final handle = tester.ensureSemantics();
      try {
        for (final current in _destinations) {
          await tester.pumpWidget(_Harness(current: current));
          await tester.pump();

          for (final d in _destinations) {
            final node = _nodeLabeled(_labels[d]!);
            expect(
              node,
              isSemantics(
                label: _labels[d],
                isButton: true,
                hasTapAction: true,
                isFocusable: true,
                isSelected: d == current,
              ),
              reason: '${d.name} with current=${current.name}',
            );
          }
        }
      } finally {
        handle.dispose();
      }
    });

    testWidgets('NAV-08 the cart announces its real item count',
        (tester) async {
      _phone(tester);
      final handle = tester.ensureSemantics();
      try {
        const expected = {
          0: 'Carrito',
          1: 'Carrito, 1 artículo',
          2: 'Carrito, 2 artículos',
          12: 'Carrito, 12 artículos',
        };
        for (final entry in expected.entries) {
          await tester.pumpWidget(
            _Harness(
              current: MonettaBottomDestination.home,
              bagCount: entry.key,
            ),
          );
          await tester.pump();

          final node = _nodeLabeled(entry.value);
          expect(
            node,
            isSemantics(
              label: entry.value,
              isButton: true,
              hasTapAction: true,
            ),
            reason: 'bagCount=${entry.key}',
          );
        }
      } finally {
        handle.dispose();
      }
    });

    testWidgets('NAV-08 meets the platform accessibility guidelines',
        (tester) async {
      _phone(tester, bottomInset: 34);
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _Harness(
            current: MonettaBottomDestination.catalog,
            bagCount: 2,
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      } finally {
        handle.dispose();
      }
    });
  });

  group('NAV-09 text scale', () {
    for (final width in [320.0, 390.0, 800.0]) {
      for (final scale in [1.0, 1.3, 1.5, 2.0, 3.0]) {
        testWidgets(
            'NAV-09 width ${width.toInt()} at x$scale: labels fit, stay '
            'uniform and the bar contains them', (tester) async {
          _phone(tester, width: width, bottomInset: 34);
          await tester.pumpWidget(
            _Harness(
              current: MonettaBottomDestination.catalog,
              bagCount: 12,
              textScale: scale,
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);

          final surface = tester.getRect(_surface);
          expect(surface.height, greaterThanOrEqualTo(56 + 34));

          final heights = <double>[];
          for (final d in _destinations) {
            final paragraph = _paragraph(tester, d);
            final dest = tester.getRect(_dest(d));
            final label = tester.getRect(_label(d));

            expect(
              paragraph.didExceedMaxLines,
              isFalse,
              reason: '${d.name} label is clipped',
            );
            expect(
              paragraph.getMaxIntrinsicWidth(double.infinity),
              lessThanOrEqualTo(paragraph.size.width + 0.5),
              reason: '${d.name} label is wider than the room it was given',
            );
            expect(
              label.left,
              greaterThanOrEqualTo(dest.left - 0.5),
              reason: '${d.name} label overflows its column (left)',
            );
            expect(
              label.right,
              lessThanOrEqualTo(dest.right + 0.5),
              reason: '${d.name} label overflows its column (right)',
            );
            expect(
              paragraph.textScaler.scale(13) / 13,
              lessThanOrEqualTo(scale + 1e-9),
              reason: '${d.name} label grows past the requested scale',
            );

            expect(
              dest.top,
              greaterThanOrEqualTo(surface.top - 0.01),
              reason: '${d.name} starts above the bar',
            );
            expect(
              dest.bottom,
              lessThanOrEqualTo(surface.bottom - 34 + 0.01),
              reason: '${d.name} ends inside the safe area',
            );
            heights.add(label.height);
          }
          for (final h in heights) {
            expect(
              h,
              closeTo(heights.first, 0.01),
              reason: 'label heights $heights are not uniform',
            );
          }
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('NAV-09 on a wide screen the label follows the system scale',
        (tester) async {
      await tester.runAsync(loadBundledFonts);
      _phone(tester, width: 800, height: 600);
      await tester.pumpWidget(
        _Harness(
          current: MonettaBottomDestination.home,
          textScale: 1.05,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      for (final d in _destinations) {
        expect(_label(d), findsOneWidget, reason: d.name);
        expect(
          tester.getSize(_label(d)).height,
          closeTo(13 * 1.25 * 1.05, 0.5),
          reason: '${d.name} label height',
        );
      }
    });
  });

  group('NAV-11 press and focus feedback', () {
    testWidgets('NAV-11 pressing dims the icon, releasing restores it',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_Harness(current: MonettaBottomDestination.home));
      await tester.pump();

      final icon = _icon(MonettaBottomDestination.catalog);
      final dest = _dest(MonettaBottomDestination.catalog);
      expect(icon, findsOneWidget);
      expect(_opacityAbove(icon, dest), 1.0);

      final gesture = await tester.startGesture(tester.getCenter(dest));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(_opacityAbove(icon, dest), lessThan(1.0));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(_opacityAbove(icon, dest), 1.0);
    });

    testWidgets('NAV-11 no painted background between the ink well and icon',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_Harness(current: MonettaBottomDestination.home));
      await tester.pump();

      await tester.tap(find.byKey(const Key('bottom-nav-catalog')));
      await tester.pumpAndSettle();

      for (final d in _destinations) {
        expect(_icon(d), findsOneWidget);
        final backgrounds = find.ancestor(
          of: _icon(d),
          matching: find.descendant(
            of: _dest(d),
            matching: find.byWidgetPredicate(_paintsBackground),
          ),
        );
        expect(
          backgrounds,
          findsNothing,
          reason: '${d.name} paints a fill behind its icon',
        );
      }
    });
  });
}

// --- harness -----------------------------------------------------------------

ThemeData _theme({required bool dark}) =>
    dark ? buildDarkTheme() : buildLightTheme();

/// Fixed phone-sized view; 1 logical px == 1 physical px.
void _phone(
  WidgetTester tester, {
  double width = 390,
  double height = 844,
  double bottomInset = 0,
}) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, height);
  tester.view.padding = FakeViewPadding(bottom: bottomInset);
  tester.view.viewPadding = FakeViewPadding(bottom: bottomInset);
  addTearDown(tester.view.reset);
}

class _Harness extends StatefulWidget {
  _Harness({
    required this.current,
    this.bagCount = 0,
    ThemeData? theme,
    this.textScale = 1.0,
    this.disableAnimations = false,
    this.accessibleNavigation = false,
  }) : theme = theme ?? buildLightTheme();

  final MonettaBottomDestination current;
  final int bagCount;
  final ThemeData theme;
  final double textScale;
  final bool disableAnimations;
  final bool accessibleNavigation;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late MonettaBottomDestination current = widget.current;

  @override
  void didUpdateWidget(_Harness oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current != widget.current) current = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: widget.theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(widget.textScale),
          disableAnimations: widget.disableAnimations,
          accessibleNavigation: widget.accessibleNavigation,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: MonettaBottomNavigation(
          current: current,
          bagCount: widget.bagCount,
          onSelected: (destination) => setState(() => current = destination),
        ),
      ),
    );
  }
}

// --- finders and readers -----------------------------------------------------

final _surface = find.byKey(const Key('bottom-nav-surface'));

Finder _dest(MonettaBottomDestination d) =>
    find.byKey(Key('bottom-nav-${d.name}'));
Finder _icon(MonettaBottomDestination d) =>
    find.byKey(Key('bottom-nav-${d.name}-icon'));
Finder _label(MonettaBottomDestination d) =>
    find.byKey(Key('bottom-nav-${d.name}-label'));

Color _iconColor(WidgetTester tester, MonettaBottomDestination d) {
  expect(_icon(d), findsOneWidget, reason: 'Key(bottom-nav-${d.name}-icon)');
  final color = IconTheme.of(tester.element(_icon(d))).color;
  expect(color, isNotNull, reason: '${d.name} icon has no icon-theme color');
  return color!;
}

RenderParagraph _paragraph(WidgetTester tester, MonettaBottomDestination d) {
  expect(_label(d), findsOneWidget, reason: 'Key(bottom-nav-${d.name}-label)');
  final rich = find.descendant(of: _label(d), matching: find.byType(RichText));
  return tester.renderObject<RenderParagraph>(rich.first);
}

TextStyle _labelStyle(WidgetTester tester, MonettaBottomDestination d) {
  final style = _paragraph(tester, d).text.style;
  expect(style, isNotNull, reason: '${d.name} label has no effective style');
  return style!;
}

String _labelText(WidgetTester tester, MonettaBottomDestination d) =>
    _paragraph(tester, d).text.toPlainText();

BoxDecoration _surfaceDecoration(WidgetTester tester) =>
    tester.widget<DecoratedBox>(_surface).decoration as BoxDecoration;

/// Combined opacity of every [Opacity] between the ink well and the icon.
double _opacityAbove(Finder icon, Finder dest) {
  final opacities = find.ancestor(
    of: icon,
    matching: find.descendant(of: dest, matching: find.byType(Opacity)),
  );
  var product = 1.0;
  for (final element in opacities.evaluate()) {
    product *= (element.widget as Opacity).opacity;
  }
  return product;
}

/// A fill painted by a widget, ignoring fully transparent colors.
bool _paintsBackground(Widget widget) {
  bool opaque(Color? color) => color != null && color.a > 0;
  bool decorated(Decoration? d) =>
      d is BoxDecoration &&
      (opaque(d.color) || d.gradient != null || d.image != null);

  return switch (widget) {
    ColoredBox(:final color) => opaque(color),
    DecoratedBox(:final decoration) => decorated(decoration),
    Container(:final color, :final decoration) =>
      opaque(color) || decorated(decoration),
    Material(:final type, :final color) =>
      color == null ? type != MaterialType.transparency : opaque(color),
    _ => false,
  };
}

/// The one semantics node whose label is exactly [label].
SemanticsNode _nodeLabeled(String label) {
  final matches = find.semantics.byLabel(label).evaluate().toList();
  if (matches.length != 1) {
    final all = [
      for (final node in find.semantics.byPredicate((n) => true).evaluate())
        if (node.label.isNotEmpty) node.label,
    ];
    fail(
      'expected exactly one semantics node labeled "$label", found '
      '${matches.length}; labels in the tree: $all',
    );
  }
  return matches.single;
}

// --- assertions --------------------------------------------------------------

Map<String, Offset> _anchors(WidgetTester tester) => {
      for (final d in _destinations) ...{
        '${d.name} icon': tester.getCenter(_icon(d)),
        '${d.name} label': tester.getCenter(_label(d)),
      },
    };

void _expectAnchors(
  WidgetTester tester,
  Map<String, Offset> before,
  String when,
) {
  final now = _anchors(tester);
  for (final key in before.keys) {
    expect(
      now[key]!.dx,
      closeTo(before[key]!.dx, 0.01),
      reason: '$key moved horizontally $when',
    );
    expect(
      now[key]!.dy,
      closeTo(before[key]!.dy, 0.01),
      reason: '$key moved vertically $when',
    );
  }
}

void _expectPair(
  WidgetTester tester,
  MonettaBottomDestination d,
  Color color,
) {
  expect(_iconColor(tester, d), color, reason: '${d.name} icon');
  expect(_labelStyle(tester, d).color, color, reason: '${d.name} label');
}

void _expectBetween(Color value, Color a, Color b, String reason) {
  expect(value, isNot(a), reason: '$reason is still at the start color');
  expect(value, isNot(b), reason: '$reason already reached the end color');
  for (final (v, x, y) in [
    (value.r, a.r, b.r),
    (value.g, a.g, b.g),
    (value.b, a.b, b.b),
  ]) {
    expect(
      v,
      inInclusiveRange(x < y ? x : y, x < y ? y : x),
      reason: '$reason is outside the $a..$b range',
    );
  }
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
