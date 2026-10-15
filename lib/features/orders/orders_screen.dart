/// Mis pedidos (paquete E): filtros pertinentes, resumen y acceso al detalle.
///
/// Fuente: [AccountController.orders], el historial real de
/// [OrderHistoryRepository] (CAA de Shopify + apartados). Cada acción tiene
/// destino real: el detalle del pedido; cada estado (carga, error, vacío,
/// caché, sesión caducada) tiene presentación propia.
library;

import 'package:flutter/material.dart';

import '../../app/account_controller.dart';
import '../../app/theme.dart';
import '../../data/customer_auth/customer_auth_error.dart';
import '../../data/local/database.dart' show OrderSummary;
import '../../data/repositories/order_history_repository.dart';
import '../account/account_boutique.dart';
import '../boutique/boutique_tokens.dart';
import '../rewards/rewards_section.dart';
import 'order_detail_screen.dart';
import 'order_status.dart';

Future<void> openOrders(
  BuildContext context, {
  required AccountController controller,
  RewardsReader? rewardsReader,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => OrdersScreen(
        controller: controller,
        rewardsReader: rewardsReader,
      ),
    ),
  );
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({
    required this.controller,
    this.rewardsReader,
    super.key,
  });

  final AccountController controller;

  /// Lector Rewards fijo (fixtures de prueba). Nulo = la pantalla lo
  /// resuelve del backend configurado o muestra no disponible.
  final RewardsReader? rewardsReader;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  OrderFilter _filter = OrderFilter.all;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        backgroundColor: palette.bar,
        foregroundColor: palette.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Mis pedidos',
          style: boutiqueTitle(size: 15, color: palette.ink),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(.5),
          child: Container(height: .5, color: palette.hairline),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) => _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final controller = widget.controller;
    if (!controller.isSignedIn) {
      return const _OrdersSignedOut();
    }
    if (controller.ordersLoading && controller.orders.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          const AccountPageHeader(
            kicker: 'Historial',
            title: 'Mis pedidos',
          ),
          const SizedBox(height: BoutiqueSpace.lg),
          Text(
            'Cargando tus pedidos…',
            style: boutiqueText(
              size: 14,
              color: context.boutique.inkMuted,
            ),
          ),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: controller.loadOrders,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          const AccountPageHeader(
            kicker: 'Historial',
            title: 'Mis pedidos',
          ),
          const SizedBox(height: BoutiqueSpace.lg),
          ..._statusNotices(controller),
          _FilterRow(
            filter: _filter,
            counts: _counts(controller.orders),
            onChanged: (next) => setState(() => _filter = next),
          ),
          const SizedBox(height: BoutiqueSpace.lg),
          _OrdersList(
            controller: controller,
            filter: _filter,
            rewardsReader: widget.rewardsReader,
          ),
        ],
      ),
    );
  }

  Map<OrderFilter, int> _counts(List<OrderSummary> orders) => {
        OrderFilter.all: orders.length,
        OrderFilter.inTransit:
            filterOrders(orders, OrderFilter.inTransit).length,
        OrderFilter.delivered:
            filterOrders(orders, OrderFilter.delivered).length,
        OrderFilter.apartado: filterOrders(orders, OrderFilter.apartado).length,
      };

  List<Widget> _statusNotices(AccountController controller) {
    switch (controller.ordersStatus) {
      case OrderHistoryStatus.populated:
      case OrderHistoryStatus.empty:
        return const [];
      case OrderHistoryStatus.unavailable:
        return [
          const ENotice(
            message: 'El historial de pedidos no está disponible en esta '
                'versión de la app.',
            icon: Icons.cloud_off_outlined,
          ),
          const SizedBox(height: BoutiqueSpace.md),
        ];
      case OrderHistoryStatus.failed:
        if (controller.orders.isNotEmpty) break;
        return [
          ENotice(
            message: 'No pudimos cargar tus pedidos. Intenta actualizar.',
            actionLabel: 'Reintentar',
            onAction: controller.ordersLoading ? null : controller.loadOrders,
            icon: Icons.signal_wifi_off_rounded,
          ),
          const SizedBox(height: BoutiqueSpace.md),
        ];
      case OrderHistoryStatus.staleCache:
        break;
    }
    final notices = <Widget>[];
    if (controller.ordersStatus == OrderHistoryStatus.staleCache) {
      notices.addAll([
        const ENotice(
          message: 'Mostrando pedidos guardados. No pudimos actualizar ahora.',
          icon: Icons.history_rounded,
        ),
        const SizedBox(height: BoutiqueSpace.md),
      ]);
    }
    if (controller.ordersStatus == OrderHistoryStatus.failed) {
      notices.addAll([
        ENotice(
          message: 'No pudimos actualizar tus pedidos.',
          actionLabel: 'Reintentar',
          onAction: controller.ordersLoading ? null : controller.loadOrders,
          icon: Icons.signal_wifi_off_rounded,
        ),
        const SizedBox(height: BoutiqueSpace.md),
      ]);
    }
    final lastError = controller.lastError;
    if (lastError != null &&
        lastError.kind == CustomerAuthErrorKind.sessionExpired) {
      notices.addAll([
        ENotice(
          message: 'Tu sesión terminó. Inicia sesión de nuevo para '
              'actualizar tus pedidos.',
          actionLabel: 'Iniciar sesión',
          onAction: controller.isLoading ? null : () => controller.login(),
          icon: Icons.lock_outline_rounded,
        ),
        const SizedBox(height: BoutiqueSpace.md),
      ]);
    }
    return notices;
  }
}

