/// Pegamento E para el contrato Rewards V1 (paquete F).
///
/// F es propietario del motor, el ledger, `RewardsApi`, los modelos y los
/// componentes de presentación (`rewards_api.dart`, `rewards_models.dart`,
/// `rewards_components.dart`). Este archivo, propiedad de E, solo resuelve el
/// lector y pinta los estados de pantalla que F no posee: carga, función no
/// disponible, sesión caducada, error con reintento y vacío.
///
/// Reglas:
/// - E nunca calcula ni modifica saldos. Todo importe viene del servidor.
/// - Sin backend configurado (`ACCOUNTS_ORDERS_BASE_URL` ausente) se muestra
///   el estado honesto de no disponible; nunca un saldo ficticio.
/// - La figura antigua de "320 puntos / Nivel Plata" no se implementa.
library;

import 'package:flutter/material.dart';

import '../../app/account_controller.dart';
import '../../data/accounts_orders/accounts_orders_config.dart';
import '../account/account_boutique.dart';
import '../boutique/boutique_tokens.dart';
import 'rewards_api.dart';
import 'rewards_components.dart';
import 'rewards_error_kind.dart';
import 'rewards_models.dart';

/// Lectura mínima del contrato que necesitan las pantallas de E.
abstract class RewardsReader {
  Future<RewardsSummary> summary();
  Future<({List<RewardsMovement> movements, String? nextCursor})> activity();
  Future<OrderRewardsState> orderRewards(String shopifyOrderId);
}

/// Lector real sobre el cliente HTTP de F.
class ApiRewardsReader implements RewardsReader {
  ApiRewardsReader(this._api);

  final RewardsApi _api;

  @override
  Future<RewardsSummary> summary() => _api.summary();

  @override
  Future<({List<RewardsMovement> movements, String? nextCursor})> activity() =>
      _api.activity();

  @override
  Future<OrderRewardsState> orderRewards(String shopifyOrderId) =>
      _api.orderRewards(shopifyOrderId);
}

/// Resuelve el cliente de F para la cuenta activa, o null cuando el backend
/// no está configurado en este build. Síncrono a propósito: el token se pide
/// por callback en cada llamada, así que construirlo no hace red.
RewardsApi? resolveRewardsApi({
  required AccountsOrdersConfig config,
  required RewardsTokenProvider tokenProvider,
}) {
  final baseUrl = config.baseUrl;
  if (!config.enabled || baseUrl == null || baseUrl.isEmpty) return null;
  return RewardsApi(baseUrl: baseUrl, tokenProvider: tokenProvider);
}

/// Sección con ciclo de vida propio: resuelve el lector de F una sola vez
/// por pantalla y cierra su cliente HTTP al salir.
///
/// [reader] fijo (fixtures de prueba) tiene prioridad y no se cierra aquí.
/// Sin [reader], se intenta el backend configurado en el entorno; sin
/// backend, la sección muestra el estado honesto de no disponible.
class AutoRewardsSection extends StatefulWidget {
  const AutoRewardsSection({
    required this.controller,
    this.reader,
    this.showMovements = true,
    super.key,
  });

  final AccountController controller;
  final RewardsReader? reader;
  final bool showMovements;

  @override
  State<AutoRewardsSection> createState() => _AutoRewardsSectionState();
}

class _AutoRewardsSectionState extends State<AutoRewardsSection> {
  RewardsApi? _api;
  RewardsReader? _effective;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant AutoRewardsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reader != widget.reader ||
        oldWidget.controller != widget.controller) {
      _resolve();
    }
  }

  void _resolve() {
    _api?.close();
    _api = null;
    final fixed = widget.reader;
    if (fixed != null) {
      _effective = fixed;
      return;
    }
    _api = resolveRewardsApi(
      config: AccountsOrdersConfig.fromEnvironment(),
      tokenProvider: widget.controller.accessTokenForBackend,
    );
    final api = _api;
    _effective = api == null ? null : ApiRewardsReader(api);
  }

  @override
  void dispose() {
    _api?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RewardsSection(
      controller: widget.controller,
      reader: _effective,
      showMovements: widget.showMovements,
    );
  }
}

