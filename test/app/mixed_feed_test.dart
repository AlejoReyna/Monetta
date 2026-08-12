import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/mixed_feed.dart';
import 'package:monetta_app/data/normalize/facets.dart';
import 'package:monetta_app/domain/catalog_item.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/reco/explainer.dart';
import 'package:monetta_app/reco/profile.dart';
import 'package:monetta_app/reco/scorer.dart';

CatalogItem _external({
  required String brand,
  required String title,
  String id = 'coach_us:1',
}) {
  return CatalogItem(
    sourceScopedId: id,
    source: CatalogSourceType.coachUs,
    merchant: 'Coach',
    title: title,
    brand: brand,
    category: null,
    imageUrl: null,
    price: const Money(amount: 100, currency: Currency.usd),
    availability: CatalogAvailability.inStock,
    detailUrl: 'https://www.coach.com/x',
    marketRestriction: MarketRestriction.unitedStates,
    lastObservedAt: DateTime.utc(2026, 8, 10),
    purchaseMode: PurchaseMode.externalResearch,
  );
}

CatalogItem _monetta({required String brand, required String title}) {
  return CatalogItem(
    sourceScopedId: 'monetta:1',
    source: CatalogSourceType.monettaShopify,
    merchant: 'Monetta',
    title: title,
    brand: brand,
    category: null,
    imageUrl: null,
    price: const Money(amount: 1999, currency: Currency.mxn),
    availability: CatalogAvailability.inStock,
    detailUrl: 'https://monetta.mx/products/x',
    marketRestriction: MarketRestriction.mexico,
    lastObservedAt: DateTime.utc(2026, 8, 10),
    purchaseMode: PurchaseMode.monettaCheckout,
    shopifyProductId: '1',
  );
}

