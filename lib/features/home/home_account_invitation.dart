/// Account invitation shown at the end of the shopper home.
library;

import 'package:flutter/material.dart';

import '../boutique/boutique_tokens.dart';

import '../checkout/purchase_notices.dart';

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
    final palette = context.boutique;
    return Container(
      key: const ValueKey('home-account-invitation'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.surfaceDeep,
        border: Border(
          top: BorderSide(color: palette.hairline, width: .5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        BoutiqueSpace.gutter,
        BoutiqueSpace.xxl,
        BoutiqueSpace.gutter,
        BoutiqueSpace.xxl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            children: [
              Text(
                isSignedIn ? 'TU CUENTA' : 'REGÍSTRATE',
                textAlign: TextAlign.center,
                style: boutiqueDisplay(28, color: palette.ink),
              ),
              const SizedBox(height: BoutiqueSpace.md),
              Text(
                'Consulta tus pedidos y datos de compra',
                textAlign: TextAlign.center,
                style: boutiqueText(size: 14, color: palette.inkMuted),
              ),
              const SizedBox(height: BoutiqueSpace.xl),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: BoutiqueButton(
                  key: const ValueKey('home-register-button'),
                  label: isSignedIn ? 'VER MI CUENTA' : 'REGISTRARME AHORA',
                  onPressed: onRegister,
                ),
              ),
              const SizedBox(height: BoutiqueSpace.xxl),
              const SecurePaymentLine(key: ValueKey('home-payment-methods')),
              const SizedBox(height: BoutiqueSpace.lg),
              const PurchasePolicyNotice(),
            ],
          ),
        ),
      ),
    );
  }
}
