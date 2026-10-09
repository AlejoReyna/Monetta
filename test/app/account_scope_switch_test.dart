/// CHAR-16: an account switch A -> B with A's hydration still in flight leaves
/// only B's bag, wishlist and search history visible (invariant 9: a late
/// result of account A is never applied to account B).
///
/// Characterization of today's behaviour: `CatalogStore.setAccountScope`
/// discards a hydration whose scope changed while it awaited the database
/// (`catalog_store.dart`, `_hydrateBagAndWishlist`), and `SearchHistory`
/// keeps one state per scope so a late restore lands on its own scope.
/// RF-32 moves the switch into a use case; this file must stay green.
library;

import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/local/bag_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/wishlist_store.dart';
import 'package:monetta_app/features/catalog/search_history.dart';

import '../support/product_screen_harness.dart';

const _guestProductId = 'gid://shopify/Product/9100';
const _productAId = 'gid://shopify/Product/9101';
const _productBId = 'gid://shopify/Product/9102';
const _guestVariantId = 'gid://shopify/ProductVariant/9100';
const _variantAId = 'gid://shopify/ProductVariant/9101';
const _variantBId = 'gid://shopify/ProductVariant/9102';

/// Holds back SELECTs that filter on a gated account scope until the test
/// opens the gate, so "A's answer arrives after B was applied" is guaranteed
/// by construction instead of by timing.
class _ScopeGate {
  final Completer<void> reached = Completer<void>();
  final Completer<void> open = Completer<void>();
}

class _GatedReads extends QueryInterceptor {
  final Map<String, _ScopeGate> _gates = <String, _ScopeGate>{};

  _ScopeGate gate(String scope) => _gates.putIfAbsent(scope, _ScopeGate.new);

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    for (final entry in _gates.entries) {
      if (args.contains(entry.key)) {
        if (!entry.value.reached.isCompleted) entry.value.reached.complete();
        await entry.value.open.future;
      }
    }
    return super.runSelect(executor, statement, args);
  }
}

String _view(CatalogStore store) {
  final bag = store.bagLines.map((l) => l.variant.id).toList()..sort();
  final wishlist = store.wishlist.toList()..sort();
  return 'bag=$bag qty=${store.bagQuantity} wishlist=$wishlist';
}

