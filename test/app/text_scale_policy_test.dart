/// UI-02 (objective state, red until RF-17 step 3): the app root applies the
/// text scale policy of E-T1 and D-12 to everything below the navigator.
///
/// * E-T1: global cap of 1.5 and headlines at 1.2.
/// * D-12: the cap is applied by size, in the root. Text of 20 px or more grows
///   at most 1.2x; smaller text grows up to 1.5x without passing 24 px.
///
/// Written as `expected(s, k) = min(k*s, s >= 20 ? 1.2*s : min(1.5*s, 24))`
/// (`expectedTextSize`), with `s` the nominal size and `k` the operating
/// system's scale. The real `MonettaApp` is mounted, the system scale is set
/// through `platformDispatcher.textScaleFactorTestValue`, and the scaler that
/// reaches `HomeScreen` (and the one inside each of its paragraphs) is read.
///
/// Today the root hands down the system's linear scale, so every case with
/// `k` above 1.0 fails (`scale(14)` is 43.4 at 3.1, not 21). Cases at 0.85 and
/// 1.0 already agree with the policy and pass: the policy only tightens.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/features/navigation/monetta_floating_bottom_navigation.dart';

import '../support/e_t1_text_scaler.dart';
import '../support/monetta_app_harness.dart';

const double _tolerance = 0.01;

/// Sizes swept for the properties (8 to 60 in half-pixel steps).
final List<double> _sweep = [for (var s = 8.0; s <= 60.0; s += 0.5) s];

TextScaler _scalerBelowHome(WidgetTester tester) =>
    MediaQuery.textScalerOf(tester.element(find.byType(HomeScreen)));

/// Private-use glyphs are icon fonts: Flutter draws them without text scaling.
bool _isIconGlyph(String text) =>
    text.isNotEmpty &&
    text.runes.every(
      (r) => (r >= 0xE000 && r <= 0xF8FF) || (r >= 0xF0000 && r <= 0x10FFFF),
    );

/// Paragraphs under `HomeScreen`, minus those inside the bottom navigation
/// (it fits its own scaler) and icon glyphs.
List<RenderParagraph> _homeParagraphs(WidgetTester tester) {
  final inNav = find
      .descendant(
        of: find.byType(MonettaFloatingBottomNavigation),
        matching: find.byType(RichText),
      )
      .evaluate()
      .map((e) => e.renderObject)
      .toSet();
  return find
      .descendant(
        of: find.byType(HomeScreen),
        matching: find.byType(RichText),
      )
      .evaluate()
      .map((e) => e.renderObject)
      .whereType<RenderParagraph>()
      .where((p) => !inNav.contains(p))
      .where((p) => !_isIconGlyph(p.text.toPlainText()))
      .where((p) => p.text.style?.fontSize != null)
      .toList();
}

void _expectNone(List<String> problems) {
  final shown = problems.take(10).join('\n  ');
  final more =
      problems.length > 10 ? '\n  ... and ${problems.length - 10} more' : '';
  expect(
    problems.isEmpty,
    isTrue,
    reason: '${problems.length} violation(s) of the text scale policy:\n  '
        '$shown$more',
  );
}

/// Checks the scale that reaches the home against the policy for system scale
/// [k]: the matrix, the properties and each paragraph's own scaler.
void _expectPolicy(WidgetTester tester, double k) {
  final scaler = _scalerBelowHome(tester);
  final problems = <String>[];

  for (final s in kNominalSizes) {
    final want = expectedTextSize(s, k);
    final got = scaler.scale(s);
    if ((got - want).abs() > _tolerance) {
      problems.add('MediaQuery scale($s) = $got, expected $want at k=$k');
    }
  }

  for (final s in _sweep) {
    final got = scaler.scale(s);
    if (k == 1.0 && (got - s).abs() > _tolerance) {
      problems.add('at system scale 1.0 nothing changes; scale($s) = $got');
    }
    if (got > 1.5 * s + _tolerance) {
      problems.add('no size may pass 1.5x; scale($s) = $got at k=$k');
    }
    if (s >= 20 && got > 1.2 * s + _tolerance) {
      problems.add('sizes of 20 px or more may not pass 1.2x; scale($s) = '
          '$got at k=$k');
    }
    if (s < 20 && got > 24 + _tolerance) {
      problems.add('sizes under 20 px may not pass 24 px; scale($s) = $got at '
          'k=$k');
    }
  }
  var previous = 0.0;
  for (final s in _sweep) {
    final got = scaler.scale(s);
    if (got < previous - _tolerance) {
      problems.add('the scale must be monotone: scale($s) = $got fell below '
          'the scale of a smaller size ($previous) at k=$k');
    }
    previous = got;
  }

  final paragraphs = _homeParagraphs(tester);
  expect(
    paragraphs,
    isNotEmpty,
    reason: 'HomeScreen must paint at least one scalable paragraph.',
  );
  for (final p in paragraphs) {
    final own = p.text.style!.fontSize!;
    final snippet = p.text.toPlainText().replaceAll('\n', ' ');
    final shown =
        snippet.length > 24 ? '${snippet.substring(0, 24)}...' : snippet;
    final ownGot = p.textScaler.scale(own);
    final ownWant = expectedTextSize(own, k);
    if ((ownGot - ownWant).abs() > _tolerance) {
      problems.add(
        'paragraph "$shown" ($own px) paints at $ownGot, expected $ownWant at '
        'k=$k',
      );
    }
    for (final s in kNominalSizes) {
      final got = p.textScaler.scale(s);
      final want = expectedTextSize(s, k);
      if ((got - want).abs() > _tolerance) {
        problems.add(
          'paragraph "$shown" scaler.scale($s) = $got, expected $want at k=$k',
        );
        break;
      }
    }
  }
  _expectNone(problems);
}

void _setSystemScale(WidgetTester tester, double k) {
  tester.platformDispatcher.textScaleFactorTestValue = k;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final k in kSystemScales) {
    testWidgets('UI-02 root text scale policy at system scale $k',
        (tester) async {
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      _setSystemScale(tester, k);
      await withMonettaApp(tester, () async {
        _expectPolicy(tester, k);
      });
    });
  }

  testWidgets(
    'UI-02 root text scale policy follows a system scale change at runtime',
    (tester) async {
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      _setSystemScale(tester, 1.0);
      await withMonettaApp(tester, () async {
        _expectPolicy(tester, 1.0);

        _setSystemScale(tester, 3.1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        _expectPolicy(tester, 3.1);
      });
    },
  );
}
