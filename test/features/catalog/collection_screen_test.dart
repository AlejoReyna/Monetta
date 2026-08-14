import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/main.dart';

Future<CatalogStore> _loadedStore() async {
  final store = CatalogStore(database: openTestDatabase());
  await store.loadFromAsset();
  return store;
}

void main() {
  testWidgets('collection filters actually reduce the grid', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: StoreScope(
          notifier: store,
          child: const CollectionScreen(
            title: 'Bolsas',
            filter: CollectionFilter(category: 'bolsa'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Bolsas'), findsOneWidget);
    expect(find.text('TODO'), findsOneWidget);
    expect(find.text('extracted'), findsNothing);
    expect(find.text('También en marcas de Estados Unidos'), findsNothing);

    await tester.tap(find.text('TODO'));
    await tester.pump();
    expect(find.text('EN STOCK'), findsOneWidget);
  });
}
