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
  testWidgets('collection states a count and sort, and filters reduce the grid',
      (tester) async {
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
    expect(find.textContaining('piezas ordenadas por'), findsOneWidget);
    expect(find.text('Más nuevas'), findsOneWidget);
    expect(find.text('extracted'), findsNothing);
    expect(find.text('También en marcas de Estados Unidos'), findsNothing);

    final silhouettePills = find.byWidgetPredicate(
      (widget) =>
          widget is ChoiceChip &&
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>)
              .value
              .startsWith('collection-silhouette-'),
    );
    expect(silhouettePills, findsWidgets);

    final firstPill = silhouettePills.first;
    expect(tester.widget<ChoiceChip>(firstPill).selected, isFalse);
    await tester.tap(firstPill);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(firstPill).selected, isTrue);
    expect(
      tester
          .widget<ChoiceChip>(firstPill)
          .color
          ?.resolve(const <WidgetState>{WidgetState.selected}),
      MonettaColors.light.navigationSelection,
    );
    await tester.tap(firstPill);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Más nuevas'));
    await tester.pumpAndSettle();
    expect(find.text('EN STOCK'), findsOneWidget);

    await tester.tap(find.text('EN STOCK'));
    await tester.pump();
    expect(find.text('En stock  ×'), findsOneWidget);
  });
}
