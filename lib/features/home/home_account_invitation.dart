/// Account invitation shown at the end of the shopper home.
library;

import 'package:flutter/material.dart';

import '../boutique/boutique_tokens.dart';
import '../../app/monetta_tokens.g.dart';
import '../boutique/client_guide_components.dart';

import '../checkout/purchase_notices.dart';

/// Gives shoppers a clear account entry point without breaking the editorial
/// rhythm of the home page.
class HomeAccountInvitation extends StatelessWidget {
  const HomeAccountInvitation({
    required this.onRegister,
    this.isSignedIn = false,
    super.key,
  });

  final VoidCallback? onRegister;
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
          top: BorderSide(color: palette.hairline, width: 1),
        ),
      ),
      padding: EdgeInsets.all(MonettaTokens.space[4]),
      child: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: MonettaTokens.breakpointMedium),
          child: Column(
            children: [
              Text(
                isSignedIn ? 'TU CUENTA' : 'REGÍSTRATE',
                textAlign: TextAlign.center,
                style: clientGuideStyle(context, MonettaTokens.sectionTitle),
              ),
              SizedBox(height: MonettaTokens.space[2]),
              Text(
                'Consulta tus pedidos y datos de compra',
                textAlign: TextAlign.center,
                style: clientGuideStyle(
                  context,
                  MonettaTokens.body,
                  color: palette.inkMuted,
                ),
              ),
              SizedBox(height: MonettaTokens.space[3]),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: MonettaTokens.breakpointMedium,
                ),
                child: ClientGuideButton(
                  key: const ValueKey('home-register-button'),
                  label: isSignedIn ? 'VER MI CUENTA' : 'REGISTRARME AHORA',
                  onPressed: onRegister,
                ),
              ),
              SizedBox(height: MonettaTokens.space[4]),
              const SecurePaymentLine(key: ValueKey('home-payment-methods')),
              SizedBox(height: MonettaTokens.space[3]),
              const PurchasePolicyNotice(),
            ],
          ),
        ),
      ),
    );
  }
}
