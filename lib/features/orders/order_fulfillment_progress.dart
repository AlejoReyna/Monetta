/// Horizontal shipping progress for order detail (UI:G23, Corrección 5).
///
/// Three steps — preparing, in transit, delivered — filled from fulfillment
/// evidence only. Payment state is shown elsewhere; this bar never waits on pay.
library;

import 'package:flutter/material.dart';

import '../../app/monetta_tokens.g.dart';
import '../../data/local/database.dart' show OrderSummary;
import '../account/account_boutique.dart';
import '../boutique/boutique_tokens.dart';
import 'order_status.dart';

/// Fulfillment phase derived from [OrderSummary.fulfillmentStatus].
enum OrderFulfillmentPhase {
  preparing,
  inTransit,
  delivered,
  partial,
  unavailable,
}

/// Maps Shopify fulfillment tokens to a v4.1 progress phase.
OrderFulfillmentPhase orderFulfillmentPhase(OrderSummary order) {
  if (order.source == 'whatsapp_apartado') {
    return OrderFulfillmentPhase.unavailable;
  }
  if (_fulfillmentBlockedByTerminalPayment(order)) {
    return OrderFulfillmentPhase.unavailable;
  }
  final raw = order.fulfillmentStatus?.toLowerCase().trim();
  if (raw == null || raw.isEmpty) {
    return OrderFulfillmentPhase.preparing;
  }
  switch (raw) {
    case 'delivered':
      return OrderFulfillmentPhase.delivered;
    case 'fulfilled':
    case 'shipped':
    case 'in_transit':
    case 'in transit':
    case 'out_for_delivery':
      return OrderFulfillmentPhase.inTransit;
    case 'partial':
    case 'partially_fulfilled':
    case 'partially fulfilled':
      return OrderFulfillmentPhase.partial;
    default:
      return OrderFulfillmentPhase.preparing;
  }
}

bool _fulfillmentBlockedByTerminalPayment(OrderSummary order) {
  final payment = orderPaymentStatus(order);
  return payment.key == 'refunded' ||
      payment.key == 'cancelled' ||
      payment.key == 'voided';
}

/// Labels for the three progress circles (Correction 5 copy).
class OrderFulfillmentStepLabels {
  const OrderFulfillmentStepLabels({
    required this.preparing,
    required this.inTransit,
    required this.delivered,
  });

  final String preparing;
  final String inTransit;
  final String delivered;

  static const correction5 = OrderFulfillmentStepLabels(
    preparing: 'Preparando tu pedido',
    inTransit: 'Tu pedido va en camino',
    delivered: 'Tu pedido fue entregado',
  );
}

/// Firm-outline horizontal progress with truck / plane / house icons.
class OrderFulfillmentProgressBar extends StatelessWidget {
  const OrderFulfillmentProgressBar({
    required this.order,
    this.labels = OrderFulfillmentStepLabels.correction5,
    super.key,
  });

  final OrderSummary order;
  final OrderFulfillmentStepLabels labels;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final phase = orderFulfillmentPhase(order);
    if (phase == OrderFulfillmentPhase.unavailable) {
      return const SizedBox.shrink();
    }

    final activeIndex = switch (phase) {
      OrderFulfillmentPhase.preparing => 0,
      OrderFulfillmentPhase.partial => 1,
      OrderFulfillmentPhase.inTransit => 1,
      OrderFulfillmentPhase.delivered => 2,
      OrderFulfillmentPhase.unavailable => -1,
    };

    final steps = <_StepData>[
      _StepData(
        icon: Icons.local_shipping_outlined,
        label: labels.preparing,
      ),
      _StepData(
        icon: Icons.flight_outlined,
        label: labels.inTransit,
      ),
      _StepData(
        icon: Icons.home_outlined,
        label: labels.delivered,
      ),
    ];

    return Semantics(
      label: 'Progreso de envío',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                Expanded(
                  child: _StepCircle(
                    data: steps[i],
                    active: i <= activeIndex,
                    current: i == activeIndex,
                    palette: palette,
                  ),
                ),
                if (i < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 28),
                      color: i < activeIndex
                          ? palette.goldText
                          : palette.hairline,
                    ),
                  ),
              ],
            ],
          ),
          if (phase == OrderFulfillmentPhase.partial) ...[
            const SizedBox(height: BoutiqueSpace.sm),
            Text(
              'Envío parcial: parte de tu pedido va en camino; lo restante '
              'sigue en preparación.',
              style: boutiqueText(size: 12, color: palette.inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepData {
  const _StepData({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _StepCircle extends StatelessWidget {
  const _StepCircle({
    required this.data,
    required this.active,
    required this.current,
    required this.palette,
  });

  final _StepData data;
  final bool active;
  final bool current;
  final BoutiquePalette palette;

  @override
  Widget build(BuildContext context) {
    final borderColor = active ? palette.goldText : palette.hairline;
    final fill = active ? palette.goldText.withValues(alpha: 0.12) : null;
    final iconColor = active ? palette.ink : palette.inkMuted;

    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            border: Border.all(color: borderColor, width: current ? 2 : 1),
          ),
          child: Icon(data.icon, size: 22, color: iconColor),
        ),
        const SizedBox(height: BoutiqueSpace.sm),
        Text(
          data.label,
          textAlign: TextAlign.center,
          style: boutiqueText(
            size: 11,
            color: active ? palette.ink : palette.inkMuted,
            height: 1.25,
            weight: current ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
