import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/main.dart';

import 'bundled_fonts.dart';
import 'e_t1_text_scaler.dart';
import 'product_screen_harness.dart' show mockPathProvider;

/// UI-03 matrix: a screen is mounted at two phone sizes and three text scales
/// with the real Inter and Playfair Display faces, scrolled to its end in
/// bounded steps, and any `FlutterError` (overflow included) fails the case.
///
/// The text scale is the policy oracle ([PolicyTextScaler]) so the layout is
/// the one the app root will produce once RF-17 lands, and the matrix does not
/// depend on any `lib/` class that implements it.

/// Phones in logical pixels, at a device pixel ratio of 3.0.
const List<Size> kPhones = <Size>[Size(375, 812), Size(440, 956)];

/// System scales: 1.0, 1.3 and 1.5 (the global cap of E-T1).
const List<double> kMatrixScales = <double>[1.0, 1.3, 1.5];

/// Builds the screen under test. [store] is the asset catalog.
typedef ScreenBuilder = Future<Widget> Function(
  WidgetTester tester,
  CatalogStore store,
);

/// Hook that runs after the first scroll pass, for screens with a second step.
typedef AfterScroll = Future<void> Function(WidgetTester tester);

/// Registers the 2 x 3 cases of one screen under the names
/// `UI-03 <screen> <w>x<h> @<k>`. Call it from `main()`.
///
/// [anchor] finds something that proves the screen really painted its content
/// (not an empty shell), so a green case is not a vacuous one.
void registerTextScaleMatrix(
  String screen,
  ScreenBuilder build, {
  required Finder Function(CatalogStore store) anchor,
  AfterScroll? afterScroll,
}) {
  for (final phone in kPhones) {
    for (final k in kMatrixScales) {
      final name =
          'UI-03 $screen ${phone.width.toInt()}x${phone.height.toInt()} @$k';
      testWidgets(name, (tester) async {
        _phoneView(tester, phone);
        mockPathProvider();
        final log = _ErrorLog.install();

        final store = CatalogStore(database: openTestDatabase());
        addTearDown(store.dispose);
        await store.loadFromAsset();

        try {
          final home = await build(tester, store);
          await tester.pumpWidget(_app(store, home, k));
          await _settle(tester, name, log);
          log.restore();
          expect(
            anchor(store),
            findsWidgets,
            reason: '$name: the screen did not paint its content.',
          );
          log.reinstall();

          await _scrollThrough(tester, name, log);
          if (afterScroll != null) {
            await afterScroll(tester);
            _failOnError(tester, name, log, 'after the second step');
            await _scrollThrough(tester, name, log);
          }
        } finally {
          log.restore();
        }
      });
    }
  }
}

/// Loads the real faces once per test file. Call it from `main()`.
void useBundledFonts() {
  setUpAll(loadBundledFonts);
}

void _phoneView(WidgetTester tester, Size logical) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = logical * 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(CatalogStore store, Widget home, double k) {
  return StoreScope(
    notifier: store,
    child: MaterialApp(
      theme: buildLightTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: PolicyTextScaler(k)),
        child: child!,
      ),
      home: home,
    ),
  );
}

/// Bounded frames instead of `pumpAndSettle`: shimmers and carousels never
/// settle.
Future<void> _settle(
  WidgetTester tester,
  String name,
  _ErrorLog log,
) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    _failOnError(tester, name, log, 'while mounting');
  }
}

