/// Wires `data/local`'s order cache together with `data/accounts_orders`'s
/// backend client — `data/repositories/`'s pattern
/// (`docs/ARCHITECTURE.md`), applied to order history instead of the
/// catalog. See `docs/ACCOUNTS_AND_SYNC_PLAN.md` Phase 3.
library;

import 'package:drift/drift.dart';

import '../accounts_orders/accounts_orders_config.dart';
import '../accounts_orders/order_history_client.dart';
import '../local/database.dart';
import '../local/order_summary_store.dart';

class OrderHistoryRepository {
  OrderHistoryRepository({
    required this.store,
    required AccountsOrdersConfig config,
    OrderHistoryClient? client,
  }) : _client = client ??
            (config.enabled ? HttpOrderHistoryClient(baseUrl: config.baseUrl!) : null);

  final OrderSummaryStore store;
  final OrderHistoryClient? _client;

  bool get canRefresh => _client != null;

  Future<List<OrderSummary>> loadCached(String accountId) => store.allForAccount(accountId);

  /// Refetches the shopper's full order list from `services/accounts_orders`
  /// and replaces the local cache — a safe no-op when the service isn't
  /// configured (`AccountsOrdersConfig.disabled`, today's default), and a
  /// swallowed, cache-preserving failure on any network/parse error, same
  /// contract as `ExternalCatalogRepository.refresh`.
  Future<void> refresh({
    required String accountId,
    required String shopifyCustomerId,
  }) async {
    final client = _client;
    if (client == null) return;
    try {
      final remote = await client.fetchOrders(shopifyCustomerId);
      final rows = [
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
            placedAt: order.placedAt ?? DateTime.now(),
          ),
      ];
      await store.replaceAllForAccount(accountId, rows);
    } catch (_) {
      // Deliberately swallowed — see the doc comment above.
    }
  }
}
