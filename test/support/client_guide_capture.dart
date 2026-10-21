import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/theme.dart';

import 'bundled_fonts.dart';

const clientGuideCaptureKey = ValueKey('client-guide-capture');

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
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: RepaintBoundary(key: clientGuideCaptureKey, child: screen),
    ),
  );
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      if (image.image is AssetImage) {
        await precacheImage(image.image, element, onError: (_, __) {});
      }
    }
  });
  await tester.pumpAndSettle();
}

/// Optional review evidence, never updates or approves reference goldens.
Future<void> captureClientGuide(WidgetTester tester, String name) async {
  final directory = Platform.environment['MONETTA_M4_CAPTURE_DIR'] ??
      Platform.environment['MONETTA_M3_CAPTURE_DIR'] ??
      Platform.environment['MONETTA_M2_CAPTURE_DIR'];
  if (directory == null) return;
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final widget = element.widget as Image;
      if (widget.image is AssetImage) {
        await precacheImage(widget.image, element, onError: (_, __) {});
      }
    }
  });
  await tester.pumpAndSettle();
  final boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(clientGuideCaptureKey));
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