/// Pumps a few frames, for the hook of a multi-step screen.
Future<void> pumpFrames(WidgetTester tester, [int frames = 6]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The outermost vertical scrollable: the screen's main content.
Finder _mainScrollable() => find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .first;

/// Scrolls the main content to its end in steps of 70% of the viewport, and
/// checks for errors after every step. The extent of a lazy list is an
/// estimate until its tail is built, so the loop runs until it is stable.
Future<void> _scrollThrough(
  WidgetTester tester,
  String name,
  _ErrorLog log,
) async {
  if (_mainScrollable().evaluate().isEmpty) return;
  final state = tester.state<ScrollableState>(_mainScrollable());
  final position = state.position;
  final step = position.viewportDimension * 0.7;
  position.jumpTo(position.minScrollExtent);
  await tester.pump();
  _failOnError(tester, name, log, 'at the top');

  for (var i = 0; i < 80; i++) {
    final before = position.pixels;
    final target = (before + step).clamp(0.0, position.maxScrollExtent);
    position.jumpTo(target);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    _failOnError(
      tester,
      name,
      log,
      'after scrolling to ${position.pixels.toStringAsFixed(0)} of '
      '${position.maxScrollExtent.toStringAsFixed(0)}',
    );
    if (position.pixels >= position.maxScrollExtent - 0.5 &&
        position.pixels == before) {
      return;
    }
  }
  fail('$name: the main content never reached a stable end in 80 steps.');
}

/// Routes every `FlutterError` of the test into a list instead of the
/// framework's single pending-exception slot, which keeps only a counter once
/// two errors land in the same frame.
///
/// The handler must be put back before the test fails: `fail` reports through
/// `FlutterError.onError`, and a swallowed failure hangs the test.
class _ErrorLog {
  _ErrorLog._(this._previous);

  factory _ErrorLog.install() {
    final log = _ErrorLog._(FlutterError.onError);
    FlutterError.onError = log.errors.add;
    addTearDown(log.restore);
    return log;
  }

  final List<FlutterErrorDetails> errors = <FlutterErrorDetails>[];
  final void Function(FlutterErrorDetails)? _previous;

  void restore() => FlutterError.onError = _previous;

  void reinstall() => FlutterError.onError = errors.add;
}

void _failOnError(
  WidgetTester tester,
  String name,
  _ErrorLog log,
  String when,
) {
  final pending = tester.takeException();
  if (pending != null) {
    log.restore();
    fail('$name: unexpected pending exception ($when): $pending');
  }
  final errors = log.errors;
  if (errors.isEmpty) return;
  log.restore();

  final sites = <String, int>{};
  for (final details in errors) {
    sites.update(_site(details), (n) => n + 1, ifAbsent: () => 1);
  }
  final first = errors.first;
  fail(
    '$name: ${_firstLine(first)} ($when)\n'
    '    first error site: ${_site(first)}\n'
    '    ${errors.length} error(s) in total at ${sites.length} site(s): '
    '${sites.entries.map((e) => '${e.key} x${e.value}').take(6).join('; ')}\n'
    '    families painted on this screen: ${_families(tester)}',
  );
}

List<String> _deepLines(FlutterErrorDetails details) =>
    details.toDiagnosticsNode().toStringDeep().trim().split('\n');

String _firstLine(FlutterErrorDetails details) {
  final exception = details.exception;
  if (exception is FlutterError) {
    return exception.toString().trim().split('\n').first;
  }
  return '$exception'.split('\n').first;
}

/// The widget the framework blames, as `Column@lib/features/x.dart:316`.
String _site(FlutterErrorDetails details) {
  final lines = _deepLines(details);
  final blame = lines.indexWhere((l) => l.contains('error-causing widget'));
  if (blame < 0 || blame + 2 >= lines.length) return _firstLine(details);
  final located = lines[blame + 2].trim();
  final match =
      RegExp(r'^(\S+?):file:///.*?/(lib/.*?):(\d+):\d+$').firstMatch(located);
  return match == null
      ? located
      : '${match.group(1)}@${match.group(2)}:${match.group(3)}';
}

/// How many paragraphs use each declared font family, to tell text drawn with
/// a face the test registers (Inter, Playfair Display) from text drawn with
/// the test font (Helvetica Neue, New York, Roboto...).
String _families(WidgetTester tester) {
  final counts = <String, int>{};
  for (final element in find.byType(RichText).evaluate()) {
    final render = element.renderObject;
    if (render is! RenderParagraph) continue;
    final text = render.text.toPlainText();
    // Icon glyphs live in the private-use area.
    if (text.isNotEmpty &&
        text.runes.every((r) => r >= 0xE000 && r <= 0xF8FF)) {
      continue;
    }
    final family = render.text.style?.fontFamily ?? '(default)';
    counts[family] = (counts[family] ?? 0) + 1;
  }
  return counts.entries.map((e) => '${e.key} x${e.value}').join(', ');
}
