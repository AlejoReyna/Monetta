import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/features/home/home_closing_section.dart';
import 'package:monetta_app/features/home/home_payment_methods.dart';

void main() {
  Widget app({
    required VoidCallback onRegister,
    double width = 390,
    bool isSignedIn = false,
    TargetPlatform? platform,
    VoidCallback? onOpenWhatsApp,
    ValueChanged<Uri>? onOpenUrl,
  }) {
    return MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            child: HomeClosingSection(
              onRegister: onRegister,
              isSignedIn: isSignedIn,
              platform: platform ?? TargetPlatform.android,
              onOpenWhatsApp: onOpenWhatsApp,
              onOpenUrl: onOpenUrl,
            ),
          ),
        ),
      ),
    );
  }

  void phone(WidgetTester tester, {Size size = const Size(800, 2000)}) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
  }

  test('payment config is one list and flags the guideline check', () {
    expect(
      kHomePaymentMethods.map((method) => method.id),
      <String>[
        'visa',
        'mastercard',
        'paypal',
        'mercado_pago',
        'bank_transfer',
        'apple_pay',
        'google_pay',
      ],
    );
    expect(
      kHomePaymentMethods.map((method) => method.id),
      isNot(contains('maestro')),
    );
    expect(
      kHomePaymentMethods.map((method) => method.id),
      isNot(contains('shop_pay')),
    );
    expect(
      kHomePaymentMethods
          .singleWhere((method) => method.id == 'bank_transfer')
          .variant,
      PaymentLogoVariant.monochrome,
    );
    expect(
      kHomePaymentMethods
          .where((method) => method.variant == PaymentLogoVariant.officialColor)
          .map((method) => method.id)
          .toSet(),
      kHomePaymentMethodsNeedingGuidelineCheck,
    );
    expect(kHomeOriginalsPromise, 'Originales garantizados');
  });

  testWidgets('presents the first-order benefit and account action', (
    tester,
  ) async {
    phone(tester);
    var registerCalls = 0;
    await tester.pumpWidget(app(onRegister: () => registerCalls++));

    expect(find.text('OBTÉN TU PRIMER ENVÍO GRATIS'), findsOneWidget);
    expect(find.text('Porque tú lo vales'), findsOneWidget);
    expect(find.textContaining(':)'), findsNothing);
    expect(find.text('Aplica en tu primera compra.'), findsOneWidget);
    expect(find.text(kHomeOriginalsPromise), findsOneWidget);
    expect(find.text('Envíos rápidos a todo México'), findsOneWidget);
    expect(find.text('Pagos seguros'), findsOneWidget);
    expect(find.text('¿Dudas? Escríbenos por WhatsApp'), findsOneWidget);
    expect(find.text(kHomeFooterCopyright), findsOneWidget);

    final button = find.byKey(const ValueKey('home-register-button'));
    expect(tester.getSize(button).height, 52);
    final material = tester.widget<Material>(
      find.descendant(of: button, matching: find.byType(Material)),
    );
    expect(material.borderRadius, const BorderRadius.all(Radius.circular(4)));
    expect(
      tester.getSize(find.byKey(const ValueKey('home-signup-gold-line'))).width,
      40,
    );

    await tester.tap(button);
    expect(registerCalls, 1);
  });

  testWidgets('uses account copy instead of registration copy when signed in', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(app(onRegister: () {}, isSignedIn: true));

    expect(find.text('TU CUENTA'), findsOneWidget);
    expect(find.text('VER MI CUENTA'), findsOneWidget);
    expect(find.text('OBTÉN TU PRIMER ENVÍO GRATIS'), findsNothing);
    expect(find.text('Aplica en tu primera compra.'), findsNothing);
  });

  testWidgets('scrolls payment marks without boxes, one wallet per platform', (
    tester,
  ) async {
    phone(tester, size: const Size(800, 2000));
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      app(onRegister: () {}, width: 320, platform: TargetPlatform.android),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('home-payment-methods')))
          .label,
      'Métodos de pago: Visa, Mastercard, PayPal, Mercado Pago, '
      'Transferencia y Google Pay',
    );
    expect(
      find.byKey(const ValueKey('home-payment-logo-google_pay')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-payment-logo-apple_pay')),
      findsNothing,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('home-payment-logo-visa')))
          .height,
      kHomePaymentLogoHeight,
    );
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('home-payment-logo-bank_transfer')),
          )
          .height,
      kHomePaymentLogoHeight,
    );
    expect(
      tester.widget<Text>(find.text('VISA')).style!.color,
      const Color(0xFF1434CB),
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.account_balance_outlined)).color,
      kPaymentMonochrome,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-payment-methods')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color != null,
        ),
      ),
      findsNothing,
    );
    semantics.dispose();
  });

  testWidgets('iOS shows Apple Pay in black and hides Google Pay', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(
      app(onRegister: () {}, platform: TargetPlatform.iOS),
    );

    expect(
      find.byKey(const ValueKey('home-payment-logo-apple_pay')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-payment-logo-google_pay')),
      findsNothing,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.apple)).color,
      const Color(0xFF000000),
    );
  });

  testWidgets('iPad centers the closing column at a 720 max width', (
    tester,
  ) async {
    phone(tester, size: const Size(1024, 2000));
    await tester.pumpWidget(app(onRegister: () {}, width: 1024));

    final column = find.byKey(const ValueKey('home-closing-column'));
    expect(tester.getSize(column).width, 720);
    expect(tester.getCenter(column).dx, closeTo(512, 1));
  });

  testWidgets('WhatsApp, privacy, and terms use the configured targets', (
    tester,
  ) async {
    phone(tester);
    var whatsapp = 0;
    final opened = <Uri>[];
    await tester.pumpWidget(
      app(
        onRegister: () {},
        onOpenWhatsApp: () => whatsapp++,
        onOpenUrl: opened.add,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('home-whatsapp-link')));
    await tester.tap(find.byKey(const ValueKey('home-footer-privacy')));
    await tester.tap(find.byKey(const ValueKey('home-footer-terms')));
    await tester.tap(find.byKey(const ValueKey('home-social-instagram')));
    await tester.pump();

    expect(whatsapp, 1);
    expect(opened, contains(Uri.parse(kHomePrivacyPolicyUrl)));
    expect(opened, contains(Uri.parse(kHomeTermsUrl)));
    expect(
      opened.map((uri) => uri.toString()),
      contains('https://www.instagram.com/_monetta.mx'),
    );
  });
}
