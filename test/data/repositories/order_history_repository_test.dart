import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/accounts_orders/accounts_orders_config.dart';
import 'package:monetta_app/data/accounts_orders/order_history_client.dart';
import 'package:monetta_app/data/customer_auth/customer_auth_error.dart';
import 'package:monetta_app/data/customer_auth/customer_orders.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/order_summary_store.dart';
import 'package:monetta_app/data/repositories/order_history_repository.dart';
import 'package:monetta_app/features/orders/order_status.dart';

class _FakeMirror implements OrderHistoryClient {
  _FakeMirror(this.orders);

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

class _FakeCaa implements CustomerOrdersService {
  _FakeCaa(this.orders);
  _FakeCaa.throwing()
      : orders = const [],
        shouldThrow = true;

  List<CustomerAccountOrder> orders;
  bool shouldThrow = false;
  String? receivedToken;

  @override
  Future<List<CustomerAccountOrder>> fetchOrders(
    String accessToken, {
    int first = 25,
  }) async {
    receivedToken = accessToken;
    if (shouldThrow) {
      throw const CustomerAuthException(CustomerAuthErrorKind.offline);
    }
    return orders;
  }
}

CustomerAccountOrder _caa({
  String id = 'gid://shopify/Order/1',
  int number = 100,
  double amount = 1749,
  String? financialStatus = 'PAID',
  String? paymentMethod,
}) =>
    CustomerAccountOrder(
      id: id,
      name: '#$number',
      number: number,
      processedAt: DateTime.utc(2026, 8, 1),
      financialStatus: financialStatus,
      fulfillmentStatus: null,
      totalAmount: amount,
      currencyCode: 'MXN',
      paymentMethod: paymentMethod,
    );

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
    test(
        'R7 canonical identity enriches once; CAA state and display stay authoritative',
        () async {
      final mirror = _FakeMirror([
        const MirroredOrder(
          id: 9,
          shopifyOrderId: '1',
          source: 'whatsapp_apartado',
          attributionCode: 'MN-7K3Q',
          financialStatus: 'pending',
          fulfillmentStatus: null,
          totalAmount: 400,
          currencyCode: 'MXN',
          placedAt: null,
        ),
      ]);
      final repo = OrderHistoryRepository(
        store: OrderSummaryStore(db),
        config: AccountsOrdersConfig.disabled,
        customerOrders: _FakeCaa([_caa(number: 1001)]),
        mirrorClient: mirror,
      );
      final result = await repo.refresh(
        accountId: 'acct-1',
        customerAccountAccessToken: 'caa',
        backendAccessToken: 'mirror',
      );
      expect(result.orders, hasLength(1));
      final order = result.orders.single;
      expect(order.shopifyOrderId, 'gid://shopify/Order/1');
      expect(order.displayNumber, '#1001');
      expect(order.source, 'whatsapp_apartado');
      expect(order.attributionCode, 'MN-7K3Q');
      expect(order.status, 'paid');
      expect(order.totalAmount, 1749);
      mirror.shouldThrow = true;
      final offlineMirror = await repo.refresh(
        accountId: 'acct-1',
        customerAccountAccessToken: 'caa',
        backendAccessToken: 'mirror',
      );
      expect(offlineMirror.orders, hasLength(1));
      expect(offlineMirror.orders.single.shopifyOrderId, order.shopifyOrderId);
      await db.into(db.accounts).insert(
            AccountsCompanion.insert(
              localAccountId: 'acct-2',
              createdAt: DateTime.now(),
              lastSeenAt: DateTime.now(),
            ),
          );
      await repo.refresh(
        accountId: 'acct-2',
        customerAccountAccessToken: 'caa',
      );
      expect(await repo.loadCached('acct-1'), hasLength(1));
      expect(await repo.loadCached('acct-2'), hasLength(1));
    });

    test('unavailable when neither CAA nor mirror can run', () async {
      final repo = OrderHistoryRepository(
        store: OrderSummaryStore(db),
        config: AccountsOrdersConfig.disabled,
      );

      expect(repo.canRefresh, isFalse);
      final view = await repo.refresh(accountId: 'acct-1');
      expect(view.status, OrderHistoryStatus.unavailable);
      expect(view.orders, isEmpty);
    });

