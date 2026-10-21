/// Approved payment presentation and explicit placeholders for unapproved copy.
library;

import 'package:flutter/material.dart';
import '../../app/monetta_tokens.g.dart';
import '../boutique/boutique_tokens.dart';
import '../boutique/client_guide_components.dart';

const purchasePolicyPlaceholder =
    'Envíos, devoluciones y garantía: contenido pendiente de aprobación.';

class PurchasePolicyNotice extends StatelessWidget {
  const PurchasePolicyNotice({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(MonettaTokens.space[3]),
        decoration: BoxDecoration(
          color: context.boutique.surfaceDeep,
          borderRadius:
              const BorderRadius.all(Radius.circular(MonettaTokens.radiusCard)),
        ),
        child: Text(
          purchasePolicyPlaceholder,
          style: clientGuideStyle(
            context,
            MonettaTokens.cardLabel,
            color: context.boutique.inkMuted,
          ),
        ),
      );
}

/// Methods must come from the existing active checkout configuration. An empty
/// list names only the hosted checkout provider, never inferred payment brands.
class SecurePaymentLine extends StatelessWidget {
  const SecurePaymentLine({this.methods = const [], super.key});
  final List<String> methods;

  @override
  Widget build(BuildContext context) => Text(
        methods.isEmpty
            ? 'Pagos seguros con Shopify.'
            : 'Pagos seguros con Shopify · ${methods.join(' · ')}',
        textAlign: TextAlign.center,
        style: clientGuideStyle(
          context,
          MonettaTokens.cardLabel,
          color: context.boutique.inkMuted,
        ),
      );
}
