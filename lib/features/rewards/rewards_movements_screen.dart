/// Pantalla dedicada de Saldo y movimientos (`UI:G21`).
library;

import 'package:flutter/material.dart';

import '../../app/monetta_tokens.g.dart';
import '../../app/theme.dart';
import '../boutique/boutique_tokens.dart';
import '../boutique/client_guide_components.dart';
import '../boutique/client_guide_scaffold.dart';
import 'rewards_models.dart';
import 'rewards_section.dart';

Future<void> openRewardsMovements(
  BuildContext context, {
  required RewardsReader reader,
  RewardsSummary? initialSummary,
}) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/rewards/movements'),
        builder: (_) => RewardsMovementsScreen(
          reader: reader,
          initialSummary: initialSummary,
        ),
      ),
    );

class RewardsMovementsScreen extends StatefulWidget {
  const RewardsMovementsScreen({
    required this.reader,
    this.initialSummary,
    super.key,
  });

  final RewardsReader reader;
  final RewardsSummary? initialSummary;

  @override
  State<RewardsMovementsScreen> createState() => _RewardsMovementsScreenState();
}

class _RewardsMovementsScreenState extends State<RewardsMovementsScreen> {
  late Future<({RewardsSummary summary, List<RewardsMovement> movements})>
      _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = (() async {
      final summary = widget.initialSummary ?? await widget.reader.summary();
      final page = await widget.reader.activity();
      return (summary: summary, movements: page.movements);
    })();
  }

  void _retry() {
    setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return ClientGuideScaffold(
      current: ClientGuideDestination.account,
      body: FutureBuilder<
          ({RewardsSummary summary, List<RewardsMovement> movements})>(
        future: _future,
        builder: (context, snapshot) {
          final summary = snapshot.data?.summary ?? widget.initialSummary;
          final availableText = summary == null
              ? '—'
              : RewardsSummary.formatMxn(summary.availableCents);
          return ListView(
            key: const ValueKey('rewards-movements-scroll'),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              InkWell(
                key: const ValueKey('rewards-movements-back'),
                onTap: () => Navigator.of(context).maybePop(),
                borderRadius: BoutiqueRadius.control,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.chevron_left,
                        size: 22,
                        color: palette.inkMuted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Movimientos',
                          style: clientGuideStyle(
                            context,
                            MonettaTokens.screenTitle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Saldo disponible',
                style: sans(size: 13, color: palette.inkMuted),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    availableText,
                    key: const ValueKey('rewards-movements-balance'),
                    style: boutiqueScreenTitle(
                      context: context,
                      color: palette.gold,
                    ),
                  ),
                  if (summary != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      'mxn',
                      style: sans(size: 13, color: palette.inkMuted),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              Divider(height: 1, color: palette.hairline),
              const SizedBox(height: 16),
              if (snapshot.connectionState == ConnectionState.waiting)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.ink,
                    ),
                  ),
                )
              else if (snapshot.hasError)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No pudimos cargar tus movimientos.',
                      style: sans(size: 14, color: palette.inkMuted),
                    ),
                    const SizedBox(height: 12),
                    ClientGuideButton(
                      label: 'Reintentar',
                      outlined: true,
                      onPressed: _retry,
                    ),
                  ],
                )
              else if (snapshot.data!.movements.isEmpty)
                Container(
                  key: const ValueKey('rewards-movements-empty'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 36,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BoutiqueRadius.card,
                    border: Border.all(color: palette.hairline),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Aún no hay movimientos',
                        textAlign: TextAlign.center,
                        style: display(20).copyWith(color: palette.ink),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Aquí podrás consultar el detalle de tu saldo.',
                        textAlign: TextAlign.center,
                        style: sans(size: 13.5, color: palette.inkMuted),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    for (var i = 0;
                        i < snapshot.data!.movements.length;
                        i++) ...[
                      _MovementRow(movement: snapshot.data!.movements[i]),
                      if (i < snapshot.data!.movements.length - 1)
                        Divider(height: 24, color: palette.hairline),
                    ],
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.movement});

  final RewardsMovement movement;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final positive = movement.amountCents >= 0;
    final formattedAbs = RewardsSummary.formatMxn(movement.amountCents.abs());
    final signed = '${positive ? '+' : '-'}$formattedAbs';
    final amountColor = positive ? const Color(0xFF3B7030) : palette.ink;
    final title = _movementTitle(movement);
    final subtitle = _movementSubtitle(movement);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: sans(
                  size: 14.5,
                  weight: FontWeight.w500,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: sans(size: 12.5, color: palette.inkMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              signed,
              style: sans(
                size: 14.5,
                weight: FontWeight.w600,
                color: amountColor,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              'mxn',
              style: sans(size: 11, color: palette.inkMuted),
            ),
          ],
        ),
      ],
    );
  }

  static String _movementTitle(RewardsMovement m) => switch (m.type) {
        'earn_pending' => 'Abono pendiente',
        'earn_released' => 'Abono',
        'bonus_released' || 'bonus_pending' => 'Bono de nivel',
        'redeem_settled' || 'redeem_reserved' => 'Uso de saldo',
        'redeem_released' => 'Liberación de reserva',
        'earn_reversed' || 'bonus_reversed' => 'Ajuste por devolución',
        'expired' => 'Saldo vencido',
        _ => 'Movimiento',
      };

  static String _movementSubtitle(RewardsMovement m) {
    final date = _formatDate(m.createdAt.toLocal());
    final reason = m.reason?.trim();
    if (reason != null && reason.isNotEmpty && reason.startsWith('Bono de')) {
      return '$date · $reason';
    }
    if (m.orderShopifyId != null && m.orderShopifyId!.isNotEmpty) {
      return '$date · Pedido #${m.orderShopifyId}';
    }
    if (reason != null && reason.isNotEmpty) {
      return '$date · $reason';
    }
    return date;
  }

  static String _formatDate(DateTime d) {
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
