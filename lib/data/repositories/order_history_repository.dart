/// Wires local order cache with Customer Account API (primary) and the
/// optional `services/accounts_orders` mirror (apartado enrichment) —
/// `docs/ARCHITECTURE.md` repository pattern + audit F13.
library;

import 'package:drift/drift.dart';

import '../accounts_orders/accounts_orders_config.dart';
import '../accounts_orders/order_history_client.dart';
import '../customer_auth/customer_orders.dart';
import '../local/database.dart';
import '../local/order_summary_store.dart';

/// How the account UI should interpret the current order list.
enum OrderHistoryStatus {
  /// Successful fetch returned no rows.
  empty,

  /// Successful fetch returned one or more rows.
  populated,

  /// No Customer Account or mirror source is usable for this session.
  unavailable,

  /// Fetch failed and there is no account-bound cache to show.
  failed,

  /// Fetch failed; showing previously cached rows for this account only.
  staleCache,
}

class OrderHistoryView {
  const OrderHistoryView({
    required this.orders,
    required this.status,
  });

  final List<OrderSummary> orders;
  final OrderHistoryStatus status;
}

class OrderHistoryRepository {
  OrderHistoryRepository({
    required this.store,
    required AccountsOrdersConfig config,
    OrderHistoryClient? mirrorClient,
    CustomerOrdersService? customerOrders,
  })  : _mirrorClient = mirrorClient ??
            (config.enabled
                ? HttpOrderHistoryClient(baseUrl: config.baseUrl!)
                : null),
        _customerOrders = customerOrders;

  final Map<String, int> _refreshGenerations = {};
  final OrderSummaryStore store;
  final OrderHistoryClient? _mirrorClient;
  final CustomerOrdersService? _customerOrders;

  bool get hasCustomerAccountSource => _customerOrders != null;
  bool get hasMirrorSource => _mirrorClient != null;

  /// True when at least one remote source can be attempted.
  bool get canRefresh => hasCustomerAccountSource || hasMirrorSource;

  Future<List<OrderSummary>> loadCached(String accountId) =>
      store.allForAccount(accountId);

  /// Refetches buyer history.
  ///
  /// Prefer [customerAccountAccessToken] + Customer Account API when present.
  /// On CAA success, merge WhatsApp apartados from the mirror when
  /// [backendAccessToken] works. Never treat a mirror-only empty list as
  /// authoritative when CAA was attempted and failed (that would fake
  /// "no pedidos" for pre-install Shopify orders). Failures preserve the
  /// account-scoped cache and surface [OrderHistoryStatus.staleCache].
  Future<OrderHistoryView> refresh({
    required String accountId,
    String? customerAccountAccessToken,
    String? backendAccessToken,
  }) async {
    final generation = (_refreshGenerations[accountId] ?? 0) + 1;
    _refreshGenerations[accountId] = generation;
    final cached = await store.allForAccount(accountId);

    final tryCaa = _customerOrders != null &&
        customerAccountAccessToken != null &&
        customerAccountAccessToken.isNotEmpty;
    final tryMirror = _mirrorClient != null &&
        backendAccessToken != null &&
        backendAccessToken.isNotEmpty;

    if (!tryCaa && !tryMirror) {
      if (cached.isNotEmpty) {
        return OrderHistoryView(
          orders: cached,
          status: OrderHistoryStatus.staleCache,
        );
      }
      return const OrderHistoryView(
        orders: [],
        status: OrderHistoryStatus.unavailable,
      );
    }

    List<CustomerAccountOrder>? caaOrders;
    if (tryCaa) {
      try {
        caaOrders = await _customerOrders.fetchOrders(
          customerAccountAccessToken,
        );
      } catch (_) {
        // CAA fetch failed; fall through with caaOrders == null.
      }
    }

    List<MirroredOrder>? mirrorOrders;
    var mirrorFailed = false;
    if (tryMirror) {
      try {
        mirrorOrders = await _mirrorClient.fetchOrders(backendAccessToken);
      } catch (_) {
        mirrorFailed = true;
      }
    }

    if (_refreshGenerations[accountId] != generation) {
      final latest = await store.allForAccount(accountId);
      return OrderHistoryView(
        orders: latest,
        status: OrderHistoryStatus.staleCache,
      );
    }

    if (tryCaa) {
      if (caaOrders != null) {
        final rows = _companionsFromCaa(
          accountId: accountId,
          caaOrders: caaOrders,
          // Enrich only on CAA success — never invent Shopify history from
          // a partial mirror when CAA is the primary source.
          apartados: mirrorFailed
              ? const <MirroredOrder>[]
              : (mirrorOrders ?? const <MirroredOrder>[])
                  .where((o) => o.isApartado)
                  .toList(),
        );
        await store.replaceAllForAccount(accountId, rows);
        final loaded = await store.allForAccount(accountId);
        return OrderHistoryView(
          orders: loaded,
          status: loaded.isEmpty
              ? OrderHistoryStatus.empty
              : OrderHistoryStatus.populated,
        );
      }

      // CAA was the primary path and failed: never map that to empty.
      if (cached.isNotEmpty) {
        return OrderHistoryView(
          orders: cached,
          status: OrderHistoryStatus.staleCache,
        );
      }
      return const OrderHistoryView(
        orders: [],
        status: OrderHistoryStatus.failed,
      );
    }

    // Mirror-only (legacy Monetta session, or CAA not wired).
    if (mirrorOrders != null) {
      final rows = _companionsFromMirror(accountId, mirrorOrders);
      await store.replaceAllForAccount(accountId, rows);
      final loaded = await store.allForAccount(accountId);
      return OrderHistoryView(
        orders: loaded,
        status: loaded.isEmpty
            ? OrderHistoryStatus.empty
            : OrderHistoryStatus.populated,
      );
    }

    if (cached.isNotEmpty) {
      return OrderHistoryView(
        orders: cached,
        status: OrderHistoryStatus.staleCache,
      );
    }
    return const OrderHistoryView(
      orders: [],
      status: OrderHistoryStatus.failed,
    );
  }

