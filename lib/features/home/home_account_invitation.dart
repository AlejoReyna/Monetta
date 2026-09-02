/// Account invitation shown at the end of the shopper home.
library;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Gives shoppers a clear account entry point without breaking the editorial
/// rhythm of the home page.
class HomeAccountInvitation extends StatelessWidget {
  const HomeAccountInvitation({
    required this.onRegister,
    this.isSignedIn = false,
    super.key,
  });

  final VoidCallback onRegister;
  final bool isSignedIn;

  @override
  Widget build(BuildContext context) {
    final colors = context.monettaColors;
    return Container(
      key: const ValueKey('home-account-invitation'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        border: Border(
          top: BorderSide(color: colors.divider, width: .5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 44),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            children: [
              Text(
                isSignedIn ? 'TU CUENTA' : 'REGÍSTRATE',
                textAlign: TextAlign.center,
                style: editorial(31, color: colors.contentPrimary),
              ),
              const SizedBox(height: 12),
              Text(
                isSignedIn
                    ? 'Consulta tus pedidos y datos de compra'
                    : 'Obtén envío gratis en tu primer pedido',
                textAlign: TextAlign.center,
                style: eyebrow(
                  size: 9.5,
                  color: colors.contentMuted,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 28),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: FilledButton(
                  key: const ValueKey('home-register-button'),
                  onPressed: onRegister,
                  child: Text(
                    isSignedIn ? 'VER MI CUENTA' : 'REGISTRARME AHORA',
                  ),
                ),
              ),
              const SizedBox(height: 34),
              Text(
                'ENVÍOS RÁPIDOS Y PAGOS SEGUROS',
                textAlign: TextAlign.center,
                style: eyebrow(
                  size: 9,
                  color: colors.contentMuted,
                  weight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              const _PaymentMethods(),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentMethods extends StatelessWidget {
  const _PaymentMethods();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const ValueKey('home-payment-methods'),
      label:
          'Métodos de pago: Apple Pay, Google Pay, Maestro, Mastercard, PayPal, Shop Pay y Visa',
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              _PaymentBadge(width: 47, child: _ApplePayMark()),
              SizedBox(width: 7),
              _PaymentBadge(width: 52, child: _GooglePayMark()),
              SizedBox(width: 7),
              _PaymentBadge(width: 46, child: _CirclesMark.maestro()),
              SizedBox(width: 7),
              _PaymentBadge(width: 46, child: _CirclesMark.mastercard()),
              SizedBox(width: 7),
              _PaymentBadge(width: 46, child: _PayPalMark()),
              SizedBox(width: 7),
              _PaymentBadge(width: 54, child: _ShopPayMark()),
              SizedBox(width: 7),
              _PaymentBadge(width: 46, child: _VisaMark()),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentBadge extends StatelessWidget {
  const _PaymentBadge({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.monettaColors;
    return Container(
      width: width,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        border: Border.all(color: colors.divider, width: .6),
      ),
      child: child,
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
        Icon(
          Icons.apple,
          size: 14,
          color: context.monettaColors.contentPrimary,
        ),
        const SizedBox(width: 1),
        Text(
          'Pay',
          style: sans(
            size: 9,
            weight: FontWeight.w600,
            color: context.monettaColors.contentPrimary,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _GooglePayMark extends StatelessWidget {
  const _GooglePayMark();

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: sans(
          size: 8.5,
          weight: FontWeight.w600,
          color: context.monettaColors.contentPrimary,
          height: 1,
        ),
        children: const [
          TextSpan(text: 'G', style: TextStyle(color: Color(0xFF4285F4))),
          TextSpan(text: ' Pay'),
        ],
      ),
    );
  }
}

class _CirclesMark extends StatelessWidget {
  const _CirclesMark.maestro()
      : left = const Color(0xFFE32636),
        right = const Color(0xFF2575C8);

  const _CirclesMark.mastercard()
      : left = const Color(0xFFEB001B),
        right = const Color(0xFFF79E1B);

  final Color left;
  final Color right;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 17,
      child: Stack(
        children: [
          Positioned(left: 1, child: _circle(left)),
          Positioned(right: 1, child: _circle(right)),
        ],
      ),
    );
  }

  Widget _circle(Color color) => Container(
        width: 17,
        height: 17,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

class _PayPalMark extends StatelessWidget {
  const _PayPalMark();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'P',
      style: TextStyle(
        color: Color(0xFF166AB5),
        fontSize: 16,
        fontWeight: FontWeight.w800,
        fontStyle: FontStyle.italic,
        height: 1,
      ),
    );
  }
}

class _ShopPayMark extends StatelessWidget {
  const _ShopPayMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF5A31F4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      child: const Text(
        'shop',
        style: TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

class _VisaMark extends StatelessWidget {
  const _VisaMark();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'VISA',
      style: TextStyle(
        color: Color(0xFF1434CB),
        fontSize: 9,
        fontWeight: FontWeight.w800,
        fontStyle: FontStyle.italic,
        letterSpacing: -.4,
        height: 1,
      ),
    );
  }
}
