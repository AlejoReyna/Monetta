import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/customer_auth/customer_graphql_client.dart';
import 'package:monetta_app/data/shopify/shop_policy_repository.dart';
import 'package:monetta_app/features/help/policy_reader.dart';
import 'package:monetta_app/features/checkout/purchase_notices.dart';
import 'package:monetta_app/features/boutique/client_guide_sections.dart';

void main() {
  testWidgets(
      'failure retries, unpublished is hidden, safe policy links return',
      (tester) async {
    var attempts = 0;
    final controller = PolicyController(() async {
      if (++attempts == 1) throw Exception('fixture');
      return {
        ShopPolicyKind.shipping: CapabilityRead.supported(ShopPolicyContent(
            id: 'fixture',
            kind: ShopPolicyKind.shipping,
            title: 'Envíos vigentes',
            bodyHtml:
                '<p>Contenido de prueba</p><script>hidden script</script><a href="javascript:alert(1)">unsafe</a><a href="/help">ayuda externa</a>',
            url: Uri.parse('https://fixture.example/policy'))),
        ShopPolicyKind.privacy: const CapabilityRead.unavailable('withdrawn'),
      };
    });
    addTearDown(controller.dispose);
    await controller.refresh();
    await tester.pumpWidget(MaterialApp(
        home: PolicyScope(
            controller: controller,
            child: Scaffold(
                body: ClientGuideFooter(
                    onContact: () {}, onAbout: () {}, onWholesale: () {})))));
    expect(find.text('Privacidad'), findsNothing);
    expect(find.text('Reintentar políticas'), findsOneWidget);
    await tester.tap(find.text('Reintentar políticas'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Envíos'), findsOneWidget);
    await tester.tap(find.text('Envíos'));
    await tester.pumpAndSettle();
    expect(find.text('Contenido de prueba'), findsOneWidget);
    expect(find.text('hidden script'), findsNothing);
    expect(find.widgetWithText(TextButton, 'unsafe'), findsNothing);
    expect(find.widgetWithText(TextButton, 'ayuda externa'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Envíos'), findsOneWidget);
  });
  testWidgets('approved FAQ expands and collapses', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: HelpScreen(questions: [
      HelpQuestion(question: 'Pregunta fixture', answer: 'Respuesta fixture')
    ])));
    expect(find.text('Respuesta fixture'), findsNothing);
    await tester.tap(find.text('Pregunta fixture'));
    await tester.pumpAndSettle();
    expect(find.text('Respuesta fixture'), findsOneWidget);
    await tester.tap(find.text('Pregunta fixture'));
    await tester.pumpAndSettle();
    expect(find.text('Respuesta fixture'), findsNothing);
  });
  testWidgets('withdrawn content becomes unavailable on reopening',
      (tester) async {
    var published = true;
    final controller = PolicyController(() async => {
          ShopPolicyKind.shipping: published
              ? CapabilityRead.supported(ShopPolicyContent(
                  id: 'fixture',
                  kind: ShopPolicyKind.shipping,
                  title: 'Envíos',
                  bodyHtml: '<p>Texto fixture</p>',
                  url: Uri.parse('https://fixture.example/policy')))
              : const CapabilityRead.unavailable('withdrawn')
        });
    addTearDown(controller.dispose);
    await controller.refresh();
    await tester.pumpWidget(MaterialApp(
        home: PolicyScope(
            controller: controller,
            child: Scaffold(
                body: Builder(
                    builder: (context) => TextButton(
                        onPressed: () =>
                            openPolicy(context, ShopPolicyKind.shipping),
                        child: const Text('Abrir')))))));
    published = false;
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Esta política no está disponible.'), findsOneWidget);
    expect(find.text('Texto fixture'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Abrir'), findsOneWidget);
  });
  testWidgets('checkout notice links only published policy', (tester) async {
    final controller = PolicyController(() async => {
          ShopPolicyKind.shipping: CapabilityRead.supported(ShopPolicyContent(
              id: 'fixture',
              kind: ShopPolicyKind.shipping,
              title: 'Envíos fixture',
              bodyHtml: '<p>Texto fixture</p>',
              url: Uri.parse('https://fixture.example/policy'))),
          ShopPolicyKind.refund: const CapabilityRead.unavailable('withdrawn')
        });
    addTearDown(controller.dispose);
    await controller.refresh();
    await tester.pumpWidget(MaterialApp(
        home: PolicyScope(
            controller: controller,
            child: const Scaffold(body: PurchasePolicyNotice()))));
    expect(find.text('Envíos'), findsOneWidget);
    expect(find.text('Cambios y devoluciones'), findsNothing);
    await tester.tap(find.text('Envíos'));
    await tester.pumpAndSettle();
    expect(find.text('Texto fixture'), findsOneWidget);
  });
}
