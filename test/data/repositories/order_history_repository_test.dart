import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/accounts_orders/accounts_orders_config.dart';
import 'package:monetta_app/data/accounts_orders/order_history_client.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/order_summary_store.dart';
import 'package:monetta_app/data/repositories/order_history_repository.dart';

class _FakeOrderHistoryClient implements OrderHistoryClient {
  _FakeOrderHistoryClient(this.orders);
  _FakeOrderHistoryClient.throwing()
      : orders = const [],
        shouldThrow = true;

  List<MirroredOrder> orders;
  bool shouldThrow = false;
  String? receivedAccessToken;

  @override
  Future<List<MirroredOrder>> fetchOrders(String accessToken) async {
    receivedAccessToken = accessToken;
    if (shouldThrow) throw OrderHistoryException('boom');
    return orders;
  }
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = openTestDatabase();
    await db.into(db.accounts).insert(
          AccountsCompanion.insert(
            localAccountId: 'acct-1',
            createdAt: DateTime.utc(2026, 1, 1),
            lastSeenAt: DateTime.utc(2026, 1, 1),
          ),
        );
  });

  tearDown(() => db.close());

  group('OrderHistoryRepository', () {
    test('canRefresh is false and refresh() is a no-op when not configured',
        () async {
      final repo = OrderHistoryRepository(
        store: OrderSummaryStore(db),
        config: AccountsOrdersConfig.disabled,
      );

      expect(repo.canRefresh, isFalse);
      await repo.refresh(accountId: 'acct-1', accessToken: 'access');
      expect(await repo.loadCached('acct-1'), isEmpty);
    });

    test('refresh() unifies real and apartado orders into the local cache',
        () async {
      final client = _FakeOrderHistoryClient([
        const MirroredOrder(
          id: 1,
          shopifyOrderId: '100',
          source: 'shopify_checkout',
          attributionCode: null,
          financialStatus: 'paid',
          fulfillmentStatus: null,
          totalAmount: 1749,
          currencyCode: 'MXN',
          placedAt: null,
        ),
        const MirroredOrder(
          id: 2,
          shopifyOrderId: '101',
          source: 'whatsapp_apartado',
          attributionCode: 'MN-7K3Q',
          financialStatus: null,
          fulfillmentStatus: null,
          totalAmount: 400,
          currencyCode: 'MXN',
          placedAt: null,
        ),
      ]);
      final repo = OrderHistoryRepository(
        store: OrderSummaryStore(db),
        config: AccountsOrdersConfig.disabled,
        client: client,
      );

      expect(repo.canRefresh, isTrue);
      await repo.refresh(accountId: 'acct-1', accessToken: 'access');
      expect(client.receivedAccessToken, 'access');

      final cached = await repo.loadCached('acct-1');
      expect(cached, hasLength(2));
      expect(
        cached.map((o) => o.source).toSet(),
        {'shopify_checkout', 'whatsapp_apartado'},
      );
      expect(cached.firstWhere((o) => o.id == '2').attributionCode, 'MN-7K3Q');
    });

    test('a failed refresh preserves the cache rather than clearing it',
        () async {
      final store = OrderSummaryStore(db);
      final workingRepo = OrderHistoryRepository(
        store: store,
        config: AccountsOrdersConfig.disabled,
        client: _FakeOrderHistoryClient([
          const MirroredOrder(
            id: 1,
            shopifyOrderId: '100',
            source: 'shopify_checkout',
            attributionCode: null,
            financialStatus: 'paid',
            fulfillmentStatus: null,
            totalAmount: 1749,
            currencyCode: 'MXN',
            placedAt: null,
          ),
        ]),
      );
      await workingRepo.refresh(accountId: 'acct-1', accessToken: 'access');
      expect(await store.allForAccount('acct-1'), hasLength(1));

      final failingRepo = OrderHistoryRepository(
        store: store,
        config: AccountsOrdersConfig.disabled,
        client: _FakeOrderHistoryClient.throwing(),
      );
      await failingRepo.refresh(accountId: 'acct-1', accessToken: 'access');

      expect(await store.allForAccount('acct-1'), hasLength(1));
    });
  });
}
