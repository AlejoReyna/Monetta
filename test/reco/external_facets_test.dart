import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/domain/catalog_item.dart';
import 'package:monetta_app/reco/external_facets.dart';

CatalogItem _item({
  CatalogSourceType source = CatalogSourceType.coachUs,
  String? category,
  Money? price,
  CatalogAvailability availability = CatalogAvailability.inStock,
}) {
  return CatalogItem(
    sourceScopedId: 'coach_us:1',
    source: source,
    merchant: 'Coach',
    title: 'X',
    brand: 'Coach',
    category: category,
    imageUrl: null,
    price: price,
    availability: availability,
    detailUrl: 'https://www.coach.com/x',
    marketRestriction: MarketRestriction.unitedStates,
    lastObservedAt: DateTime.utc(2026, 8, 10),
    purchaseMode: PurchaseMode.externalResearch,
  );
}

void main() {
  group('externalPriceBandFor', () {
    test('bands independently of Monetta\'s MXN thresholds', () {
      expect(externalPriceBandFor(50), 'accesible');
      expect(externalPriceBandFor(200), 'medio');
      expect(externalPriceBandFor(400), 'alto');
      expect(externalPriceBandFor(900), 'premium');
    });
  });

  group('externalItemFacets', () {
    test('maps each external source to the same brand slugs Monetta uses', () {
      expect(
        externalItemFacets(_item(source: CatalogSourceType.coachUs))
            .brand
            ?.value,
        'coach',
      );
      expect(
        externalItemFacets(_item(source: CatalogSourceType.michaelKorsUs))
            .brand
            ?.value,
        'michael_kors',
      );
      expect(
        externalItemFacets(_item(source: CatalogSourceType.guessUs))
            .brand
            ?.value,
        'guess',
      );
      expect(
        externalItemFacets(_item(source: CatalogSourceType.steveMaddenUs))
            .brand
            ?.value,
        'steve_madden',
      );
      expect(
        externalItemFacets(_item(source: CatalogSourceType.marcJacobsUs))
            .brand
            ?.value,
        'marc_jacobs',
      );
      expect(
        externalItemFacets(_item(source: CatalogSourceType.toryBurchUs))
            .brand
            ?.value,
        'tory_burch',
      );
      expect(
        externalItemFacets(_item(source: CatalogSourceType.kateSpadeUs))
            .brand
            ?.value,
        'kate_spade',
      );
      expect(
        externalItemFacets(_item(source: CatalogSourceType.guessFactoryUs))
            .brand
            ?.value,
        'guess_factory',
      );
      expect(
        externalItemFacets(_item(source: CatalogSourceType.gpMcallenPerfumes))
            .brand
            ?.value,
        'perfumes',
      );
    });

    test('maps a known English category to the Monetta slug vocabulary', () {
      final facets = externalItemFacets(_item(category: 'Handbags'));
      expect(facets.category?.value, 'bolsa');
    });

    test('an unmapped category contributes no category facet', () {
      final facets =
          externalItemFacets(_item(category: 'Something Unrecognized'));
      expect(facets.category, isNull);
    });

    test('a null price contributes no price-band facet at all', () {
      final facets = externalItemFacets(_item(price: null));
      expect(facets.priceBand, isNull);
      final vectorKeys = facets.toVector(const {}).keys;
      expect(vectorKeys.any((k) => k.startsWith('price_band:')), isFalse);
    });

    test('a known price is banded via the USD-only table', () {
      final facets = externalItemFacets(
        _item(price: const Money(amount: 350, currency: Currency.usd)),
      );
      expect(facets.priceBand, 'alto');
    });

    test('uses source USD rather than a suggested MXN retail price', () {
      final base = _item(
        price: const Money(amount: 6200, currency: Currency.mxn),
      );
      final item = CatalogItem(
        sourceScopedId: base.sourceScopedId,
        source: base.source,
        merchant: base.merchant,
        title: base.title,
        brand: base.brand,
        category: base.category,
        imageUrl: base.imageUrl,
        price: base.price,
        sourcePrice: const Money(amount: 250, currency: Currency.usd),
        availability: base.availability,
        detailUrl: base.detailUrl,
        marketRestriction: base.marketRestriction,
        lastObservedAt: base.lastObservedAt,
        purchaseMode: base.purchaseMode,
      );

      expect(externalItemFacets(item).priceBand, 'medio');
    });

    test('omits price band when only a MXN price is available', () {
      final facets = externalItemFacets(
        _item(price: const Money(amount: 6200, currency: Currency.mxn)),
      );
      expect(facets.priceBand, isNull);
    });

    test('inStock/outOfStock maps to CanonicalFacets.inStock', () {
      expect(
        externalItemFacets(_item(availability: CatalogAvailability.inStock))
            .inStock,
        isTrue,
      );
      expect(
        externalItemFacets(_item(availability: CatalogAvailability.outOfStock))
            .inStock,
        isFalse,
      );
    });

    test('productId is the source-scoped id, not a Shopify id', () {
      final facets = externalItemFacets(_item());
      expect(facets.productId, 'coach_us:1');
    });
  });
}
