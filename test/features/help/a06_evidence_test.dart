// All policy copy, links and callbacks in these captures are deterministic fixtures.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/customer_auth/customer_graphql_client.dart';
import 'package:monetta_app/data/shopify/shop_policy_repository.dart';
import 'package:monetta_app/features/boutique/client_guide_sections.dart';
import 'package:monetta_app/features/help/policy_reader.dart';
import 'package:monetta_app/features/home/home_account_invitation.dart';
import '../../support/client_guide_capture.dart';

Map<ShopPolicyKind, CapabilityRead<ShopPolicyContent>> fixture() => {
      for (final kind in ShopPolicyKind.values)
        kind: CapabilityRead.supported(ShopPolicyContent(
            id: 'fixture-${kind.name}',
            kind: kind,
            title: 'Política fixture ${kind.name}',
            bodyHtml:
                '<h2>Contenido de prueba</h2><p>Una política publicada de ejemplo con un <a href="/help">enlace de prueba</a>.</p>',
            url: Uri.parse('https://fixture.example/policy'))),
    };
void main() {
  for (final (width, scale, brightness) in [
    (320.0, 2.0, Brightness.light),
    (390.0, 1.0, Brightness.light),
    (834.0, 1.0, Brightness.light),
    (1440.0, 2.0, Brightness.dark)
  ]) {
    testWidgets('footer and policy fixture $width $scale $brightness',
        (tester) async {
      final controller = PolicyController(() async => fixture());
      addTearDown(controller.dispose);
      await controller.refresh();
      await pumpClientGuide(
          tester,
          PolicyScope(
              controller: controller,
              child: Scaffold(
                  body: SingleChildScrollView(
                      child: ClientGuideFooter(
                          onContact: () {},
                          onAbout: () {},
                          onWholesale: () {})))),
          size: Size(width, 1000),
          textScale: scale,
          brightness: brightness);
      for (final label in [
        'Contacto',
        'Envíos',
        'Cambios y devoluciones',
        'Mayoreo',
        'Privacidad',
        'Términos'
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      await captureClientGuide(tester,
          'fixture-footer-${width.toInt()}-${scale.toInt()}x-${brightness.name}');
      await tester.ensureVisible(find.text('Envíos'));
      await tester.tap(find.text('Envíos'));
      await tester.pumpAndSettle();
      expect(find.text('Contenido de prueba'), findsOneWidget);
      await captureClientGuide(tester,
          'fixture-policy-${width.toInt()}-${scale.toInt()}x-${brightness.name}');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('keyboard route return restores trigger focus', (tester) async {
    final controller = PolicyController(() async => fixture());
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await controller.refresh();
    await tester.pumpWidget(MaterialApp(
        home: PolicyScope(
            controller: controller,
            child: Scaffold(
                body: Builder(
                    builder: (context) => TextButton(
                        focusNode: focus,
                        onPressed: () =>
                            openPolicy(context, ShopPolicyKind.shipping),
                        child: const Text('Abrir política')))))));
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Contenido de prueba'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isTrue);
  });
  testWidgets('failed link shows error without navigation', (tester) async {
    final controller = PolicyController(() async => fixture());
    addTearDown(controller.dispose);
    await controller.refresh();
    await tester.pumpWidget(MaterialApp(
        home: PolicyReader(
            kind: ShopPolicyKind.shipping,
            controller: controller,
            openLink: (_) async => false)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('enlace de prueba'));
    await tester.pump();
    expect(find.text('No se pudo abrir el enlace.'), findsOneWidget);
    expect(find.text('Contenido de prueba'), findsOneWidget);
  });
  testWidgets('opaque reduced motion registration remains interactive',
      (tester) async {
    // The shared primitive owns the glass fallback; this fixture exercises it
    // under the platform settings used by the real footer.
    final controller = PolicyController(() async => fixture());
    addTearDown(controller.dispose);
    await controller.refresh();
    await pumpClientGuide(
        tester,
        Builder(
            builder: (context) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(highContrast: true, disableAnimations: true),
                  child: PolicyScope(
                      controller: controller,
                      child: Scaffold(
                          body: Column(children: [
                        HomeAccountInvitation(
                            onRegister: null,
                            onEmailRegister: (_) async => null),
                        ClientGuideFooter(
                            onContact: () {},
                            onAbout: () {},
                            onWholesale: () {}),
                      ]))),
                )),
        size: const Size(390, 1000));
    await captureClientGuide(tester, 'fixture-footer-opaque-reduced-motion');
    expect(find.text('Contacto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
