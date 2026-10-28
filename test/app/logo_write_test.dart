// Motion spec «Logo de Welcome» §10. Synthetic geometry, not hardware.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/logo_write.dart';
import 'package:monetta_app/app/motion.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/features/welcome/welcome_screen.dart';

class _MemoryStore implements LogoWrittenStore {
  _MemoryStore([this.written = false]);
  bool written;
  int writes = 0;
  @override
  Future<bool> read() async => written;
  @override
  Future<void> markWritten() async {
    written = true;
    writes++;
  }
}

double _shownProgress(WidgetTester tester) =>
    tester.widget<MonettaLogoWrite>(find.byType(MonettaLogoWrite)).progress;

void main() {
  late _MemoryStore store;
  late WelcomeLogoController logo;
  late int starts;

  setUp(() async {
    debugMotionInWidgetTests = true;
    store = _MemoryStore();
    logo = WelcomeLogoController(store: store);
    await logo.restore();
    starts = 0;
  });

  tearDown(() {
    debugMotionInWidgetTests = false;
    logo.dispose();
  });

  Widget harness({
    Size size = const Size(466, 678),
    EdgeInsets padding = EdgeInsets.zero,
    bool disableAnimations = false,
    bool accessibleNavigation = false,
    Key? welcomeKey,
    ThemeData? theme,
  }) {
    return MediaQuery(
      data: MediaQueryData(
        size: size,
        padding: padding,
        disableAnimations: disableAnimations,
        accessibleNavigation: accessibleNavigation,
      ),
      child: MaterialApp(
        theme: theme ?? buildLightTheme(),
        home: WelcomeLogoScope(
          notifier: logo,
          child: WelcomeScreen(key: welcomeKey, onStart: () => starts++),
        ),
      ),
    );
  }

  Future<void> pumpAt(WidgetTester tester, Widget app, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app);
  }

  testWidgets('§10.1 animated path: empty at 0, M whole at 220, done at 1000',
      (tester) async {
    await pumpAt(tester, harness(), const Size(466, 678));
    expect(logo.phase, WelcomeLogoPhase.playing);
    expect(_shownProgress(tester), 0);
    expect(logoLetterReveal(0), everyElement(0));

    await tester.pump(); // first tick sets the base
    await tester.pump(const Duration(milliseconds: 220));
    final at220 = logoLetterReveal(_shownProgress(tester));
    expect(at220[0], 1);
    expect(at220.skip(1), everyElement(0));

    await tester.pump(const Duration(milliseconds: 780));
    await tester.pump();
    expect(logo.phase, WelcomeLogoPhase.done);
    expect(_shownProgress(tester), 1);
    expect(store.written, isTrue);
  });

  testWidgets('§10.2 final frame pixels equal the unclipped asset',
      (tester) async {
    const height = 48.0;
    final a = GlobalKey(), b = GlobalKey();
    await tester.binding.setSurfaceSize(const Size(400, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            RepaintBoundary(
              key: a,
              child: const MonettaLogoWrite(progress: 1, height: height),
            ),
            RepaintBoundary(
              key: b,
              child: const SizedBox(
                height: height,
                width: height * kLogoAspect,
                child: MonettaWordmark(height: height),
              ),
            ),
          ],
        ),
      ),
    );
    Future<Uint8List> bytes(GlobalKey k) async {
      final boundary =
          k.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData();
      return data!.buffer.asUint8List();
    }

    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pump();
    final pair =
        await tester.runAsync(() async => [await bytes(a), await bytes(b)]);
    expect(pair![0].any((v) => v != 0), isTrue, reason: 'asset painted');
    expect(pair[0], orderedEquals(pair[1]));
  });

  test('§10.3 letter cuts sit on the least-ink columns of the 3.0x asset',
      () async {
    final codec = await ui.instantiateImageCodec(
      File('assets/images/3.0x/logo_monetta.png').readAsBytesSync(),
    );
    final image = (await codec.getNextFrame()).image;
    expect(image.width, 396);
    final rgba = (await image.toByteData())!;
    int mass(int x) {
      var sum = 0;
      for (var y = 0; y < image.height; y++) {
        sum += rgba.getUint8((y * image.width + x) * 4 + 3);
      }
      return sum;
    }

    for (final start in kLogoLetterStarts.skip(1)) {
      final cut = (start * 396).round();
      // The column just before the cut is the lightest within ±3 px, so no
      // mask takes more than 1 px of a neighbour's ink.
      final here = [mass(cut - 1), mass(cut)].reduce((a, b) => a < b ? a : b);
      for (var d = 2; d <= 3; d++) {
        expect(here, lessThanOrEqualTo(mass(cut - 1 - d)), reason: 'cut $cut');
        expect(here, lessThanOrEqualTo(mass(cut + d)), reason: 'cut $cut');
      }
    }
    // M/O/N match spec §3: M|O valley at col 91, N after the 148–153 gap.
    expect(kLogoLetterStarts[1] * 396, 92);
    expect(kLogoLetterStarts[2] * 396, inInclusiveRange(148, 154));
  });

  testWidgets('§10.4 window change at 500 ms jumps to the end; no replay',
      (tester) async {
    await pumpAt(tester, harness(), const Size(466, 678));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(logo.phase, WelcomeLogoPhase.playing);

    await pumpAt(
        tester, harness(size: const Size(951, 669)), const Size(951, 669));
    expect(_shownProgress(tester), 1, reason: 'first frame with new geometry');
    await tester.pump();
    expect(logo.phase, WelcomeLogoPhase.done);

    await pumpAt(tester, harness(), const Size(466, 678));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_shownProgress(tester), 1);
    expect(logo.phase, WelcomeLogoPhase.done);
  });

  testWidgets('§10.5 inset-only snapshot at 500 ms keeps writing to 1000',
      (tester) async {
    await pumpAt(tester, harness(), const Size(466, 678));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(
      harness(padding: const EdgeInsets.only(right: 84, top: 20)),
    );
    expect(logo.phase, WelcomeLogoPhase.playing);
    expect(_shownProgress(tester), lessThan(1));
    await tester.pump(const Duration(milliseconds: 480));
    expect(logo.phase, WelcomeLogoPhase.playing);
    await tester.pump(const Duration(milliseconds: 40));
    expect(logo.phase, WelcomeLogoPhase.done);
  });

  testWidgets('§10.6 COMENZAR works on frame 0 and nothing absorbs input',
      (tester) async {
    await pumpAt(tester, harness(), const Size(466, 678));
    final button = find.text('COMENZAR');
    final absorbing = tester
        .widgetList<AbsorbPointer>(
          find.ancestor(of: button, matching: find.byType(AbsorbPointer)),
        )
        .where((w) => w.absorbing);
    expect(absorbing, isEmpty);
    final semantics = tester.ensureSemantics();
    expect(tester.getSemantics(button), isNotNull);
    semantics.dispose();
    await tester.tap(button);
    expect(starts, 1);
    await tester.pump();
    expect(logo.phase, WelcomeLogoPhase.done);
    expect(_shownProgress(tester), 1);
  });

  for (final mode in ['accessibleNavigation', 'disableAnimations']) {
    testWidgets('§10.8 reduce motion ($mode): full logo on frame 0',
        (tester) async {
      await pumpAt(
        tester,
        harness(
          accessibleNavigation: mode == 'accessibleNavigation',
          disableAnimations: mode == 'disableAnimations',
        ),
        const Size(466, 678),
      );
      expect(_shownProgress(tester), 1);
      await tester.pump();
      expect(logo.phase, WelcomeLogoPhase.done);
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('§10.9 logoWritten persisted: cold start shows it static',
      (tester) async {
    logo.dispose();
    store = _MemoryStore(true);
    logo = WelcomeLogoController(store: store);
    await logo.restore();
    await pumpAt(tester, harness(), const Size(466, 678));
    expect(logo.phase, WelcomeLogoPhase.done);
    expect(_shownProgress(tester), 1);
    expect(store.writes, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(_shownProgress(tester), 1);
  });

  testWidgets('§10.10 theme change and remount at 500 ms do not restart',
      (tester) async {
    await pumpAt(tester, harness(), const Size(466, 678));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final before = logo.progress;
    expect(before, closeTo(0.5, 0.02));

    await tester.pumpWidget(harness(theme: buildDarkTheme()));
    await tester.pump(const Duration(milliseconds: 16));
    expect(logo.progress, greaterThanOrEqualTo(before));

    await tester.pumpWidget(harness(welcomeKey: const ValueKey('remount')));
    expect(_shownProgress(tester), greaterThanOrEqualTo(before));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 520));
    expect(logo.phase, WelcomeLogoPhase.done);
  });
}
