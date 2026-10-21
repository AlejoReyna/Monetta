import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/boutique/boutique_tokens.dart';
import 'package:monetta_app/features/catalog/catalog_controls.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/catalog/product_tile.dart';
import 'package:monetta_app/features/home/home_account_invitation.dart';
import 'package:monetta_app/main.dart';

import '../../support/catalog_browse_fixtures.dart';

// Product-related titles share the family and fallback chain of the card
// names (`boutiqueText`): Inter + the platform sans (FICHA-T1, BRIEF 2.3).
// Editorial surfaces (Home, welcome, account...) must stay serif.
//
// These tests read the style handed to each `Text`, so the Ahem test font is
// irrelevant to them.

BrowseEntry _item(int i) => browseEntry(i, price: 1000.0 + i);

void _view(WidgetTester tester, {double height = 1600}) {
  addTearDown(tester.view.reset);
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(390, height);
}

Widget _app(Widget home) => MaterialApp(theme: buildLightTheme(), home: home);

Future<CatalogStore> _loadedStore() async {
  final store = CatalogStore(database: openTestDatabase());
  await store.loadFromAsset();
  return store;
}

TextStyle _styleOf(WidgetTester tester, Finder finder) {
  expect(finder, findsOneWidget);
  final style = tester.widget<Text>(finder).style;
  expect(style, isNotNull, reason: 'the text carries an explicit style');
  return style!;
}

/// The style the first card of the screen gives to its product name.
TextStyle _cardNameStyle(WidgetTester tester, BrowseEntry item) {
  final name = item.tileData.title;
  return _styleOf(
    tester,
    find.descendant(
      of: find.byType(MonettaProductTile).first,
      matching: find.text(name),
    ),
  );
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

void _expectSans(TextStyle style, {required String reason}) {
  expect(style.fontFamily, kBoutiqueSansFamily, reason: '$reason: family');
  expect(
    style.fontFamilyFallback,
    kBoutiqueSansFallback,
    reason: '$reason: fallback chain',
  );
  expect(style.fontWeight, FontWeight.w600, reason: '$reason: weight');
}

void _expectSameFace(TextStyle style, TextStyle reference, String reason) {
  expect(style.fontFamily, reference.fontFamily, reason: '$reason: family');
  expect(
    style.fontFamilyFallback,
    reference.fontFamilyFallback,
    reason: '$reason: fallback chain',
  );
}

Future<void> _openCatalogPanel(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('catalog-filter-button')));
  await tester.pumpAndSettle();
}

void main() {
  group('TYPE-01 page titles use the editorial face of the bag', () {
    testWidgets(
        'TYPE-01 Productos uses the bag title face beside the back arrow',
        (tester) async {
      _view(tester);
      final items = [_item(1), _item(2), _item(3)];
      await tester.pumpWidget(_app(browseScreen(items)));
      await tester.pump();

      final title = _styleOf(tester, find.text('Productos'));
      expect(title.fontFamily, kBoutiqueSerifFamily);
      expect(title.fontWeight, FontWeight.w400);
      expect(title.fontSize, 28);
    });

    testWidgets('TYPE-01b "Sin resultados" of the empty catalog is serif w400',
        (tester) async {
      _view(tester);
      await tester.pumpWidget(_app(browseScreen(const [])));
      await tester.pump();

      _expectSerif(
        _styleOf(tester, find.text('Sin resultados')),
        reason: 'catalog empty state',
      );
    });

    testWidgets('TYPE-01b "Sin resultados" of CatalogEmptyState is serif w400',
        (tester) async {
      _view(tester);
      await tester.pumpWidget(
        _app(
          const Scaffold(
            body: CatalogEmptyState(title: 'Sin resultados', body: 'Nada.'),
          ),
        ),
      );
      await tester.pump();

      _expectSerif(
        _styleOf(tester, find.text('Sin resultados')),
        reason: 'CatalogEmptyState',
      );
    });

    testWidgets('TYPE-01b the catalog panel title is sans w600',
        (tester) async {
      _view(tester);
      final items = [_item(1), _item(2), _item(3)];
      await tester.pumpWidget(_app(browseScreen(items)));
      await tester.pump();
      await _openCatalogPanel(tester);

      final title = _styleOf(tester, find.text('Filtrar y ordenar'));
      _expectSans(title, reason: 'catalog panel title');
      _expectSameFace(title, _cardNameStyle(tester, items.first), 'vs card');
    });

    testWidgets('TYPE-01b the collection panel title is sans w600',
        (tester) async {
      _view(tester);
      final store = await _loadedStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(
        _app(
          StoreScope(
            notifier: store,
            child: const CollectionScreen(
              title: 'Bolsas',
              filter: CollectionFilter(category: 'bolsa'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('collection-filter-button')));
      await tester.pumpAndSettle();

      _expectSans(
        _styleOf(tester, find.text('Filtrar y ordenar')),
        reason: 'collection panel title',
      );
    });
  });

  group('TYPE-01c collections share the bag heading', () {
    for (final image in <String?>[null, 'assets/images/campaign_olive.jpg']) {
      testWidgets('collection heading remains beside back with artwork $image',
          (tester) async {
        _view(tester, height: 844);
        final store = await _loadedStore();
        addTearDown(store.dispose);
        await tester.pumpWidget(
          _app(
            StoreScope(
              notifier: store,
              child: CollectionScreen(
                title: 'Bolsas',
                filter: const CollectionFilter(category: 'bolsa'),
                heroImageAsset: image,
              ),
            ),
          ),
        );
        await tester.pump();
        final title = find.byKey(const ValueKey('monetta-page-title'));
        final back = find.byKey(const ValueKey('monetta-page-back'));
        final style = _styleOf(tester, title);
        expect(style.fontFamily, kBoutiqueSerifFamily);
        expect(style.fontSize, 28);
        expect(
          tester.getRect(title).left,
          closeTo(tester.getRect(back).right, .01),
        );
        final before = tester.getRect(title);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(tester.getRect(title), before);
      });
    }
  });

  group('TYPE-02 editorial surfaces stay serif (vigente)', () {
    test('TYPE-02 boutiqueDisplay is the serif chain', () {
      final style = boutiqueDisplay(24);
      expect(style.fontFamily, kBoutiqueSerifFamily);
      expect(style.fontFamilyFallback, kBoutiqueSerifFallback);
    });

    test('TYPE-02 editorial() keeps the New York chain', () {
      expect(editorial(24).fontFamily, kEditorialFontFamily);
      expect(editorial(24).fontFamily, isNot(kBoutiqueSansFamily));
    });

    testWidgets('TYPE-02 the Home account invitation title is still serif',
        (tester) async {
      _view(tester);
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: SingleChildScrollView(
              child: HomeAccountInvitation(onRegister: () {}),
            ),
          ),
        ),
      );
      await tester.pump();

      final style = _styleOf(tester, find.text('OBTEN TU PRIMER ENVÍO GRATIS'));
      expect(style.fontFamily, kBoutiqueSerifFamily);
      expect(style.fontFamilyFallback, kBoutiqueSerifFallback);
    });
  });
}
