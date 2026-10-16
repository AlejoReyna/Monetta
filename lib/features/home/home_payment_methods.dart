/// Home payment marks. Display only — checkout is untouched.
///
/// [kHomePaymentMethods] is the only list. A gray mark is used only when
/// [PaymentLogoVariant.monochrome] says the brand allows it. Everyone else
/// is drawn in official color, at one shared height, with no tile behind it.
///
/// These are stand-ins. [kHomePaymentMethodsNeedingGuidelineCheck] is the set
/// that still needs a human pass against the current brand guidelines before
/// a licensed asset replaces the drawing.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../boutique/boutique_tokens.dart';

/// Every mark in the row is this tall. Clear space is a multiple of it.
const double kHomePaymentLogoHeight = 24;

/// Enable only after MON-PAY-04 passes on device.
///
/// While this is false the home hides every [HomePaymentMethod.expressPay]
/// entry. When it is true, [kHomePaymentMethods] still decides the row:
/// Apple Pay on iOS, Google Pay on Android.
const bool kExpressPayLogosEnabled = false;

/// Drawn payment marks. Off shows one sentence; on shows the logo row.
const bool kPaymentLogoRowEnabled = false;

/// Lead of [kHomePaymentMethodsLine], set in medium weight.
const String kHomePaymentMethodsLineLead = 'Pagos seguros con';

/// Shown in place of the logo row while [kPaymentLogoRowEnabled] is false.
const String kHomePaymentMethodsLine =
    'Pagos seguros con tarjeta de crédito o débito, PayPal, Mercado Pago y transferencia.';

const Color kPaymentMonochrome = Color(0xFF8A8A8A);

/// Visa Blue. Visa has no gray variant on this row.
const Color kVisaBlue = Color(0xFF1434CB);

/// White Apple Pay mark. The apple is an outline, never a black fill.
const Color kApplePayMarkWhite = Color(0xFFFFFFFF);

/// Strip behind the payment row, inside the cream closing band.
const Color kHomePaymentStripColor = Color(0xFFFFFFFF);

enum PaymentLogoVariant {
  /// Gray reproduction. Only for marks whose guidelines allow it.
  monochrome,

  /// Official brand colors. Visa uses [kVisaBlue]. Apple Pay uses white.
  officialColor,
}

class HomePaymentMethod {
  const HomePaymentMethod({
    required this.id,
    required this.label,
    required this.variant,
    this.platforms = const <TargetPlatform>{},
    this.expressPay = false,
    required this.clearSpaceFactor,
  });

  final String id;
  final String label;
  final PaymentLogoVariant variant;

  /// Empty means every platform.
  final Set<TargetPlatform> platforms;

  /// Apple Pay or Google Pay. Off until [kExpressPayLogosEnabled].
  final bool expressPay;

  /// Clear space on each side, as a multiple of [kHomePaymentLogoHeight].
  ///
  /// The list comment names the brand rule (V, the Apple mark, the G, the P,
  /// the d, or the Mastercard circle). Those references are drawn at the
  /// mark height, and a Mastercard circle's width equals that height.
  final double clearSpaceFactor;

  bool showsOn(
    TargetPlatform platform, {
    bool expressPayLogosEnabled = kExpressPayLogosEnabled,
  }) {
    if (expressPay && !expressPayLogosEnabled) return false;
    return platforms.isEmpty || platforms.contains(platform);
  }
}

