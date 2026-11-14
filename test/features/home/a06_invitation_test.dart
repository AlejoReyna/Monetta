import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/features/home/home_account_invitation.dart';
import '../../support/bundled_fonts.dart';

void main() {
  setUpAll(loadBundledFonts);
  testWidgets('validates and retains email after access failure',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: HomeAccountInvitation(
                    onRegister: null,
                    onEmailRegister: (email) async {
                      calls++;
                      return 'No disponible';
                    })))));
    await tester.tap(find.text('Registrarme'));
    await tester.pump();
    expect(find.text('Introduce un correo válido.'), findsOneWidget);
    expect(calls, 0);
    await tester.enterText(find.byType(TextField), 'shopper@example.com');
    await tester.tap(find.text('Registrarme'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('No disponible'), findsOneWidget);
    expect(find.text('shopper@example.com'), findsOneWidget);
  });
  testWidgets('keyboard submit is serialized and cancellation retains email',
      (tester) async {
    final result = Completer<String?>();
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: HomeAccountInvitation(
                onRegister: null,
                onEmailRegister: (email) {
                  calls++;
                  return result.future;
                }))));
    await tester.enterText(find.byType(TextField), ' shopper@example.com ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(calls, 1);
    result.complete(
        null); // Cancel/return from the real access flow, no success claim.
    await tester.pumpAndSettle();
    expect(find.text(' shopper@example.com '), findsOneWidget);
    expect(find.textContaining('registrado'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets('three C5 lines fit individually at 320 base scale',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: HomeAccountInvitation(onRegister: () {}))));
    for (final text in [
      'Regístrate en MONETTA REWARDS',
      'ENVÍO GRATIS para siempre',
      'GANA CASHBACK con cada compra'
    ]) {
      final rich = find.byWidgetPredicate(
          (widget) => widget is RichText && widget.text.toPlainText() == text);
      expect(rich, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(rich);
      final lines = paragraph
          .getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: text.length))
          .map((box) => box.top)
          .toSet();
      final top = lines.reduce((a, b) => a < b ? a : b);
      final bottom = lines.reduce((a, b) => a > b ? a : b);
      expect(bottom - top, lessThan(12), reason: text);
    }
  });
}
