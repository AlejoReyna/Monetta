import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/theme.dart';

import 'bundled_fonts.dart';

const clientGuideCaptureKey = ValueKey('client-guide-capture');

/// Network stills in widget tests never resolve. Bound the wait so a caret
/// or a retry timer cannot hold a capture for the whole test timeout.
Future<void> _precacheImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      try {
        await precacheImage(image.image, element, onError: (_, __) {}).timeout(
          const Duration(seconds: 2),
        );
      } on Object {
        // A missing still is not a reason to hang the harness.
      }
    }
  });
}

Future<void> _settleBriefly(WidgetTester tester) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );
  } on FlutterError {
    await tester.pump();
  }
}

Future<void> pumpClientGuide(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(390, 844),
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.runAsync(() async {
    await loadBundledFonts();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme:
          brightness == Brightness.dark ? buildDarkTheme() : buildLightTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: RepaintBoundary(key: clientGuideCaptureKey, child: screen),
    ),
  );
  await _precacheImages(tester);
  await _settleBriefly(tester);
}

/// Optional review evidence, never updates or approves reference goldens.
Future<void> captureClientGuide(WidgetTester tester, String name) async {
  final directory = Platform.environment['MONETTA_1TO1_CAPTURE_DIR'] ??
      Platform.environment['MONETTA_M4_CAPTURE_DIR'] ??
      Platform.environment['MONETTA_M3_CAPTURE_DIR'] ??
      Platform.environment['MONETTA_M2_CAPTURE_DIR'];
  if (directory == null) return;
  await _precacheImages(tester);
  await tester.pump();
  await _expandToFullContent(tester);
  // Expanding builds the rows that were below the fold; their stills have
  // not been decoded yet and would be captured blank.
  await _precacheImages(tester);
  await tester.pump();
  // The home [RepaintBoundary] does not include modal routes. Paint the
  // render view so a quick-view sheet is in the file.
  final renderView = tester.binding.renderViews.first;
  await tester.runAsync(() async {
    final layer = renderView.debugLayer! as OffsetLayer;
    final ratio = 1 / renderView.flutterView.devicePixelRatio;
    final image = await layer.toImage(
      renderView.paintBounds,
      pixelRatio: ratio,
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

/// Grows the test surface until the tallest vertical scroller fits, so the
/// PNG is the whole page rather than the first 844 px.
Future<void> _expandToFullContent(WidgetTester tester) async {
  for (final element in find.byType(Scrollable).evaluate()) {
    final scrollable = element.widget as Scrollable;
    if (scrollable.axis != Axis.vertical) continue;
    final state = (element as StatefulElement).state;
    if (state is! ScrollableState) continue;
    final position = state.position;
    if (position.hasPixels && position.pixels > 0) {
      position.jumpTo(position.minScrollExtent);
    }
  }
  await tester.pump();
  final width = tester.view.physicalSize.width;
  var height = tester.view.physicalSize.height;
  var previous = double.infinity;
  for (var pass = 0; pass < 8; pass++) {
    final extra = _tallestVerticalExtent();
    if (extra < 2) return;
    // A closed drawer or a scroller that ignores the new height keeps
    // reporting the same leftover. Stop instead of painting blank canvas.
    if (pass > 0 && extra >= previous - 1) return;
    previous = extra;
    final next = math.min(height + extra, 8000).toDouble();
    if (next <= height + 1) return;
    height = next;
    tester.view.physicalSize = Size(width, height);
    try {
      await tester.pumpAndSettle(
        const Duration(milliseconds: 50),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 3),
      );
    } on FlutterError {
      await tester.pump();
    }
  }
}

double _tallestVerticalExtent() {
  var extra = 0.0;
  for (final element in find.byType(Scrollable).evaluate()) {
    final scrollable = element.widget as Scrollable;
    if (scrollable.axis != Axis.vertical) continue;
    final render = element.renderObject;
    if (render is! RenderBox || !render.attached || !render.hasSize) continue;
    if (render.size.height < 48 || render.size.width < 48) continue;
    final origin = render.localToGlobal(Offset.zero);
    // Closed drawers sit off the left edge and must not stretch the page.
    if (origin.dx < -8) continue;
    final state = (element as StatefulElement).state;
    if (state is! ScrollableState) continue;
    final position = state.position;
    if (!position.hasContentDimensions) continue;
    extra = math.max(extra, position.maxScrollExtent);
  }
  return extra;
}
