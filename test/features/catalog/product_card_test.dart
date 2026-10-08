import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/normalize/facets.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/catalog/product_card.dart';
import 'package:monetta_app/features/catalog/product_tile.dart';
import 'package:monetta_app/main.dart';

Product _product({
  String id = 'gid://shopify/Product/1',
  String title = 'Bolsa Tabby',
  double price = 6490,
  double? compareAt,
  bool available = true,
}) =>
    Product(
      id: id,
      handle: 'bolsa-tabby',
      title: title,
      vendor: 'Monetta ',
      productType: '',
      tags: const [],
      variants: [
        ProductVariant(
          id: '$id/v1',
          title: 'Default Title',
          price: price,
          available: available,
          compareAtPrice: compareAt,
        ),
      ],
      images: const [],
      createdAt: DateTime.utc(2026, 8, 1),
      updatedAt: DateTime.utc(2026, 8, 1),
    );

CanonicalFacets _facets({bool newArrival = false}) => CanonicalFacets(
      productId: 'gid://shopify/Product/1',
      brand: const FacetValue('coach', FacetSource.tag),
      category: const FacetValue('bolsa', FacetSource.tag),
      priceBand: 'alto',
      onSale: false,
      inStock: true,
      newArrival: newArrival,
    );

Widget _host(Widget child) => MaterialApp(
      theme: buildTheme(),
      home: Scaffold(body: SizedBox(width: 200, child: child)),
    );

void main() {
  group('ProductTileData', () {
    test('shows a real discount and never invents one', () {
      final onSale = ProductTileData.fromProduct(
        _product(price: 4900, compareAt: 6490),
        facets: _facets(),
      );
      expect(onSale.compareAtLabel, isNotNull);
      expect(onSale.badge?.label, '-24%');
      expect(onSale.badge?.tone, ProductBadgeTone.sale);

      final plain = ProductTileData.fromProduct(
        _product(),
        facets: _facets(),
      );
      expect(plain.compareAtLabel, isNull);
      expect(plain.badge, isNull);
    });

    test('the NUEVO badge comes from the rules window, not from a guess', () {
      final fresh = ProductTileData.fromProduct(
        _product(),
        facets: _facets(newArrival: true),
      );
      expect(fresh.badge?.label, 'NUEVO');
      expect(fresh.badge?.tone, ProductBadgeTone.fresh);

      final suppressed = ProductTileData.fromProduct(
        _product(),
        facets: _facets(newArrival: true),
        allowNewBadge: false,
      );
      expect(suppressed.badge, isNull);
    });

    test('a discount wins over the new-arrival badge', () {
      final data = ProductTileData.fromProduct(
        _product(price: 4900, compareAt: 6490),
        facets: _facets(newArrival: true),
      );
      expect(data.badge?.tone, ProductBadgeTone.sale);
    });

    test('unresolved brand drops the line instead of printing a placeholder',
        () {
      final data = ProductTileData.fromProduct(_product());
      expect(data.brand, isNull);
      expect(data.fallbackLabel, 'Bolsa Tabby');
    });

    test('the catalog browser keeps the plain MXN price, with no discount', () {
      final data = ProductTileData.forCatalogBrowse(
        _product(price: 4900, compareAt: 6490),
        facets: _facets(newArrival: true),
      );
      expect(data.priceLabel, r'$4,900 MXN');
      expect(data.compareAtLabel, isNull);
      expect(data.badge, isNull);
      expect(data.brand, 'Coach');
      expect(data.inStock, isTrue);
    });
  });

  group('grid', () {
    test('columns grow with width and drop rather than squeeze', () {
      expect(productGridColumns(320), 1);
      expect(productGridColumns(390), 2);
      expect(productGridColumns(760), 3);
      expect(productGridColumns(1200), 4);
    });
  });

  testWidgets('a sold-out piece is marked and still opens', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      _host(
        MonettaProductTile(
          data: ProductTileData.fromProduct(
            _product(available: false),
            facets: _facets(),
          ),
          onTap: () => opened++,
        ),
      ),
    );

    expect(find.text('AGOTADO'), findsOneWidget);
    await tester.tap(find.text('Bolsa Tabby'));
    expect(opened, 1);
  });

  testWidgets('a long name is clamped instead of overflowing', (tester) async {
    await tester.pumpWidget(
      _host(
        MonettaProductTile(
          data: ProductTileData.fromProduct(
            _product(
              title: 'Bolsa Tabby Shoulder Bag 26 en piel grabada con herraje '
                  'dorado y correa larga desmontable',
            ),
            facets: _facets(),
          ),
          onTap: () {},
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('no wishlist control is drawn when the surface has none',
      (tester) async {
    await tester.pumpWidget(
      _host(
        MonettaProductTile(
          data: ProductTileData.fromProduct(_product(), facets: _facets()),
          onTap: () {},
        ),
      ),
    );
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect(find.byIcon(Icons.favorite), findsNothing);
  });

  testWidgets('tapping the favourite saves it and does not open the piece',
      (tester) async {
    final store = CatalogStore(database: openTestDatabase());
    addTearDown(store.dispose);
    await store.loadFromAsset();
    final product = store.products.first;

    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: StoreScope(
          notifier: store,
          child: Scaffold(
            body: SizedBox(
              width: 200,
              child: ProductCard(
                product: product,
                onTap: () => opened++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();

    expect(opened, 0, reason: 'the heart must not open the product page');
    expect(store.wishlist, contains(product.id));
  });

  testWidgets('showWishlist: false removes the control entirely',
      (tester) async {
    final store = CatalogStore(database: openTestDatabase());
    addTearDown(store.dispose);
    await store.loadFromAsset();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: StoreScope(
          notifier: store,
          child: Scaffold(
            body: SizedBox(
              width: 200,
              child: ProductCard(
                product: store.products.first,
                showWishlist: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });

  testWidgets('the compact density keeps the same anatomy in a rail',
      (tester) async {
    final store = CatalogStore(database: openTestDatabase());
    addTearDown(store.dispose);
    await store.loadFromAsset();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: StoreScope(
          notifier: store,
          child: Scaffold(
            body: SizedBox(
              height: 320,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final product in store.products.take(3))
                    SizedBox(
                      width: 170,
                      child: ProductCard(
                        product: product,
                        density: ProductTileDensity.compact,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(ProductCard), findsNWidgets(3));
  });

  testWidgets('a quick-view callback is a long press, never a dead button',
      (tester) async {
    var quickViews = 0;
    var opened = 0;
    await tester.pumpWidget(
      _host(
        MonettaProductTile(
          data: ProductTileData.fromProduct(_product(), facets: _facets()),
          onTap: () => opened++,
          onQuickView: () => quickViews++,
        ),
      ),
    );

    await tester.longPress(find.text('Bolsa Tabby'));
    await tester.pumpAndSettle();
    expect(quickViews, 1);
    expect(opened, 0);
  });
}
