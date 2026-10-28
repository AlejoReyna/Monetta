/// Mis pedidos (paquete E): filtros pertinentes, resumen y acceso al detalle.
///
/// Fuente: [AccountController.orders], el historial real de
/// [OrderHistoryRepository] (CAA de Shopify + apartados). Cada acción tiene
/// destino real: el detalle del pedido; cada estado (carga, error, vacío,
/// caché, sesión caducada) tiene presentación propia.
library;

import '../../platform/system_layout_context.dart';
import 'package:flutter/material.dart';

import '../../app/account_controller.dart';
import '../../app/theme.dart';
import '../../app/monetta_tokens.g.dart';
import '../../data/customer_auth/customer_auth_error.dart';
import '../../data/local/database.dart' show OrderSummary;
import '../../data/repositories/order_history_repository.dart';
import '../account/account_boutique.dart';
import '../boutique/boutique_tokens.dart';
import '../boutique/client_guide_components.dart';
import '../boutique/client_guide_scaffold.dart';
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
    return ClientGuideScaffold(
      current: ClientGuideDestination.account,
      accountController: widget.controller,
      body: SystemUsableSurface(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: MonettaTokens.breakpointMedium,
              ),
              child: ListenableBuilder(
                listenable: widget.controller,
                builder: (context, _) => _buildBody(context),
              ),
            ),
          ),
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
        padding: EdgeInsets.fromLTRB(
          MonettaTokens.gutterFor(MediaQuery.sizeOf(context).width),
          MonettaTokens.space[4],
          MonettaTokens.gutterFor(MediaQuery.sizeOf(context).width),
          MonettaTokens.space[5],
        ),
        children: [
          const _OrdersHeading(),
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
        padding: EdgeInsets.fromLTRB(
          MonettaTokens.gutterFor(MediaQuery.sizeOf(context).width),
          MonettaTokens.space[4],
          MonettaTokens.gutterFor(MediaQuery.sizeOf(context).width),
          MonettaTokens.space[5],
        ),
        children: [
          const _OrdersHeading(),
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
      padding: EdgeInsets.fromLTRB(
        MonettaTokens.gutterFor(MediaQuery.sizeOf(context).width),
        MonettaTokens.space[4],
        MonettaTokens.gutterFor(MediaQuery.sizeOf(context).width),
        MonettaTokens.space[5],
      ),
      children: const [
        _OrdersHeading(),
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

  /// «Todos», «En camino» and «Completos» are always there, as in the guide.
  /// The apartado tab only appears when there is one (or it is selected).
  static bool _alwaysShown(OrderFilter option) =>
      option == OrderFilter.all ||
      option == OrderFilter.inTransit ||
      option == OrderFilter.delivered;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final options = [
      for (final option in OrderFilter.values)
        if (_alwaysShown(option) ||
            (counts[option] ?? 0) > 0 ||
            filter == option)
          option,
    ];
    return Semantics(
      label: 'Filtrar pedidos',
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) SizedBox(width: MonettaTokens.space[1]),
            Expanded(
              child: Semantics(
                label:
                    '${orderFilterLabel(options[i])}: ${counts[options[i]] ?? 0} pedidos',
                selected: filter == options[i],
                button: true,
                excludeSemantics: true,
                onTap: () => onChanged(options[i]),
                child: Material(
                  key: ValueKey('orders-filter-${options[i].name}'),
                  color: filter == options[i] ? palette.action : palette.canvas,
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: filter == options[i]
                          ? palette.action
                          : palette.hairline,
                    ),
                  ),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => onChanged(options[i]),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: MonettaTokens.tapTarget,
                      ),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: MonettaTokens.space[1],
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              options[i] == OrderFilter.delivered
                                  ? 'Completos'
                                  : orderFilterLabel(options[i]),
                              maxLines: 1,
                              style: clientGuideStyle(
                                context,
                                MonettaTokens.cardLabel,
                                color: filter == options[i]
                                    ? palette.onAction
                                    : palette.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
    final showAction = status.key != 'awaiting_transfer';
    final action = status.actionLabel ?? 'Ver detalles';
    final secondary = status.secondaryLabel;
    final refundHelp = paidCancelledRefundWhatsAppUri(order) != null;
    final actionPrefix = showAction ? '$action del pedido' : 'Pedido';
    return Semantics(
      button: true,
      label: '$actionPrefix ${orderLabelOf(order)}, '
          '${status.label}'
          '${secondary == null ? '' : ', $secondary'}'
          '${refundHelp ? ', $paidCancelledRefundHelp' : ''}, '
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
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: MonettaTokens.space[3],
                runSpacing: MonettaTokens.space[2],
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        orderLabelOf(order),
                        style: clientGuideStyle(
                          context,
                          MonettaTokens.sectionTitle,
                        ),
                      ),
                      SizedBox(height: MonettaTokens.space[0]),
                      Text(
                        orderDateLabel(order.placedAt),
                        style: clientGuideStyle(
                          context,
                          MonettaTokens.cardLabel,
                          color: palette.inkMuted,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: EStatusCapsule.forOrderKey(
                          status.key,
                          label: status.label,
                          guideIcon: status.key == 'in_transit'
                              ? Icons.local_shipping_outlined
                              : status.key == 'delivered'
                                  ? Icons.check_circle_outline
                                  : Icons.receipt_long_outlined,
                        ),
                      ),
                      SizedBox(width: MonettaTokens.space[1]),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: palette.ink,
                        size: 24,
                      ),
                    ],
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
              PaidCancelledRefundHelp(order: order),
              SizedBox(height: MonettaTokens.space[3]),
              // `OrderSummary` carries no order lines yet, so there is no
              // product photograph to show: a discreet note stands in until
              // the history brings lines (then up to three catalog photos).
              Text(
                'Las imágenes de este pedido aún no están disponibles.',
                key: ValueKey('order-thumbs-placeholder-${order.id}'),
                style: clientGuideStyle(
                  context,
                  MonettaTokens.navLabel,
                  color: palette.inkMuted,
                ),
              ),
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
                    style: clientGuideStyle(context, MonettaTokens.price),
                  ),
                  if (showAction)
                    SizedBox(
                      // Narrow enough to sit beside the total at 390 px; a
                      // larger text size flows it to its own line (Wrap).
                      width: 136,
                      child: ClientGuideButton(
                        label: action,
                        chevron: true,
                        compact: true,
                        onPressed: onTap,
                      ),
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

class _OrdersHeading extends StatelessWidget {
  const _OrdersHeading();
  @override
  Widget build(BuildContext context) => Text(
        'Mis pedidos',
        textAlign: TextAlign.center,
        style: clientGuideStyle(context, MonettaTokens.screenTitle),
      );
}