/// Renglón por pedido con ciclo de vida propio. Sin [reader] ni [controller]
/// no muestra nada; sin identidad Shopify tampoco.
class AutoOrderRewardsLine extends StatefulWidget {
  const AutoOrderRewardsLine({
    required this.shopifyOrderId,
    this.reader,
    this.controller,
    super.key,
  });

  final String? shopifyOrderId;
  final RewardsReader? reader;
  final AccountController? controller;

  @override
  State<AutoOrderRewardsLine> createState() => _AutoOrderRewardsLineState();
}

class _AutoOrderRewardsLineState extends State<AutoOrderRewardsLine> {
  RewardsApi? _api;
  RewardsReader? _effective;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant AutoOrderRewardsLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reader != widget.reader ||
        oldWidget.controller != widget.controller ||
        oldWidget.shopifyOrderId != widget.shopifyOrderId) {
      _resolve();
    }
  }

  void _resolve() {
    _api?.close();
    _api = null;
    final fixed = widget.reader;
    if (fixed != null) {
      _effective = fixed;
      return;
    }
    final controller = widget.controller;
    if (controller == null) {
      _effective = null;
      return;
    }
    _api = resolveRewardsApi(
      config: AccountsOrdersConfig.fromEnvironment(),
      tokenProvider: controller.accessTokenForBackend,
    );
    final api = _api;
    _effective = api == null ? null : ApiRewardsReader(api);
  }

  @override
  void dispose() {
    _api?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OrderRewardsLine(
      reader: _effective,
      shopifyOrderId: widget.shopifyOrderId,
    );
  }
}

/// Lector de fixtures controlados para pruebas y capturas. No usar en
/// producción: el saldo real siempre viene del servicio de F.
class FakeRewardsReader implements RewardsReader {
  FakeRewardsReader({
    RewardsSummary? summary,
    List<RewardsMovement>? activity,
    Map<String, OrderRewardsState>? perOrder,
    Object? failure,
  })  : _summary = summary,
        _activity = activity ?? const [],
        _perOrder = perOrder ?? const {},
        _failure = failure;

  final RewardsSummary? _summary;
  final List<RewardsMovement> _activity;
  final Map<String, OrderRewardsState> _perOrder;
  final Object? _failure;

  @override
  Future<RewardsSummary> summary() async {
    final failure = _failure;
    if (failure != null) throw failure;
    return _summary ??
        RewardsSummary(
          redemptionEnabled: true,
          availableCents: 18400,
          pendingCents: 5400,
          reservedCents: 0,
          nextExpiry: null,
          asOf: DateTime.utc(2026, 9, 14),
          firstPurchaseEnabled: false,
          reviewEnabled: false,
          referralEnabled: false,
        );
  }

  @override
  Future<({List<RewardsMovement> movements, String? nextCursor})>
      activity() async {
    final failure = _failure;
    if (failure != null) throw failure;
    return (
      movements: List<RewardsMovement>.unmodifiable(_activity),
      nextCursor: null
    );
  }

  @override
  Future<OrderRewardsState> orderRewards(String shopifyOrderId) async {
    final failure = _failure;
    if (failure != null) throw failure;
    return _perOrder[shopifyOrderId] ??
        OrderRewardsState(
          orderShopifyId: shopifyOrderId,
          isWholesale: false,
          earnedPendingCents: 0,
          earnedReleasedCents: 0,
          usedCents: 0,
          state: 'none',
        );
  }
}

