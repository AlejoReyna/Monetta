import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/normalize/facets.dart';
import 'package:monetta_app/data/normalize/normalizer.dart';
import 'package:monetta_app/data/normalize/rules.dart';
import 'package:monetta_app/data/shopify/catalog_item_mapper.dart';
import 'package:monetta_app/domain/catalog_item.dart';
import 'package:monetta_app/domain/product.dart';

Product _product({required bool inStock, String productType = 'Bolsa'}) {
  return Product(
    id: 'gid://shopify/Product/1',
    handle: 'test-product',
    title: 'Test Product',
    vendor: 'Monetta ',
    productType: productType,
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
    test('maps into a monettaCheckout, MXN CatalogItem scoped by "monetta:"', () {
      final item = catalogItemFromShopifyProduct(_product(inStock: true));

      expect(item.sourceScopedId, 'monetta:gid://shopify/Product/1');
      expect(item.source, CatalogSourceType.monettaShopify);
      expect(item.purchaseMode, PurchaseMode.monettaCheckout);
      expect(item.marketRestriction, MarketRestriction.mexico);
      expect(item.price, isNotNull);
      expect(item.price!.currency, Currency.mxn);
      expect(item.price!.amount, 1999);
      expect(item.availability, CatalogAvailability.inStock);
      expect(item.shopifyProductId, 'gid://shopify/Product/1');
      expect(item.imageUrl, 'https://cdn.shopify.com/img.jpg');
    });

    test('prefers normalized facets brand/category over the raw, unreliable vendor field', () {
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

      expect(item.brand, 'Coach');
      expect(item.category, 'Bolsas');
      expect(item.vertical, CatalogVertical.bagsWallets);
    });

    test('maps out-of-stock variants to outOfStock availability', () {
      final item = catalogItemFromShopifyProduct(_product(inStock: false));
      expect(item.availability, CatalogAvailability.outOfStock);
    });

    group('CatalogVertical mapping', () {
      final bagCategories = [
        'bolsa', 'bolsas', 'cartera', 'carteras',
        'monedero', 'monederos', 'cosmetiquera', 'cosmetiqueras',
      ];
      for (final cat in bagCategories) {
        test('maps category "$cat" (case insensitive/spaces) to bagsWallets', () {
          final facets = CanonicalFacets(
            productId: 'gid://shopify/Product/1',
            category: FacetValue('  ${cat.toUpperCase()}  ', FacetSource.metafieldOverride),
            priceBand: 'alto',
            onSale: false,
            inStock: true,
            newArrival: false,
          );
          final item = catalogItemFromShopifyProduct(_product(inStock: true), facets: facets);
          expect(item.vertical, CatalogVertical.bagsWallets);
        });
      }

      final perfumeCategories = ['perfume', 'perfumes', 'fragancia', 'fragancias'];
      for (final cat in perfumeCategories) {
        test('maps category "$cat" (spaces/caps) to perfumes', () {
          final facets = CanonicalFacets(
            productId: 'gid://shopify/Product/1',
            category: FacetValue('  ${cat.toUpperCase()}  ', FacetSource.metafieldOverride),
            priceBand: 'alto',
            onSale: false,
            inStock: true,
            newArrival: false,
          );
          final item = catalogItemFromShopifyProduct(_product(inStock: true), facets: facets);
          expect(item.vertical, CatalogVertical.perfumes);
        });
      }

      test('maps unknown categories to general vertical', () {
        const facets = CanonicalFacets(
          productId: 'gid://shopify/Product/1',
          category: FacetValue('Sombrero', FacetSource.metafieldOverride),
          priceBand: 'alto',
          onSale: false,
          inStock: true,
          newArrival: false,
        );
        final item = catalogItemFromShopifyProduct(_product(inStock: true), facets: facets);
        expect(item.vertical, CatalogVertical.general);
      });
    });

    group('Integrated Normalizer to Mapper', () {
      late Normalizer normalizer;

      setUpAll(() {
        final file = File('assets/rules/normalization_rules.json');
        final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final rules = NormalizationRules.fromJson(json);
        normalizer = Normalizer(rules);
      });

      test('integrates Shopify Product -> Normalizer -> CatalogItem for Perfumes', () {
        final product = _product(inStock: true, productType: 'Fragancias');
        final facets = normalizer.normalize(product, now: DateTime.utc(2026, 8, 1));
        final item = catalogItemFromShopifyProduct(product, facets: facets);

        expect(facets.category?.value, 'perfume'); // Verified by normalizer config
        expect(item.vertical, CatalogVertical.perfumes);
      });

      test('integrates Shopify Product -> Normalizer -> CatalogItem for Bags', () {
        final product = _product(inStock: true, productType: 'Bolso de mano');
        final facets = normalizer.normalize(product, now: DateTime.utc(2026, 8, 1));
        final item = catalogItemFromShopifyProduct(product, facets: facets);

        expect(facets.category?.value, 'bolsa');
        expect(item.vertical, CatalogVertical.bagsWallets);
      });
    });
  });
}
