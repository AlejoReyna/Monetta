import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/monetta_tokens.g.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/domain/catalog_item.dart';
import 'package:monetta_app/features/boutique/boutique_tokens.dart';
import 'package:monetta_app/features/boutique/guide_art.dart';
import 'package:monetta_app/features/catalog/catalog_browse_screen.dart';
import 'package:monetta_app/features/catalog/catalog_controls.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/catalog/product_tile.dart';
import 'package:monetta_app/features/home/home_account_invitation.dart';
import 'package:monetta_app/main.dart';

// The client guide sets screen and banner titles in the editorial serif.
// Filter panels and compact bar titles retain the sans; the product card
// caption is serif since the card redesign.
// Editorial surfaces (Home, welcome, account...) must stay serif.
//
// These tests read the style handed to each `Text`, so the Ahem test font is
// irrelevant to them.

CatalogItem _item(int i) => CatalogItem(
      sourceScopedId: 'monetta:$i',
      source: CatalogSourceType.monettaShopify,
      merchant: 'Monetta',
      title: 'Monetta Item $i',
      brand: 'Guess',
      category: null,
      imageUrl: null,
      price: Money(amount: 1000.0 + i, currency: Currency.mxn),
      availability: CatalogAvailability.inStock,
      detailUrl: 'https://monetta.mx/products/item-$i',
      marketRestriction: MarketRestriction.mexico,
      lastObservedAt: DateTime.utc(2026, 8, 10),
      purchaseMode: PurchaseMode.monettaCheckout,
      shopifyProductId: '$i',
    );

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
TextStyle _cardNameStyle(WidgetTester tester, CatalogItem item) {
  final name = ProductTileData.fromCatalogItem(item).title;
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

Future<void> _openCatalogPanel(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('catalog-filter-button')));
  await tester.pumpAndSettle();
}

void main() {
  group('TYPE-01 catalog titles follow the client guide', () {
    testWidgets('TYPE-01 "Productos" is serif w400, 26', (tester) async {
      _view(tester);
      final items = [_item(1), _item(2), _item(3)];
      await tester.pumpWidget(_app(CatalogBrowseScreen(items: items)));
      await tester.pump();

      final title = _styleOf(tester, find.text('Productos'));
      _expectSerif(title, reason: 'Productos');
      expect(title.fontSize, MonettaTokens.screenTitle.compact);
      // The card's own caption is set in the serif since the card redesign.
      expect(
        _cardNameStyle(tester, items.first).fontFamily,
        kBoutiqueSerifFamily,
      );
    });

    testWidgets('TYPE-01b "Sin resultados" of the empty catalog is serif w400',
        (tester) async {
      _view(tester);
      await tester.pumpWidget(_app(const CatalogBrowseScreen(items: [])));
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
      await tester.pumpWidget(_app(CatalogBrowseScreen(items: items)));
      await tester.pump();
      await _openCatalogPanel(tester);

      final title = _styleOf(tester, find.text('Filtrar y ordenar'));
      _expectSans(title, reason: 'catalog panel title');
      // Panel chrome stays sans while the card caption is serif.
      expect(
        _cardNameStyle(tester, items.first).fontFamily,
        isNot(title.fontFamily),
      );
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

  group('TYPE-01c collection titles follow the client guide', () {
    Future<CatalogStore> pump(
      WidgetTester tester, {
      String? heroImageAsset,
    }) async {
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
              heroImageAsset: heroImageAsset,
            ),
          ),
        ),
      );
      await tester.pump();
      return store;
    }

    // «Bolsas» is also the label of a category pill under the banner; the
    // title is the one inside the banner.
    Iterable<TextStyle> stylesOfTitle(WidgetTester tester) => tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(CatalogEditorialBanner),
            matching: find.text('Bolsas'),
          ),
        )
        .map((text) => text.style!)
        .toList();

    testWidgets('TYPE-01c typographic banner title is serif w400, 26',
        (tester) async {
      // A bag collection now resolves to a guide photograph; the studio still
      // is passed explicitly to keep exercising the plain banner title.
      await pump(tester, heroImageAsset: kGuideStudioBanner);

      final title = _styleOf(
        tester,
        find.descendant(
          of: find.byType(CatalogEditorialBanner),
          matching: find.text('Bolsas'),
        ),
      );
      _expectSerif(title, reason: 'banner title');
      expect(title.fontSize, MonettaTokens.screenTitle.compact);
    });

    testWidgets('TYPE-01c photo banner title is serif w400, 26',
        (tester) async {
      await pump(tester, heroImageAsset: 'assets/images/campaign_olive.jpg');

      final title = _styleOf(
        tester,
        find.descendant(
          of: find.byType(CatalogEditorialBanner),
          matching: find.text('Bolsas'),
        ),
      );
      _expectSerif(title, reason: 'photo banner title');
      expect(title.fontSize, MonettaTokens.screenTitle.compact);
    });

    testWidgets(
        'TYPE-01c the bar keeps the wordmark and the banner title stays serif',
        (tester) async {
      await pump(tester, heroImageAsset: kGuideStudioBanner);
      expect(
        find.descendant(
          of: find.byType(SliverAppBar),
          matching: find.byType(MonettaWordmark),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(SliverAppBar),
          matching: find.text('Bolsas'),
        ),
        findsNothing,
      );
      final title = _styleOf(
        tester,
        find.descendant(
          of: find.byType(CatalogEditorialBanner),
          matching: find.text('Bolsas'),
        ),
      );
      _expectSerif(title, reason: 'banner title');
      expect(title.fontSize, MonettaTokens.screenTitle.compact);
      expect(stylesOfTitle(tester), hasLength(1));

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(SliverAppBar),
          matching: find.text('Bolsas'),
        ),
        findsNothing,
        reason: 'the guide bar keeps the wordmark after the banner scrolls',
      );
    });

    testWidgets('TYPE-01c a photo banner keeps its serif title out of the bar',
        (tester) async {
      await pump(tester, heroImageAsset: 'assets/images/campaign_olive.jpg');

      final titles = stylesOfTitle(tester).toList();
      expect(titles, hasLength(1));
      _expectSerif(titles.single, reason: 'photo banner');
      expect(titles.single.fontSize, MonettaTokens.screenTitle.compact);
      expect(
        find.descendant(
          of: find.byType(SliverAppBar),
          matching: find.text('Bolsas'),
        ),
        findsNothing,
        reason: 'the collection name stays in the photograph',
      );

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(SliverAppBar),
          matching: find.text('Bolsas'),
        ),
        findsNothing,
        reason: 'scrolling does not move the name into the wordmark bar',
      );
    });
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

      final style = _styleOf(tester, find.text('REGÍSTRATE'));
      expect(style.fontFamily, kBoutiqueSerifFamily);
      expect(style.fontFamilyFallback, kBoutiqueSerifFallback);
    });
  });
}
