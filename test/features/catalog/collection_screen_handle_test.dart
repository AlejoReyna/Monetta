import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/main.dart';

void main() {
  testWidgets('collection handle falls back to category for offline products',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = CatalogStore(database: openTestDatabase());
    addTearDown(store.dispose);
    await store.loadFromAsset();

    expect(store.products.first.collectionHandles, isEmpty);
    final bagCount = store.products.where((product) {
      return store.facetsFor(product.id)?.category?.value == 'bolsa';
    }).length;

    await tester.pumpWidget(
      MaterialApp(
        home: StoreScope(
          notifier: store,
          child: const CollectionScreen(
            title: 'Bolsas',
            filter: CollectionFilter(
              collectionHandle: 'guess',
              category: 'bolsa',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('$bagCount piezas ordenadas por '), findsOneWidget);
    expect(bagCount, greaterThan(0));
  });
}
