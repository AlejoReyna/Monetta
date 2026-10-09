/// RF-41: the search ViewModel derives one immutable state from the store and
/// the history, and notifies only when that state changes by value.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/catalog/query/product_search.dart';
import 'package:monetta_app/features/catalog/search_history.dart';
import 'package:monetta_app/features/catalog/search_view_model.dart';
import 'package:monetta_app/reco/events.dart';

/// A [CatalogStore] that counts its listeners, to prove `dispose` lets go.
class _CountingStore extends CatalogStore {
  _CountingStore({required super.database});

  int listeners = 0;

  @override
  void addListener(VoidCallback listener) {
    listeners++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    listeners--;
    super.removeListener(listener);
  }
}

class _CountingHistory extends SearchHistory {
  int listeners = 0;

  @override
  void addListener(VoidCallback listener) {
    listeners++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    listeners--;
    super.removeListener(listener);
  }
}

/// A history whose `remember` fails before it returns a future.
class _FailingHistory extends SearchHistory {
  @override
  Future<void> remember(String raw) => throw StateError('disk full');
}

/// Persistence whose saves wait until [release] is called.
class _HeldPersistence implements SearchHistoryPersistence {
  final Completer<void> _gate = Completer<void>();
  final List<List<String>> saves = <List<String>>[];

  void release() => _gate.complete();

  @override
  Future<List<String>> load(String scopeKey) async => const <String>[];

  @override
  Future<void> save(String scopeKey, List<String> queries) async {
    saves.add(List<String>.of(queries));
    await _gate.future;
  }
}

