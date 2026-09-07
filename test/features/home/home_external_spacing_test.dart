import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/home/external_catalog_section.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/main.dart';

void main() {
  testWidgets('home no longer mounts the retired external catalog section', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = CatalogStore(database: openTestDatabase());
    addTearDown(store.dispose);
    await store.loadFromAsset();

    await tester.pumpWidget(
      MaterialApp(
        home: StoreScope(
          notifier: store,
          child: const HomeScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const ValueKey('home-section-offers')), findsOneWidget);
    expect(find.byType(ExternalCatalogSection), findsNothing);
  });
}
