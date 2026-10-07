/// Tarjeta de saldo para las pantallas de E (paquete F).
///
/// Lee [RewardsService] y delega la presentación a
/// `rewards_components.dart`. Estados honestos: carga, no disponible,
/// error con reintento y vacío. Nunca muestra saldos ficticios.
///
/// Nota de nombres: `rewards_components.dart` expone la tarjeta puramente
/// presentacional (datos del contrato); esta es la tarjeta ligada al
/// servicio que E monta en Cuenta, Pedidos y Notificaciones.
library;

import 'package:flutter/material.dart';

import '../account/account_boutique.dart';
import '../boutique/boutique_tokens.dart';
import 'rewards_account.dart';
import 'rewards_components.dart' as rc;
import 'rewards_error_kind.dart';
import 'rewards_models.dart';

/// `accountId` es clave local de alcance; la identidad la deriva el backend
/// del bearer. `compact` reduce el bloque para listas (Pedidos,
/// Notificaciones).
class RewardsBalanceCard extends StatefulWidget {
  const RewardsBalanceCard({
    required this.accountId,
    required this.service,
    this.compact = false,
    super.key,
  });

  final String accountId;
  final RewardsService service;
  final bool compact;

  @override
  State<RewardsBalanceCard> createState() => _RewardsBalanceCardState();
}

class _RewardsBalanceCardState extends State<RewardsBalanceCard> {
  late Future<RewardsBalance?> _pending;

  @override
  void initState() {
    super.initState();
    _pending = _safeBalance();
  }

  @override
  void didUpdateWidget(covariant RewardsBalanceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId ||
        oldWidget.service != widget.service) {
      _pending = _safeBalance();
    }
  }

  Future<RewardsBalance?> _safeBalance() async {
    try {
      return await widget.service.balance(accountId: widget.accountId);
    } on Object catch (error) {
      if (classifyRewardsError(error) == RewardsErrorKind.unavailable) {
        return null;
      }
      rethrow;
    }
  }

  void _retry() => setState(() => _pending = _safeBalance());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RewardsBalance?>(
      future: _pending,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _CardLoading(
            key: ValueKey('rewards-card-loading'),
          );
        }
        if (snapshot.hasError) {
          // Error independiente: no rompe la pantalla que lo contiene.
          return _CardError(
            key: const ValueKey('rewards-card-error'),
            kind: classifyRewardsError(snapshot.error),
            onRetry: _retry,
          );
        }
        final balance = snapshot.data;
        if (balance == null) {
          return const _CardUnavailable(
            key: ValueKey('rewards-card-unavailable'),
          );
        }
        return RewardsBalancePresentation(
          balance: balance,
          compact: widget.compact,
        );
      },
    );
  }
}

/// Presentación pura del saldo leído (delegada por la tarjeta de servicio).
class RewardsBalancePresentation extends StatelessWidget {
  const RewardsBalancePresentation({
    required this.balance,
    this.compact = false,
    super.key,
  });

  final RewardsBalance balance;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return rc.RewardsBalanceCard(
      summary: RewardsSummary(
        redemptionEnabled: balance.redemptionEnabled,
        availableCents: balance.availableCents,
        pendingCents: balance.pendingCents,
        reservedCents: balance.reservedCents,
        nextExpiry:
            balance.nextExpiryAt == null || balance.nextExpiryCents == null
                ? null
                : RewardsExpiry(
                    cents: balance.nextExpiryCents!,
                    at: balance.nextExpiryAt!,
                  ),
        asOf: balance.asOf,
        firstPurchaseEnabled: false,
        reviewEnabled: false,
        referralEnabled: false,
      ),
    );
  }
}

class _CardFrame extends StatelessWidget {
  const _CardFrame({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BoutiqueSpace.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BoutiqueRadius.card,
        border: Border.all(color: palette.hairline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _CardLoading extends StatelessWidget {
  const _CardLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return _CardFrame(
      children: [
        Text(
          'SALDO MONETTA',
          style: boutiqueEyebrow(size: 11, color: palette.goldText),
        ),
        const SizedBox(height: BoutiqueSpace.sm),
        Text(
          'Consultando tu saldo…',
          style: boutiqueText(size: 13, color: palette.inkMuted),
        ),
      ],
    );
  }
}

class _CardUnavailable extends StatelessWidget {
  const _CardUnavailable({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return _CardFrame(
      children: [
        Text(
          'SALDO MONETTA',
          style: boutiqueEyebrow(size: 11, color: palette.goldText),
        ),
        const SizedBox(height: BoutiqueSpace.sm),
        Text(
          'Monetta Rewards aún no está disponible',
          style: boutiqueTitle(size: 15, color: palette.ink),
        ),
        const SizedBox(height: BoutiqueSpace.xs),
        Text(
          'Tus compras se registran con normalidad; aquí verás tu '
          'disponible y pendiente en cuanto el programa esté activo.',
          style: boutiqueText(size: 13, color: palette.inkMuted),
        ),
      ],
    );
  }
}

class _CardError extends StatelessWidget {
  const _CardError({required this.kind, required this.onRetry, super.key});

  final RewardsErrorKind kind;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final isSession = kind == RewardsErrorKind.session;
    final title =
        isSession ? 'Tu sesión terminó' : 'No pudimos consultar tu saldo';
    return _CardFrame(
      children: [
        Text(
          'SALDO MONETTA',
          style: boutiqueEyebrow(size: 11, color: palette.goldText),
        ),
        const SizedBox(height: BoutiqueSpace.sm),
        Text(
          title,
          style: boutiqueTitle(size: 15, color: palette.ink),
        ),
        const SizedBox(height: BoutiqueSpace.md),
        if (isSession)
          const ENotice(
            message: 'Tu sesión terminó. Inicia sesión de nuevo para ver tu '
                'saldo Monetta.',
            icon: Icons.lock_outline_rounded,
          )
        else
          ENotice(
            message: kind == RewardsErrorKind.serviceDown
                ? 'Monetta Rewards no responde en este momento. '
                    'Inténtalo más tarde.'
                : 'Revisa tu conexión e inténtalo de nuevo.',
            actionLabel: 'Reintentar',
            onAction: onRetry,
            icon: kind == RewardsErrorKind.serviceDown
                ? Icons.cloud_off_rounded
                : Icons.signal_wifi_off_rounded,
          ),
      ],
    );
  }
}
