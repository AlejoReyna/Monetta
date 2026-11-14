/// DTOs del contrato Rewards V1 (`docs/redesign/REWARDS_CONTRACT_V1.md`).
///
/// Solo presentación: ningún saldo autoritativo se calcula aquí. El servidor
/// es la autoridad; el cliente muestra lo que el contrato devuelve.
library;

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

  // V1 has no authoritative membership, thresholds or benefits source.
  // These gates must stay closed until a versioned membership DTO is approved.
  bool get membershipAvailable => false;
  bool get tierProgressAvailable => false;
  bool get tierBenefitsAvailable => false;

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
    );
  }

  /// "Tienes $184 Monetta disponibles".
  String get availableLabel => _short(availableCents);

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
