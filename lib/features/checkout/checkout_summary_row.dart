/// One label/value line of a bag, checkout or Shopify cart summary.
library;

import 'package:flutter/material.dart';

import '../boutique/boutique_tokens.dart';

class CheckoutSummaryRow extends StatelessWidget {
  const CheckoutSummaryRow({
    required this.label,
    required this.value,
    this.prominent = false,
    super.key,
  });

  final String label;
  final String value;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: boutiqueText(
              size: prominent ? 15 : 13,
              weight: prominent ? FontWeight.w600 : FontWeight.w400,
              color: palette.ink,
            ),
          ),
        ),
        Text(
          value,
          style: boutiqueText(
            size: prominent ? 16 : 13,
            weight: prominent ? FontWeight.w700 : FontWeight.w500,
            color: palette.ink,
          ),
        ),
      ],
    );
  }
}
