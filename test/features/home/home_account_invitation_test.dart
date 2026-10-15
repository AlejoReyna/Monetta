import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/features/boutique/boutique_tokens.dart';
import 'package:monetta_app/features/home/home_closing_section.dart';
import 'package:monetta_app/features/home/home_payment_methods.dart';

void main() {
  Widget app({
    required VoidCallback onRegister,
    double width = 390,
    bool isSignedIn = false,
    TargetPlatform? platform,
    bool expressPayLogosEnabled = kExpressPayLogosEnabled,
    bool paymentLogoRowEnabled = kPaymentLogoRowEnabled,
    VoidCallback? onOpenWhatsApp,
    ValueChanged<Uri>? onOpenUrl,
    TextScaler? textScaler,
  }) {
    return MaterialApp(
      theme: buildTheme(),
      builder: textScaler == null
          ? null
          : (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                child: child!,
              );
            },
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            child: HomeClosingSection(
              onRegister: onRegister,
              isSignedIn: isSignedIn,
              platform: platform ?? TargetPlatform.android,
              expressPayLogosEnabled: expressPayLogosEnabled,
              paymentLogoRowEnabled: paymentLogoRowEnabled,
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
    expect(kHomePaymentLogoHeight, 24);
    expect(kExpressPayLogosEnabled, isFalse);
    expect(kPaymentLogoRowEnabled, isFalse);
    final (lead, rest) = homePaymentMethodsLineParts();
    expect(lead, kHomePaymentMethodsLineLead);
    expect('$lead$rest', kHomePaymentMethodsLine);
    expect(rest, isNotEmpty);
    expect(
      {
        for (final method in kHomePaymentMethods)
          method.id: method.clearSpaceFactor,
      },
      <String, double>{
        'visa': 0.5,
        'mastercard': 0.25,
        'paypal': 1,
        'mercado_pago': 1,
        'bank_transfer': 0.25,
        'apple_pay': 0.25,
        'google_pay': 0.5,
      },
    );
    expect(
      kHomePaymentMethods.singleWhere((method) => method.id == 'visa').variant,
      PaymentLogoVariant.officialColor,
    );
    expect(
      kHomePaymentMethods
          .where((method) => method.expressPay)
          .map((method) => method.id)
          .toSet(),
      <String>{'apple_pay', 'google_pay'},
    );
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

  testWidgets('scrolls payment marks without boxes while wallets stay off', (
    tester,
  ) async {
    phone(tester, size: const Size(800, 2000));
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      app(
        onRegister: () {},
        width: 320,
        platform: TargetPlatform.android,
        paymentLogoRowEnabled: true,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<ColoredBox>(
            find.byKey(const ValueKey('home-payment-strip')),
          )
          .color,
      kHomePaymentStripColor,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('home-payment-methods'))).height,
      kHomePaymentLogoHeight,
    );
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('home-payment-methods')))
          .label,
      'Métodos de pago: Visa, Mastercard, PayPal, Mercado Pago y Transferencia',
    );
    expect(
      find.byKey(const ValueKey('home-payment-logo-google_pay')),
      findsNothing,
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
      kVisaBlue,
    );
    expect(
      tester
          .widget<Padding>(
            find.byKey(const ValueKey('home-payment-logo-visa')),
          )
          .padding,
      const EdgeInsets.symmetric(horizontal: 12),
    );
    expect(
      tester
          .widget<Padding>(
            find.byKey(const ValueKey('home-payment-logo-mastercard')),
          )
          .padding,
      const EdgeInsets.symmetric(horizontal: 6),
    );
    expect(
      tester
          .widget<Padding>(
            find.byKey(const ValueKey('home-payment-logo-paypal')),
          )
          .padding,
      const EdgeInsets.symmetric(horizontal: 24),
    );
    expect(
      tester
          .widget<Padding>(
            find.byKey(const ValueKey('home-payment-logo-mercado_pago')),
          )
          .padding,
      const EdgeInsets.symmetric(horizontal: 24),
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

  testWidgets('logo row off shows the payment sentence', (tester) async {
    phone(tester);
    await tester.pumpWidget(app(onRegister: () {}));

    expect(find.byKey(const ValueKey('home-payment-strip')), findsNothing);
    expect(find.byKey(const ValueKey('home-payment-logo-visa')), findsNothing);
    final line = tester.widget<Text>(
      find.byKey(const ValueKey('home-payment-methods-line')),
    );
    final span = line.textSpan! as TextSpan;
    expect(line.textAlign, TextAlign.center);
    expect(line.maxLines, isNull);
    expect(line.overflow, isNull);
    expect(span.toPlainText(), kHomePaymentMethodsLine);
    expect(span.style!.fontFamily, kBoutiqueSansFamily);
    expect(span.style!.fontSize, 13);
    expect(span.style!.color, const Color(0xFF6B6660));
    final lead = span.children!.first as TextSpan;
    final rest = span.children![1] as TextSpan;
    expect(lead.text, kHomePaymentMethodsLineLead);
    expect(lead.style!.fontWeight, FontWeight.w500);
    expect(
      rest.text,
      kHomePaymentMethodsLine.substring(kHomePaymentMethodsLineLead.length),
    );
  });

  testWidgets(
    'payment sentence at textScaler 2.0 shows the full line',
    (tester) async {
      phone(tester);
      await tester.pumpWidget(
        app(
          onRegister: () {},
          textScaler: const TextScaler.linear(2),
        ),
      );

      expect(tester.takeException(), isNull);
      final finder = find.byKey(
        const ValueKey<String>('home-payment-methods-line'),
      );
      expect(
        MediaQuery.textScalerOf(tester.element(finder)),
        const TextScaler.linear(2),
      );
      final line = tester.widget<Text>(finder);
      expect(line.maxLines, isNull);
      expect(line.overflow, isNot(TextOverflow.ellipsis));
      final paragraph = tester.renderObject<RenderParagraph>(finder);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(paragraph.text.toPlainText(), kHomePaymentMethodsLine);
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(
          baseOffset: 0,
          extentOffset: kHomePaymentMethodsLine.length,
        ),
      );
      expect(boxes, isNotEmpty);
      final tops = boxes.map((box) => box.top.round()).toSet();
      expect(tops.length, greaterThanOrEqualTo(3));
      var bottom = 0.0;
      for (final TextBox box in boxes) {
        if (box.bottom > bottom) bottom = box.bottom;
      }
      expect(bottom, lessThanOrEqualTo(paragraph.size.height + 0.01));
      for (var index = 0; index < kHomePaymentMethodsLine.length; index++) {
        final glyph = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: index, extentOffset: index + 1),
        );
        expect(
          glyph,
          isNotEmpty,
          reason: 'hidden glyph at $index',
        );
      }
    },
  );

  testWidgets('logo row on hides the payment sentence', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      app(onRegister: () {}, paymentLogoRowEnabled: true),
    );

    expect(
      find.byKey(const ValueKey('home-payment-methods-line')),
      findsNothing,
    );
    expect(find.text(kHomePaymentMethodsLine), findsNothing);
    expect(find.byKey(const ValueKey('home-payment-strip')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-payment-logo-apple_pay')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('home-payment-logo-google_pay')),
      findsNothing,
    );
  });

  testWidgets('flag off hides Apple Pay and Google Pay on iOS and Android', (
    tester,
  ) async {
    phone(tester);
    for (final platform in <TargetPlatform>[
      TargetPlatform.android,
      TargetPlatform.iOS,
    ]) {
      await tester.pumpWidget(
        app(
          onRegister: () {},
          platform: platform,
          paymentLogoRowEnabled: true,
        ),
      );
      expect(
        find.byKey(const ValueKey('home-payment-logo-apple_pay')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('home-payment-logo-google_pay')),
        findsNothing,
      );
    }
  });

  testWidgets('flag on shows only the platform wallet', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      app(
        onRegister: () {},
        platform: TargetPlatform.android,
        expressPayLogosEnabled: true,
        paymentLogoRowEnabled: true,
      ),
    );
    expect(
      find.byKey(const ValueKey('home-payment-logo-google_pay')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-payment-logo-apple_pay')),
      findsNothing,
    );

    await tester.pumpWidget(
      app(
        onRegister: () {},
        platform: TargetPlatform.iOS,
        expressPayLogosEnabled: true,
        paymentLogoRowEnabled: true,
      ),
    );
    expect(
      find.byKey(const ValueKey('home-payment-logo-apple_pay')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-payment-logo-google_pay')),
      findsNothing,
    );
    expect(find.text('Pay'), findsOneWidget);
    expect(find.text('Pagar'), findsNothing);
    expect(find.byIcon(Icons.apple), findsNothing);
    expect(
      tester.widget<Text>(find.text('Pay')).style!.color,
      kApplePayMarkWhite,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-payment-logo-apple_pay')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Text && widget.style?.color == const Color(0xFF000000),
        ),
      ),
      findsNothing,
    );
    expect(
      tester
          .widget<Padding>(
            find.byKey(const ValueKey('home-payment-logo-apple_pay')),
          )
          .padding,
      const EdgeInsets.symmetric(horizontal: 6),
    );

    await tester.pumpWidget(
      app(
        onRegister: () {},
        platform: TargetPlatform.android,
        expressPayLogosEnabled: true,
        paymentLogoRowEnabled: true,
      ),
    );
    expect(find.text('Pay'), findsOneWidget);
    expect(find.text('Pagar'), findsNothing);
    expect(
      tester
          .widget<Padding>(
            find.byKey(const ValueKey('home-payment-logo-google_pay')),
          )
          .padding,
      const EdgeInsets.symmetric(horizontal: 12),
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
