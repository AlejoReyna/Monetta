import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/features/navigation/monetta_bottom_navigation.dart';

// Target behaviour of the iOS "liquid glass" bottom bar (NAV-GLASS-01..09).
// The platform is read from Theme.of(context).platform, which follows the
// TargetPlatformVariant of each test.
//
// Structure assumed for the capsule: a widget keyed `bottom-nav-glass` that
// is (or wraps) a ClipRRect whose subtree holds a BackdropFilter and the four
// destinations. The capsule rect is the rect of the `bottom-nav-glass` widget.
//
// This file loads no bundled fonts on purpose: NAV-GLASS-08 samples rendered
// pixels, see monetta_bottom_navigation_contrast_test.dart for the reason.

const _destinations = MonettaBottomDestination.values;
const _viewWidth = 390.0;
const _viewHeight = 844.0;
const _bottomInset = 34.0;

const _labels = {
  MonettaBottomDestination.home: 'Inicio',
  MonettaBottomDestination.catalog: 'Catálogo',
  MonettaBottomDestination.bag: 'Carrito',
  MonettaBottomDestination.account: 'Cuenta',
};

final _glass = find.byKey(const Key('bottom-nav-glass'));
final _surface = find.byKey(const Key('bottom-nav-surface'));
final _backdrop = find.byType(BackdropFilter);

Finder _dest(MonettaBottomDestination d) =>
    find.byKey(Key('bottom-nav-${d.name}'));

/// Fixed phone-sized view with a home-indicator inset; 1 logical px == 1
/// physical px.
void _phone(WidgetTester tester, {double inset = _bottomInset}) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(_viewWidth, _viewHeight);
  tester.view.padding = FakeViewPadding(bottom: inset);
  tester.view.viewPadding = FakeViewPadding(bottom: inset);
  addTearDown(tester.view.reset);
}

Widget _app({
  MonettaBottomDestination current = MonettaBottomDestination.catalog,
  int bagCount = 0,
  ValueChanged<MonettaBottomDestination>? onSelected,
  double textScale = 1.0,
  bool highContrast = false,
  bool rail = false,
}) {
  var bar = MonettaBottomNavigation(
    current: current,
    bagCount: bagCount,
    onSelected: onSelected ?? (_) {},
  );
  if (rail) bar = bar.asRail();
  return MaterialApp(
    theme: buildLightTheme(),
    builder: (context, home) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        highContrast: highContrast,
      ),
      child: home!,
    ),
    // The rail lives beside the content, never in the bottom slot.
    home: rail
        ? Scaffold(
            body: Row(
              children: [bar, const Expanded(child: SizedBox.expand())],
            ),
          )
        : Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: bar,
          ),
  );
}

/// Radius (x of the top-left corner) of every ClipRRect that is the capsule
/// itself or one of its descendants.
List<double> _clipRadii(WidgetTester tester) {
  final clips = <ClipRRect>[];
  final glassWidget = tester.widget(_glass);
  if (glassWidget is ClipRRect) clips.add(glassWidget);
  clips.addAll(
    find
        .descendant(of: _glass, matching: find.byType(ClipRRect))
        .evaluate()
        .map((e) => e.widget as ClipRRect),
  );
  return [
    for (final clip in clips)
      clip.borderRadius.resolve(TextDirection.ltr).topLeft.x,
  ];
}

