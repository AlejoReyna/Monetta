/// Pure presentation for an authoritative tier result (`UI:G19` / `UI:G20`).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../boutique/boutique_tokens.dart';
import '../boutique/client_guide_components.dart';
import 'rewards_models.dart';

class RewardsProgress extends StatelessWidget {
  const RewardsProgress({
    required this.level,
    required this.fraction,
    required this.purchaseCountLabel,
    this.nextLevel,
    this.isFinalLevel = false,
    super.key,
  }) : assert(fraction >= 0 && fraction <= 1);

  final String level;
  final double fraction;

  /// Service-provided count wording remains accessible in the final state.
  final String purchaseCountLabel;
  final String? nextLevel;
  final bool isFinalLevel;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final percentage = '${(fraction * 100).round()}%';
    return Semantics(
      label:
          '$level, $percentage, $purchaseCountLabel${nextLevel == null || isFinalLevel ? '' : ', Siguiente nivel: $nextLevel'}',
      excludeSemantics: true,
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              // Let enlarged text increase the painted area rather than shrinking
              // text into a fixed circle. The surrounding page owns scrolling.
              final side = math.min(constraints.maxWidth, 250.0);
              final height = math.max(
                side,
                MediaQuery.textScalerOf(context).scale(150),
              );
              return SizedBox(
                width: side,
                height: height,
                child: CustomPaint(
                  key: const ValueKey('rewards-progress-arc'),
                  painter: RewardsArcPainter(fraction: fraction),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          level,
                          textAlign: TextAlign.center,
                          style: display(30).copyWith(
                            fontWeight: FontWeight.w700,
                            color: palette.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          percentage,
                          style: sans(size: 14, color: palette.inkMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          if (!isFinalLevel) ...[
            Text(
              purchaseCountLabel,
              textAlign: TextAlign.center,
              style: boutiqueText(
                size: 16,
                weight: FontWeight.w500,
                color: palette.ink,
              ),
            ),
            if (nextLevel != null) ...[
              const SizedBox(height: 6),
              Text(
                'Siguiente nivel: $nextLevel',
                textAlign: TextAlign.center,
                style: display(18).copyWith(color: palette.inkMuted),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class RewardsArcPainter extends CustomPainter {
  const RewardsArcPainter({required this.fraction});

  final double fraction;
  static const start = 3 * math.pi / 4;
  static const sweep = 3 * math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final diameter = math.min(size.width, size.height) - 28;
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: diameter,
      height: diameter,
    );
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE9ECE6);
    canvas.drawArc(rect, start, sweep, false, trackPaint);

    if (fraction > 0) {
      final shadowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
        ..color = const Color(0xFFA58248).withValues(alpha: .28);
      canvas.drawArc(rect, start, sweep * fraction, false, shadowPaint);

      final progressPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFA58248).withValues(alpha: .88);
      canvas.drawArc(rect, start, sweep * fraction, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(RewardsArcPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}

/// Modal limpio de `Beneficios del nivel` (`UI:G20`).
Future<void> showRewardsBenefits(
  BuildContext context, {
  required String level,
  required String introduction,
  List<String> benefits = const [],
  List<RewardsTierBenefit> structuredBenefits = const [],
}) =>
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final palette = dialogContext.boutique;
        final items = structuredBenefits.isNotEmpty
            ? structuredBenefits
            : [
                for (final b in benefits)
                  RewardsTierBenefit(kind: 'benefit', label: b),
              ];
        return Dialog(
          backgroundColor: palette.surface,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: palette.hairline),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Miembro',
                              style: sans(size: 13, color: palette.inkMuted),
                            ),
                            Text(
                              level,
                              style: display(30).copyWith(
                                fontWeight: FontWeight.w700,
                                color: palette.ink,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('rewards-benefits-close'),
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: Icon(Icons.close, size: 20, color: palette.ink),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    introduction,
                    style: sans(
                      size: 13.5,
                      color: palette.inkMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: palette.hairline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (var i = 0; i < items.length; i++) ...[
                    _BenefitRow(benefit: items[i]),
                    if (i < items.length - 1) const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 20),
                  ClientGuideButton(
                    key: const ValueKey('rewards-benefits-dismiss'),
                    label: 'Cerrar',
                    outlined: true,
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.benefit});

  final RewardsTierBenefit benefit;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final icon = switch (benefit.kind) {
      'cashback' => Icons.credit_card_outlined,
      'bonus' => Icons.card_giftcard_outlined,
      'shipping' => Icons.send_outlined,
      _ => Icons.check_circle_outline,
    };

    Widget labelWidget;
    final bonusCents = benefit.amountCents;
    if (benefit.kind == 'bonus' && bonusCents != null && bonusCents > 0) {
      final whole = (bonusCents / 100).round();
      labelWidget = Text.rich(
        TextSpan(
          style: sans(size: 14.5, color: palette.ink),
          children: [
            const TextSpan(text: 'Bono de '),
            TextSpan(
              text: '\$$whole',
              style: sans(
                size: 14.5,
                weight: FontWeight.w600,
                color: const Color(0xFF3B7030),
              ),
            ),
            TextSpan(
              text: ' mxn',
              style: sans(size: 11.5, color: palette.inkMuted),
            ),
          ],
        ),
      );
    } else {
      labelWidget = Text(
        benefit.label,
        style: sans(size: 14.5, color: palette.ink),
      );
    }

    return Row(
      children: [
        Icon(icon, size: 19, color: palette.inkMuted),
        const SizedBox(width: 12),
        Expanded(child: labelWidget),
      ],
    );
  }
}
