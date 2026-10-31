import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// The text scale policy of RF-17, written down independently of `lib/`.
///
/// * E-T1: the global cap is 1.5 and headlines are capped at 1.2.
/// * D-12: the cap is applied by size, at the app root. Text of 20 px or more
///   grows at most 1.2x; smaller text grows up to 1.5x without passing 24 px.
///
/// [systemScale] is the scale the operating system asks for and [nominal] the
/// size the style declares. The scaled size never passes `systemScale * nominal`
/// either: the policy only ever tightens a scale, it does not amplify one.
double expectedTextSize(double nominal, double systemScale) {
  final cap = nominal >= 20 ? 1.2 * nominal : math.min(1.5 * nominal, 24.0);
  return math.min(systemScale * nominal, cap);
}

/// A [TextScaler] that implements [expectedTextSize] for one system scale.
///
/// Test oracle: it lets a screen test run the layout the policy produces
/// without depending on whichever class the app uses to implement it.
class PolicyTextScaler extends TextScaler {
  const PolicyTextScaler(this.systemScale);

  final double systemScale;

  @override
  double scale(double fontSize) => expectedTextSize(fontSize, systemScale);

  @override
  double get textScaleFactor => systemScale;

  @override
  bool operator ==(Object other) =>
      other is PolicyTextScaler && other.systemScale == systemScale;

  @override
  int get hashCode => systemScale.hashCode;

  @override
  String toString() => 'PolicyTextScaler($systemScale)';
}

/// System scales and nominal sizes of the UI-02 matrix.
const List<double> kSystemScales = <double>[0.85, 1.0, 1.3, 2.0, 3.1];
const List<double> kNominalSizes = <double>[
  8, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 22, 24, 28, 34, 40, //
];
