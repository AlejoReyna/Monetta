/// RF-41: the product ViewModel derives one immutable state from the store,
/// the page and the chosen variant, and notifies only when that state changes
/// by value.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/product/product_view_model.dart';
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

Product _optionProduct(
  String suffix, {
  List<String> options = const ['Negro', 'Rojo'],
}) =>
    Product(
      id: 'gid://shopify/Product/rf41-$suffix',
      handle: 'rf41-$suffix',
      title: 'Bolso de prueba RF-41 $suffix',
      vendor: 'Monetta',
      productType: 'Bolsa',
      tags: const <String>[],
      images: const <String>['https://cdn.example/x.jpg'],
      createdAt: DateTime.utc(2030),
      updatedAt: DateTime.utc(2030),
      variants: <ProductVariant>[
        for (var i = 0; i < options.length; i++)
          ProductVariant(
            id: 'gid://shopify/ProductVariant/rf41-$suffix-$i',
            title: options[i],
            price: 100.0 + i * 50,
            available: true,
          ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CountingStore store;
  late ProductViewModel viewModel;
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

  ProductViewModel build({
    String? productId,
    int initialVariantIndex = 0,
  }) {
    viewModel = ProductViewModel(
      store: store,
      productId: productId ?? store.products.first.id,
      initialVariantIndex: initialVariantIndex,
    )..addListener(() => notifications++);
    return viewModel;
  }

  /// A store notification that touches neither the catalog nor the bag.
  Future<void> poke() => store.setAccountScope(null);

  test('RF-41 ProductViewModel starts on the requested product', () {
    final product = store.products.first;
    final vm = build(productId: product.id, initialVariantIndex: 0);
    final state = vm.state;

    expect(state.product, same(product));
    expect(state.facets, same(store.facetsFor(product.id)));
    expect(state.wishlisted, isFalse);
    expect(state.variantIndex, 0);
    expect(
      state.recent.map((p) => p.id),
      store.recentlyViewed(excluding: product.id).map((p) => p.id),
    );
    final brand = store.facetsFor(product.id)?.brand?.value;
    expect(
      state.related.map((p) => p.id),
      brand == null
          ? isEmpty
          : store.moreFromBrand(brand, excluding: product.id).map((p) => p.id),
    );
    expect(notifications, 0);
  });

  test('RF-41 ProductViewModel reports a missing product as absent', () {
    final vm = build(productId: 'gid://shopify/Product/0');

    expect(vm.state.product, isNull);
    expect(vm.state.facets, isNull);
    expect(vm.state.wishlisted, isFalse);
    expect(vm.state.recent, isEmpty);
    expect(vm.state.related, isEmpty);
    expect(notifications, 0);
  });

  test(
      'RF-41 ProductViewModel selectVariant changes the choice and notifies '
      'once, and stays quiet when unchanged', () {
    store.products = <Product>[...store.products, _optionProduct('opts')];
    final vm = build(
      productId: 'gid://shopify/Product/rf41-opts',
      initialVariantIndex: 0,
    );
    expect(vm.state.variantIndex, 0);

    vm.selectVariant(1);

    expect(vm.state.variantIndex, 1);
    expect(notifications, 1);

    vm.selectVariant(1);

    expect(notifications, 1);
  });

  test(
      'RF-41 ProductViewModel ignores a store notification that changes '
      'nothing', () async {
    final shown = store.products.first;
    final other = store.products.lastWhere((p) => p.id != shown.id);
    final vm = build(productId: shown.id);
    final before = vm.state;
    var storeNotifications = 0;
    store.addListener(() => storeNotifications++);

    await poke();
    // An event about a piece nobody is looking at: the store notifies.
    store.record(
      EventType.galleryInteraction,
      productId: other.id,
    );

    expect(storeNotifications, greaterThanOrEqualTo(2));
    expect(notifications, 0);
    expect(vm.state, before);
  });

  test(
      'RF-41 ProductViewModel notifies for its own wishlist change and stays '
      'quiet for another piece', () async {
    final shown = store.products.first;
    final other = store.products.firstWhere((p) => p.id != shown.id);
    final vm = build(productId: shown.id);
    expect(vm.state.wishlisted, isFalse);

    await store.toggleWishlist(shown.id);

    expect(vm.state.wishlisted, isTrue);
    expect(notifications, 1);

    await store.toggleWishlist(other.id);

    expect(vm.state.wishlisted, isTrue);
    expect(notifications, 1);
  });

  test(
      'RF-41 ProductViewModel notifies when its product leaves the catalog '
      'and when it returns', () async {
    final shown = store.products.first;
    final vm = build(productId: shown.id);
    expect(vm.state.product, same(shown));

    store.products = store.products.where((p) => p.id != shown.id).toList();
    await poke();

    expect(vm.state.product, isNull);
    expect(notifications, 1);

    store.products = <Product>[...store.products, shown];
    await poke();

    expect(vm.state.product, same(shown));
    expect(notifications, 2);
  });

  test(
      'RF-41 ProductViewModel notifies when a view about another piece '
      'refreshes the recent rail', () {
    final shown = store.products.firstWhere((p) => p.isInStock);
    final other =
        store.products.firstWhere((p) => p.isInStock && p.id != shown.id);
    final vm = build(productId: shown.id);

    store.record(EventType.productView, productId: other.id);

    expect(notifications, 1);
    expect(vm.state.recent.first.id, other.id);
  });

  test(
      'RF-41 ProductViewModel updateProductId follows the new piece and keeps '
      'the variant', () {
    store.products = <Product>[
      ...store.products,
      _optionProduct('a'),
      _optionProduct('b'),
    ];
    final vm = build(
      productId: 'gid://shopify/Product/rf41-a',
      initialVariantIndex: 1,
    );
    expect(vm.state.variantIndex, 1);

    vm.updateProductId('gid://shopify/Product/rf41-b');

    expect(vm.state.product!.id, 'gid://shopify/Product/rf41-b');
    expect(vm.state.variantIndex, 1);
    expect(notifications, 1);

    vm.updateProductId('gid://shopify/Product/rf41-b');

    expect(notifications, 1);
  });

  test('RF-41 ProductViewModel keeps the raw index when it is out of range',
      () {
    store.products = <Product>[...store.products, _optionProduct('opts')];
    final vm = build(
      productId: 'gid://shopify/Product/rf41-opts',
      initialVariantIndex: 7,
    );

    // Read-time fallback (selectedVariant) shows the first option; the state
    // keeps the raw index, exactly as the screen's former `late` field did.
    expect(vm.state.variantIndex, 7);
    expect(notifications, 0);
  });

  test('RF-41 ProductViewModel state compares by value', () {
    final product = store.products.first;
    final vm = build(productId: product.id);

    expect(vm.state, vm.state);
    expect(vm.state.hashCode, vm.state.hashCode);
  });

  test('RF-41 ProductViewModel dispose releases its listener', () async {
    final before = store.listeners;
    final vm = build();
    expect(store.listeners, before + 1);

    vm.dispose();
    expect(store.listeners, before);

    // A late store notification must neither throw nor notify.
    await poke();
    expect(notifications, 0);

    // tearDown disposes it again: build a fresh one for it.
    viewModel =
        ProductViewModel(store: store, productId: store.products.first.id);
  });
}