/// Resumen de Rewards para Cuenta, Pedidos y Notificaciones.
///
/// [reader] nulo = backend sin configurar: estado honesto de no disponible.
/// Con lector, carga el resumen y delega la presentación al componente de F;
/// los movimientos se cargan solo al desplegar.
class RewardsSection extends StatefulWidget {
  const RewardsSection({
    required this.controller,
    this.reader,
    this.showMovements = true,
    super.key,
  });

  /// Nulo solo en superficies de prueba sin sesión (p. ej. Notificaciones
  /// con lector fijo): se oculta la acción de re-login.
  final AccountController? controller;
  final RewardsReader? reader;
  final bool showMovements;

  @override
  State<RewardsSection> createState() => _RewardsSectionState();
}

class _RewardsSectionState extends State<RewardsSection> {
  late Future<RewardsSummary>? _pending;
  Future<({List<RewardsMovement> movements, String? nextCursor})>? _movements;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _pending = widget.reader?.summary();
  }

  @override
  void didUpdateWidget(covariant RewardsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reader != widget.reader) {
      _pending = widget.reader?.summary();
      _movements = null;
      _expanded = false;
    }
  }

  void _reload() {
    final reader = widget.reader;
    if (reader == null) return;
    setState(() {
      _pending = reader.summary();
      _movements = null;
      _expanded = false;
    });
  }

  void _toggleMovements() {
    final reader = widget.reader;
    if (reader == null) return;
    setState(() {
      _expanded = !_expanded;
      _movements ??= reader.activity();
    });
  }

  @override
  Widget build(BuildContext context) {
    final reader = widget.reader;
    if (reader == null) {
      return const _RewardsUnavailable(
        key: ValueKey('rewards-unavailable'),
      );
    }
    return FutureBuilder<RewardsSummary>(
      future: _pending,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _RewardsLoading(
            key: ValueKey('rewards-loading'),
          );
        }
        final error = snapshot.error;
        if (error != null || !snapshot.hasData) {
          if (classifyRewardsError(error) == RewardsErrorKind.unavailable) {
            return const _RewardsUnavailable(
              key: ValueKey('rewards-unavailable'),
            );
          }
          final controller = widget.controller;
          return _RewardsError(
            key: const ValueKey('rewards-error'),
            error: error,
            onRetry: _reload,
            onRelogin: controller != null && !controller.isLoading
                ? () => controller.login()
                : null,
          );
        }
        final summary = snapshot.data!;
        return _RewardsLoaded(
          summary: summary,
          showMovements: widget.showMovements,
          expanded: _expanded,
          movementsFuture: _movements,
          onToggleMovements: _toggleMovements,
          onRetryMovements: () {
            setState(() => _movements = reader.activity());
          },
        );
      },
    );
  }
}

