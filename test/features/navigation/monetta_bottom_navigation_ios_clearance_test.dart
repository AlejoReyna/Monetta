import '../../support/bundled_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/domain/catalog_item.dart';
import 'package:monetta_app/features/catalog/catalog_browse_screen.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/catalog/product_card.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/main.dart';

// NAV-GLASS-10: on iOS the bottom bar floats as a capsule; scrolled content
// must still end above it on every screen that hosts the bar. The Scaffold
// body stops at the top of the bar slot (capsule plus its margins), and Home,
// which extends behind it, clears the whole slot.

const _viewHeight = 844.0;
const _bottomInset = 34.0;

final _glass = find.byKey(const Key('bottom-nav-glass'));

void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, _viewHeight);
  tester.view.padding = const FakeViewPadding(bottom: _bottomInset);
  tester.view.viewPadding = const FakeViewPadding(bottom: _bottomInset);
  addTearDown(tester.view.reset);
}

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

Future<CatalogStore> _loadedStore() async {
  final store = CatalogStore(database: openTestDatabase());
  await store.loadFromAsset();
  return store;
}

Finder _verticalScrollable() => find
    .byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    )
    .first;

/// Scrolls to the very end; the grids are lazy, so the extent is re-read
/// until it stops moving.
Future<void> _scrollToEnd(WidgetTester tester) async {
  final scrollable = _verticalScrollable();
  for (var i = 0; i < 12; i++) {
    final position = tester.state<ScrollableState>(scrollable).position;
    final before = position.maxScrollExtent;
    position.jumpTo(before);
    await tester.pumpAndSettle();
    if (tester.state<ScrollableState>(scrollable).position.maxScrollExtent ==
        before) {
      break;
    }
  }
}

double _lowestBottom(WidgetTester tester, Finder finder) {
  var lowest = double.negativeInfinity;
  for (var i = 0; i < finder.evaluate().length; i++) {
    final bottom = tester.getRect(finder.at(i)).bottom;
    if (bottom > lowest) lowest = bottom;
  }
  return lowest;
}

void main() {
  setUpAll(loadBundledFonts);
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

  testWidgets(
    'NAV-GLASS-10 catalog: the last tile ends above the capsule',
    (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: CatalogBrowseScreen(
            items: [for (var i = 1; i <= 30; i++) _item(i)],
          ),
        ),
      );
      await tester.pump();
      await _scrollToEnd(tester);

      expect(_glass, findsOneWidget);
      final capsuleTop = tester.getRect(_glass).top;
      final tiles = find.byType(MonettaProductTile);
      expect(tiles, findsWidgets);
      expect(_lowestBottom(tester, tiles), lessThanOrEqualTo(capsuleTop));
      expect(
        tester.getRect(find.text('Monetta Item 30')).bottom,
        lessThanOrEqualTo(capsuleTop),
      );
    },
    variant: ios,
  );

  testWidgets(
    'NAV-GLASS-10 collection: the last card ends above the capsule',
    (tester) async {
      _phone(tester);
      final store = await _loadedStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
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
      await _scrollToEnd(tester);

      expect(_glass, findsOneWidget);
      final cards = find.byType(ProductCard);
      expect(cards, findsWidgets);
      expect(
        _lowestBottom(tester, cards),
        lessThanOrEqualTo(tester.getRect(_glass).top),
      );
    },
    variant: ios,
  );

  testWidgets(
    'NAV-GLASS-10 home: the trailing clearance spans the whole bar slot',
    (tester) async {
      _phone(tester);
      final store = await _loadedStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: StoreScope(notifier: store, child: const HomeScreen()),
        ),
      );
      await tester.pump();
      final bleed =
          find.byKey(const ValueKey('home-account-invitation-bottom-bleed'));
      await tester.scrollUntilVisible(
        bleed,
        800,
        scrollable: _verticalScrollable(),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(_glass, findsOneWidget);
      final capsule = tester.getRect(_glass);
      final clearance = tester.getRect(bleed);
      // Slot = 6 pt above the capsule plus the capsule plus the home
      // indicator inset below it; everything above it is real content.
      expect(clearance.top, lessThanOrEqualTo(capsule.top));
      expect(clearance.bottom, _viewHeight);
      expect(clearance.height, greaterThanOrEqualTo(_viewHeight - capsule.top));
    },
    variant: ios,
  );
}
