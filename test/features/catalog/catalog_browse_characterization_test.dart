// CHAR-11: what the full-catalog browser shows today, reached only through
// the UI. It deliberately names no catalog-item type and no money type, so it
// survives the removal of the external catalog without edits (see ARCH-03).
// The person kept this look (D-10): plain MXN price, no discount, no badge.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/shopper_copy.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/catalog/catalog_browse_screen.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/catalog/product_tile.dart';
import 'package:monetta_app/main.dart';

/// Independent oracle for the price line: whole amounts without decimals,
/// otherwise two decimals; `$` first, en_US thousands separators, ` MXN` last.
String _expectedPriceLabel(double amount) {
  final isWhole = amount == amount.roundToDouble();
  final fixed = amount.toStringAsFixed(isWhole ? 0 : 2);
  final parts = fixed.split('.');
  final grouped = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final decimals = parts.length > 1 ? '.${parts[1]}' : '';
  return '\$$grouped$decimals MXN';
}

String _expectedBrand(CatalogStore store, Product product) {
  final raw = store.facetsFor(product.id)?.brand?.value ?? product.vendor;
  // An empty brand falls back to the merchant name the browser shows.
  return humanizeCatalogValue(raw.trim().isEmpty ? 'Monetta' : raw);
}

Future<CatalogStore> _loadedStore() async {
  final store = CatalogStore(database: openTestDatabase());
  await store.loadFromAsset();
  return store;
}

Future<void> _openFullCatalog(WidgetTester tester, CatalogStore store) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: StoreScope(
        notifier: store,
        child: const CollectionScreen(title: 'Bolsas'),
      ),
    ),
  );
  await tester.pump();

  await tester.tap(find.byKey(const Key('bottom-nav-catalog')));
  await tester.pumpAndSettle();
  expect(find.byType(CatalogBrowseScreen), findsOneWidget);
}

Finder get _browseTiles => find.descendant(
      of: find.byType(CatalogBrowseScreen),
      matching: find.byType(MonettaProductTile),
    );

List<ProductTileData> _tileData(WidgetTester tester) => tester
    .widgetList<MonettaProductTile>(_browseTiles)
    .map((tile) => tile.data)
    .toList();

/// Products whose title and price line match [data]; tiles carry no id.
List<Product> _productsFor(
  CatalogStore store,
  ProductTileData data,
) =>
    store.products
        .where(
          (product) =>
              shopperProductName(product.title) == data.title &&
              _expectedPriceLabel(product.price) == data.priceLabel,
        )
        .toList();

void main() {
  testWidgets(
    'CHAR-11 full catalog browser tiles show the plain MXN price, no discount '
    'and no badge',
    (tester) async {
      final store = await _loadedStore();
      await _openFullCatalog(tester, store);

      void expectTilesMatchTheOracle() {
        final tiles = _tileData(tester);
        expect(tiles, isNotEmpty);
        for (final data in tiles) {
          final candidates = _productsFor(store, data);
          expect(
            candidates,
            isNotEmpty,
            reason: 'no product matches tile "${data.title}" '
                'at "${data.priceLabel}"',
          );
          expect(
            candidates.any((p) => _expectedBrand(store, p) == data.brand),
            isTrue,
            reason: 'brand "${data.brand}" of "${data.title}" does not match '
                'any matching product',
          );
          expect(data.badge, isNull, reason: data.title);
          expect(data.compareAtLabel, isNull, reason: data.title);
          expect(data.priceLabel, endsWith(' MXN'));
        }
      }

      expectTilesMatchTheOracle();

      // The first products of the asset are on sale, so the sale-priced piece
      // is on screen and must still show only its current price.
      final onSale = store.products.where((p) => p.isOnSale).toList();
      expect(onSale, isNotEmpty);
      final saleTiles = _tileData(tester).where(
        (data) => onSale.any(
          (p) =>
              shopperProductName(p.title) == data.title &&
              _expectedPriceLabel(p.price) == data.priceLabel,
        ),
      );
      expect(
        saleTiles,
        isNotEmpty,
        reason: 'a product with compareAtPrice > price must be visible',
      );
      for (final data in saleTiles) {
        expect(data.compareAtLabel, isNull);
        expect(data.badge, isNull);
      }

      // Scroll to a fractional price and to a piece that is not on sale: they
      // follow the same rules (two decimals, nothing struck through).
      final fractional = store.products.firstWhere(
        (p) => p.price != p.price.roundToDouble(),
      );
      final regular = store.products.firstWhere((p) => !p.isOnSale);
      // Visit them in catalog order: the grid only scrolls forward here.
      final targets = [fractional, regular]..sort(
          (a, b) =>
              store.products.indexOf(a).compareTo(store.products.indexOf(b)),
        );
      for (final product in targets) {
        final tile = find.byWidgetPredicate(
          (widget) =>
              widget is MonettaProductTile &&
              widget.data.title == shopperProductName(product.title) &&
              widget.data.priceLabel == _expectedPriceLabel(product.price),
        );
        await tester.scrollUntilVisible(
          tile,
          600,
          scrollable: find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
          maxScrolls: 100,
        );
        await tester.pumpAndSettle();
        expectTilesMatchTheOracle();
      }
      expect(
        _tileData(tester).any((data) => data.priceLabel.contains('.')),
        isTrue,
        reason: 'a fractional price must have been checked',
      );
    },
  );

  group('CHAR-11 category filter of the full catalog browser', () {
    // Panel label -> the category facet value the products carry.
    const categories = <String, ({String option, String label})>{
      'reloj': (option: 'reloj', label: 'Relojes'),
      'cartera': (option: 'cartera', label: 'Carteras'),
    };

    for (final entry in categories.entries) {
      final facetValue = entry.key;
      final option = entry.value.option;
      final label = entry.value.label;

      testWidgets('CHAR-11 filtering by "$label" leaves only that category', (
        tester,
      ) async {
        final store = await _loadedStore();
        await _openFullCatalog(tester, store);

        bool inCategory(Product product) =>
            store.facetsFor(product.id)?.category?.value == facetValue;

        // Before filtering, the grid also shows pieces of other categories.
        final before = _tileData(tester);
        expect(before, isNotEmpty);
        expect(
          before.any(
            (data) => _productsFor(store, data).every((p) => !inCategory(p)),
          ),
          isTrue,
          reason: 'the unfiltered grid must show another category too',
        );

        await tester.tap(find.byKey(const Key('catalog-filter-button')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('catalog-filter-section-category')),
        );
        await tester.pumpAndSettle();

        final optionFinder = find.byKey(Key('catalog-filter-category-$option'));
        expect(optionFinder, findsOneWidget);
        expect(
          find.descendant(of: optionFinder, matching: find.text(label)),
          findsOneWidget,
          reason: 'the panel labels the option "$label"',
        );
        await tester.ensureVisible(optionFinder);
        await tester.pumpAndSettle();
        await tester.tap(optionFinder);
        await tester.pumpAndSettle();

        final apply = find.byKey(const Key('catalog-filter-apply'));
        await tester.ensureVisible(apply);
        await tester.pumpAndSettle();
        await tester.tap(apply);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('catalog-filter-apply')), findsNothing);
        final after = _tileData(tester);
        expect(after, isNotEmpty);
        for (final data in after) {
          final candidates = _productsFor(store, data);
          expect(candidates, isNotEmpty, reason: data.title);
          expect(
            candidates.every(inCategory),
            isTrue,
            reason: '"${data.title}" is not in category $facetValue',
          );
        }
      });
    }
  });
}
