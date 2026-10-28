import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/monetta_tokens.g.dart';

/// WCAG 2.x relative-luminance contrast of two opaque colours.
double _ratio(Color a, Color b) {
  double lum(Color c) {
    double ch(double v) => v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  final l1 = lum(a);
  final l2 = lum(b);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

void main() {
  // The same pairs as design-system/monetta.tokens.json "contrast"; the Node
  // build gates the manifest, this keeps the generated Dart honest too.
  final pairs = <String, (Color, Color, double)>{
    'ink on canvas': (MonettaTokens.ink, MonettaTokens.canvas, 4.5),
    'ink on warm panel': (MonettaTokens.ink, MonettaTokens.surfaceWarm, 4.5),
    'ink on tile': (MonettaTokens.ink, MonettaTokens.surfaceTile, 4.5),
    'muted on canvas': (MonettaTokens.inkMuted, MonettaTokens.canvas, 4.5),
    'muted on warm panel': (
      MonettaTokens.inkMuted,
      MonettaTokens.surfaceWarm,
      4.5,
    ),
    'muted on tile': (MonettaTokens.inkMuted, MonettaTokens.surfaceTile, 4.5),
    'muted on bar': (MonettaTokens.inkMuted, MonettaTokens.bar, 4.5),
    'purchase label': (
      MonettaTokens.onActionPrimary,
      MonettaTokens.actionPrimary,
      4.5,
    ),
    'dark pill label': (
      MonettaTokens.onActionDark,
      MonettaTokens.actionDark,
      4.5,
    ),
    'accent text on canvas': (
      MonettaTokens.accentText,
      MonettaTokens.canvas,
      4.5,
    ),
    'accent text on warm panel': (
      MonettaTokens.accentText,
      MonettaTokens.surfaceWarm,
      4.5,
    ),
    'active nav on bar': (
      MonettaTokens.navigationActive,
      MonettaTokens.bar,
      4.5
    ),
    'inactive nav on bar': (
      MonettaTokens.navigationInactive,
      MonettaTokens.bar,
      4.5,
    ),
    'sale on canvas': (MonettaTokens.sale, MonettaTokens.canvas, 4.5),
    'sale on chip': (MonettaTokens.sale, MonettaTokens.saleSurface, 4.5),
    'control border on canvas': (
      MonettaTokens.borderControl,
      MonettaTokens.canvas,
      3,
    ),
  };

  for (final entry in pairs.entries) {
    test('STYLE-03 ${entry.key} reaches ${entry.value.$3}:1', () {
      final (fg, bg, min) = entry.value;
      expect(_ratio(fg, bg), greaterThanOrEqualTo(min));
    });
  }

  test('STYLE-03 gold is decorative: it never reaches text contrast', () {
    expect(_ratio(MonettaTokens.gold, MonettaTokens.canvas), lessThan(3));
  });

  test('STYLE-04 type roles step up with the width class', () {
    for (final role in <MonettaTypeRole>[
      MonettaTokens.campaign,
      MonettaTokens.screenTitle,
      MonettaTokens.sectionTitle,
      MonettaTokens.productName,
      MonettaTokens.body,
    ]) {
      expect(role.sizeFor(390), role.compact);
      expect(role.sizeFor(834), role.medium);
      expect(role.sizeFor(1440), role.expanded);
      expect(role.medium, greaterThanOrEqualTo(role.compact));
      expect(role.expanded, greaterThanOrEqualTo(role.medium));
    }
  });

  test('STYLE-04 serif roles are the editorial ones, sans the working ones',
      () {
    expect(MonettaTokens.campaign.serif, isTrue);
    expect(MonettaTokens.productName.serif, isTrue);
    expect(MonettaTokens.accountRow.serif, isTrue);
    expect(MonettaTokens.price.serif, isFalse);
    expect(MonettaTokens.control.serif, isFalse);
  });

  test('STYLE-04 touch targets keep the product standard', () {
    expect(MonettaTokens.tapTarget, 48);
    expect(MonettaTokens.controlHeight, 52);
  });
}
