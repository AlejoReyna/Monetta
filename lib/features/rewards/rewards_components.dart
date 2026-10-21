/// Componentes reutilizables Rewards para el agente E (Cuenta, Pedidos,
/// Notificaciones) y puntos de integración A–D (Home, Producto, Checkout).
///
/// Consumen el contrato V1; no calculan saldo autoritativo ni presentan
/// estimaciones como ganancias liberadas. Sin gamificación ni niveles.
library;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../boutique/boutique_tokens.dart';
import 'rewards_models.dart';

// ---------------------------------------------------------------------------
// Resumen de saldo: "Tienes $184 Monetta disponibles".
// ---------------------------------------------------------------------------

/// Bloque disponible/pendiente + próximo vencimiento + movimientos.
/// E lo integra en Cuenta. `movements` es presentación paginada del contrato.
class RewardsBalanceCard extends StatelessWidget {
  const RewardsBalanceCard({
    required this.summary,
    this.movements = const [],
    this.expanded = false,
    this.onToggleExpanded,
    super.key,
  });

  final RewardsSummary summary;
  final List<RewardsMovement> movements;
  final bool expanded;
  final VoidCallback? onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.monettaColors;
    return Container(
      key: const ValueKey('rewards-balance-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceWarm,
        border: Border.all(color: colors.divider, width: .5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(Icons.card_giftcard_outlined,
                    size: 24, color: colors.accentContent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MONETTA REWARDS',
                        style: boutiqueRowLabel(color: colors.contentPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      'Tienes ${summary.availableLabel} disponibles',
                      key: const ValueKey('rewards-balance-available'),
                      style: boutiqueText(
                          size: 16,
                          weight: FontWeight.w600,
                          color: colors.contentPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '\$${(summary.pendingCents / 100).toStringAsFixed(0)} pendientes de entrega',
            style: sans(size: 12.5, color: colors.contentMuted),
          ),
          if (summary.nextExpiry != null) ...[
            const SizedBox(height: 6),
            Text(
              'Próximo vencimiento: \$${(summary.nextExpiry!.cents / 100).toStringAsFixed(0)} '
              'el ${_date(summary.nextExpiry!.at)}',
              style: sans(size: 12, color: colors.contentMuted),
            ),
          ],
          if (!summary.redemptionEnabled) ...[
            const SizedBox(height: 10),
            Text(
              'El canje se habilita cuando el programa esté activo.',
              style: sans(size: 12, color: colors.contentMuted, height: 1.5),
            ),
          ],
          if (movements.isNotEmpty || onToggleExpanded != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 0.5),
            InkWell(
              key: const ValueKey('rewards-movements-toggle'),
              onTap: onToggleExpanded,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Text(
                      expanded ? 'OCULTAR MOVIMIENTOS' : 'VER MOVIMIENTOS',
                      style: eyebrow(size: 9),
                    ),
                    const Spacer(),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 18,
                      color: colors.contentMuted,
                    ),
                  ],
                ),
              ),
            ),
            if (expanded)
              for (final movement in movements)
                _MovementRow(movement: movement),
          ],
        ],
      ),
    );
  }

  static String _date(DateTime at) => '${at.day.toString().padLeft(2, '0')}/'
      '${at.month.toString().padLeft(2, '0')}/${at.year}';
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.movement});

  final RewardsMovement movement;

  @override
  Widget build(BuildContext context) {
    final colors = context.monettaColors;
    final sign = movement.amountCents < 0 ? '−' : '+';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _movementLabel(movement),
                  style: sans(size: 12.5, weight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  _stateLabel(movement.state),
                  style: sans(size: 11, color: colors.contentMuted),
                ),
              ],
            ),
          ),
          Text(
            '$sign\$${(movement.amountCents.abs() / 100).toStringAsFixed(0)}',
            style: sans(size: 12.5, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  static String _movementLabel(RewardsMovement movement) {
    if (movement.orderShopifyId != null) {
      return 'Pedido ${movement.orderShopifyId}';
    }
    return switch (movement.type) {
      'expired' => 'Vencimiento de saldo',
      'redeem_settled' => 'Canje aplicado',
      'redeem_reserved' => 'Canje reservado',
      'adjustment' => 'Ajuste',
      _ => 'Movimiento Monetta',
    };
  }

  static String _stateLabel(String state) => switch (state) {
        'pending' => 'Pendiente de entrega',
        'available' => 'Disponible',
        'used' || 'utilizado' => 'Utilizado',
        'expired' => 'Expirado',
        'reversed' => 'Revertido',
        _ => state,
      };
}

// ---------------------------------------------------------------------------
// Beneficio estimado (Producto): siempre identificado como estimación.
// ---------------------------------------------------------------------------

/// Debajo del precio: "Podrías ganar $54 Monetta" + aclaración.
/// Nunca afirma ganancia definitiva antes del pedido.
class RewardsEstimateLabel extends StatelessWidget {
  const RewardsEstimateLabel({
    required this.estimatedCents,
    this.isWholesale = false,
    super.key,
  });

  final int estimatedCents;
  final bool isWholesale;

  @override
  Widget build(BuildContext context) {
    final colors = context.monettaColors;
    if (isWholesale) return const SizedBox.shrink();
    if (estimatedCents <= 0) return const SizedBox.shrink();
    return Row(
      key: const ValueKey('rewards-estimate'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 15, color: colors.contentMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Podrías ganar \$${(estimatedCents / 100).toStringAsFixed(0)} Monetta. '
            'Estimación pendiente de entrega; no es saldo liberado.',
            style: sans(size: 12, color: colors.contentMuted, height: 1.5),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Estado por pedido (Mis Pedidos): ganado, pendiente/liberado, usado.
// ---------------------------------------------------------------------------

class OrderRewardsStatus extends StatelessWidget {
  const OrderRewardsStatus({required this.state, super.key});

  final OrderRewardsState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.monettaColors;
    final line = state.isWholesale
        ? 'Este pedido de mayoreo no genera Rewards.'
        : switch (state.state) {
            'pending' =>
              'Generaste \$${(state.earnedPendingCents / 100).toStringAsFixed(0)} Monetta pendientes. Se liberan al entregar tu pedido.',
            'available' =>
              'Liberados \$${(state.earnedReleasedCents / 100).toStringAsFixed(0)} Monetta de este pedido.',
            'reversed' =>
              'El saldo de este pedido se ajustó por devolución o cancelación.',
            _ => state.usedCents > 0
                ? 'Usaste \$${(state.usedCents / 100).toStringAsFixed(0)} Monetta en este pedido.'
                : 'Sin movimientos Rewards en este pedido.',
          };
    return Row(
      key: const ValueKey('order-rewards-status'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 15, color: colors.contentMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            line,
            style: sans(size: 12, color: colors.contentMuted, height: 1.5),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Control de canje (Checkout): disponible, máximo, toggle, errores.
// ---------------------------------------------------------------------------

/// Estado del control: el servidor (quote) define el máximo; el cliente solo
/// presenta y solicita. `onAmountChanged` + `onConfirm` los conecta el
/// integrador al `RewardsApi`.
class RewardsRedemptionControl extends StatelessWidget {
  const RewardsRedemptionControl({
    required this.quote,
    required this.selectedCents,
    required this.onAmountChanged,
    required this.onConfirm,
    this.busy = false,
    this.errorCode,
    super.key,
  });

  final RewardsQuote quote;
  final int selectedCents;
  final ValueChanged<int> onAmountChanged;
  final VoidCallback onConfirm;
  final bool busy;
  final String? errorCode;

  @override
  Widget build(BuildContext context) {
    final colors = context.monettaColors;
    if (!quote.redemptionEnabled) {
      return Text(
        'El canje de Rewards aún no está disponible.',
        key: const ValueKey('rewards-redemption-disabled'),
        style: sans(size: 12.5, color: colors.contentMuted, height: 1.5),
      );
    }
    final steps = _stepsFor(quote.maxAllowedCents);
    return Column(
      key: const ValueKey('rewards-redemption-control'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Usar \$${(selectedCents / 100).toStringAsFixed(0)} Monetta',
                style: sans(size: 13, weight: FontWeight.w600),
              ),
            ),
            Switch.adaptive(
              key: const ValueKey('rewards-redemption-toggle'),
              value: selectedCents > 0,
              onChanged: busy
                  ? null
                  : (on) => onAmountChanged(
                        on ? quote.maxAllowedCents : 0,
                      ),
            ),
          ],
        ),
        Text(
          'Disponible: \$${(quote.availableCents / 100).toStringAsFixed(0)} · '
          'Máximo para esta compra: \$${(quote.maxAllowedCents / 100).toStringAsFixed(0)} (20%)',
          style: sans(size: 12, color: colors.contentMuted, height: 1.5),
        ),
        if (selectedCents > 0 && steps.length > 1) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final step in steps)
                ChoiceChip(
                  label: Text('\$${(step / 100).toStringAsFixed(0)}'),
                  selected: selectedCents == step,
                  onSelected: busy ? null : (_) => onAmountChanged(step),
                ),
            ],
          ),
        ],
        if (errorCode != null) ...[
          const SizedBox(height: 8),
          Text(
            RewardsApiError.friendly(errorCode!),
            key: const ValueKey('rewards-redemption-error'),
            style: sans(size: 12, color: colors.sale, height: 1.5),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: busy || selectedCents <= 0 ? null : onConfirm,
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('APLICAR REWARDS'),
          ),
        ),
      ],
    );
  }

  /// Opciones discretas: máximo y mitades redondeadas a pesos. Sin slider
  /// continuo que invite a suponer precisión que el servidor no promete.
  static List<int> _stepsFor(int max) {
    if (max <= 0) return const [];
    final half = (max / 2).round();
    final options = {max, if (half > 0) half};
    final sorted = options.toList()..sort();
    return sorted;
  }
}