    test('CAA is primary and merges mirror apartados only', () async {
      final caa = _FakeCaa([_caa()]);
      final mirror = _FakeMirror([
        const MirroredOrder(
          id: 9,
          shopifyOrderId: '999',
          source: 'shopify_checkout',
          attributionCode: null,
          financialStatus: 'paid',
          fulfillmentStatus: null,
          totalAmount: 1,
          currencyCode: 'MXN',
          placedAt: null,
        ),
        const MirroredOrder(
          id: 2,
          shopifyOrderId: null,
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
        customerOrders: caa,
        mirrorClient: mirror,
      );

      final view = await repo.refresh(
        accountId: 'acct-1',
        customerAccountAccessToken: 'caa-token',
        backendAccessToken: 'backend-token',
      );

      expect(caa.receivedToken, 'caa-token');
      expect(view.status, OrderHistoryStatus.populated);
      expect(view.orders, hasLength(2));
      expect(
        view.orders.map((o) => o.source).toSet(),
        {'shopify_checkout', 'whatsapp_apartado'},
      );
      // Mirror shopify_checkout row must not replace/duplicate CAA history.
      expect(
        view.orders.where((o) => o.source == 'shopify_checkout'),
        hasLength(1),
      );
      expect(
        view.orders
            .firstWhere((o) => o.source == 'whatsapp_apartado')
            .attributionCode,
        'MN-7K3Q',
      );
    });

    test('CAA failure with empty cache is failed, not empty', () async {
      final repo = OrderHistoryRepository(
        store: OrderSummaryStore(db),
        config: AccountsOrdersConfig.disabled,
        customerOrders: _FakeCaa.throwing(),
        mirrorClient: _FakeMirror(const []),
      );

      final view = await repo.refresh(
        accountId: 'acct-1',
        customerAccountAccessToken: 'caa',
        backendAccessToken: 'backend',
      );

      expect(view.status, OrderHistoryStatus.failed);
      expect(view.orders, isEmpty);
    });

    test('CAA failure preserves cache as staleCache', () async {
      final store = OrderSummaryStore(db);
      final seed = OrderHistoryRepository(
        store: store,
        config: AccountsOrdersConfig.disabled,
        customerOrders: _FakeCaa([_caa()]),
      );
      await seed.refresh(
        accountId: 'acct-1',
        customerAccountAccessToken: 'caa',
      );
      expect(await store.allForAccount('acct-1'), hasLength(1));

      final failing = OrderHistoryRepository(
        store: store,
        config: AccountsOrdersConfig.disabled,
        customerOrders: _FakeCaa.throwing(),
      );
      final view = await failing.refresh(
        accountId: 'acct-1',
        customerAccountAccessToken: 'caa',
      );

      expect(view.status, OrderHistoryStatus.staleCache);
      expect(view.orders, hasLength(1));
    });

    test('successful CAA empty list is empty', () async {
      final repo = OrderHistoryRepository(
        store: OrderSummaryStore(db),
        config: AccountsOrdersConfig.disabled,
        customerOrders: _FakeCaa(const []),
      );

      final view = await repo.refresh(
        accountId: 'acct-1',
        customerAccountAccessToken: 'caa',
      );
      expect(view.status, OrderHistoryStatus.empty);
      expect(view.orders, isEmpty);
    });

    test('mirror-only path still works for legacy sessions', () async {
      final mirror = _FakeMirror([
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
      ]);
      final repo = OrderHistoryRepository(
        store: OrderSummaryStore(db),
        config: AccountsOrdersConfig.disabled,
        mirrorClient: mirror,
      );

      final view = await repo.refresh(
        accountId: 'acct-1',
        backendAccessToken: 'access',
      );
      expect(mirror.receivedAccessToken, 'access');
      expect(view.status, OrderHistoryStatus.populated);
      expect(view.orders, hasLength(1));
    });

    test('webhook-only pending transfer keeps the mirror payment method',
        () async {
      final repo = OrderHistoryRepository(
        store: OrderSummaryStore(db),
        config: AccountsOrdersConfig.disabled,
        mirrorClient: _FakeMirror([
          const MirroredOrder(
            id: 7,
            shopifyOrderId: '700',
            source: 'shopify_checkout',
            attributionCode: null,
            financialStatus: 'pending',
            fulfillmentStatus: null,
            totalAmount: 890,
            currencyCode: 'MXN',
            placedAt: null,
            paymentMethod: 'bank_deposit',
          ),
        ]),
      );

      final view = await repo.refresh(
        accountId: 'acct-1',
        backendAccessToken: 'access',
      );
      final order = view.orders.single;
      expect(order.paymentMethod, 'bank_deposit');
      expect(order.status, 'pending');
      final status = orderDisplayStatus(order);
      expect(status.label, 'Esperando tu transferencia');
      expect(status.actionLabel, transferPaymentDetailsLabel);
    });

    test('app-loaded pending transfer keeps the Customer Account method',
        () async {
      final repo = OrderHistoryRepository(
        store: OrderSummaryStore(db),
        config: AccountsOrdersConfig.disabled,
        customerOrders: _FakeCaa([
          _caa(
            number: 1008,
            financialStatus: 'PENDING',
            paymentMethod: 'manual',
          ),
        ]),
      );

      final view = await repo.refresh(
        accountId: 'acct-1',
        customerAccountAccessToken: 'caa',
      );
      final order = view.orders.single;
      expect(order.paymentMethod, 'manual');
      expect(order.displayNumber, '#1008');
      final status = orderDisplayStatus(order);
      expect(status.label, 'Esperando tu transferencia');
      expect(status.actionLabel, transferPaymentDetailsLabel);
    });

    test('card pending stays Pago en proceso', () async {
      final repo = OrderHistoryRepository(
        store: OrderSummaryStore(db),
        config: AccountsOrdersConfig.disabled,
        customerOrders: _FakeCaa([
          _caa(
            financialStatus: 'PENDING',
            paymentMethod: 'card',
          ),
        ]),
      );

      final view = await repo.refresh(
        accountId: 'acct-1',
        customerAccountAccessToken: 'caa',
      );
      final status = orderDisplayStatus(view.orders.single);
      expect(view.orders.single.paymentMethod, 'card');
      expect(status.label, 'Pago en proceso');
      expect(status.actionLabel, isNot(transferPaymentDetailsLabel));
    });

    test('missing payment method stays Pago en proceso', () async {
      final repo = OrderHistoryRepository(
        store: OrderSummaryStore(db),
        config: AccountsOrdersConfig.disabled,
        mirrorClient: _FakeMirror([
          const MirroredOrder(
            id: 8,
            shopifyOrderId: '800',
            source: 'shopify_checkout',
            attributionCode: null,
            financialStatus: 'pending',
            fulfillmentStatus: null,
            totalAmount: 100,
            currencyCode: 'MXN',
            placedAt: null,
          ),
        ]),
      );

      final view = await repo.refresh(
        accountId: 'acct-1',
        backendAccessToken: 'access',
      );
      expect(view.orders.single.paymentMethod, isNull);
      expect(orderDisplayStatus(view.orders.single).label, 'Pago en proceso');
      expect(orderDisplayStatus(view.orders.single).actionLabel, isNull);
    });

    test('paypal, mercadopago, and unknown gateway stay Pago en proceso',
        () async {
      const methods = ['paypal', 'mercadopago', 'other:kueski_pay'];
      for (var index = 0; index < methods.length; index++) {
        final method = methods[index];
        final repo = OrderHistoryRepository(
          store: OrderSummaryStore(db),
          config: AccountsOrdersConfig.disabled,
          mirrorClient: _FakeMirror([
            MirroredOrder(
              id: 20 + index,
              shopifyOrderId: '${900 + index}',
              source: 'shopify_checkout',
              attributionCode: null,
              financialStatus: 'pending',
              fulfillmentStatus: null,
              totalAmount: 100,
              currencyCode: 'MXN',
              placedAt: null,
              paymentMethod: method,
            ),
          ]),
        );
        final view = await repo.refresh(
          accountId: 'acct-1',
          backendAccessToken: 'access',
        );
        final order = view.orders.singleWhere(
          (candidate) => candidate.paymentMethod == method,
        );
        expect(order.paymentMethod, method);
        final status = orderDisplayStatus(order);
        expect(status.label, 'Pago en proceso');
        expect(status.actionLabel, isNull);
      }
    });
  });
}