/// Visa, Mastercard, PayPal, Mercado Pago, transferencia, then the wallet
/// for the platform in hand. Maestro and Shop Pay are not offered.
const List<HomePaymentMethod> kHomePaymentMethods = <HomePaymentMethod>[
  // Visa Blue wordmark. A gray recolor is not a Visa variant.
  // Clear space: 0.5 × the height of the V.
  HomePaymentMethod(
    id: 'visa',
    label: 'Visa',
    variant: PaymentLogoVariant.officialColor,
    clearSpaceFactor: 0.5,
  ),
  // Interlocking circles stay red and yellow. Recoloring is not allowed.
  // Clear space: 1/4 of the circle width. The circle's width is the mark height.
  HomePaymentMethod(
    id: 'mastercard',
    label: 'Mastercard',
    variant: PaymentLogoVariant.officialColor,
    clearSpaceFactor: 0.25,
  ),
  // PayPal Blue wordmark. Approved inks are blue, black, and white — not gray.
  // Clear space: the height of the P.
  HomePaymentMethod(
    id: 'paypal',
    label: 'PayPal',
    variant: PaymentLogoVariant.officialColor,
    clearSpaceFactor: 1,
  ),
  // Mercado Pago blue. No approved gray lockup is published for this use.
  // Clear space: the height of the d.
  HomePaymentMethod(
    id: 'mercado_pago',
    label: 'Mercado Pago',
    variant: PaymentLogoVariant.officialColor,
    clearSpaceFactor: 1,
  ),
  // Generic bank icon, not a network logo. House gap: a quarter of the icon.
  HomePaymentMethod(
    id: 'bank_transfer',
    label: 'Transferencia',
    variant: PaymentLogoVariant.monochrome,
    clearSpaceFactor: 0.25,
  ),
  // White mark, Apple drawn as an outline. Black is not this variant.
  // Clear space: 1/4 of the mark height. "Pay" stays in English.
  HomePaymentMethod(
    id: 'apple_pay',
    label: 'Apple Pay',
    variant: PaymentLogoVariant.officialColor,
    platforms: <TargetPlatform>{TargetPlatform.iOS},
    expressPay: true,
    clearSpaceFactor: 0.25,
  ),
  // Google Pay's mark is the official color lockup. Gray is not allowed.
  // Clear space: 1/2 of the G. The G is the mark height. "Pay" stays in English.
  HomePaymentMethod(
    id: 'google_pay',
    label: 'Google Pay',
    variant: PaymentLogoVariant.officialColor,
    platforms: <TargetPlatform>{TargetPlatform.android},
    expressPay: true,
    clearSpaceFactor: 0.5,
  ),
];

/// Stand-ins that still need a guideline check before licensed files ship.
const Set<String> kHomePaymentMethodsNeedingGuidelineCheck = <String>{
  'visa',
  'mastercard',
  'paypal',
  'mercado_pago',
  'apple_pay',
  'google_pay',
};

List<HomePaymentMethod> homePaymentMethodsFor(
  TargetPlatform platform, {
  bool expressPayLogosEnabled = kExpressPayLogosEnabled,
}) {
  return <HomePaymentMethod>[
    for (final method in kHomePaymentMethods)
      if (method.showsOn(
        platform,
        expressPayLogosEnabled: expressPayLogosEnabled,
      ))
        method,
  ];
}

double homePaymentClearSpace(HomePaymentMethod method) {
  return kHomePaymentLogoHeight * method.clearSpaceFactor;
}

String homePaymentMethodsLabel(List<HomePaymentMethod> methods) {
  if (methods.isEmpty) return 'Métodos de pago';
  if (methods.length == 1) {
    return 'Métodos de pago: ${methods.single.label}';
  }
  final labels = methods.map((method) => method.label).toList(growable: false);
  final head = labels.sublist(0, labels.length - 1).join(', ');
  return 'Métodos de pago: $head y ${labels.last}';
}

/// Lead and remainder of [kHomePaymentMethodsLine].
///
/// The remainder is that constant with the lead removed, so the sentence
/// has one source. An empty lead means the constant no longer starts with
/// [kHomePaymentMethodsLineLead]; the full line is still shown.
(String lead, String rest) homePaymentMethodsLineParts() {
  const line = kHomePaymentMethodsLine;
  const lead = kHomePaymentMethodsLineLead;
  if (!line.startsWith(lead)) return ('', line);
  return (lead, line.substring(lead.length));
}

class HomePaymentMethodsLine extends StatelessWidget {
  const HomePaymentMethodsLine({super.key});

