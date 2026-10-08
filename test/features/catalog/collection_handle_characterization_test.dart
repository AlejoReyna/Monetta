/// CHAR-07: characterization of the collection-handle rule in
/// `CollectionScreen._scopedItems`.
///
/// With a `collectionHandle` set, a product is dropped only when it has
/// collection handles and none of them matches. A product with no handles at
/// all always passes (the bundled offline catalog never has any), so an
/// unrelated product can appear inside a collection. The decision on this rule
/// belongs to RF-40; that WP must change this test explicitly.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/catalog/product_card.dart';
import 'package:monetta_app/main.dart';

const _inCollection = 'gid://shopify/Product/7701';
const _otherCollection = 'gid://shopify/Product/7702';
const _noHandles = 'gid://shopify/Product/7703';

Product _product(String id, List<String> collectionHandles) => Product(
      id: id,
      handle: 'handle-${id.split('/').last}',
      title: 'Producto ${id.split('/').last}',
      vendor: 'Monetta',
      productType: 'Bolsa',
      tags: const [],
      images: const [],
      createdAt: DateTime.utc(2026, 7, 1),
      updatedAt: DateTime.utc(2026, 8, 1),
      collectionHandles: collectionHandles,
      variants: [
        ProductVariant(
          id: 'gid://shopify/ProductVariant/${id.split('/').last}',
          title: 'Default Title',
          price: 1000,
          available: true,
        ),
      ],
    );

Future<CatalogStore> _storeWithThreeProducts() async {
  final store = CatalogStore(database: openTestDatabase());
  await store.loadFromAsset();
  store.products = [
    _product(_inCollection, const ['rebajas']),
    _product(_otherCollection, const ['otra']),
    _product(_noHandles, const []),
  ];
  store.facetsById = const {};
  return store;
}

Future<Set<String>> _visibleIds(
  WidgetTester tester,
  CatalogStore store,
  CollectionFilter filter,
) async {
  addTearDown(() => tester.view.resetPhysicalSize());
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1.0;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: StoreScope(
        notifier: store,
        child: CollectionScreen(title: 'Rebajas', filter: filter),
      ),
    ),
  );
  await tester.pump();
  return tester
      .widgetList<ProductCard>(find.byType(ProductCard))
      .map((card) => card.product.id)
      .toSet();
}

void main() {
  testWidgets(
      'CHAR-07 (vigente, decisión en RF-40) con collectionHandle se ven el '
      'producto de la colección y el que no tiene handles, no el de otra '
      'colección', (tester) async {
    final store = await _storeWithThreeProducts();
    addTearDown(store.dispose);

    final ids = await _visibleIds(
      tester,
      store,
      const CollectionFilter(collectionHandle: 'rebajas'),
    );

    expect(ids, contains(_inCollection));
    expect(
      ids,
      contains(_noHandles),
      reason: 'a product without handles passes every collection',
    );
    expect(ids, isNot(contains(_otherCollection)));
    expect(ids, hasLength(2));
  });

  testWidgets(
      'CHAR-07 (vigente, decisión en RF-40) control: sin collectionHandle '
      'se ven los tres productos', (tester) async {
    final store = await _storeWithThreeProducts();
    addTearDown(store.dispose);

    final ids = await _visibleIds(tester, store, const CollectionFilter());

    expect(ids, {_inCollection, _otherCollection, _noHandles});
  });
}
