import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/boutique/boutique_tokens.dart';
import 'package:monetta_app/features/catalog/brand_screen.dart';
import 'package:monetta_app/features/catalog/search_history.dart';
import 'package:monetta_app/features/catalog/search_screen.dart';
import 'package:monetta_app/main.dart';

// TYPE-01d: the product-related titles of the brand and search screens share
// the family and fallback chain of the card names (`boutiqueText`).

Future<CatalogStore> _loadedStore() async {
  final store = CatalogStore(database: openTestDatabase());
  await store.loadFromAsset();
  return store;
}

void _view(WidgetTester tester) {
  addTearDown(tester.view.reset);
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 1600);
}

TextStyle _styleOf(WidgetTester tester, Finder finder) {
  expect(finder, findsOneWidget);
  final style = tester.widget<Text>(finder).style;
  expect(style, isNotNull);
  return style!;
}

void _expectSerif(TextStyle style, {required String reason}) {
  expect(style.fontFamily, kBoutiqueSerifFamily, reason: '$reason: family');
  expect(
    style.fontFamilyFallback,
    kBoutiqueSerifFallback,
    reason: '$reason: fallback chain',
  );
  expect(style.fontWeight, FontWeight.w400, reason: '$reason: weight');
}

void main() {
  testWidgets('TYPE-01d the brand story heading is serif w400', (tester) async {
    _view(tester);
    final store = await _loadedStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: StoreScope(
          notifier: store,
          child: BrandScreen(
            brandSlug: store.availableBrands.first,
            story: 'Texto de la dueña.',
          ),
        ),
      ),
    );
    await tester.pump();

    final heading = find.text('Sobre la marca');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('brand-story')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final style = _styleOf(tester, heading);
    _expectSerif(style, reason: 'Sobre la marca');
    expect(style.fontSize, kBoutiqueSectionHeadingSize);
  });

  testWidgets('TYPE-01d the search section titles are serif w400',
      (tester) async {
    _view(tester);
    final store = await _loadedStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: StoreScope(
          notifier: store,
          child: SearchScreen(history: SearchHistory()),
        ),
      ),
    );
    await tester.pump();

    final style = _styleOf(tester, find.text('Sugerencias'));
    _expectSerif(style, reason: 'Sugerencias');
    expect(style.fontSize, kBoutiqueSectionHeadingSize);
  });

  testWidgets('TYPE-01d the search results title is serif w400',
      (tester) async {
    _view(tester);
    final store = await _loadedStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: StoreScope(
          notifier: store,
          child: SearchScreen(
            initialQuery: 'bolsa',
            history: SearchHistory(),
          ),
        ),
      ),
    );
    await tester.pump();

    final style = _styleOf(tester, find.text('“bolsa”'));
    _expectSerif(style, reason: 'results title');
    expect(style.fontSize, 22);
  });
}
