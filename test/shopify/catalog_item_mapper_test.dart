import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/normalize/facets.dart';
import 'package:monetta_app/data/shopify/catalog_item_mapper.dart';
import 'package:monetta_app/domain/catalog_item.dart';
import 'package:monetta_app/domain/product.dart';

Product _product({required bool inStock}) {
  return Product(
    id: 'gid://shopify/Product/1',
    handle: 'tabby-bag',
    title: 'Tabby Bag',
    vendor:
        'Monetta ', // the unreliable raw field — mapper must not use it when facets exist
    productType: 'Bolsa',
    tags: const ['coach'],
    variants: [
      ProductVariant(
        id: 'v1',
        title: 'Default Title',
        price: 1999,
        available: inStock,
      ),
    ],
    images: const ['https://cdn.shopify.com/img.jpg'],
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 8, 1),
  );
}

void main() {
  group('catalogItemFromShopifyProduct', () {
    test('maps into a monettaCheckout, MXN CatalogItem scoped by "monetta:"',
        () {
      final item = catalogItemFromShopifyProduct(_product(inStock: true));

      expect(item.sourceScopedId, 'monetta:gid://shopify/Product/1');
      expect(item.source, CatalogSourceType.monettaShopify);
      expect(item.purchaseMode, PurchaseMode.monettaCheckout);
      expect(item.marketRestriction, MarketRestriction.mexico);
      expect(item.price, isNotNull); // Monetta items always have a price
      expect(item.price!.currency, Currency.mxn);
      expect(item.price!.amount, 1999);
      expect(item.availability, CatalogAvailability.inStock);
      expect(item.shopifyProductId, 'gid://shopify/Product/1');
      expect(item.imageUrl, 'https://cdn.shopify.com/img.jpg');
    });

    test(
        'prefers normalized facets brand/category over the raw, unreliable vendor field',
        () {
      const facets = CanonicalFacets(
        productId: 'gid://shopify/Product/1',
        brand: FacetValue('Coach', FacetSource.tag),
        category: FacetValue('Bolsas', FacetSource.productType),
        priceBand: 'alto',
        onSale: false,
        inStock: true,
        newArrival: false,
      );
      final item = catalogItemFromShopifyProduct(
        _product(inStock: true),
        facets: facets,
      );

      expect(item.brand, 'Coach'); // not "Monetta " (the raw vendor)
      expect(item.category, 'Bolsas');
      expect(item.vertical, CatalogVertical.bagsWallets);
    });

    test('maps perfume facets into the perfumes vertical', () {
      const facets = CanonicalFacets(
        productId: 'gid://shopify/Product/1',
        category: FacetValue('perfume', FacetSource.metafieldOverride),
        priceBand: 'alto',
        onSale: false,
        inStock: true,
        newArrival: false,
      );

      final item = catalogItemFromShopifyProduct(
        _product(inStock: true),
        facets: facets,
      );

      expect(item.vertical, CatalogVertical.perfumes);
    });

    test('falls back to raw vendor only when no facets are supplied', () {
      final item = catalogItemFromShopifyProduct(_product(inStock: true));
      expect(item.brand, 'Monetta ');
      expect(item.vertical, CatalogVertical.general);
    });

    test('maps out-of-stock variants to outOfStock availability', () {
      final item = catalogItemFromShopifyProduct(_product(inStock: false));
      expect(item.availability, CatalogAvailability.outOfStock);
    });
  });
}