Product _extraProduct(String title) => Product(
      id: 'gid://shopify/Product/rf41-${title.hashCode}',
      handle: 'rf41-extra',
      title: title,
      vendor: 'Monetta',
      productType: 'Bolsa',
      tags: const <String>[],
      images: const <String>['https://cdn.example/x.jpg'],
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      variants: const <ProductVariant>[
        ProductVariant(
          id: 'gid://shopify/ProductVariant/rf41',
          title: 'Unica',
          price: 100,
          available: true,
        ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CountingStore store;
  late SearchHistory history;
  late SearchViewModel viewModel;
  late int notifications;

  setUp(() async {
    store = _CountingStore(database: openTestDatabase());
    await store.loadFromAsset();
    history = SearchHistory();
    notifications = 0;
  });

  tearDown(() {
    viewModel.dispose();
    store.dispose();
  });

  SearchViewModel build({String initialQuery = '', SearchHistory? history_}) {
    viewModel = SearchViewModel(
      store: store,
      history: history_ ?? history,
      initialQuery: initialQuery,
    )..addListener(() => notifications++);
    return viewModel;
  }

  /// A store notification that touches neither the catalog nor the profile.
  Future<void> poke() => store.setAccountScope(null);

  test('RF-41 SearchViewModel starts in discovery for an empty query', () {
    final vm = build();
    final state = vm.state;

    expect(state.query, '');
    expect(state.showResults, isFalse);
    expect(state.isEmptyQuery, isTrue);
    expect(state.history, isEmpty);
    expect(state.categories, isNotEmpty);
    expect(state.discovery, isNotEmpty);
    expect(state.discovery.length, lessThanOrEqualTo(8));
    expect(state.results, isEmpty);
    expect(state.suggestions, isEmpty);
  });

  test('RF-41 SearchViewModel starts on the results of an initial query', () {
    final vm = build(initialQuery: 'Michael Kors');
    final expected = searchProductList(
      store.products,
      store.facetsFor,
      'Michael Kors',
    );

    expect(vm.state.showResults, isTrue);
    expect(expected, isNotEmpty);
    expect(
      vm.state.results.map((p) => p.id),
      expected.map((p) => p.id),
    );
    expect(vm.state.suggestions, isEmpty);
    expect(vm.state.discovery, isEmpty);
  });

  test('RF-41 SearchViewModel queryChanged goes back to type-ahead', () {
    final vm = build(initialQuery: 'Michael Kors');

    vm.queryChanged('mich');

    expect(vm.state.query, 'mich');
    expect(vm.state.showResults, isFalse);
    expect(vm.state.results, isEmpty);
    expect(vm.state.suggestions, isNotEmpty);
    expect(vm.state.suggestions.length, lessThanOrEqualTo(6));
    expect(
      vm.state.suggestions.every(
        (s) => s.label.toLowerCase().contains('mich'),
      ),
      isTrue,
    );
    expect(notifications, 1);
  });

  test('RF-41 SearchViewModel submit shows results and remembers the query',
      () async {
    final vm = build();
    vm.queryChanged('  coach ');

    await vm.submit.execute('  coach ');

    expect(vm.state.showResults, isTrue);
    expect(vm.state.query, '  coach ');
    expect(
      vm.state.results.map((p) => p.id),
      searchProductList(store.products, store.facetsFor, 'coach')
          .map((p) => p.id),
    );
    expect(history.queries, <String>['coach']);
    expect(vm.submit.completed, isTrue);
  });

  test('RF-41 SearchViewModel submit of blank text only hides the results',
      () async {
    final vm = build(initialQuery: 'coach');
    vm.queryChanged('   ');

    await vm.submit.execute('   ');

    expect(vm.state.showResults, isFalse);
    expect(vm.state.isEmptyQuery, isTrue);
    expect(history.queries, isEmpty);
  });

  test('RF-41 SearchViewModel submit with no match lists categories', () async {
    final vm = build();

    await vm.submit.execute('zzzzqq');

    expect(vm.state.showResults, isTrue);
    expect(vm.state.results, isEmpty);
    expect(vm.state.categories, isNotEmpty);
  });

  test('RF-41 SearchViewModel edit keeps the text and leaves the results', () {
    final vm = build(initialQuery: 'coach');

    vm.edit();

    expect(vm.state.query, 'coach');
    expect(vm.state.showResults, isFalse);
    expect(vm.state.suggestions, isNotEmpty);
  });

  test('RF-41 SearchViewModel clear returns to discovery', () {
    final vm = build(initialQuery: 'coach');

    vm.clear();

    expect(vm.state.query, '');
    expect(vm.state.showResults, isFalse);
    expect(vm.state.discovery, isNotEmpty);
  });

  test(
      'RF-41 SearchViewModel ignores a store notification that changes nothing',
      () async {
    final vm = build(initialQuery: 'Michael Kors');
    final before = vm.state;
    var storeNotifications = 0;
    store.addListener(() => storeNotifications++);

    await poke();
    // An event about a piece nobody is looking at: the store notifies.
    store.record(
      EventType.galleryInteraction,
      productId: store.products.last.id,
    );

    expect(storeNotifications, greaterThanOrEqualTo(2));
    expect(notifications, 0);
    expect(vm.state, before);
  });

  test('RF-41 SearchViewModel ignores store notifications while typing',
      () async {
    final vm = build();
    vm.queryChanged('mich');
    notifications = 0;

    await poke();
    store.record(
      EventType.galleryInteraction,
      productId: store.products.last.id,
    );

    expect(notifications, 0);
  });

  test('RF-41 SearchViewModel ignores store notifications on discovery',
      () async {
    final vm = build();

    await poke();

    expect(notifications, 0);
    expect(vm.state.discovery, isNotEmpty);
  });

  test('RF-41 SearchViewModel notifies when a new product matches the query',
      () async {
    final vm = build(initialQuery: 'Michael Kors');
    final count = vm.state.results.length;
    final extra = _extraProduct('Cartera Michael Kors Nueva');

    store.products = <Product>[...store.products, extra];
    await poke();

    expect(notifications, 1);
    expect(vm.state.results.length, count + 1);
    expect(vm.state.results.map((p) => p.id), contains(extra.id));
  });

  test(
      'RF-41 SearchViewModel stays quiet for a new product that does not match',
      () async {
    final vm = build(initialQuery: 'Michael Kors');
    final extra = _extraProduct('Reloj de otra marca');

    store.products = <Product>[...store.products, extra];
    await poke();

    expect(notifications, 0);
    expect(vm.state.results.map((p) => p.id), isNot(contains(extra.id)));
  });

  test('RF-41 SearchViewModel notifies when a replaced product changes',
      () async {
    final vm = build(initialQuery: 'Michael Kors');
    final first = vm.state.results.first;
    final renamed = Product(
      id: first.id,
      handle: first.handle,
      title: '${first.title} (nuevo precio)',
      vendor: first.vendor,
      productType: first.productType,
      tags: first.tags,
      variants: first.variants,
      images: first.images,
      createdAt: first.createdAt,
      updatedAt: first.updatedAt,
      collectionHandles: first.collectionHandles,
    );

    store.products = <Product>[
      for (final p in store.products) p.id == first.id ? renamed : p,
    ];
    await poke();

    expect(notifications, 1);
    expect(vm.state.results.first.title, renamed.title);
  });

  test('RF-41 SearchViewModel shows the history only on an empty query',
      () async {
    final vm = build();

    await history.remember('bolso coach');
    expect(notifications, 1);
    expect(vm.state.history, <String>['bolso coach']);

    vm.queryChanged('mich');
    notifications = 0;
    await history.remember('cartera');
    expect(notifications, 0, reason: 'type-ahead does not draw the history');

    vm.clear();
    expect(vm.state.history, <String>['cartera', 'bolso coach']);
  });

  test('RF-41 SearchViewModel follows an account scope switch of the history',
      () async {
    final vm = build();
    await history.remember('de invitado');
    notifications = 0;

    await history.setScope('acct-1');

    expect(notifications, 1);
    expect(vm.state.history, isEmpty);

    await history.setScope(null);
    expect(vm.state.history, <String>['de invitado']);
  });

  test('RF-41 SearchViewModel forget removes one entry', () async {
    final vm = build();
    await history.remember('uno');
    await history.remember('dos');

    await vm.forget.execute('uno');

    expect(vm.state.history, <String>['dos']);
    expect(vm.forget.completed, isTrue);
    expect(vm.forget.running, isFalse);
  });

  test('RF-41 SearchViewModel clearHistory empties the history', () async {
    final vm = build();
    await history.remember('uno');
    await history.remember('dos');

    await vm.clearHistory.execute();

    expect(vm.state.history, isEmpty);
    expect(history.queries, isEmpty);
    expect(vm.clearHistory.completed, isTrue);
  });

  test('RF-41 SearchViewModel submit command reports running and completed',
      () async {
    final vm = build();
    final seen = <String>[];
    vm.submit.addListener(
      () => seen.add('running=${vm.submit.running}'),
    );

    final run = vm.submit.execute('coach');
    expect(vm.submit.running, isTrue);
    await run;

    expect(vm.submit.running, isFalse);
    expect(vm.submit.completed, isTrue);
    expect(vm.submit.error, isNull);
    expect(seen, <String>['running=true', 'running=false']);
  });

  test('RF-41 SearchViewModel submit command surfaces a failure as error',
      () async {
    final failing = _FailingHistory();
    final vm = build(history_: failing);

    await vm.submit.execute('coach');

    expect(vm.submit.error, isA<StateError>());
    expect(vm.submit.completed, isFalse);
    expect(vm.submit.running, isFalse);
  });

  test('RF-41 SearchViewModel does not drop a submit while a save is pending',
      () async {
    final held = _HeldPersistence();
    final slow = SearchHistory(persistence: held);
    final vm = build(history_: slow);

    await vm.submit.execute('uno');
    await vm.submit.execute('dos');
    await vm.forget.execute('uno');

    expect(slow.queries, <String>['dos']);
    expect(held.saves, <List<String>>[
      <String>['uno'],
      <String>['dos', 'uno'],
      <String>['dos'],
    ]);
    held.release();
  });

  test('RF-41 SearchViewModel dispose releases its listeners', () {
    final counting = _CountingHistory();
    final base = store.listeners;
    final vm = SearchViewModel(store: store, history: counting);

    expect(store.listeners, base + 1);
    expect(counting.listeners, 1);

    vm.dispose();

    expect(store.listeners, base);
    expect(counting.listeners, 0);

    // Built only so the shared tearDown has something to dispose.
    build();
  });

  test('RF-41 SearchViewModel state compares by value', () {
    final vm = build(initialQuery: 'coach');
    final again = SearchViewModel(
      store: store,
      history: history,
      initialQuery: 'coach',
    );
    addTearDown(again.dispose);

    expect(again.state, vm.state);
    expect(again.state.hashCode, vm.state.hashCode);

    vm.edit();
    expect(vm.state, isNot(again.state));
  });
}
