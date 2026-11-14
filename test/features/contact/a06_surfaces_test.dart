import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/features/contact/contact_screen.dart';
import 'package:monetta_app/features/wholesale/wholesale_screen.dart';
import 'package:monetta_app/features/home/home_account_invitation.dart';
import '../../support/client_guide_capture.dart';

void main() {
  for (final spec in [
    (320.0, 1.0, Brightness.light),
    (320.0, 2.0, Brightness.light),
    (390.0, 1.0, Brightness.light),
    (768.0, 1.0, Brightness.light),
    (768.0, 2.0, Brightness.light),
    (834.0, 2.0, Brightness.light),
    (1440.0, 1.0, Brightness.light),
    (1440.0, 2.0, Brightness.light),
    (1440.0, 2.0, Brightness.dark),
    (390.0, 1.0, Brightness.dark)
  ]) {
    for (final page in ['contact', 'wholesale', 'registration']) {
      testWidgets('fixture $page ${spec.$1} ${spec.$2} ${spec.$3}',
          (tester) async {
        final screen = switch (page) {
          'contact' => ContactScreen(groups: {
              'grupo-1': Uri.parse('https://fixture.example/group1'),
              'grupo-2': Uri.parse('https://fixture.example/group2'),
              'facebook-group': Uri.parse('https://fixture.example/facebook')
            }, openUri: (_) async => true),
          'wholesale' => WholesaleScreen(groups: {
              'grupo-1': Uri.parse('https://fixture.example/group1'),
              'grupo-2': Uri.parse('https://fixture.example/group2')
            }, onEmailRegister: (_) async => null, openUri: (_) async => true),
          _ => Scaffold(
              body: SingleChildScrollView(
                  child: HomeAccountInvitation(
                      onRegister: null, onEmailRegister: (_) async => null))),
        };
        await pumpClientGuide(tester, screen,
            size: Size(spec.$1, 1000), textScale: spec.$2, brightness: spec.$3);
        expect(tester.takeException(), isNull);
        await captureClientGuide(tester,
            'fixture-$page-${spec.$1.toInt()}-${spec.$2.toInt()}x-${spec.$3.name}');
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('contact only opens explicit channel and preserves return',
      (tester) async {
    final opened = <Uri>[];
    await pumpClientGuide(tester, ContactScreen(openUri: (uri) async {
      opened.add(uri);
      return true;
    }));
    expect(opened, isEmpty);
    expect(find.byKey(const ValueKey('contact-channel-grupo-1')), findsNothing);
    await tester
        .ensureVisible(find.byKey(const ValueKey('contact-channel-whatsapp')));
    await tester.tap(find.byKey(const ValueKey('contact-channel-whatsapp')));
    await tester.pump();
    expect(opened.single, Uri.parse('https://wa.me/528261066868'));
    expect(opened.single.query, isEmpty);
  });
  testWidgets('wholesale steps remain horizontal at enlarged text',
      (tester) async {
    await pumpClientGuide(tester, const WholesaleScreen(),
        size: const Size(320, 850), textScale: 2);
    final scroll = find.byWidgetPredicate((w) =>
        w is SingleChildScrollView && w.scrollDirection == Axis.horizontal);
    expect(scroll, findsWidgets);
    expect(find.text('Elige tus productos'), findsOneWidget);
    await tester.ensureVisible(scroll.first);
    await tester.pumpAndSettle();
    final position = tester
        .state<ScrollableState>(find
            .descendant(of: scroll.first, matching: find.byType(Scrollable))
            .first)
        .position;
    expect(position.maxScrollExtent, greaterThan(0));
    await tester.drag(scroll.first, const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
    expect(find.text('Consulta el pago'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('normal 320px C5 WhatsApp label fits one line', (tester) async {
    await pumpClientGuide(tester, ContactScreen(openUri: (_) async => true),
        size: const Size(320, 1000));
    final label = find.text('Enviar Whatsapp al 826 106 6868');
    final rich = find.descendant(of: label, matching: find.byType(RichText));
    final paragraph = tester.renderObject<RenderParagraph>(rich.first);
    expect(
        paragraph
            .getBoxesForSelection(
                const TextSelection(baseOffset: 0, extentOffset: 31))
            .map((box) => box.top)
            .toSet(),
        hasLength(1));
  });
  testWidgets(
      'received reservation copy is review-only, without operational action',
      (tester) async {
    await pumpClientGuide(
        tester, const WholesaleScreen(showUnapprovedEditorial: true),
        size: const Size(390, 1000));
    expect(find.textContaining(r'$800'), findsOneWidget);
    expect(find.textContaining('20 días'), findsOneWidget);
    expect(find.byKey(const ValueKey('wholesale-step-2')), findsOneWidget);
  });
  testWidgets('wholesale footer returns to its hero', (tester) async {
    await pumpClientGuide(tester, const WholesaleScreen(),
        size: const Size(390, 1000));
    final list = find
        .descendant(
            of: find.byKey(const ValueKey('wholesale-scroll')),
            matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.text('Mayoreo'), 400,
        scrollable: list);
    await tester.ensureVisible(find.text('Mayoreo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mayoreo'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const ValueKey('wholesale-step-0'))).dy,
        greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}
