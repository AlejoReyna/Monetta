// Motion spec «Logo de Welcome» §10.7 and §12. Synthetic geometry taken from
// the Duo simulator table (iOS 27.1), not hardware.
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/logo_write.dart';
import 'package:monetta_app/app/motion.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/features/welcome/welcome_screen.dart';

class _MemoryStore implements LogoWrittenStore {
  bool written = false;
  @override
  Future<bool> read() async => written;
  @override
  Future<void> markWritten() async => written = true;
}

class _Posture {
  const _Posture(
    this.name,
    this.size, {
    this.padding = EdgeInsets.zero,
    this.occlusions = const [],
    this.division,
    this.divisionActive = false,
  });
  final String name;
  final Size size;
  final EdgeInsets padding;
  final List<Rect> occlusions;
  final Rect? division;
  final bool divisionActive;

  List<Rect> get reserved => [
        ...occlusions,
        if (division != null && divisionActive) division!,
      ];
}

// Camera occlusion bounds are not in the brief: a synthetic top-centre box.
const _camera = Rect.fromLTWH(203, 0, 60, 30);
const _vertical = Rect.fromLTWH(455.5, 0, 40, 669);
const _horizontal = Rect.fromLTWH(0, 455.5, 669, 40);

const _postures = [
  _Posture(
    'P1 closed outer portrait',
    Size(466, 678),
    padding: EdgeInsets.only(top: 30, right: 84, bottom: 34),
    occlusions: [_camera],
  ),
  _Posture(
    'P3 open inner landscape (division inactive)',
    Size(951, 669),
    padding: EdgeInsets.only(right: 20),
    division: _vertical,
  ),
  _Posture(
    'P4 open inner portrait (band inactive)',
    Size(669, 951),
    division: _horizontal,
  ),
  _Posture(
    'P5 book (vertical division active)',
    Size(951, 669),
    padding: EdgeInsets.only(right: 20),
    division: _vertical,
    divisionActive: true,
  ),
];

void main() {
  setUp(() => debugMotionInWidgetTests = true);
  tearDown(() => debugMotionInWidgetTests = false);

  Widget harness(_Posture p, WelcomeLogoController logo) => MediaQuery(
        data: MediaQueryData(
          size: p.size,
          padding: p.padding,
          displayFeatures: [
            if (p.division != null && p.divisionActive)
              DisplayFeature(
                bounds: p.division!,
                type: DisplayFeatureType.hinge,
                state: DisplayFeatureState.postureHalfOpened,
              ),
          ],
        ),
        child: MaterialApp(
          theme: buildLightTheme(),
          home: WelcomeLogoScope(
            notifier: logo,
            child: WelcomeScreen(onStart: () {}),
          ),
        ),
      );

  for (final p in _postures) {
    testWidgets('§10.7 ${p.name}: logo and COMENZAR avoid active regions',
        (tester) async {
      await tester.binding.setSurfaceSize(p.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final logo = WelcomeLogoController(store: _MemoryStore());
      addTearDown(logo.dispose);
      await logo.restore();
      await tester.pumpWidget(harness(p, logo));

      final button = tester.getRect(
        find.byKey(const ValueKey('welcome-start-button')),
      );
      final box = tester.getRect(find.byKey(const ValueKey('welcome-logo')));
      final screen = Offset.zero & p.size;
      expect(screen.contains(button.topLeft), isTrue);
      expect(screen.contains(button.bottomRight - const Offset(1, 1)), isTrue);
      expect(button.height, greaterThanOrEqualTo(48));
      for (final region in p.reserved) {
        expect(button.overlaps(region), isFalse, reason: 'COMENZAR $region');
        expect(box.overlaps(region), isFalse, reason: 'logo $region');
      }
      // Outside the bar inset on P1 (right rail).
      expect(button.right, lessThanOrEqualTo(p.size.width - p.padding.right));
      if (p.divisionActive) {
        expect(box.right, lessThanOrEqualTo(p.division!.left));
        expect(button.right, lessThanOrEqualTo(p.division!.left));
      }
      if (p.name.startsWith('P4')) {
        expect(box.bottom, lessThanOrEqualTo(_horizontal.top));
      }
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('§12 COMENZAR at 200 ms, then cold start: static from frame 1',
      (tester) async {
    final store = _MemoryStore();
    final first = WelcomeLogoController(store: store);
    await first.restore();
    await tester.pumpWidget(harness(_postures.first, first));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(first.phase, WelcomeLogoPhase.playing);
    expect(store.written, isTrue, reason: 'persisted on entering playing');
    await tester.tap(find.text('COMENZAR'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    first.dispose();

    final cold = WelcomeLogoController(store: store);
    addTearDown(cold.dispose);
    await cold.restore();
    await tester.pumpWidget(harness(_postures.first, cold));
    expect(cold.phase, WelcomeLogoPhase.done);
    expect(
      tester.widget<MonettaLogoWrite>(find.byType(MonettaLogoWrite)).progress,
      1,
    );
    await tester.pump(const Duration(seconds: 1));
  });
}
