/// Costos autoritativos del Cart Shopify + controles de descuento accesibles.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/cart_controller.dart';
import '../../data/shopify/cart/cart_repository.dart';
import '../../data/shopify/cart/cart_session_store.dart';
import '../../domain/cart.dart';
import '../boutique/boutique_tokens.dart';

class ShopifyCartSummary extends StatefulWidget {
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
  State<ShopifyCartSummary> createState() => _ShopifyCartSummaryState();
}

class _ShopifyCartSummaryState extends State<ShopifyCartSummary> {
  final TextEditingController _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final cart = widget.controller.scopedSnapshot?.scope == widget.scope
            ? widget.controller.snapshot?.cart
            : null;
        if (cart == null) return const SizedBox.shrink();
        final palette = context.boutique;
        final applying = widget.controller.discountStatus ==
            CartDiscountUpdateStatus.applying;
        final allocatedApplications = cart.discountApplications
            .where((item) => item.totalAllocatedAmount != null)
            .toList(growable: false);
        final returnedCodes = {
          for (final item in cart.discountCodes) item.code.toUpperCase(),
        };
        final unconfirmedCodes = widget.controller.requestedDiscountCodes
            .where((code) => !returnedCodes.contains(code.toUpperCase()))
            .toList(growable: false);

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
                label: cart.cost.subtotalEstimated
                    ? 'Subtotal de Shopify (estimado)'
                    : 'Subtotal de Shopify',
                money: cart.cost.subtotal,
              ),
              if (allocatedApplications.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (final application in allocatedApplications)
                  _MoneyRow(
                    label: application.kind ==
                            CartDiscountApplicationKind.automatic
                        ? 'Descuento automático'
                        : 'Descuento aplicado',
                    money: application.totalAllocatedAmount!,
                    negative: true,
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
              _SummaryTextRow(
                label: 'Envío',
                value: 'Se calcula en Shopify',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Container(height: .5, color: palette.hairline),
              ),
              _MoneyRow(
                label: cart.cost.totalEstimated
                    ? 'Total de Shopify (estimado)'
                    : 'Total de Shopify',
                money: cart.cost.total,
                prominent: true,
              ),
              const SizedBox(height: 20),
              TextField(
                key: const ValueKey('discount-code-field'),
                controller: _code,
                enabled: !applying,
                textCapitalization: TextCapitalization.characters,
                style: boutiqueText(size: 14, color: palette.ink),
                decoration: InputDecoration(
                  labelText: 'Código de descuento',
                  hintText: 'Escribe tu código',
                  labelStyle: boutiqueText(size: 12, color: palette.inkMuted),
                  hintStyle: boutiqueText(size: 12, color: palette.inkMuted),
                  filled: true,
                  fillColor: palette.surfaceDeep,
                  contentPadding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BoutiqueRadius.control,
                    borderSide: BorderSide(color: palette.hairline, width: .5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BoutiqueRadius.control,
                    borderSide: BorderSide(color: palette.ink, width: 1),
                  ),
                ),
                onSubmitted: applying ? null : (_) => _apply(),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: BoutiqueButton(
                  key: const ValueKey('apply-discount-button'),
                  label: applying ? 'APLICANDO…' : 'APLICAR CÓDIGO',
                  filled: false,
                  onPressed: applying ? null : _apply,
                ),
              ),
              for (final discount in cart.discountCodes)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    discount.code,
                    style: boutiqueText(size: 13, color: palette.ink),
                  ),
                  subtitle: Text(
                    discount.applicable ? 'Aplicado' : 'Válido, no aplicable',
                    style: boutiqueText(size: 11, color: palette.inkMuted),
                  ),
                  trailing: IconButton(
                    tooltip: 'Eliminar código ${discount.code}',
                    onPressed: applying
                        ? null
                        : () => unawaited(
                              widget.controller.removeDiscountCode(
                                scope: widget.scope,
                                localIntent: widget.localIntent,
                                code: discount.code,
                              ),
                            ),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ),
              for (final code in unconfirmedCodes)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    code,
                    style: boutiqueText(size: 13, color: palette.ink),
                  ),
                  subtitle: Text(
                    widget.controller.discountStatus ==
                            CartDiscountUpdateStatus.error
                        ? 'No confirmado'
                        : 'Inválido',
                    style: boutiqueText(size: 11, color: palette.inkMuted),
                  ),
                  trailing: IconButton(
                    tooltip: 'Eliminar código $code',
                    onPressed: applying
                        ? null
                        : () => unawaited(
                              widget.controller.removeDiscountCode(
                                scope: widget.scope,
                                localIntent: widget.localIntent,
                                code: code,
                              ),
                            ),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ),
              if (widget.controller.discountMessage case final message?) ...[
                const SizedBox(height: 6),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    key: const ValueKey('discount-status-message'),
                    style: boutiqueText(size: 11, color: palette.inkMuted),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              BoutiqueButton(
                label: 'Continuar al checkout',
                onPressed: widget.onContinue,
              ),
            ],
          ),
        );
      },
    );
  }

  void _apply() {
    final value = _code.text;
    unawaited(
      widget.controller.applyDiscountCode(
        scope: widget.scope,
        localIntent: widget.localIntent,
        code: value,
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.money,
    this.negative = false,
    this.prominent = false,
  });

  final String label;
  final CartMoney money;
  final bool negative;
  final bool prominent;

  @override
  Widget build(BuildContext context) => _SummaryTextRow(
        label: label,
        value: '${negative ? '−' : ''}${money.amount} ${money.currencyCode}',
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
