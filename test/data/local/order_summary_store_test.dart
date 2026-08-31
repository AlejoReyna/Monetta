import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/order_summary_store.dart';

OrderSummariesCompanion _order({
  required String id,
  required String accountId,
  String source = 'shopify_checkout',
  String? attributionCode,
  DateTime? placedAt,
}) {
  return OrderSummariesCompanion.insert(
    id: id,
    accountId: accountId,
    source: source,
    attributionCode: Value(attributionCode),
    status: 'paid',
    totalAmount: 1749,
    currencyCode: 'MXN',
    placedAt: placedAt ?? DateTime.utc(2026, 1, 1),
  );
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

  group('OrderSummaryStore', () {
    test('allForAccount returns newest first', () async {
      final store = OrderSummaryStore(db);
      await store.replaceAllForAccount('acct-1', [
        _order(
            id: '1', accountId: 'acct-1', placedAt: DateTime.utc(2026, 1, 1)),
        _order(
            id: '2', accountId: 'acct-1', placedAt: DateTime.utc(2026, 6, 1)),
      ]);

      final orders = await store.allForAccount('acct-1');
      expect(orders.map((o) => o.id), ['2', '1']);
    });

    test('replaceAllForAccount fully replaces rather than appending', () async {
      final store = OrderSummaryStore(db);
      await store.replaceAllForAccount(
          'acct-1', [_order(id: '1', accountId: 'acct-1')]);
      await store.replaceAllForAccount(
          'acct-1', [_order(id: '2', accountId: 'acct-1')]);

      final orders = await store.allForAccount('acct-1');
      expect(orders.map((o) => o.id), ['2']);
    });

    test(
        'unifies shopify_checkout and whatsapp_apartado sources for the same account',
        () async {
      final store = OrderSummaryStore(db);
      await store.replaceAllForAccount('acct-1', [
        _order(id: '1', accountId: 'acct-1'),
        _order(
          id: '2',
          accountId: 'acct-1',
          source: 'whatsapp_apartado',
          attributionCode: 'MN-7K3Q',
        ),
      ]);

      final orders = await store.allForAccount('acct-1');
      expect(orders.map((o) => o.source).toSet(),
          {'shopify_checkout', 'whatsapp_apartado'});
      expect(orders.firstWhere((o) => o.id == '2').attributionCode, 'MN-7K3Q');
    });
  });
}