class _RewardsCardFrame extends StatelessWidget {
  const _RewardsCardFrame({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Container(
      key: const ValueKey('rewards-section'),
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

class _RewardsLoading extends StatelessWidget {
  const _RewardsLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return _RewardsCardFrame(
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

/// Estado honesto cuando F aún no conecta el backend en este build.
class _RewardsUnavailable extends StatelessWidget {
  const _RewardsUnavailable({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return _RewardsCardFrame(
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
          'Estamos conectando tu saldo en pesos. Tus compras se registran '
          'con normalidad; aquí verás tu disponible y pendiente en cuanto '
          'el programa esté activo.',
          style: boutiqueText(size: 13, color: palette.inkMuted),
        ),
      ],
    );
  }
}

class _RewardsError extends StatelessWidget {
  const _RewardsError({
    required this.error,
    required this.onRetry,
    required this.onRelogin,
    super.key,
  });

  final Object? error;
  final VoidCallback onRetry;
  final VoidCallback? onRelogin;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final kind = classifyRewardsError(error);
    final isSession = kind == RewardsErrorKind.session;
    final title =
        isSession ? 'Tu sesión terminó' : 'No pudimos consultar tu saldo';
    final body = switch (kind) {
      RewardsErrorKind.session =>
        'Inicia sesión de nuevo para ver tu saldo Monetta.',
      RewardsErrorKind.serviceDown =>
        'Monetta Rewards no responde en este momento. Inténtalo más '
            'tarde; esto no afecta tus pedidos ni tu cuenta.',
      RewardsErrorKind.network ||
      RewardsErrorKind.unavailable =>
        'Revisa tu conexión e inténtalo de nuevo. Esto no afecta tus '
            'pedidos ni tu cuenta.',
    };
    final retryIcon = kind == RewardsErrorKind.serviceDown
        ? Icons.cloud_off_rounded
        : Icons.signal_wifi_off_rounded;
    return _RewardsCardFrame(
      children: [
        Text(
          'SALDO MONETTA',
          style: boutiqueEyebrow(size: 11, color: palette.goldText),
        ),
        const SizedBox(height: BoutiqueSpace.sm),
        Text(title, style: boutiqueTitle(size: 15, color: palette.ink)),
        const SizedBox(height: BoutiqueSpace.xs),
        Text(body, style: boutiqueText(size: 13, color: palette.inkMuted)),
        const SizedBox(height: BoutiqueSpace.md),
        if (isSession && onRelogin != null)
          ENotice(
            message: 'Tu sesión terminó.',
            actionLabel: 'Iniciar sesión',
            onAction: onRelogin,
            icon: Icons.lock_outline_rounded,
          )
        else
          ENotice(
            message: body,
            actionLabel: 'Reintentar',
            onAction: onRetry,
            icon: retryIcon,
          ),
      ],
    );
  }
}

class _RewardsLoaded extends StatelessWidget {
  const _RewardsLoaded({
    required this.summary,
    required this.showMovements,
    required this.expanded,
    required this.movementsFuture,
    required this.onToggleMovements,
    required this.onRetryMovements,
  });

  final RewardsSummary summary;
  final bool showMovements;
  final bool expanded;
  final Future<({List<RewardsMovement> movements, String? nextCursor})>?
      movementsFuture;
  final VoidCallback onToggleMovements;
  final VoidCallback onRetryMovements;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Container(
      key: const ValueKey('rewards-section'),
      decoration: BoxDecoration(
        borderRadius: BoutiqueRadius.card,
        border: Border.all(color: palette.hairline, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RewardsBalanceCard(
            summary: summary,
            movements: const [],
            expanded: false,
          ),
          if (showMovements)
            _MovementsExpander(
              expanded: expanded,
              movementsFuture: movementsFuture,
              onToggle: onToggleMovements,
              onRetry: onRetryMovements,
            ),
        ],
      ),
    );
  }
}

/// Desplegable de movimientos con carga bajo demanda. Sus errores son
/// independientes: si el historial falla, el saldo ya mostrado no se pierde.
class _MovementsExpander extends StatelessWidget {
  const _MovementsExpander({
    required this.expanded,
    required this.movementsFuture,
    required this.onToggle,
    required this.onRetry,
  });

  final bool expanded;
  final Future<({List<RewardsMovement> movements, String? nextCursor})>?
      movementsFuture;
  final VoidCallback onToggle;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Container(
      color: palette.surface,
      padding: const EdgeInsets.symmetric(horizontal: BoutiqueSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: .5, color: palette.hairline),
          Semantics(
            button: true,
            label: expanded ? 'Ocultar movimientos' : 'Ver movimientos',
            child: InkWell(
              key: const ValueKey('rewards-movements-toggle'),
              onTap: onToggle,
              borderRadius: BoutiqueRadius.control,
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: BoutiqueSpace.tapTarget,
                ),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Movimientos',
                        style: boutiqueText(
                          size: 13,
                          weight: FontWeight.w600,
                          color: palette.ink,
                        ),
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 20,
                      color: palette.inkMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded) _buildBody(palette),
        ],
      ),
    );
  }