  List<OrderSummariesCompanion> _companionsFromCaa({
    required String accountId,
    required List<CustomerAccountOrder> caaOrders,
    required List<MirroredOrder> apartados,
  }) {
    String? canonical(String? id) {
      if (id == null || id.isEmpty) return null;
      if (id.startsWith('gid://shopify/Order/')) return id;
      return RegExp(r'^\d+$').hasMatch(id) ? 'gid://shopify/Order/$id' : null;
    }

    final mirrorById = {
      for (final order in apartados)
        if (canonical(order.shopifyOrderId) != null)
          canonical(order.shopifyOrderId)!: order,
    };
    final seen = <String>{};
    final rows = <OrderSummariesCompanion>[];
    for (final order in caaOrders) {
      final id = canonical(order.id) ?? order.id;
      if (!seen.add(id)) continue;
      final mirror = mirrorById[id];
      rows.add(
        OrderSummariesCompanion.insert(
          id: id,
          accountId: accountId,
          shopifyOrderId: Value(id),
          displayNumber: Value(order.name),
          fulfillmentStatus: Value(order.fulfillmentStatus?.toLowerCase()),
          source: mirror?.source ?? 'shopify_checkout',
          attributionCode: Value(mirror?.attributionCode),
          status:
              (order.financialStatus ?? order.fulfillmentStatus ?? 'unknown')
                  .toLowerCase(),
          paymentMethod: Value(order.paymentMethod),
          totalAmount: order.totalAmount,
          currencyCode: order.currencyCode,
          placedAt: order.processedAt,
        ),
      );
    }
    for (final order in apartados) {
      final canonicalId = canonical(order.shopifyOrderId);
      final id = canonicalId ?? 'apartado:${order.id}';
      if (!seen.add(id)) continue;
      rows.add(
        OrderSummariesCompanion.insert(
          id: id,
          accountId: accountId,
          shopifyOrderId: Value(canonicalId),
          source: order.source,
          attributionCode: Value(order.attributionCode),
          fulfillmentStatus: Value(order.fulfillmentStatus),
          status: order.financialStatus ?? 'unknown',
          totalAmount: order.totalAmount ?? 0,
          currencyCode: order.currencyCode ?? 'MXN',
          placedAt: order.placedAt ?? DateTime.now().toUtc(),
        ),
      );
    }
    return rows;
  }

  List<OrderSummariesCompanion> _companionsFromMirror(
    String accountId,
    List<MirroredOrder> remote,
  ) {
    return [
      for (final order in remote)
        OrderSummariesCompanion.insert(
          id: order.id.toString(),
          accountId: accountId,
          shopifyOrderId: Value(order.shopifyOrderId),
          source: order.source,
          attributionCode: Value(order.attributionCode),
          status: order.financialStatus ?? 'unknown',
          totalAmount: order.totalAmount ?? 0,
          currencyCode: order.currencyCode ?? 'MXN',
          placedAt: order.placedAt ?? DateTime.now().toUtc(),
        ),
    ];
  }
}
