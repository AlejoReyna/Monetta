/// RF-41: the collection ViewModel derives one immutable state from the store
/// and the destination, and notifies only when that state changes by value.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/catalog/collection_view_model.dart';
import 'package:monetta_app/features/catalog/query/collection_filter.dart';
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

Product _extraProduct(String title, {List<String> handles = const []}) =>
    Product(
      id: 'gid://shopify/Product/rf41-${title.hashCode}',
      handle: 'rf41-extra',
      title: title,
      vendor: 'Monetta',
      productType: 'Bolsa',
      tags: const <String>[],
      images: const <String>['https://cdn.example/x.jpg'],
      createdAt: DateTime.utc(2030),
      updatedAt: DateTime.utc(2030),
      collectionHandles: handles,
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
  late CollectionViewModel viewModel;
  late int notifications;

  setUp(() async {
    store = _CountingStore(database: openTestDatabase());
    await store.loadFromAsset();
    notifications = 0;
  });

  tearDown(() {
    viewModel.dispose();
    store.dispose();
  });

  CollectionViewModel build({
    CollectionFilter filter = const CollectionFilter(category: 'bolsa'),
  }) {
    viewModel = CollectionViewModel(store: store, filter: filter)
      ..addListener(() => notifications++);
    return viewModel;
  }

  /// A store notification that touches neither the catalog nor the bag.
  Future<void> poke() => store.setAccountScope(null);

  /// A brand present in the bags of the asset catalog.
  String someBrand() => build().state.brands.first;

  test('RF-41 CollectionViewModel starts on the whole destination', () {
    final vm = build();
    final state = vm.state;

    expect(state.scoped, isNotEmpty);
    expect(
      state.scoped.map((p) => p.id),
      filterCollectionProducts(
        store.products,
        store.facetsFor,
        const CollectionFilter(category: 'bolsa'),
      ).map((p) => p.id),
    );
    expect(state.filters, const CollectionFilters());
    expect(state.baseline, const CollectionFilters());
    expect(state.activeCount, 0);
    expect(
      state.items.map((p) => p.id),
      unorderedEquals(state.scoped.map((p) => p.id)),
    );
    // Newest first.
    for (var i = 1; i < state.items.length; i++) {
      expect(
        state.items[i - 1].createdAt.isBefore(state.items[i].createdAt),
        isFalse,
      );
    }
    expect(state.brands, isNotEmpty);
    expect(state.bagCount, 0);
  });

  test(
      'RF-41 CollectionViewModel lists only brands and silhouettes of the scope',
      () {
    final vm = build();
    final state = vm.state;

    final brands = {
      for (final p in state.scoped) store.facetsFor(p.id)?.brand?.value,
    }..remove(null);
    final silhouettes = {
      for (final p in state.scoped) store.facetsFor(p.id)?.silhouette?.value,
    }..remove(null);
    expect(state.brands.toSet(), brands);
    expect(state.silhouettes.toSet(), silhouettes);
    expect(state.brands.length, brands.length, reason: 'no duplicates');
  });

  test('RF-41 CollectionViewModel takes its baseline from the destination', () {
    final brand = someBrand();
    viewModel.dispose();
    final vm = build(
      filter: CollectionFilter(category: 'bolsa', brand: brand),
    );

    expect(vm.state.baseline, CollectionFilters(brand: brand));
    expect(vm.state.filters, CollectionFilters(brand: brand));
    expect(vm.state.activeCount, 0, reason: 'the destination is no filter');
    expect(
      vm.state.items.every(
        (p) => store.facetsFor(p.id)?.brand?.value == brand,
      ),
      isTrue,
    );
  });

  test('RF-41 CollectionViewModel applies filters, notifying once', () {
    final vm = build();
    final brand = vm.state.brands.first;
    final expected = vm.state.scoped
        .where((p) => store.facetsFor(p.id)?.brand?.value == brand)
        .map((p) => p.id)
        .toSet();

    vm.applyFilters(CollectionFilters(brand: brand));

    expect(notifications, 1);
    expect(vm.state.items.map((p) => p.id).toSet(), expected);
    expect(vm.state.activeCount, 1);
    expect(vm.state.scoped.length, greaterThan(vm.state.items.length));

    vm.applyFilters(CollectionFilters(brand: brand));
    expect(notifications, 1, reason: 'the same choices change nothing');
  });

  test('RF-41 CollectionViewModel orders and keeps only what is in stock', () {
    final vm = build();

    vm.applyFilters(const CollectionFilters(sort: CollectionSort.priceAsc));
    final prices = vm.state.items.map((p) => p.price).toList();
    expect(prices, [...prices]..sort());
    expect(vm.state.activeCount, 0, reason: 'ordering is not a filter');

    vm.applyFilters(const CollectionFilters(sort: CollectionSort.priceDesc));
    final descending = vm.state.items.map((p) => p.price).toList();
    expect(descending, [...descending]..sort((a, b) => b.compareTo(a)));

    vm.applyFilters(const CollectionFilters(inStockOnly: true));
    expect(vm.state.items.every((p) => p.isInStock), isTrue);
    expect(vm.state.activeCount, 1);
  });

  test('RF-41 CollectionViewModel clears back to the destination', () {
    final brand = someBrand();
    viewModel.dispose();
    final vm = build(
      filter: CollectionFilter(category: 'bolsa', brand: brand),
    );
    final atStart = vm.state;

    vm.applyFilters(
      CollectionFilters(
        brand: brand,
        inStockOnly: true,
        sort: CollectionSort.priceDesc,
      ),
    );
    final other = vm.state.brands.first;
    vm.applyFilters(CollectionFilters(brand: other, inStockOnly: true));
    notifications = 0;

    vm.clearFilters();

    expect(vm.state.filters, CollectionFilters(brand: brand));
    expect(vm.state.activeCount, 0);
    expect(vm.state, atStart);
    expect(notifications, 1);

    vm.clearFilters();
    expect(notifications, 1, reason: 'already at the destination');
  });

  test('RF-41 CollectionViewModel countFor matches what the grid would show',
      () {
    final vm = build();
    const stock = CollectionFilters(inStockOnly: true);
    final count = vm.countFor(stock);

    vm.applyFilters(stock);

    expect(count, vm.state.items.length);
    expect(vm.countFor(const CollectionFilters()), vm.state.scoped.length);
  });

  test(
      'RF-41 CollectionViewModel ignores a store notification that changes '
      'nothing', () async {
    final vm = build();
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

  test('RF-41 CollectionViewModel notifies when a new product joins the scope',
      () async {
    final vm = build(filter: const CollectionFilter(collectionHandle: 'rf41'));
    final count = vm.state.items.length;
    final extra = _extraProduct('Bolso nuevo', handles: const ['rf41']);

    store.products = <Product>[...store.products, extra];
    await poke();

    expect(notifications, 1);
    expect(vm.state.items.length, count + 1);
    expect(vm.state.items.first.id, extra.id, reason: 'newest first');
    expect(vm.countFor(const CollectionFilters()), count + 1);
  });

  test('RF-41 CollectionViewModel stays quiet for a product outside the scope',
      () async {
    final vm = build(filter: const CollectionFilter(collectionHandle: 'rf41'));
    final other = _extraProduct('Bolso de otra', handles: const ['otra']);

    store.products = <Product>[...store.products, other];
    await poke();

    expect(notifications, 0);
    expect(vm.state.items.map((p) => p.id), isNot(contains(other.id)));
  });

  test('RF-41 CollectionViewModel notifies when a replaced product changes',
      () async {
    final vm = build();
    final first = vm.state.items.first;
    final repriced = Product(
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
      for (final p in store.products) p.id == first.id ? repriced : p,
    ];
    await poke();

    expect(notifications, 1);
    expect(
      vm.state.items.firstWhere((p) => p.id == first.id).title,
      repriced.title,
    );
  });

  test('RF-41 CollectionViewModel follows the bag count', () async {
    final vm = build();

    await store.addToBag(vm.state.items.first);

    expect(vm.state.bagCount, 1);
    expect(notifications, 1);
  });

  test('RF-41 CollectionViewModel follows a new destination, keeping choices',
      () {
    final vm = build();
    final brand = vm.state.brands.first;
    vm.applyFilters(CollectionFilters(brand: brand, inStockOnly: true));
    notifications = 0;

    vm.updateDestination(const CollectionFilter(category: 'reloj'));

    expect(notifications, 1);
    expect(
      vm.state.filters,
      CollectionFilters(brand: brand, inStockOnly: true),
      reason: 'the shopper\'s choices outlive a change of destination',
    );
    expect(vm.state.baseline, const CollectionFilters());
    expect(
      vm.state.scoped.map((p) => p.id),
      filterCollectionProducts(
        store.products,
        store.facetsFor,
        const CollectionFilter(category: 'reloj'),
      ).map((p) => p.id),
    );
  });

  test('RF-41 CollectionViewModel ignores an equal destination', () {
    final vm = build();

    vm.updateDestination(const CollectionFilter(category: 'bolsa'));

    expect(notifications, 0);
  });

  test('RF-41 CollectionViewModel moves the baseline with the destination', () {
    final vm = build();
    final brand = vm.state.brands.first;
    vm.applyFilters(CollectionFilters(brand: brand));
    expect(vm.state.activeCount, 1);

    vm.updateDestination(CollectionFilter(category: 'bolsa', brand: brand));

    expect(vm.state.baseline, CollectionFilters(brand: brand));
    expect(vm.state.activeCount, 0, reason: 'now the destination itself');
  });

  test('RF-41 CollectionViewModel dispose releases its listeners', () async {
    final before = store.listeners;
    final vm = build();
    expect(store.listeners, before + 1);

    vm.dispose();
    expect(store.listeners, before);

    // A late store notification must neither throw nor notify.
    await poke();
    expect(notifications, 0);

    // tearDown disposes it again: build a fresh one for it.
    viewModel = CollectionViewModel(
      store: store,
      filter: const CollectionFilter(),
    );
  });
}
