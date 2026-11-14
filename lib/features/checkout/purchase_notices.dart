/// Published merchant-policy links and checkout payment presentation.
library;

import 'package:flutter/material.dart';
import '../../app/monetta_tokens.g.dart';
import '../../data/customer_auth/customer_graphql_client.dart';
import '../../data/shopify/shop_policy_repository.dart';
import '../boutique/boutique_tokens.dart';
import '../boutique/client_guide_components.dart';
import '../help/policy_reader.dart';

class PurchasePolicyNotice extends StatelessWidget {
  const PurchasePolicyNotice({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = PolicyScope.maybeOf(context);
    final entries = <(ShopPolicyKind, String)>[
      (ShopPolicyKind.shipping, 'Envíos'),
      (ShopPolicyKind.refund, 'Cambios y devoluciones'),
    ]
        .where((e) =>
            controller?.policies?[e.$1]?.status ==
            CapabilityReadStatus.supported)
        .toList();
    if (entries.isEmpty && controller?.failed != true)
      return const SizedBox.shrink();
    return Wrap(children: [
      for (final entry in entries)
        TextButton(
            onPressed: () => openPolicy(context, entry.$1),
            child: Text(entry.$2)),
      if (controller?.failed == true)
        TextButton(
            onPressed: controller!.refresh,
            child: const Text('Reintentar políticas')),
    ]);
  }
}

class SecurePaymentLine extends StatelessWidget {
  const SecurePaymentLine({this.methods = const [], super.key});
  final List<String> methods;
  @override
  Widget build(BuildContext context) => Text(
        methods.isEmpty
            ? 'Pagos seguros con Shopify.'
            : 'Pagos seguros con Shopify · ${methods.join(' · ')}',
        textAlign: TextAlign.center,
        style: clientGuideStyle(context, MonettaTokens.cardLabel,
            color: context.boutique.inkMuted),
      );
}
