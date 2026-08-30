/// Authoritative Shopify cart costs and accessible discount controls.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/cart_controller.dart';
import '../../app/theme.dart';
import '../../data/shopify/cart/cart_repository.dart';
import '../../data/shopify/cart/cart_session_store.dart';
import '../../domain/cart.dart';

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
          color: context.monettaColors.surfaceMuted,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Resumen', style: display(22, weight: FontWeight.w400)),
              const SizedBox(height: 22),
              _MoneyRow(
                label: cart.cost.subtotalEstimated
                    ? 'Subtotal de Shopify (estimado)'
                    : 'Subtotal de Shopify',
                money: cart.cost.subtotal,
              ),
              if (allocatedApplications.isNotEmpty) ...[
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                Text(
                  'Incluye descuentos automáticos de Shopify',
                  style: sans(
                    size: 11.5,
                    color: context.monettaColors.contentMuted,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _SummaryTextRow(
                label: 'Envío',
                value: 'Se calcula en Shopify',
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Divider(),
              ),
              _MoneyRow(
                label: cart.cost.totalEstimated
                    ? 'Total de Shopify (estimado)'
                    : 'Total de Shopify',
                money: cart.cost.total,
                prominent: true,
              ),
              const SizedBox(height: 24),
              TextField(
                key: const ValueKey('discount-code-field'),
                controller: _code,
                enabled: !applying,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Código de descuento',
                  hintText: 'Escribe tu código',
                ),
                onSubmitted: applying ? null : (_) => _apply(),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  key: const ValueKey('apply-discount-button'),
                  onPressed: applying ? null : _apply,
                  child: Text(applying ? 'APLICANDO…' : 'APLICAR CÓDIGO'),
                ),
              ),
              for (final discount in cart.discountCodes)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(discount.code),
                  subtitle: Text(
                    discount.applicable ? 'Aplicado' : 'Válido, no aplicable',
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
                    icon: const Icon(Icons.close),
                  ),
                ),
              for (final code in unconfirmedCodes)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(code),
                  subtitle: Text(
                    widget.controller.discountStatus ==
                            CartDiscountUpdateStatus.error
                        ? 'No confirmado'
                        : 'Inválido',
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
                    icon: const Icon(Icons.close),
                  ),
                ),
              if (widget.controller.discountMessage case final message?) ...[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    key: const ValueKey('discount-status-message'),
                    style: sans(
                      size: 11.5,
                      color: context.monettaColors.contentMuted,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              FilledButton(
                onPressed: widget.onContinue,
                child: const Text('CONTINUAR A ENTREGA'),
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
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: sans(
                size: prominent ? 14 : 12.5,
                weight: prominent ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            value,
            style: sans(
              size: prominent ? 15 : 12.5,
              weight: prominent ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      );
}