void main() {
  group('relevantExternalItems — exact-match dedupe', () {
    test('excludes an external item that exactly matches a Monetta brand+title',
        () {
      final external = [_external(brand: 'Coach', title: 'Tabby Shoulder Bag')];
      final monetta = [_monetta(brand: 'Coach', title: 'Tabby Shoulder Bag')];

      final result = relevantExternalItems(
        external: external,
        monettaItems: monetta,
        topBrands: const [],
      );

      expect(result, isEmpty);
    });

    test('does not exclude on a partial or fuzzy title match', () {
      final external = [
        _external(brand: 'Coach', title: 'Tabby Shoulder Bag 26'),
      ];
      final monetta = [_monetta(brand: 'Coach', title: 'Tabby Shoulder Bag')];

      final result = relevantExternalItems(
        external: external,
        monettaItems: monetta,
        topBrands: const [],
      );

      expect(
        result,
        hasLength(1),
      ); // no SKU/UPC evidence — must not fuzzy-dedupe
    });

    test('is case- and whitespace-insensitive', () {
      final external = [
        _external(brand: 'coach', title: '  tabby   shoulder bag '),
      ];
      final monetta = [_monetta(brand: 'Coach', title: 'Tabby Shoulder Bag')];

      final result = relevantExternalItems(
        external: external,
        monettaItems: monetta,
        topBrands: const [],
      );

      expect(result, isEmpty);
    });
  });

  group('relevantExternalItems — brand relevance', () {
    test('on a cold-start profile (no top brands) returns an unfiltered sample',
        () {
      final external = [
        _external(brand: 'Coach', title: 'A', id: 'coach_us:1'),
        _external(brand: 'Michael Kors', title: 'B', id: 'michael_kors_us:1'),
      ];

      final result = relevantExternalItems(
        external: external,
        monettaItems: const [],
        topBrands: const [],
      );

      expect(result, hasLength(2));
    });

    test('filters to the shopper\'s top brands once a profile exists', () {
      final external = [
        _external(brand: 'Coach', title: 'A', id: 'coach_us:1'),
        _external(brand: 'Michael Kors', title: 'B', id: 'michael_kors_us:1'),
      ];

      final result = relevantExternalItems(
        external: external,
        monettaItems: const [],
        topBrands: const ['Coach'],
      );

      expect(result, hasLength(1));
      expect(result.single.brand, 'Coach');
    });

    test(
        'returns nothing when top brands exist but none overlap with external brands',
        () {
      final external = [_external(brand: 'Michael Kors', title: 'B')];

      final result = relevantExternalItems(
        external: external,
        monettaItems: const [],
        topBrands: const ['Guess'],
      );

      expect(result, isEmpty);
    });

    test('respects an explicit limit', () {
      final external = List.generate(
        20,
        (i) => _external(brand: 'Coach', title: 'Item $i', id: 'coach_us:$i'),
      );

      final result = relevantExternalItems(
        external: external,
        monettaItems: const [],
        topBrands: const [],
        limit: 3,
      );

      expect(result, hasLength(3));
    });

    test(
        'the fixed eight-item cap is gone: omitting limit returns every relevant item',
        () {
      final external = List.generate(
        20,
        (i) => _external(brand: 'Coach', title: 'Item $i', id: 'coach_us:$i'),
      );

      final result = relevantExternalItems(
        external: external,
        monettaItems: const [],
        topBrands: const [],
      );

      expect(result, hasLength(20));
    });
  });

  group('fullDeduplicatedCatalog', () {
    test('includes every Monetta item and every non-duplicate external item',
        () {
      final monetta = [_monetta(brand: 'Guess', title: 'Bolsa Roja')];
      final external = [
        _external(brand: 'Coach', title: 'Tabby', id: 'coach_us:1'),
        _external(
          brand: 'Michael Kors',
          title: 'Jet Set',
          id: 'michael_kors_us:1',
        ),
      ];

      final result = fullDeduplicatedCatalog(
        monettaItems: monetta,
        externalItems: external,
      );

      expect(result, hasLength(3));
    });

    test('an exact brand+title duplicate keeps only the Monetta copy', () {
      final monetta = [_monetta(brand: 'Coach', title: 'Tabby Shoulder Bag')];
      final external = [
        _external(
          brand: 'Coach',
          title: 'Tabby Shoulder Bag',
          id: 'coach_us:1',
        ),
      ];

      final result = fullDeduplicatedCatalog(
        monettaItems: monetta,
        externalItems: external,
      );

      expect(result, hasLength(1));
      expect(result.single.source, CatalogSourceType.monettaShopify);
    });

    test(
        'is not capped — every deduplicated item is present regardless of count',
        () {
      final external = List.generate(
        50,
        (i) => _external(brand: 'Coach', title: 'Item $i', id: 'coach_us:$i'),
      );

      final result = fullDeduplicatedCatalog(
        monettaItems: const [],
        externalItems: external,
      );

      expect(result, hasLength(50));
    });
  });

  group('unifiedRecommendations', () {
    Product product(String id, {required String vendor}) => Product(
          id: id,
          handle: id,
          title: 'Monetta $id',
          vendor: vendor,
          productType: 'Bolsa',
          tags: [vendor.toLowerCase()],
          images: ['https://cdn.shopify.com/$id.jpg'],
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 8, 1),
          variants: [
            ProductVariant(
              id: '$id-v1',
              title: 'Default Title',
              price: 1999,
              available: true,
            ),
          ],
        );

    CanonicalFacets facetsFor(Product p) => CanonicalFacets(
          productId: p.id,
          brand: FacetValue(p.vendor.toLowerCase(), FacetSource.tag),
          category: const FacetValue('bolsa', FacetSource.productType),
          priceBand: 'alto',
          onSale: false,
          inStock: true,
          newArrival: false,
        );

    final recommender = Recommender(
      facetWeights: const {'brand': 1.0, 'category': 0.8, 'price_band': 0.6},
    );
    const explainer = Explainer();

    test('external items appear in the unified ranked candidate set', () {
      final products = [
        product('p1', vendor: 'Coach'),
        product('p2', vendor: 'Guess'),
      ];
      final facetsById = {for (final p in products) p.id: facetsFor(p)};
      final coachProfile = seedProfileFromOnboarding(
        brands: const ['coach'],
        categories: const ['bolsa'],
        now: DateTime.utc(2026, 8, 10),
      );

      final external = [
        _external(
          brand: 'Coach',
          title: 'External Coach Item',
          id: 'coach_us:1',
        ),
      ];

      final result = unifiedRecommendations(
        recommender: recommender,
        explainer: explainer,
        profile: coachProfile,
        monettaProducts: products,
        monettaFacetsById: facetsById,
        externalItems: external,
      );

      expect(
        result.any(
          (r) => r.isExternal && r.item.sourceScopedId == 'coach_us:1',
        ),
        isTrue,
      );
    });

    test(
        'an exact duplicate prefers the Monetta item — the external twin never appears',
        () {
      final products = [product('p1', vendor: 'Coach')];
      final facetsById = {for (final p in products) p.id: facetsFor(p)};
      // Same normalized brand+title as the Monetta product above.
      final external = [
        _external(brand: 'Coach', title: 'Monetta p1', id: 'coach_us:dup'),
      ];

      final result = unifiedRecommendations(
        recommender: recommender,
        explainer: explainer,
        profile: seedProfileFromOnboarding(
          brands: const ['coach'],
          categories: const [],
          now: DateTime.utc(2026, 8, 10),
        ),
        monettaProducts: products,
        monettaFacetsById: facetsById,
        externalItems: external,
      );

      expect(
        result.where((r) => r.item.sourceScopedId == 'coach_us:dup'),
        isEmpty,
      );
      expect(result.any((r) => r.product?.id == 'p1'), isTrue);
    });

    test(
        'an external MixedRecommendation never carries a Monetta product reference',
        () {
      final products = [product('p1', vendor: 'Coach')];
      final facetsById = {for (final p in products) p.id: facetsFor(p)};
      final external = [
        _external(
          brand: 'Michael Kors',
          title: 'External MK Item',
          id: 'michael_kors_us:1',
        ),
      ];

      final result = unifiedRecommendations(
        recommender: recommender,
        explainer: explainer,
        profile: seedProfileFromOnboarding(
          brands: const ['michael_kors'],
          categories: const [],
          now: DateTime.utc(2026, 8, 10),
        ),
        monettaProducts: products,
        monettaFacetsById: facetsById,
        externalItems: external,
      );

      final externalRec = result.firstWhere((r) => r.isExternal);
      // External actions cannot enter Monetta flows.
      expect(externalRec.product, isNull);
    });

    test(
        'the external item\'s score never changes with its raw USD amount — only the neutral price-band label can matter, never the number',
        () {
      final products = [product('p1', vendor: 'Coach')];
      final facetsById = {for (final p in products) p.id: facetsFor(p)};
      final profile = seedProfileFromOnboarding(
        brands: const ['coach'],
        categories: const ['bolsa'],
        now: DateTime.utc(2026, 8, 10),
      );

      CatalogItem externalWithPrice(double amount) => CatalogItem(
            sourceScopedId: 'coach_us:1',
            source: CatalogSourceType.coachUs,
            merchant: 'Coach',
            title: 'External Item',
            brand: 'Coach',
            category: null,
            imageUrl: null,
            price: Money(amount: amount, currency: Currency.usd),
            availability: CatalogAvailability.inStock,
            detailUrl: 'https://www.coach.com/x',
            marketRestriction: MarketRestriction.unitedStates,
            lastObservedAt: DateTime.utc(2026, 8, 10),
            purchaseMode: PurchaseMode.externalResearch,
          );

      double? scoreFor(double usdAmount) {
        final result = unifiedRecommendations(
          recommender: recommender,
          explainer: explainer,
          profile: profile,
          monettaProducts: products,
          monettaFacetsById: facetsById,
          externalItems: [externalWithPrice(usdAmount)],
        );
        final matches = result.where((r) => r.isExternal).toList();
        return matches.isEmpty ? null : matches.first.score;
      }

      // $10 ("accesible" band) vs $10,000 ("premium" band): a 1000x swing in
      // the raw number. If price magnitude ever leaked into ranking (e.g. by
      // comparing it, even implicitly, against a Monetta MXN amount), these
      // scores would differ. They must not.
      final cheap = scoreFor(10);
      final expensive = scoreFor(10000);
      expect(cheap, isNotNull);
      expect(cheap, equals(expensive));
    });
  });
}
