/// DTOs del contrato Rewards V1 (`docs/redesign/REWARDS_CONTRACT_V1.md`).
///
/// Solo presentación: ningún saldo autoritativo se calcula aquí. El servidor
/// es la autoridad; el cliente muestra lo que el contrato devuelve.
library;

class RewardsTierBenefit {
  const RewardsTierBenefit({
    required this.kind,
    required this.label,
    this.amountCents,
  });

  final String kind;
  final String label;
  final int? amountCents;

  factory RewardsTierBenefit.fromJson(Map<String, dynamic> json) =>
      RewardsTierBenefit(
        kind: '${json['kind'] ?? 'benefit'}',
        label: '${json['label'] ?? ''}',
        amountCents: (json['amountCents'] as num?)?.toInt(),
      );
}

class RewardsTier {
  const RewardsTier({
    required this.level,
    required this.nextLevel,
    required this.isFinalLevel,
    required this.completedPurchases,
    required this.targetPurchases,
    required this.progressFraction,
    required this.progressPercent,
    required this.purchaseCountLabel,
    required this.cashbackBps,
    required this.bonusCents,
    required this.freeShipping,
    required this.introduction,
    required this.benefits,
  });

  final String level;
  final String? nextLevel;
  final bool isFinalLevel;
  final int completedPurchases;
  final int targetPurchases;
  final double progressFraction;
  final int progressPercent;
  final String purchaseCountLabel;
  final int cashbackBps;
  final int bonusCents;
  final bool freeShipping;
  final String introduction;
  final List<RewardsTierBenefit> benefits;

  factory RewardsTier.fromJson(Map<String, dynamic> json) {
    final rawBenefits = json['benefits'];
    final benefits = <RewardsTierBenefit>[
      if (rawBenefits is List)
        for (final item in rawBenefits)
          if (item is Map<String, dynamic>) RewardsTierBenefit.fromJson(item),
    ];
    final fraction =
        ((json['progressFraction'] as num? ?? 0).toDouble()).clamp(0.0, 1.0);
    return RewardsTier(
      level: '${json['level'] ?? 'PRO'}',
      nextLevel: json['nextLevel'] as String?,
      isFinalLevel: json['isFinalLevel'] == true,
      completedPurchases: (json['completedPurchases'] as num? ?? 0).toInt(),
      targetPurchases: (json['targetPurchases'] as num? ?? 10).toInt(),
      progressFraction: fraction,
      progressPercent: (json['progressPercent'] as num? ?? 0).toInt(),
      purchaseCountLabel: '${json['purchaseCountLabel'] ?? ''}',
      cashbackBps: (json['cashbackBps'] as num? ?? 100).toInt(),
      bonusCents: (json['bonusCents'] as num? ?? 0).toInt(),
      freeShipping: json['freeShipping'] != false,
      introduction: '${json['introduction'] ?? ''}',
      benefits: List.unmodifiable(benefits),
    );
  }
}

class RewardsSummary {
  const RewardsSummary({
    required this.redemptionEnabled,
    required this.availableCents,
    required this.pendingCents,
    required this.reservedCents,
    required this.nextExpiry,
    required this.asOf,
    required this.firstPurchaseEnabled,
    required this.reviewEnabled,
    required this.referralEnabled,
    this.earnBps = 100,
    this.tier,
  });

  final bool redemptionEnabled;
  final int availableCents;
  final int pendingCents;
  final int reservedCents;
  final RewardsExpiry? nextExpiry;
  final DateTime asOf;
  final bool firstPurchaseEnabled;
  final bool reviewEnabled;
  final bool referralEnabled;
  final int earnBps;
  final RewardsTier? tier;

  bool get membershipAvailable => tier != null;
  bool get tierProgressAvailable => tier != null;
  bool get tierBenefitsAvailable => tier != null && tier!.benefits.isNotEmpty;

  factory RewardsSummary.fromJson(Map<String, dynamic> json) {
    final rawBalance = json['balance'];
    if (rawBalance is! Map<String, dynamic>) {
      throw const RewardsApiError('invalid_response');
    }
    final balance = rawBalance;
    final incentives =
        (json['incentives'] ?? <String, dynamic>{}) as Map<String, dynamic>;
    final program =
        (json['program'] ?? <String, dynamic>{}) as Map<String, dynamic>;
    final expiry = balance['nextExpiry'] as Map<String, dynamic>?;
    final rawTier = json['tier'];
    return RewardsSummary(
      redemptionEnabled: program['redemptionEnabled'] == true,
      availableCents: _requiredInt(balance['availableCents']),
      pendingCents: _requiredInt(balance['pendingCents']),
      reservedCents: _requiredInt(balance['reservedCents']),
      nextExpiry: expiry == null
          ? null
          : RewardsExpiry(
              cents: _requiredInt(expiry['cents']),
              at: _requiredDate(expiry['at']),
            ),
      asOf: _requiredDate(balance['asOf']),
      firstPurchaseEnabled:
          (incentives['firstPurchase'] as Map<String, dynamic>?)?['enabled'] ==
              true,
      reviewEnabled:
          (incentives['review'] as Map<String, dynamic>?)?['enabled'] == true,
      referralEnabled:
          (incentives['referral'] as Map<String, dynamic>?)?['enabled'] == true,
      earnBps: (program['earnBps'] as num? ?? 100).toInt(),
      tier: rawTier is Map<String, dynamic>
          ? RewardsTier.fromJson(rawTier)
          : null,
    );
  }

