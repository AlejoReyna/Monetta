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

/// Shared cap height so a color mark and a gray mark sit on one line.
const double kHomePaymentLogoHeight = 22;

const Color kPaymentMonochrome = Color(0xFF8A8A8A);

enum PaymentLogoVariant {
  /// Gray reproduction. Only for marks whose guidelines allow it.
  monochrome,

  /// Official brand colors. Apple Pay's light-background mark is black.
  officialColor,
}

class HomePaymentMethod {
  const HomePaymentMethod({
    required this.id,
    required this.label,
    required this.variant,
    this.platforms = const <TargetPlatform>{},
  });

  final String id;
  final String label;
  final PaymentLogoVariant variant;

  /// Empty means every platform.
  final Set<TargetPlatform> platforms;

  bool showsOn(TargetPlatform platform) =>
      platforms.isEmpty || platforms.contains(platform);
}

/// Visa, Mastercard, PayPal, Mercado Pago, transferencia, then the wallet
/// for the platform in hand. Maestro and Shop Pay are not offered.
const List<HomePaymentMethod> kHomePaymentMethods = <HomePaymentMethod>[
  // Visa Blue wordmark. A gray recolor is not an approved reproduction.
  HomePaymentMethod(
    id: 'visa',
    label: 'Visa',
    variant: PaymentLogoVariant.officialColor,
  ),
  // Interlocking circles stay red and yellow. Recoloring is not allowed.
  HomePaymentMethod(
    id: 'mastercard',
    label: 'Mastercard',
    variant: PaymentLogoVariant.officialColor,
  ),
  // PayPal Blue wordmark. Approved inks are blue, black, and white — not gray.
  HomePaymentMethod(
    id: 'paypal',
    label: 'PayPal',
    variant: PaymentLogoVariant.officialColor,
  ),
  // Mercado Pago blue. No approved gray lockup is published for this use.
  HomePaymentMethod(
    id: 'mercado_pago',
    label: 'Mercado Pago',
    variant: PaymentLogoVariant.officialColor,
  ),
  // Generic bank icon, not a network logo.
  HomePaymentMethod(
    id: 'bank_transfer',
    label: 'Transferencia',
    variant: PaymentLogoVariant.monochrome,
  ),
  // Apple forbids any color other than black or white, including gray.
  HomePaymentMethod(
    id: 'apple_pay',
    label: 'Apple Pay',
    variant: PaymentLogoVariant.officialColor,
    platforms: <TargetPlatform>{TargetPlatform.iOS},
  ),
  // Google Pay's mark is the official color lockup. Gray is not allowed.
  HomePaymentMethod(
    id: 'google_pay',
    label: 'Google Pay',
    variant: PaymentLogoVariant.officialColor,
    platforms: <TargetPlatform>{TargetPlatform.android},
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

List<HomePaymentMethod> homePaymentMethodsFor(TargetPlatform platform) {
  return <HomePaymentMethod>[
    for (final method in kHomePaymentMethods)
      if (method.showsOn(platform)) method,
  ];
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

class HomePaymentMethodRow extends StatelessWidget {
  const HomePaymentMethodRow({this.platform, super.key});

  final TargetPlatform? platform;

  @override
  Widget build(BuildContext context) {
    final resolved = platform ?? Theme.of(context).platform;
    final methods = homePaymentMethodsFor(resolved);
    return Semantics(
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
                      for (var index = 0; index < methods.length; index++) ...[
                        if (index > 0) const SizedBox(width: 22),
                        HomePaymentLogo(method: methods[index]),
                      ],
                    ],
                  ),
                ),
              );
            },
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
      'visa' => _VisaWordmark(monochrome: mono),
      'mastercard' => _MastercardMark(monochrome: mono),
      'paypal' => _PayPalWordmark(monochrome: mono),
      'mercado_pago' => _MercadoPagoWordmark(monochrome: mono),
      'bank_transfer' => _BankTransferMark(monochrome: mono),
      'apple_pay' => _ApplePayMark(monochrome: mono),
      'google_pay' => _GooglePayMark(monochrome: mono),
      _ => const SizedBox.shrink(),
    };
    return SizedBox(
      key: ValueKey<String>('home-payment-logo-${method.id}'),
      height: kHomePaymentLogoHeight,
      child: mark,
    );
  }
}

class _VisaWordmark extends StatelessWidget {
  const _VisaWordmark({required this.monochrome});

  final bool monochrome;

  @override
  Widget build(BuildContext context) {
    return Text(
      'VISA',
      style: TextStyle(
        color: monochrome ? kPaymentMonochrome : const Color(0xFF1434CB),
        fontSize: 16,
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
      width: 34,
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
        fontSize: 16,
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
        fontSize: 14,
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
  const _ApplePayMark({required this.monochrome});

  final bool monochrome;

  @override
  Widget build(BuildContext context) {
    // Official light-background Apple Pay mark is black. Gray is not allowed,
    // so the monochrome variant is only a fallback if the config asks for it.
    final color = monochrome ? kPaymentMonochrome : const Color(0xFF000000);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.apple, size: 16, color: color),
        Text(
          'Pay',
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ],
    );
  }
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
          width: 18,
          height: 18,
          child: CustomPaint(
            painter: _GoogleGPainter(monochrome: monochrome),
          ),
        ),
        const SizedBox(width: 2),
        Text(
          'Pay',
          style: TextStyle(
            color: pay,
            fontSize: 15,
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
