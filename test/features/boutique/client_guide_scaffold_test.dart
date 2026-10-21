import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/boutique/client_guide_scaffold.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/catalog/search_screen.dart';
import 'package:monetta_app/features/checkout/checkout_screen.dart';
import 'package:monetta_app/main.dart';

void main() {
  testWidgets('guide shortcuts open existing catalog, search and bag routes',
      (tester) async {
    final db = openTestDatabase();
    final store = CatalogStore(database: db);
    addTearDown(() async {
      store.dispose();
      await db.close();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: StoreScope(
          notifier: store,
          child: const ClientGuideScaffold(
            current: ClientGuideDestination.account,
            body: SizedBox(),
          ),
        ),
      ),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await tester.tap(find.byKey(const ValueKey('guide-nav-categories')));
    await tester.pumpAndSettle();
    expect(find.byType(CollectionScreen), findsOneWidget);
    navigator.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('guide-search-button')));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
    navigator.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('guide-nav-bag')));
    await tester.pumpAndSettle();
    expect(find.byType(BagScreen), findsOneWidget);
    expect(find.text('Tu bolsa está vacía'), findsOneWidget);
  });

  testWidgets('drawer home exits the guide route to the existing root',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Fixture home'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ClientGuideScaffold(
                    current: ClientGuideDestination.account,
                    body: SizedBox(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Fixture home'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('guide-menu-home')));
    await tester.pumpAndSettle();
    expect(find.byType(ClientGuideScaffold), findsNothing);
    expect(find.text('Fixture home'), findsOneWidget);
  });
}
