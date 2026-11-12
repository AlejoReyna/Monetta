// Fixture-only viewport captures, not production content or approved goldens.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/features/contact/contact_screen.dart';
import 'package:monetta_app/features/wholesale/wholesale_screen.dart';
import '../../support/client_guide_capture.dart';

Future<void> captureViewport(WidgetTester tester, String name) async {
  final directory = Platform.environment['MONETTA_1TO1_CAPTURE_DIR'];
  if (directory == null) return;
  await tester.pump();
  final renderView = tester.binding.renderViews.first;
  await tester.runAsync(() async {
    final image = await (renderView.debugLayer! as OffsetLayer)
        .toImage(renderView.paintBounds, pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  for (final (width, scale, brightness) in [
    (320.0, 2.0, Brightness.light),
    (390.0, 1.0, Brightness.light),
    (834.0, 1.0, Brightness.light),
    (1440.0, 2.0, Brightness.dark)
  ]) {
    for (final page in ['contact', 'wholesale']) {
      testWidgets('viewport $page $width $scale $brightness', (tester) async {
        final groups = {
          'grupo-1': Uri.parse('https://fixture.example/1'),
          'grupo-2': Uri.parse('https://fixture.example/2'),
          'facebook-group': Uri.parse('https://fixture.example/3')
        };
        final screen = page == 'contact'
            ? ContactScreen(groups: groups, openUri: (_) async => true)
            : WholesaleScreen(
                groups: groups,
                openUri: (_) async => true,
                onEmailRegister: (_) async => null);
        await pumpClientGuide(tester, screen,
            size: Size(width, 900), textScale: scale, brightness: brightness);
        final prefix =
            'viewport-$page-${width.toInt()}-${scale.toInt()}x-${brightness.name}';
        await captureViewport(tester, '$prefix-hero');
        final list = find
            .descendant(
                of: find.byKey(ValueKey('$page-scroll')),
                matching: find.byType(Scrollable))
            .first;
        if (page == 'wholesale') {
          final card = find.byKey(const ValueKey('wholesale-step-0'));
          await tester.scrollUntilVisible(card, 150, scrollable: list);
          await tester.pumpAndSettle();
          await captureViewport(tester, '$prefix-steps-start');
          final horizontal = find
              .byWidgetPredicate((w) =>
                  w is SingleChildScrollView &&
                  w.scrollDirection == Axis.horizontal)
              .first;
          await tester.drag(horizontal, const Offset(-220, 0));
          await tester.pumpAndSettle();
          await captureViewport(tester, '$prefix-steps-middle');
          await tester.drag(horizontal, const Offset(-600, 0));
          await tester.pumpAndSettle();
          await captureViewport(tester, '$prefix-steps-end');
        }
        final target = page == 'contact'
            ? find.text('Únete')
            : find.text('Comienza a vender');
        await tester.scrollUntilVisible(target, 200, scrollable: list);
        await tester.pumpAndSettle();
        await captureViewport(tester, '$prefix-community');
        if (page == 'wholesale') {
          await tester.scrollUntilVisible(
              find.byKey(const ValueKey('home-account-invitation')), 250,
              scrollable: list);
          await tester.pumpAndSettle();
          await captureViewport(tester, '$prefix-end');
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