String _expectedView({required String variantId, required String productId}) =>
    'bag=[$variantId] qty=1 wishlist=[$productId]';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _GatedReads gates;
  late AppDatabase db;
  late CatalogStore store;
  late List<String> notified;

  setUp(() async {
    gates = _GatedReads();
    db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;'),
      ).interceptWith(gates),
    );
    store = CatalogStore(database: db, shopDomain: 'monetta.mx');
    await store.loadFromAsset();
    addProducts(store, [
      syntheticProduct(id: _guestProductId),
      syntheticProduct(id: _productAId),
      syntheticProduct(id: _productBId),
    ]);

    final bag = BagStore(db);
    final wishlist = WishlistStore(db);
    await bag.upsert(
      productId: _guestProductId,
      variantId: _guestVariantId,
      quantity: 1,
    );
    await wishlist.add(_guestProductId);
    await bag.upsert(
      productId: _productAId,
      variantId: _variantAId,
      quantity: 1,
      accountId: 'A',
    );
    await wishlist.add(_productAId, accountId: 'A');
    await bag.upsert(
      productId: _productBId,
      variantId: _variantBId,
      quantity: 1,
      accountId: 'B',
    );
    await wishlist.add(_productBId, accountId: 'B');

    // Start from a hydrated guest scope.
    await store.setAccountScope(null);
    expect(
      _view(store),
      _expectedView(variantId: _guestVariantId, productId: _guestProductId),
    );

    notified = <String>[];
    store.addListener(() => notified.add(_view(store)));
  });

  tearDown(() async {
    store.dispose();
    await db.close();
  });

  group('CatalogStore bag and wishlist', () {
    test(
      'CHAR-16 guest -> A -> B launched back to back shows only B',
      () async {
        final toA = store.setAccountScope('A');
        final toB = store.setAccountScope('B');
        await Future.wait([toA, toB]);

        final expected =
            _expectedView(variantId: _variantBId, productId: _productBId);
        expect(_view(store), expected);
        expect(store.bagLines.single.product.id, _productBId);
        expect(store.bagQuantity, 1);
        expect(store.wishlist, {_productBId});
        // Whatever intermediate state a listener saw, it never held A's data.
        expect(
          notified.where((view) => view.contains('9101')),
          isEmpty,
          reason: 'A leaked into a notification: $notified',
        );
        // The switch only changes what is visible; A's rows stay on disk.
        expect(
          (await BagStore(db).all(accountId: 'A')).map((r) => r.variantId),
          [_variantAId],
        );
        expect(
          await WishlistStore(db).allProductIds(accountId: 'A'),
          {_productAId},
        );
      },
    );

    test(
      'CHAR-16 B -> guest launched back to back shows only the guest',
      () async {
        final toB = store.setAccountScope('B');
        final toGuest = store.setAccountScope(null);
        await Future.wait([toB, toGuest]);

        expect(
          _view(store),
          _expectedView(
            variantId: _guestVariantId,
            productId: _guestProductId,
          ),
        );
        expect(store.wishlist, {_guestProductId});
        expect(
          notified.where((view) => view.contains('9102')),
          isEmpty,
          reason: 'B leaked into a notification: $notified',
        );
      },
    );

    test(
      'CHAR-16 A answering after B was applied is discarded (A gated)',
      () async {
        final gateA = gates.gate('A');

        final toA = store.setAccountScope('A');
        // A's read is now parked inside the database: its answer is in flight.
        await gateA.reached.future;

        await store.setAccountScope('B');
        final expected =
            _expectedView(variantId: _variantBId, productId: _productBId);
        expect(_view(store), expected);
        expect(gateA.open.isCompleted, isFalse, reason: 'A must still be late');

        gateA.open.complete();
        await toA;

        // The late A answer carried X/A rows; none of them were applied.
        expect(_view(store), expected);
        expect(store.wishlist, {_productBId});
        expect(notified, isNotEmpty);
        expect(
          notified.where((view) => view != expected),
          isEmpty,
          reason: 'only B was ever visible after the switch: $notified',
        );
      },
    );

    test(
      'CHAR-16 B -> guest with B gated: late B answer does not reach the guest',
      () async {
        final gateB = gates.gate('B');

        final toB = store.setAccountScope('B');
        await gateB.reached.future;

        await store.setAccountScope(null);
        final expected = _expectedView(
          variantId: _guestVariantId,
          productId: _guestProductId,
        );
        expect(_view(store), expected);

        gateB.open.complete();
        await toB;

        expect(_view(store), expected);
        expect(store.wishlist, {_guestProductId});
        expect(store.bagQuantity, 1);
      },
    );
  });

  group('SearchHistory', () {
    test(
      'CHAR-16 history: B loads first, A answers late, B stays visible',
      () async {
        final persistence = _ControlledPersistence();
        final history = SearchHistory(persistence: persistence);
        final seen = <List<String>>[];
        history.addListener(() => seen.add(history.queries));

        final toA = history.setScope('A');
        final toB = history.setScope('B');
        expect(persistence.requested, ['A', 'B']);

        persistence.complete('B', ['bolso b1', 'bolso b2']);
        await toB;
        expect(history.scopeKey, 'B');
        expect(history.queries, ['bolso b1', 'bolso b2']);

        persistence.complete('A', ['cartera a1']);
        await toA;

        expect(history.scopeKey, 'B');
        expect(history.queries, ['bolso b1', 'bolso b2']);
        expect(
          seen.where((queries) => queries.contains('cartera a1')),
          isEmpty,
          reason: 'A history surfaced while B was current: $seen',
        );
        expect(persistence.saves, isEmpty);

        // A's own history was not lost: it is there when A becomes current.
        await history.setScope('A');
        expect(history.queries, ['cartera a1']);
      },
    );

    test(
      'CHAR-16 history: A answers first, then B, B is the visible one',
      () async {
        final persistence = _ControlledPersistence();
        final history = SearchHistory(persistence: persistence);
        final seen = <List<String>>[];
        history.addListener(() => seen.add(history.queries));

        final toA = history.setScope('A');
        final toB = history.setScope('B');

        persistence.complete('A', ['cartera a1']);
        await toA;
        expect(history.scopeKey, 'B');
        expect(history.queries, isEmpty, reason: 'B has not answered yet');

        persistence.complete('B', ['bolso b1']);
        await toB;

        expect(history.queries, ['bolso b1']);
        expect(
          seen.where((queries) => queries.contains('cartera a1')),
          isEmpty,
          reason: 'A history surfaced while B was current: $seen',
        );
        expect(persistence.saves, isEmpty);
      },
    );
  });
}

/// A persistence whose `load` answers only when the test says so.
class _ControlledPersistence implements SearchHistoryPersistence {
  final Map<String, Completer<List<String>>> _loads =
      <String, Completer<List<String>>>{};
  final List<String> requested = <String>[];
  final List<(String, List<String>)> saves = <(String, List<String>)>[];

  @override
  Future<List<String>> load(String scopeKey) {
    requested.add(scopeKey);
    return _loads.putIfAbsent(scopeKey, Completer<List<String>>.new).future;
  }

  void complete(String scopeKey, List<String> queries) =>
      _loads[scopeKey]!.complete(queries);

  @override
  Future<void> save(String scopeKey, List<String> queries) async {
    saves.add((scopeKey, List<String>.of(queries)));
  }
}