  @override
  Widget build(BuildContext context) {
    final color = context.boutique.inkMuted;
    final (lead, rest) = homePaymentMethodsLineParts();
    return Text.rich(
      TextSpan(
        style: boutiqueText(size: 13, color: color),
        children: <InlineSpan>[
          TextSpan(
            text: lead,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          TextSpan(text: rest),
        ],
      ),
      key: const ValueKey<String>('home-payment-methods-line'),
      textAlign: TextAlign.center,
    );
  }
}

class HomePaymentMethodRow extends StatelessWidget {
  const HomePaymentMethodRow({
    this.platform,
    this.expressPayLogosEnabled = kExpressPayLogosEnabled,
    super.key,
  });

  final TargetPlatform? platform;

  /// Defaults to [kExpressPayLogosEnabled]. Tests pass the other value.
  final bool expressPayLogosEnabled;

  @override
  Widget build(BuildContext context) {
    final resolved = platform ?? Theme.of(context).platform;
    final methods = homePaymentMethodsFor(
      resolved,
      expressPayLogosEnabled: expressPayLogosEnabled,
    );
    return ColoredBox(
      key: const ValueKey<String>('home-payment-strip'),
      color: kHomePaymentStripColor,
      child: Semantics(
        key: const ValueKey<String>('home-payment-methods'),
        label: homePaymentMethodsLabel(methods),
        child: ExcludeSemantics(
          child: SizedBox(
            height: kHomePaymentLogoHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final method in methods)
                          HomePaymentLogo(method: method),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class HomePaymentLogo extends StatelessWidget {
  const HomePaymentLogo({required this.method, super.key});

  final HomePaymentMethod method;

  @override
  Widget build(BuildContext context) {
    final mono = method.variant == PaymentLogoVariant.monochrome;
    final mark = switch (method.id) {
      'visa' => const _VisaWordmark(),
      'mastercard' => _MastercardMark(monochrome: mono),
      'paypal' => _PayPalWordmark(monochrome: mono),
      'mercado_pago' => _MercadoPagoWordmark(monochrome: mono),
      'bank_transfer' => _BankTransferMark(monochrome: mono),
      'apple_pay' => const _ApplePayMark(),
      'google_pay' => _GooglePayMark(monochrome: mono),
      _ => const SizedBox.shrink(),
    };
    return Padding(
      key: ValueKey<String>('home-payment-logo-${method.id}'),
      padding: EdgeInsets.symmetric(
        horizontal: homePaymentClearSpace(method),
      ),
      child: SizedBox(
        height: kHomePaymentLogoHeight,
        child: mark,
      ),
    );
  }
}

class _VisaWordmark extends StatelessWidget {
  const _VisaWordmark();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'VISA',
      style: TextStyle(
        color: kVisaBlue,
        fontSize: kHomePaymentLogoHeight,
        fontWeight: FontWeight.w800,
        fontStyle: FontStyle.italic,
        letterSpacing: 0.4,
        height: 1,
      ),
    );
  }
}

class _MastercardMark extends StatelessWidget {
  const _MastercardMark({required this.monochrome});

  final bool monochrome;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kHomePaymentLogoHeight * 1.55,
      height: kHomePaymentLogoHeight,
      child: CustomPaint(
        painter: _MastercardPainter(monochrome: monochrome),
      ),
    );
  }
}

class _MastercardPainter extends CustomPainter {
  const _MastercardPainter({required this.monochrome});

  final bool monochrome;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.height / 2;
    final left = Offset(radius, size.height / 2);
    final right = Offset(size.width - radius, size.height / 2);
    canvas.drawCircle(
      left,
      radius,
      Paint()
        ..color = monochrome ? kPaymentMonochrome : const Color(0xFFEB001B),
    );
    canvas.drawCircle(
      right,
      radius,
      Paint()
        ..color =
            monochrome ? const Color(0xFFB5B5B5) : const Color(0xFFF79E1B),
    );
  }

  @override
  bool shouldRepaint(covariant _MastercardPainter oldDelegate) =>
      oldDelegate.monochrome != monochrome;
}

class _PayPalWordmark extends StatelessWidget {
  const _PayPalWordmark({required this.monochrome});

