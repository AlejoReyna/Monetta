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
