import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Global cap on the system text scale (E-T1).
const double kMaxTextScale = 1.5;

/// Cap on the growth of headline-sized text (E-T1).
const double kMaxHeadlineTextScale = 1.2;

/// Nominal font size from which text counts as a headline (D-12).
const double kHeadlineFontSize = 20;

/// Largest size that text below [kHeadlineFontSize] may reach once scaled.
const double _kMaxScaledBodySize = 24;

/// Body size at which [BoundedTextScaler.textScaleFactor] is estimated.
const double _kReferenceFontSize = 14;

/// Bounds the system text scale by font size (RF-17, E-T1 / D-12).
///
/// Text of [kHeadlineFontSize] or more grows at most [kMaxHeadlineTextScale]
/// times; smaller text grows up to [kMaxTextScale] times without passing
/// 24 px. The result never exceeds what the system scaler asks for: the policy
/// only tightens a scale, it never amplifies one.
///
/// Installed once, at the root of the app, so no call site has to change.
class BoundedTextScaler extends TextScaler {
  const BoundedTextScaler(this.system);

  /// The scaler the operating system asked for.
  final TextScaler system;

  @override
  double scale(double fontSize) {
    final cap = fontSize >= kHeadlineFontSize
        ? kMaxHeadlineTextScale * fontSize
        : math.min(kMaxTextScale * fontSize, _kMaxScaledBodySize);
    return math.min(system.scale(fontSize), cap);
  }

  /// Estimate for callers of the deprecated getter. It is measured at a body
  /// size through [scale] so that nonlinear system scalers stay representative
  /// and this file never reads a deprecated member.
  @override
  double get textScaleFactor =>
      math.min(textScaleFactorFor(system, _kReferenceFontSize), kMaxTextScale);

  @override
  bool operator ==(Object other) =>
      other is BoundedTextScaler && other.system == system;

  @override
  int get hashCode => Object.hash(BoundedTextScaler, system);

  @override
  String toString() => 'BoundedTextScaler($system)';
}

/// The factor [scaler] applies to text of [fontSize].
///
/// Use it to reserve a box for text instead of `scaler.scale(boxHeight)`:
/// under [BoundedTextScaler] the factor depends on the size of the text, not
/// on the size of the box that holds it.
double textScaleFactorFor(TextScaler scaler, double fontSize) =>
    scaler.scale(fontSize) / fontSize;