  /// "Tienes $184 Monetta disponibles".
  String get availableLabel => _short(availableCents);

  /// "$41.97" (always two decimal places for UI:G19/UI:G21).
  String get availableMxnAmount => formatMxn(availableCents);

  static String formatMxn(int cents) {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final major = abs ~/ 100;
    final frac = (abs % 100).toString().padLeft(2, '0');
    return '$sign\$$major.$frac';
  }

  static String _short(int cents) {
    final major = cents / 100;
    final body =
        cents % 100 == 0 ? major.toInt().toString() : major.toStringAsFixed(2);
    return '\$$body Monetta';
  }
}

class RewardsExpiry {
  const RewardsExpiry({required this.cents, required this.at});

  final int cents;
  final DateTime at;
}

class RewardsMovement {
  const RewardsMovement({
    required this.id,
    required this.type,
    required this.state,
    required this.amountCents,
    required this.orderShopifyId,
    required this.reason,
    required this.createdAt,
  });

  final int id;
  final String type;
  final String state;
  final int amountCents;
  final String? orderShopifyId;
  final String? reason;
  final DateTime createdAt;

  factory RewardsMovement.fromJson(Map<String, dynamic> json) =>
      RewardsMovement(
        id: _requiredInt(json['id']),
        type: _requiredString(json['type']),
        state: _requiredString(json['state']),
        amountCents: _requiredInt(json['amountCents']),
        orderShopifyId: json['orderShopifyId'] as String?,
        reason: json['reason'] as String?,
        createdAt: _requiredDate(json['createdAt']),
      );
}

class RewardsQuote {
  const RewardsQuote({
    required this.quoteId,
    required this.cartRevision,
    required this.subtotalEligibleCents,
    required this.availableCents,
    required this.maxAllowedCents,
    required this.estimatedEarnCents,
    required this.redemptionEnabled,
    required this.expiresAt,
  });

  final String quoteId;
  final String cartRevision;
  final int subtotalEligibleCents;
  final int availableCents;
  final int maxAllowedCents;
  final int estimatedEarnCents;
  final bool redemptionEnabled;
  final DateTime expiresAt;

  factory RewardsQuote.fromJson(Map<String, dynamic> json) => RewardsQuote(
        quoteId: '${json['quoteId']}',
        cartRevision: '${json['cartRevision'] ?? ''}',
        subtotalEligibleCents:
            (json['subtotalEligibleCents'] as num? ?? 0).toInt(),
        availableCents: (json['availableCents'] as num? ?? 0).toInt(),
        maxAllowedCents: (json['maxAllowedCents'] as num? ?? 0).toInt(),
        estimatedEarnCents: (json['estimatedEarnCents'] as num? ?? 0).toInt(),
        redemptionEnabled: json['redemptionEnabled'] == true,
        expiresAt: DateTime.tryParse('${json['expiresAt']}') ?? DateTime.now(),
      );
}

class OrderRewardsState {
  const OrderRewardsState({
    required this.orderShopifyId,
    required this.isWholesale,
    required this.earnedPendingCents,
    required this.earnedReleasedCents,
    required this.usedCents,
    required this.state,
  });

  final String orderShopifyId;
  final bool isWholesale;
  final int earnedPendingCents;
  final int earnedReleasedCents;
  final int usedCents;
  final String state;

  factory OrderRewardsState.fromJson(Map<String, dynamic> json) =>
      OrderRewardsState(
        orderShopifyId: '${json['orderShopifyId']}',
        isWholesale: json['isWholesale'] == true,
        earnedPendingCents: (json['earnedPendingCents'] as num? ?? 0).toInt(),
        earnedReleasedCents: (json['earnedReleasedCents'] as num? ?? 0).toInt(),
        usedCents: (json['usedCents'] as num? ?? 0).toInt(),
        state: '${json['state'] ?? 'none'}',
      );
}

/// Error tipificado del contrato para mensajes honestos en UI.
class RewardsApiError implements Exception {
  const RewardsApiError(this.code, [this.message]);

  final String code;
  final String? message;

  static String friendly(String code) => switch (code) {
        'redemption_disabled' => 'El canje está deshabilitado por ahora.',
        'wholesale_redeem_undecided' =>
          'El uso de Rewards en mayoreo aún no está definido.',
        'exceeds_limit' => 'Supera el máximo del 20% para esta compra.',
        'insufficient_balance' => 'Saldo insuficiente para ese importe.',
        'quote_expired' =>
          'Tu cotización venció; vuelve a calcular antes de pagar.',
        'reconciliation_required' =>
          'Tu canje necesita revisión; no se liberó saldo.',
        'discount_already_used' => 'Ese descuento ya fue utilizado.',
        _ => 'No fue posible completar la operación.',
      };
}

int _requiredInt(Object? raw) {
  if (raw is! num || !raw.isFinite || raw != raw.truncateToDouble()) {
    throw const RewardsApiError('invalid_response');
  }
  return raw.toInt();
}

DateTime _requiredDate(Object? raw) {
  final date = raw is String ? DateTime.tryParse(raw) : null;
  if (date == null) throw const RewardsApiError('invalid_response');
  return date.toUtc();
}

String _requiredString(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) {
    throw const RewardsApiError('invalid_response');
  }
  return raw;
}
