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

  factory RewardsSummary.fromJson(Map<String, dynamic> json) {
    final balance = _requiredObject(json, 'balance');
    final incentives =
        (json['incentives'] ?? <String, dynamic>{}) as Map<String, dynamic>;
    final program =
        (json['program'] ?? <String, dynamic>{}) as Map<String, dynamic>;
    return RewardsSummary(
      redemptionEnabled: program['redemptionEnabled'] == true,
      availableCents:
          _requiredInt(balance, 'availableCents', prefix: 'balance.'),
      pendingCents: _requiredInt(balance, 'pendingCents', prefix: 'balance.'),
      reservedCents: _requiredInt(balance, 'reservedCents', prefix: 'balance.'),
      nextExpiry: _optionalExpiry(balance),
      asOf: _requiredDate(balance, 'asOf', prefix: 'balance.'),
      firstPurchaseEnabled:
          (incentives['firstPurchase'] as Map<String, dynamic>?)?['enabled'] ==
              true,
      reviewEnabled:
          (incentives['review'] as Map<String, dynamic>?)?['enabled'] == true,
      referralEnabled:
          (incentives['referral'] as Map<String, dynamic>?)?['enabled'] == true,
    );
  }

  /// `balance.nextExpiry` may be absent or `null`; when present it must be a
  /// complete object.
  static RewardsExpiry? _optionalExpiry(Map<String, dynamic> balance) {
    final raw = balance['nextExpiry'];
    if (raw == null) return null;
    if (raw is! Map<String, dynamic>) {
      throw const RewardsContractError('balance.nextExpiry');
    }
    return RewardsExpiry(
      cents: _requiredInt(raw, 'cents', prefix: 'balance.nextExpiry.'),
      at: _requiredDate(raw, 'at', prefix: 'balance.nextExpiry.'),
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
        id: _requiredInt(json, 'id'),
        type: '${json['type'] ?? ''}',
        state: '${json['state'] ?? ''}',
        amountCents: _requiredInt(json, 'amountCents'),
        orderShopifyId: _optionalString(json, 'orderShopifyId'),
        reason: _optionalString(json, 'reason'),
        createdAt: _requiredDate(json, 'createdAt'),
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
        quoteId: _requiredNonEmptyString(json, 'quoteId'),
        cartRevision: _requiredString(json, 'cartRevision'),
        subtotalEligibleCents: _requiredInt(json, 'subtotalEligibleCents'),
        availableCents: _requiredInt(json, 'availableCents'),
        maxAllowedCents: _requiredInt(json, 'maxAllowedCents'),
        estimatedEarnCents: _requiredInt(json, 'estimatedEarnCents'),
        redemptionEnabled: json['redemptionEnabled'] == true,
        expiresAt: _requiredDate(json, 'expiresAt'),
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
        orderShopifyId: _requiredNonEmptyString(json, 'orderShopifyId'),
        isWholesale: json['isWholesale'] == true,
        earnedPendingCents: _requiredInt(json, 'earnedPendingCents'),
        earnedReleasedCents: _requiredInt(json, 'earnedReleasedCents'),
        usedCents: _requiredInt(json, 'usedCents'),
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
        'invalid_response' =>
          'Recibimos una respuesta inesperada de Monetta Rewards. '
              'Inténtalo de nuevo.',
        _ => 'No fue posible completar la operación.',
      };
}

/// The server answered, but the body does not satisfy the Rewards contract
/// (missing or mistyped required field, unparseable date, non-JSON body).
///
/// Client-side code `invalid_response`: the UI shows it as a recoverable
/// "service down" state, never as a connection problem. [field] is the path
/// of the offending field; no body values are ever kept.
class RewardsContractError extends RewardsApiError {
  const RewardsContractError(this.field)
      : super('invalid_response', 'Response does not match the contract.');

  /// Path of the field that broke the contract, e.g. `balance.asOf`.
  final String field;

  @override
  String toString() => 'RewardsContractError(field: $field)';
}

Map<String, dynamic> _requiredObject(
  Map<String, dynamic> json,
  String key, {
  String prefix = '',
}) {
  final value = json[key];
  if (value is Map<String, dynamic>) return value;
  throw RewardsContractError('$prefix$key');
}

/// Accepts a JSON number with an integral value (`18400` or `18400.0`).
int _requiredInt(
  Map<String, dynamic> json,
  String key, {
  String prefix = '',
}) {
  final value = json[key];
  if (value is num && value.isFinite && value == value.truncateToDouble()) {
    return value.toInt();
  }
  throw RewardsContractError('$prefix$key');
}

DateTime _requiredDate(
  Map<String, dynamic> json,
  String key, {
  String prefix = '',
}) {
  final value = json[key];
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed != null) return parsed;
  throw RewardsContractError('$prefix$key');
}

String _requiredString(
  Map<String, dynamic> json,
  String key, {
  String prefix = '',
}) {
  final value = json[key];
  if (value is String) return value;
  throw RewardsContractError('$prefix$key');
}

String _requiredNonEmptyString(
  Map<String, dynamic> json,
  String key, {
  String prefix = '',
}) {
  final value = _requiredString(json, key, prefix: prefix);
  if (value.isEmpty) throw RewardsContractError('$prefix$key');
  return value;
}

String? _optionalString(
  Map<String, dynamic> json,
  String key, {
  String prefix = '',
}) {
  final value = json[key];
  if (value == null || value is String) return value as String?;
  throw RewardsContractError('$prefix$key');
}