  final bool monochrome;

  @override
  Widget build(BuildContext context) {
    final pay = monochrome ? kPaymentMonochrome : const Color(0xFF003087);
    final pal = monochrome ? kPaymentMonochrome : const Color(0xFF009CDE);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'Pay', style: _paypal(pay)),
          TextSpan(text: 'Pal', style: _paypal(pal)),
        ],
      ),
    );
  }

  TextStyle _paypal(Color color) => TextStyle(
        color: color,
        fontSize: kHomePaymentLogoHeight,
        fontWeight: FontWeight.w700,
        fontStyle: FontStyle.italic,
        height: 1,
      );
}

class _MercadoPagoWordmark extends StatelessWidget {
  const _MercadoPagoWordmark({required this.monochrome});

  final bool monochrome;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Mercado Pago',
      style: TextStyle(
        color: monochrome ? kPaymentMonochrome : const Color(0xFF009EE3),
        fontSize: kHomePaymentLogoHeight,
        fontWeight: FontWeight.w700,
        height: 1,
        letterSpacing: -0.2,
      ),
    );
  }
}

class _BankTransferMark extends StatelessWidget {
  const _BankTransferMark({required this.monochrome});

  final bool monochrome;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.account_balance_outlined,
      size: kHomePaymentLogoHeight,
      color: monochrome ? kPaymentMonochrome : const Color(0xFF5C6BC0),
    );
  }
}

class _ApplePayMark extends StatelessWidget {
  const _ApplePayMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: kHomePaymentLogoHeight,
          height: kHomePaymentLogoHeight,
          child: CustomPaint(
            painter: const _AppleOutlinePainter(color: kApplePayMarkWhite),
          ),
        ),
        const Text(
          'Pay',
          style: TextStyle(
            color: kApplePayMarkWhite,
            fontSize: kHomePaymentLogoHeight,
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _AppleOutlinePainter extends CustomPainter {
  const _AppleOutlinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * 0.18,
        size.height * 0.30,
        size.width * 0.64,
        size.height * 0.58,
      ),
      stroke,
    );
    final leaf = Path()
      ..moveTo(size.width * 0.52, size.height * 0.32)
      ..quadraticBezierTo(
        size.width * 0.70,
        size.height * 0.06,
        size.width * 0.80,
        size.height * 0.22,
      );
    canvas.drawPath(leaf, stroke);
  }

  @override
  bool shouldRepaint(covariant _AppleOutlinePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _GooglePayMark extends StatelessWidget {
  const _GooglePayMark({required this.monochrome});

  final bool monochrome;

  @override
  Widget build(BuildContext context) {
    final pay = monochrome ? kPaymentMonochrome : const Color(0xFF3C4043);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: kHomePaymentLogoHeight,
          height: kHomePaymentLogoHeight,
          child: CustomPaint(
            painter: _GoogleGPainter(monochrome: monochrome),
          ),
        ),
        Text(
          'Pay',
          style: TextStyle(
            color: pay,
            fontSize: kHomePaymentLogoHeight,
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  const _GoogleGPainter({required this.monochrome});

  final bool monochrome;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.18;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.width - stroke) / 2,
    );
    void arc(Color color, double start, double sweep) {
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = monochrome ? kPaymentMonochrome : color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt,
      );
    }

    arc(const Color(0xFFEA4335), -math.pi / 3, math.pi / 2);
    arc(const Color(0xFFFBBC05), math.pi / 6, math.pi / 2);
    arc(const Color(0xFF34A853), 2 * math.pi / 3, math.pi / 2);
    arc(const Color(0xFF4285F4), 7 * math.pi / 6, math.pi / 1.6);
    canvas.drawLine(
      Offset(size.width / 2, size.height / 2),
      Offset(size.width - stroke / 2, size.height / 2),
      Paint()
        ..color = monochrome ? kPaymentMonochrome : const Color(0xFF4285F4)
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt,
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleGPainter oldDelegate) =>
      oldDelegate.monochrome != monochrome;
}