void main() {
  group('iOS glass capsule', () {
    testWidgets(
      'NAV-GLASS-01 floating capsule detached from the side edges with '
      'rounded corners',
      (tester) async {
        _phone(tester);
        await tester.pumpWidget(_app());
        await tester.pump();

        expect(_glass, findsOneWidget, reason: 'bottom-nav-glass must exist');
        final rect = tester.getRect(_glass);
        expect(rect.left, greaterThanOrEqualTo(12));
        expect(rect.right, lessThanOrEqualTo(_viewWidth - 12));
        final radii = _clipRadii(tester);
        expect(radii, isNotEmpty, reason: 'a ClipRRect rounds the capsule');
        expect(radii.reduce((a, b) => a > b ? a : b), greaterThanOrEqualTo(20));
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'NAV-GLASS-02 the capsule blurs what is behind it with a BackdropFilter',
      (tester) async {
        _phone(tester);
        await tester.pumpWidget(_app());
        await tester.pump();

        expect(_glass, findsOneWidget, reason: 'bottom-nav-glass must exist');
        final filter = find.descendant(of: _glass, matching: _backdrop);
        expect(filter, findsOneWidget);
        final widget = tester.widget<BackdropFilter>(filter);
        expect(widget.filter, isA<ImageFilter>());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'NAV-GLASS-03 the capsule sits above the bottom inset',
      (tester) async {
        _phone(tester);
        await tester.pumpWidget(_app());
        await tester.pump();

        expect(_glass, findsOneWidget, reason: 'bottom-nav-glass must exist');
        final rect = tester.getRect(_glass);
        expect(rect.bottom, lessThanOrEqualTo(_viewHeight - _bottomInset));
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'NAV-GLASS-04 destinations, badge and selected semantics keep working',
      (tester) async {
        _phone(tester);
        final handle = tester.ensureSemantics();
        try {
          final taps = <MonettaBottomDestination>[];
          await tester.pumpWidget(
            _app(
              current: MonettaBottomDestination.catalog,
              bagCount: 2,
              onSelected: taps.add,
            ),
          );
          await tester.pump();

          expect(_glass, findsOneWidget, reason: 'bottom-nav-glass must exist');
          for (final d in _destinations) {
            expect(
              find.descendant(of: _glass, matching: _dest(d)),
              findsOneWidget,
              reason: '${d.name} lives inside the capsule',
            );
          }
          expect(
            find.descendant(
              of: _glass,
              matching: find.byKey(const Key('bottom-nav-bag-badge')),
            ),
            findsOneWidget,
          );

          for (final d in _destinations) {
            await tester.tap(_dest(d));
            await tester.pump();
          }
          expect(taps, _destinations);

          for (final d in _destinations) {
            final matches = find.semantics.byLabel(
              d == MonettaBottomDestination.bag
                  ? 'Carrito, 2 artículos'
                  : _labels[d]!,
            );
            final nodes = matches.evaluate().toList();
            expect(nodes, hasLength(1), reason: d.name);
            expect(
              nodes.single,
              isSemantics(
                isButton: true,
                isSelected: d == MonettaBottomDestination.catalog,
              ),
              reason: d.name,
            );
          }
        } finally {
          handle.dispose();
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'NAV-GLASS-05 large text neither overflows nor hides a label',
      (tester) async {
        _phone(tester);
        await tester.pumpWidget(_app(textScale: 2.0));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(_glass, findsOneWidget, reason: 'bottom-nav-glass must exist');
        for (final d in _destinations) {
          expect(
            find.descendant(of: _glass, matching: find.text(_labels[d]!)),
            findsOneWidget,
            reason: '${d.name} label stays visible',
          );
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'NAV-GLASS-06 high contrast keeps the capsule but drops the blur',
      (tester) async {
        _phone(tester);
        await tester.pumpWidget(_app(highContrast: true));
        await tester.pump();

        // The capsule must still exist so this cannot pass by the glass
        // simply being absent; only the transparency goes away.
        expect(_glass, findsOneWidget, reason: 'bottom-nav-glass must exist');
        expect(_backdrop, findsNothing);
        for (final d in _destinations) {
          expect(_dest(d), findsOneWidget);
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'NAV-GLASS-07 the rail is unchanged on iOS',
      (tester) async {
        _phone(tester);
        await tester.pumpWidget(_app(rail: true, bagCount: 2));
        await tester.pump();

        expect(_glass, findsNothing);
        expect(_backdrop, findsNothing);
        for (final d in _destinations) {
          expect(_dest(d), findsOneWidget);
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'NAV-GLASS-08 labels meet the text contrast guideline on iOS',
      (tester) async {
        _phone(tester);
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(_app(bagCount: 2));
          await tester.pumpAndSettle();

          // Without the capsule this would pass vacuously, so require it.
          expect(_glass, findsOneWidget, reason: 'bottom-nav-glass must exist');
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        } finally {
          handle.dispose();
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  });

  group('Android keeps the flat bar', () {
    testWidgets(
      'NAV-GLASS-09 Android has no capsule and a full-width surface',
      (tester) async {
        _phone(tester);
        await tester.pumpWidget(_app(bagCount: 2));
        await tester.pump();

        expect(_glass, findsNothing);
        expect(_backdrop, findsNothing);
        expect(_surface, findsOneWidget);
        final rect = tester.getRect(_surface);
        expect(rect.left, 0);
        expect(rect.right, _viewWidth);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets('NAV-GLASS-09 the default platform has no capsule either',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(bagCount: 2));
      await tester.pump();

      expect(_glass, findsNothing);
      expect(_backdrop, findsNothing);
      final rect = tester.getRect(_surface);
      expect(rect.left, 0);
      expect(rect.right, _viewWidth);
    });
  });
}
