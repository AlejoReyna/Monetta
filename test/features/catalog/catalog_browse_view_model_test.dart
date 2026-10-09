/// RF-41: the catalog browser ViewModel derives one immutable state from the
/// products it was given, the applied filters and the bag quantity, and
/// notifies only when that state changes by value.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/catalog/catalog_browse_view_model.dart';
import 'package:monetta_app/features/catalog/query/browse_filters.dart';
import 'package:monetta_app/reco/events.dart';

import '../../support/catalog_browse_fixtures.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CountingStore store;
  CatalogBrowseViewModel? viewModel;
  late int notifications;

  setUp(() async {
    store = _CountingStore(database: openTestDatabase());
    await store.loadFromAsset();
    notifications = 0;
  });

  tearDown(() {
    viewModel?.dispose();
    viewModel = null;
    store.dispose();
  });

  /// A view model over the asset catalog, listening to [store] unless
  /// [withStore] is false.
  CatalogBrowseViewModel build({bool withStore = true, int bagCount = 0}) {
    viewModel = CatalogBrowseViewModel(
      products: store.products,
      facetsById: store.facetsById,
      bagCount: bagCount,
      store: withStore ? store : null,
    )..addListener(() => notifications++);
    return viewModel!;
  }

  /// A store notification that touches neither the catalog nor the bag.
  Future<void> poke() => store.setAccountScope(null);

  /// A category of the asset catalog that leaves out some of its pieces.
  String narrowingCategory() {
    final categories = {
      for (final p in store.products) browseCategoryFor(store.facetsById[p.id]),
    };
    expect(categories.length, greaterThan(1), reason: 'asset has categories');
    return categories.first;
  }

  test('RF-41 CatalogBrowseViewModel starts on the whole catalog', () {
    final vm = build();
    final state = vm.state;

    expect(state.filters, const CatalogBrowseFilters());
    expect(state.activeCount, 0);
    expect(state.bagCount, 0);
    expect(
      state.visible.map((p) => p.id),
      filterAndSortCatalog(
        store.products,
        store.facetsById,
        const CatalogBrowseFilters(),
      ).map((p) => p.id),
    );
    expect(state.visible.length, store.products.length);
  });

  test('RF-41 CatalogBrowseViewModel derives the grid from the pure filter',
      () {
    final vm = build();
    final filters = CatalogBrowseFilters(
      categories: {narrowingCategory()},
      sort: CatalogSort.priceAsc,
    );

    vm.applyFilters(filters);

    expect(notifications, 1);
    expect(vm.state.filters, filters);
    expect(vm.state.activeCount, 1);
    expect(
      vm.state.visible.map((p) => p.id),
      filterAndSortCatalog(store.products, store.facetsById, filters)
          .map((p) => p.id),
    );
    expect(vm.state.visible.length, lessThan(store.products.length));
  });

  test('RF-41 CatalogBrowseViewModel notifies only when the filters change',
      () {
    final vm = build();
    final filters = CatalogBrowseFilters(categories: {narrowingCategory()});

    vm.applyFilters(filters);
    expect(notifications, 1);

    // The same choice rebuilt from scratch is equal by value.
    vm.applyFilters(
      CatalogBrowseFilters(categories: {...filters.categories}),
    );
    expect(notifications, 1, reason: 'an equal selection is not a change');

    vm.resetFilters();
    expect(notifications, 2);
    expect(vm.state.filters, const CatalogBrowseFilters());
    expect(vm.state.visible.length, store.products.length);

    vm.resetFilters();
    expect(notifications, 2, reason: 'nothing left to reset');
  });

  test('RF-41 CatalogBrowseViewModel counts a draft without changing state',
      () {
    final vm = build();
    final before = vm.state;
    final draft = CatalogBrowseFilters(categories: {narrowingCategory()});

    final count = vm.countFor(draft);

    expect(
      count,
      filterAndSortCatalog(store.products, store.facetsById, draft).length,
    );
    expect(count, lessThan(store.products.length));
    expect(vm.countFor(const CatalogBrowseFilters()), store.products.length);
    expect(notifications, 0);
    expect(vm.state, before);
    expect(vm.state.filters, const CatalogBrowseFilters());
  });

  test('RF-41 CatalogBrowseFilters compares by value', () {
    const a = CatalogBrowseFilters(
      sort: CatalogSort.priceDesc,
      categories: {'bolsa', 'reloj'},
      colors: {'Negro'},
      inStockOnly: true,
    );
    const same = CatalogBrowseFilters(
      sort: CatalogSort.priceDesc,
      categories: {'reloj', 'bolsa'},
      colors: {'Negro'},
      inStockOnly: true,
    );

    expect(a, same);
    expect(a.hashCode, same.hashCode);
    expect(a, isNot(const CatalogBrowseFilters()));
    expect(a, isNot(a.copyForTest(inStockOnly: false)));
    expect(
      const CatalogBrowseFilters(types: {'Tote'}),
      isNot(const CatalogBrowseFilters(brands: {'Tote'})),
      reason: 'the same label under another facet is another choice',
    );
  });

  test('RF-41 CatalogBrowseViewModel follows the bag quantity of the store',
      () async {
    final vm = build(bagCount: 5);

    expect(vm.state.bagCount, 0, reason: 'the live store wins over the arg');

    await store.addToBag(store.products.first);
    expect(vm.state.bagCount, 1);
    expect(notifications, 1);

    await store.addToBag(store.products.first);
    expect(vm.state.bagCount, 2);
    expect(notifications, 2);

    await store.removeFromBag(store.products.first.variants.first.id);
    expect(vm.state.bagCount, 0);
    expect(notifications, 3);
  });

  test(
      'RF-41 CatalogBrowseViewModel ignores a store notification that changes '
      'nothing', () async {
    final vm = build();
    final before = vm.state;
    var storeNotifications = 0;
    store.addListener(() => storeNotifications++);

    await poke();
    store.record(
      EventType.galleryInteraction,
      productId: store.products.last.id,
    );

    expect(storeNotifications, greaterThanOrEqualTo(2));
    expect(notifications, 0);
    expect(identical(vm.state, before), isTrue);
  });

  test('RF-41 CatalogBrowseViewModel without a store uses the given bagCount',
      () async {
    final vm = build(withStore: false, bagCount: 3);
    expect(vm.state.bagCount, 3);

    // The store is not listened to: its bag does not reach the view model.
    await store.addToBag(store.products.first);
    expect(vm.state.bagCount, 3);
    expect(notifications, 0);
  });

  test('RF-41 CatalogBrowseViewModel follows a new bagCount without a store',
      () {
    final vm = build(withStore: false, bagCount: 2);

    vm.updateInputs(
      products: store.products,
      facetsById: store.facetsById,
      bagCount: 0,
    );
    expect(vm.state.bagCount, 0);
    expect(notifications, 1);

    vm.updateInputs(
      products: store.products,
      facetsById: store.facetsById,
      bagCount: 0,
    );
    expect(notifications, 1, reason: 'the same inputs are not a change');
  });

  test('RF-41 CatalogBrowseViewModel keeps the filters on new inputs', () {
    final entries = [
      browseEntry(1, category: 'bolsa'),
      browseEntry(2, category: 'cartera'),
      browseEntry(3, category: 'bolsa'),
      browseEntry(4, category: 'reloj'),
    ];
    viewModel = CatalogBrowseViewModel(
      products: [for (final e in entries.take(2)) e.product],
      facetsById: {
        for (final e in entries.take(2)) e.product.id: e.facets!,
      },
    )..addListener(() => notifications++);
    final vm = viewModel!;
    const bags = CatalogBrowseFilters(categories: {'bolsa'});
    vm.applyFilters(bags);
    expect(vm.state.visible.map((p) => p.id), [entries[0].product.id]);
    notifications = 0;

    vm.updateInputs(
      products: [for (final e in entries) e.product],
      facetsById: {for (final e in entries) e.product.id: e.facets!},
      bagCount: 0,
    );

    expect(notifications, 1);
    expect(vm.state.filters, bags, reason: 'the applied filters stay');
    expect(
      vm.state.visible.map((p) => p.id),
      [entries[0].product.id, entries[2].product.id],
    );
    expect(
      vm.countFor(const CatalogBrowseFilters()),
      entries.length,
      reason: 'the sheet counts over the new products',
    );
  });

  test('RF-41 CatalogBrowseViewModel dispose releases its listeners', () async {
    final before = store.listeners;
    final vm = build();
    expect(store.listeners, before + 1);

    vm.dispose();
    expect(store.listeners, before);

    // A late store notification must neither throw nor notify.
    await poke();
    await store.addToBag(store.products.first);
    expect(notifications, 0);

    // tearDown must not dispose it a second time.
    viewModel = null;
  });

  test('RF-41 CatalogBrowseViewModel without a store adds no listener', () {
    final before = store.listeners;

    build(withStore: false);

    expect(store.listeners, before);
  });
}

extension on CatalogBrowseFilters {
  /// A copy with [inStockOnly] replaced; the filters have no `copyWith`.
  CatalogBrowseFilters copyForTest({required bool inStockOnly}) =>
      CatalogBrowseFilters(
        sort: sort,
        categories: categories,
        types: types,
        brands: brands,
        priceBands: priceBands,
        colors: colors,
        inStockOnly: inStockOnly,
      );
}
