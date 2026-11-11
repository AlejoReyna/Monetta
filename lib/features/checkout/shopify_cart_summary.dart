/// Costos autoritativos del Cart Shopify, presentados como el carrito del theme.
library;

import 'package:flutter/material.dart';

import '../../app/cart_controller.dart';
import '../../data/shopify/cart/cart_repository.dart';
import '../../data/shopify/cart/cart_session_store.dart';
import '../../domain/cart.dart';
import '../boutique/boutique_tokens.dart';

class ShopifyCartSummary extends StatelessWidget {
  const ShopifyCartSummary({
    required this.controller,
    required this.scope,
    required this.localIntent,
    required this.onContinue,
    super.key,
  });

  final CartController controller;
  final CartSessionScope scope;
  final List<LocalCartIntent> localIntent;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final cart = controller.scopedSnapshot?.scope == scope
            ? controller.snapshot?.cart
            : null;
        if (cart == null) return const SizedBox.shrink();
        final palette = context.boutique;
        final allocatedApplications = cart.discountApplications
            .where((item) => item.totalAllocatedAmount != null)
            .toList(growable: false);
        final itemCount = cart.lines.fold<int>(
          0,
          (sum, line) => sum + line.quantity,
        );

        return Container(
          key: const ValueKey('shopify-cart-summary'),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BoutiqueRadius.card,
            border: Border.all(color: palette.hairline, width: .5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Resumen de compra',
                style: boutiqueTitle(color: palette.ink),
              ),
              const SizedBox(height: 18),
              _MoneyRow(
                label: itemCount == 1
                    ? 'Subtotal (1 artículo)'
                    : 'Subtotal ($itemCount artículos)',
                value: formatCartMoney(cart.cost.subtotal),
              ),
              if (allocatedApplications.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (final application in allocatedApplications)
                  _MoneyRow(
                    label: application.kind ==
                            CartDiscountApplicationKind.automatic
                        ? 'Descuento automático'
                        : 'Descuento aplicado',
                    value:
                        '−${formatCartMoney(application.totalAllocatedAmount!)}',
                  ),
              ],
              if (cart.discountApplications.any(
                (item) => item.kind == CartDiscountApplicationKind.automatic,
              )) ...[
                const SizedBox(height: 10),
                Text(
                  'Incluye descuentos automáticos de Shopify',
                  style: boutiqueText(size: 11, color: palette.inkMuted),
                ),
              ],
              const SizedBox(height: 10),
              const _MoneyRow(
                label: 'Envío',
                value: 'Se calcula en Shopify',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Container(height: .5, color: palette.hairline),
              ),
              _MoneyRow(
                label: cart.cost.totalEstimated ? 'Total estimado' : 'Total',
                value: formatCartMoney(cart.cost.total, withCurrency: true),
                prominent: true,
              ),
              const SizedBox(height: 18),
              BoutiqueButton(
                label: 'Continuar al checkout',
                onPressed: onContinue,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Presents a Shopify decimal string as the store's `$ {{amount}}` format.
///
/// Presentation only (invariant 6): the amount is rounded to cents half-up
/// with integer/string arithmetic on the decimal string, never via `double`,
/// and no total is ever computed from the result.
String formatCartMoney(CartMoney money, {bool withCurrency = false}) {
  var raw = money.amount.trim();
  final negative = raw.startsWith('-');
  if (negative || raw.startsWith('+')) raw = raw.substring(1);
  final dot = raw.indexOf('.');
  final wholeText = dot < 0 ? raw : raw.substring(0, dot);
  final fractionText = dot < 0 ? '' : raw.substring(dot + 1);
  final isDecimal = RegExp(r'^\d*$');
  if ((wholeText.isEmpty && fractionText.isEmpty) ||
      !isDecimal.hasMatch(wholeText) ||
      !isDecimal.hasMatch(fractionText)) {
    // Not a decimal string: show it untouched rather than guess.
    return withCurrency
        ? '${money.amount} ${money.currencyCode}'
        : money.amount;
  }
  final cents = BigInt.parse(
    '${wholeText.isEmpty ? '0' : wholeText}'
    '${fractionText.padRight(2, '0').substring(0, 2)}',
  );
  // Half-up: look at the first digit dropped after the cents.
  final roundUp =
      fractionText.length > 2 && fractionText.codeUnitAt(2) >= 0x35; // '5'
  final rounded = roundUp ? cents + BigInt.one : cents;
  final digits = rounded.toString().padLeft(3, '0');
  final whole = digits.substring(0, digits.length - 2);
  final grouped = whole.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+$)'),
    (_) => ',',
  );
  final isZero = rounded == BigInt.zero;
  final text =
      '${negative && !isZero ? '-' : ''}\$ $grouped.${digits.substring(digits.length - 2)}';
  return withCurrency ? '$text ${money.currencyCode}' : text;
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.value,
    this.prominent = false,
  });

  final String label;
  final String value;
  final bool prominent;

  @override
  Widget build(BuildContext context) => _SummaryTextRow(
        label: label,
        value: value,
        prominent: prominent,
      );
}

class _SummaryTextRow extends StatelessWidget {
  const _SummaryTextRow({
    required this.label,
    required this.value,
    this.prominent = false,
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
