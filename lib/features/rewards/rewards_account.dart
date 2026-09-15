/// Abstracción de lectura Rewards para las pantallas de E (paquete F).
///
/// E integra Cuenta, Pedidos y Notificaciones contra esta interfaz; F aporta
/// la implementación HTTP ([ApiRewardsService]) sobre el contrato V1 y el
/// estado honesto de no disponible ([UnavailableRewardsService]).
///
/// Identidad: el backend deriva la cuenta del bearer. `accountId` es solo una
/// clave local de alcance (no autoridad) y `orderId` debe ser el Shopify
/// order id cuando exista; sin identidad Shopify (apartado sin registrar) o
/// sin snapshot, [forOrder] devuelve null y el renglón no se muestra.
library;

import 'rewards_api.dart';
import 'rewards_models.dart';

/// Error de lectura de Rewards. `unavailable` = programa sin conectar;
/// cualquier otro código admite reintento o re-login según pantalla.
class RewardsException implements Exception {
  const RewardsException(this.code, [this.message]);

  final String code;
  final String? message;

  @override
  String toString() => 'RewardsException($code)';

  static String friendly(String code) => RewardsApiError.friendly(code);
}

/// Saldo resumido para tarjetas de cuenta. Presentación con frescura
/// explícita; nunca autorización de canje.
class RewardsBalance {
  const RewardsBalance({
    required this.availableCents,
    required this.pendingCents,
    required this.reservedCents,
    required this.redemptionEnabled,
    required this.asOf,
    this.nextExpiryCents,
    this.nextExpiryAt,
  });

  final int availableCents;
  final int pendingCents;
  final int reservedCents;
  final bool redemptionEnabled;
  final DateTime asOf;
  final int? nextExpiryCents;
  final DateTime? nextExpiryAt;
}

/// Desglose por pedido para Mis pedidos y el detalle.
class RewardsOrderBreakdown {
  const RewardsOrderBreakdown({
    required this.earnedAvailableCents,
    required this.earnedPendingCents,
    required this.redeemedCents,
    required this.adjustedCents,
  });

  final int earnedAvailableCents;
  final int earnedPendingCents;
  final int redeemedCents;
  final int adjustedCents;

  bool get isEmpty =>
      earnedAvailableCents <= 0 &&
      earnedPendingCents <= 0 &&
      redeemedCents <= 0 &&
      adjustedCents == 0;
}

/// `"$184"` estilo es-MX sin decimales cuando es entero.
String formatRewardsMxn(int cents) {
  final negative = cents < 0;
  final abs = cents.abs();
  final major = abs ~/ 100;
  final rest = abs % 100;
  final digits = '$major';
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  final body = rest == 0
      ? buffer.toString()
      : '${buffer.toString()}.${rest.toString().padLeft(2, '0')}';
  return '${negative ? '-' : ''}\$$body';
}

/// Fuente de datos Rewards para las pantallas. Implementaciones: HTTP real o
/// no disponible. Nunca calcula saldos en el cliente.
abstract class RewardsService {
  const RewardsService();

  Future<RewardsBalance> balance({required String accountId});

  /// Null cuando el pedido no tiene identidad Shopify o no tiene snapshot
  /// (apartado sin registrar, pedido antiguo sin espejo). Lanza
  /// [RewardsException] ante fallos de red/autorización.
  Future<RewardsOrderBreakdown?> forOrder({
    required String accountId,
    required String orderId,
  });
}

/// Estado honesto sin backend: toda lectura lanza `unavailable`.
class UnavailableRewardsService extends RewardsService {
  const UnavailableRewardsService();

  @override
  Future<RewardsBalance> balance({required String accountId}) =>
      Future.error(const RewardsException('unavailable'));

  @override
  Future<RewardsOrderBreakdown?> forOrder({
    required String accountId,
    required String orderId,
  }) =>
      Future.error(const RewardsException('unavailable'));
}

/// Implementación HTTP sobre el contrato V1 de F.
class ApiRewardsService extends RewardsService {
  const ApiRewardsService(this.api);

  final RewardsApi api;

  @override
  Future<RewardsBalance> balance({required String accountId}) async {
    try {
      final summary = await api.summary();
      return RewardsBalance(
        availableCents: summary.availableCents,
        pendingCents: summary.pendingCents,
        reservedCents: summary.reservedCents,
        redemptionEnabled: summary.redemptionEnabled,
        asOf: summary.asOf,
        nextExpiryCents: summary.nextExpiry?.cents,
        nextExpiryAt: summary.nextExpiry?.at,
      );
    } on RewardsApiError catch (error) {
      throw RewardsException(error.code, error.message);
    }
  }

  @override
  Future<RewardsOrderBreakdown?> forOrder({
    required String accountId,
    required String orderId,
  }) async {
    try {
      final state = await api.orderRewards(orderId);
      if (state.isWholesale) {
        return const RewardsOrderBreakdown(
          earnedAvailableCents: 0,
          earnedPendingCents: 0,
          redeemedCents: 0,
          adjustedCents: 0,
        );
      }
      return RewardsOrderBreakdown(
        earnedAvailableCents: state.earnedReleasedCents,
        earnedPendingCents: state.earnedPendingCents,
        redeemedCents: state.usedCents,
        adjustedCents: 0,
      );
    } on RewardsApiError catch (error) {
      if (error.code == 'not_found') return null;
      throw RewardsException(error.code, error.message);
    }
  }
}
