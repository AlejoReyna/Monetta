import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/catalog/search_screen.dart';
import 'package:monetta_app/main.dart';

Future<CatalogStore> _loadedStore() async {
  final store = CatalogStore(database: openTestDatabase());
  await store.loadFromAsset();
  return store;
}

Widget _app(CatalogStore store) => MaterialApp(
      theme: buildTheme(),
      home: StoreScope(
        notifier: store,
        child: const SearchScreen(prompt: 'Encuentra algo muy tú'),
      ),
    );

void main() {
  test('search invitations have five distinct prompts', () {
    expect(kSearchPrompts, hasLength(5));
    expect(kSearchPrompts.toSet(), hasLength(5));
  });

  testWidgets(
      'search stays quiet until typing, then offers catalog suggestions',
      (tester) async {
    final store = await _loadedStore();
    await tester.pumpWidget(_app(store));
    await tester.pump();

    expect(find.byKey(const ValueKey('search-query-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-empty-state')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-suggestions')), findsNothing);
    expect(find.byKey(const ValueKey('search-result-grid')), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('search-query-field')),
      'steve',
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('search-suggestions')), findsOneWidget);
    expect(find.text('Steve Madden', findRichText: true), findsOneWidget);
    expect(find.byKey(const ValueKey('search-result-grid')), findsNothing);

    await tester.tap(
      find
          .descendant(
            of: find.byKey(const ValueKey('search-suggestions')),
            matching: find.byType(InkWell),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('search-result-grid')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('search-clear-button')));
    await tester.pump();

    expect(find.byKey(const ValueKey('search-empty-state')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-suggestions')), findsNothing);
    expect(find.byKey(const ValueKey('search-result-grid')), findsNothing);
  });
}