class _OrdersSignedOut extends StatelessWidget {
  const _OrdersSignedOut();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: const [
        AccountPageHeader(
          kicker: 'Historial',
          title: 'Mis pedidos',
        ),
        SizedBox(height: BoutiqueSpace.lg),
        ENotice(
          message: 'Inicia sesión con tu cuenta Shopify para ver tu historial.',
          icon: Icons.lock_outline_rounded,
        ),
      ],
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.filter,
    required this.counts,
    required this.onChanged,
  });

  final OrderFilter filter;
  final Map<OrderFilter, int> counts;
  final ValueChanged<OrderFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Filtrar pedidos',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          children: [
            for (final option in OrderFilter.values) ...[
              if (option != OrderFilter.all &&
                  (counts[option] ?? 0) == 0 &&
                  filter != option)
                const SizedBox.shrink()
              else
                Padding(
                  padding: const EdgeInsets.only(right: BoutiqueSpace.sm),
                  child: EFilterChip(
                    key: ValueKey('orders-filter-${option.name}'),
                    label:
                        '${orderFilterLabel(option)} (${counts[option] ?? 0})',
                    selected: filter == option,
                    onTap: () => onChanged(option),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  const _OrdersList({
    required this.controller,
    required this.filter,
    required this.rewardsReader,
  });

  final AccountController controller;
  final OrderFilter filter;
  final RewardsReader? rewardsReader;

  @override
  Widget build(BuildContext context) {
    final visible = filterOrders(controller.orders, filter);
    if (visible.isEmpty) {
      if (controller.orders.isEmpty &&
          controller.ordersStatus == OrderHistoryStatus.empty) {
        return EEmptyState(
          icon: Icons.shopping_bag_outlined,
          title: 'Aún no tienes pedidos',
          body: 'Cuando completes tu primera compra, aparecerá aquí con su '
              'seguimiento.',
          actionLabel: 'Explorar el catálogo',
          onAction: () => Navigator.of(context).pop(),
        );
      }
      return EEmptyState(
        icon: Icons.filter_list_rounded,
        title: 'Sin pedidos en este filtro',
        body: 'Prueba con “${orderFilterLabel(OrderFilter.all)}” para ver '
            'todo tu historial.',
        actionLabel: 'Ver todos',
        onAction: null,
      );
    }
    final summary = summarizeOrders(visible);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryLine(summary: summary, filter: filter),
        const SizedBox(height: BoutiqueSpace.md),
        if (controller.account != null)
          AutoRewardsSection(
            controller: controller,
            reader: rewardsReader,
            showMovements: false,
          ),
        const SizedBox(height: BoutiqueSpace.md),
        for (final order in visible) ...[
          _OrderCard(
            order: order,
            controller: controller,
            rewardsReader: rewardsReader,
            onTap: () => openOrderDetail(
              context,
              order: order,
              rewardsReader: rewardsReader,
              rewardsController: controller,
            ),
          ),
          const SizedBox(height: BoutiqueSpace.md),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const ValueKey('refresh-orders'),
            onPressed:
                controller.ordersLoading ? null : () => controller.loadOrders(),
            child: Text(
              controller.ordersLoading ? 'Actualizando…' : 'Actualizar pedidos',
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.summary, required this.filter});

  final OrdersSummary summary;
  final OrderFilter filter;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final scope = filter == OrderFilter.all
        ? 'En total'
        : 'En ${orderFilterLabel(filter).toLowerCase()}';
    final total = '$scope: ${summary.count} '
        '${summary.count == 1 ? 'pedido' : 'pedidos'} · '
        '${kMoney.format(summary.totalMxn)} MXN';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          total,
          style: boutiqueText(size: 13, color: palette.inkMuted),
        ),
        if (summary.otherCurrencyCount > 0)
          Text(
            '${summary.otherCurrencyCount} en otra moneda, sin convertir.',
            style: boutiqueText(size: 12, color: palette.inkMuted),
          ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.controller,
    required this.rewardsReader,
    required this.onTap,
  });

  final OrderSummary order;
  final AccountController controller;
  final RewardsReader? rewardsReader;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final status = orderDisplayStatus(order);
    final action = status.actionLabel ?? 'Ver detalles';
    final secondary = status.secondaryLabel;
    return Semantics(
      button: true,
      label: '$action del pedido ${orderLabelOf(order)}, '
          '${status.label}'
          '${secondary == null ? '' : ', $secondary'}, '
          '${kMoney.format(order.totalAmount)}',
      child: InkWell(
        key: ValueKey('order-card-${order.id}'),
        onTap: onTap,
        borderRadius: BoutiqueRadius.card,
        child: Container(
          padding: const EdgeInsets.all(BoutiqueSpace.lg),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BoutiqueRadius.card,
            border: Border.all(color: palette.hairline, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          orderLabelOf(order),
                          style: boutiqueText(
                            size: 15,
                            weight: FontWeight.w700,
                            color: palette.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          orderDateLabel(order.placedAt),
                          style: boutiqueText(
                            size: 12,
                            color: palette.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  EStatusCapsule.forOrderKey(
                    status.key,
                    label: status.label,
                  ),
                ],
              ),
              if (secondary != null) ...[
                const SizedBox(height: 6),
                Text(
                  secondary,
                  style: boutiqueText(
                    size: 12,
                    color: palette.inkMuted,
                  ),
                ),
              ],
              const SizedBox(height: BoutiqueSpace.md),
              Container(height: .5, color: palette.hairline),
              const SizedBox(height: BoutiqueSpace.md),
              // Doble Wrap, nunca Row mínima con texto: una Row con
              // mainAxisSize.min mide a sus hijos sin cota y "Ver detalles"
              // no envolvería a texto ampliado. Así, a tamaño normal todo
              // sigue en una línea y a texto grande fluye a varias.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: BoutiqueSpace.sm,
                runSpacing: 4,
                children: [
                  Text(
                    'Total: ${kMoney.format(order.totalAmount)} '
                    '${order.currencyCode}',
                    style: boutiqueText(
                      size: 13,
                      weight: FontWeight.w600,
                      color: palette.ink,
                    ),
                  ),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      Text(
                        action,
                        style: boutiqueText(
                          size: 13,
                          weight: FontWeight.w600,
                          color: palette.ink,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: palette.inkMuted,
                      ),
                    ],
                  ),
                ],
              ),
              AutoOrderRewardsLine(
                shopifyOrderId: order.shopifyOrderId,
                reader: rewardsReader,
                controller: controller,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