  Widget _buildBody(BoutiquePalette palette) {
    return FutureBuilder<
        ({List<RewardsMovement> movements, String? nextCursor})>(
      future: movementsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.only(bottom: BoutiqueSpace.md),
            child: Text(
              'Cargando movimientos…',
              style: boutiqueText(size: 13, color: palette.inkMuted),
            ),
          );
        }
        if (snapshot.error != null || !snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.only(bottom: BoutiqueSpace.md),
            child: ENotice(
              message: 'No pudimos cargar tus movimientos.',
              actionLabel: 'Reintentar',
              onAction: onRetry,
              icon: Icons.signal_wifi_off_rounded,
            ),
          );
        }
        final movements = snapshot.data!.movements;
        if (movements.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(bottom: BoutiqueSpace.md),
            child: Text(
              'Aún no hay movimientos en tu cuenta.',
              style: boutiqueText(size: 13, color: palette.inkMuted),
            ),
          );
        }
        return Column(
          children: [
            for (final movement in movements) _MovementRow(movement: movement),
            const SizedBox(height: BoutiqueSpace.sm),
          ],
        );
      },
    );
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.movement});

  final RewardsMovement movement;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final amount = movement.amountCents;
    final reason = movement.reason?.trim();
    final title = reason != null && reason.isNotEmpty
        ? reason
        : movement.orderShopifyId != null
            ? 'Pedido ${movement.orderShopifyId}'
            : 'Movimiento Monetta';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BoutiqueSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StateDot(state: movement.state),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: boutiqueText(size: 13, color: palette.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  _stateLabel(movement.state),
                  style: boutiqueText(size: 11, color: palette.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${amount < 0 ? '-' : '+'}\$${(amount.abs() / 100).toStringAsFixed(0)}',
            style: boutiqueText(
              size: 13,
              weight: FontWeight.w600,
              color: palette.ink,
            ),
          ),
        ],
      ),
    );
  }

  static String _stateLabel(String state) => switch (state) {
        'pending' => 'Pendiente de entrega',
        'available' => 'Disponible',
        'used' => 'Utilizado',
        'expired' => 'Expirado',
        'reversed' => 'Revertido',
        _ => state,
      };
}

class _StateDot extends StatelessWidget {
  const _StateDot({required this.state});

  final String state;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final color = switch (state) {
      'available' => const Color(0xFF3B7B4A),
      'pending' => palette.goldText,
      'used' => palette.inkMuted,
      'expired' => const Color(0xFFA3342B),
      'reversed' => const Color(0xFFA3342B),
      _ => palette.inkMuted,
    };
    return Semantics(
      label: _MovementRow._stateLabel(state),
      child: Container(
        margin: const EdgeInsets.only(top: 5),
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

/// Renglón Rewards por pedido para Mis pedidos y el detalle.
///
/// Independiente del pedido: si la consulta falla o el pedido no tiene
/// identidad Shopify (apartado sin registrar), el renglón no aparece y el
/// pedido sigue mostrándose con normalidad.
class OrderRewardsLine extends StatelessWidget {
  const OrderRewardsLine({
    required this.reader,
    required this.shopifyOrderId,
    super.key,
  });

  final RewardsReader? reader;
  final String? shopifyOrderId;

  @override
  Widget build(BuildContext context) {
    final reader = this.reader;
    final shopifyId = shopifyOrderId;
    if (reader == null || shopifyId == null || shopifyId.isEmpty) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<OrderRewardsState?>(
      future: _safeLoad(reader, shopifyId),
      builder: (context, snapshot) {
        final state = snapshot.data;
        if (state == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: BoutiqueSpace.sm),
          child: OrderRewardsStatus(state: state),
        );
      },
    );
  }

  Future<OrderRewardsState?> _safeLoad(
    RewardsReader reader,
    String shopifyId,
  ) async {
    try {
      return await reader.orderRewards(shopifyId);
    } catch (_) {
      return null;
    }
  }
}
