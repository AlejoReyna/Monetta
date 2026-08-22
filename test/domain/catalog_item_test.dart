import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/domain/catalog_item.dart';

CatalogItem _item({
  required String brand,
  required String title,
  String detailUrl = 'https://www.coach.com/x',
  CatalogSourceType source = CatalogSourceType.coachUs,
  Money? price = const Money(amount: 100, currency: Currency.usd),
  PurchaseMode purchaseMode = PurchaseMode.externalResearch,
}) {
  return CatalogItem(
    sourceScopedId: 'coach_us:1',
    source: source,
    merchant: 'Coach',
    title: title,
    brand: brand,
    category: null,
    imageUrl: null,
    price: price,
    availability: CatalogAvailability.inStock,
    detailUrl: detailUrl,
    marketRestriction: MarketRestriction.unitedStates,
    lastObservedAt: DateTime.utc(2026, 8, 10),
    purchaseMode: purchaseMode,
  );
}

void main() {
  group('Money', () {
    test('currencyCode reflects the enum', () {
      expect(
        const Money(amount: 10, currency: Currency.mxn).currencyCode,
        'MXN',
      );
      expect(
        const Money(amount: 10, currency: Currency.usd).currencyCode,
        'USD',
      );
    });
  });

  group('CatalogItem.dedupeKey', () {
    test('is case- and whitespace-insensitive', () {
      final a = _item(brand: 'Coach', title: 'Tabby  Shoulder Bag');
      final b = _item(brand: '  coach ', title: 'tabby shoulder bag');
      expect(a.dedupeKey, b.dedupeKey);
    });

    test('differs for a different brand or title', () {
      final a = _item(brand: 'Coach', title: 'Tabby Shoulder Bag');
      final differentBrand =
          _item(brand: 'Michael Kors', title: 'Tabby Shoulder Bag');
      final differentTitle = _item(brand: 'Coach', title: 'Rowan Satchel');
      expect(a.dedupeKey, isNot(differentBrand.dedupeKey));
      expect(a.dedupeKey, isNot(differentTitle.dedupeKey));
    });
  });

  group('CatalogItem.isExternal', () {
    test('is true for externalResearch, false for monettaCheckout', () {
      expect(_item(brand: 'Coach', title: 'X').isExternal, isTrue);
      final monetta = CatalogItem(
        sourceScopedId: 'monetta:1',
        source: CatalogSourceType.monettaShopify,
        merchant: 'Monetta',
        title: 'X',
        brand: 'Guess',
        category: null,
        imageUrl: null,
        price: const Money(amount: 100, currency: Currency.mxn),
        availability: CatalogAvailability.inStock,
        detailUrl: 'https://monetta.mx/products/x',
        marketRestriction: MarketRestriction.mexico,
        lastObservedAt: DateTime.utc(2026, 8, 10),
        purchaseMode: PurchaseMode.monettaCheckout,
        shopifyProductId: '1',
      );
      expect(monetta.isExternal, isFalse);
    });

    test('ownerProcurement remains outside Monetta checkout', () {
      final item = _item(
        brand: 'Coach',
        title: 'Owner candidate',
        purchaseMode: PurchaseMode.ownerProcurement,
      );
      // The enum is intentionally independent from supplier authorization:
      // owner-managed candidates are external and therefore inert in cart.
      expect(item.isExternal, isTrue);
      expect(item.isOwnerProcurement, isTrue);
    });
  });

  group('CatalogItem.price is nullable (Fix 8)', () {
    test('a null price is accepted and stays null, never coerced to \$0', () {
      final item = _item(brand: 'Coach', title: 'X', price: null);
      expect(item.price, isNull);
    });
  });

  group('isValidExternalDetailUrl', () {
    test('accepts an HTTPS URL on the item\'s declared source host', () {
      expect(
        isValidExternalDetailUrl(
          _item(
            brand: 'Coach',
            title: 'X',
            detailUrl: 'https://www.coach.com/products/tabby/CEN52.html',
            source: CatalogSourceType.coachUs,
          ),
        ),
        isTrue,
      );
      final additionalSources = {
        CatalogSourceType.marcJacobsUs:
            'https://www.marcjacobs.com/us-en/a-bag/X.html',
        CatalogSourceType.toryBurchUs:
            'https://www.toryburch.com/en-us/handbags/tote-bags/a/1.html',
        CatalogSourceType.kateSpadeUs:
            'https://www.katespade.com/products/a-bag/X.html',
        CatalogSourceType.guessFactoryUs:
            'https://www.guessfactory.com/us/en/handbags/a/X-1.html',
        CatalogSourceType.gpMcallenPerfumes:
            'https://www.gpmcallen.com/a-perfume.html',
      };
      for (final entry in additionalSources.entries) {
        expect(
          isValidExternalDetailUrl(
            _item(
              brand: 'Brand',
              title: 'X',
              detailUrl: entry.value,
              source: entry.key,
            ),
          ),
          isTrue,
        );
      }
      expect(
        isValidExternalDetailUrl(
          _item(
            brand: 'GUESS',
            title: 'X',
            detailUrl: 'https://www.guess.com/en-us/bag/BS967218-LLU.html',
            source: CatalogSourceType.guessUs,
          ),
        ),
        isTrue,
      );
      expect(
        isValidExternalDetailUrl(
          _item(
            brand: 'Steve Madden',
            title: 'X',
            detailUrl: 'https://www.stevemadden.com/products/bmakia-black',
            source: CatalogSourceType.steveMaddenUs,
          ),
        ),
        isTrue,
      );
      expect(
        isValidExternalDetailUrl(
          _item(
            brand: 'Michael Kors',
            title: 'X',
            detailUrl: 'https://www.michaelkors.com/product/x/_/R-US_MM1',
            source: CatalogSourceType.michaelKorsUs,
          ),
        ),
        isTrue,
      );
    });

    test('rejects a non-HTTPS scheme', () {
      expect(
        isValidExternalDetailUrl(
          _item(
            brand: 'Coach',
            title: 'X',
            detailUrl: 'http://www.coach.com/products/tabby/CEN52.html',
          ),
        ),
        isFalse,
      );
    });

    test('rejects a host that does not belong to the declared source', () {
      expect(
        isValidExternalDetailUrl(
          _item(
            brand: 'Coach',
            title: 'X',
            detailUrl: 'https://www.michaelkors.com/products/tabby/CEN52.html',
            source: CatalogSourceType.coachUs,
          ),
        ),
        isFalse,
      );
    });

    test('rejects a lookalike host', () {
      expect(
        isValidExternalDetailUrl(
          _item(
            brand: 'Coach',
            title: 'X',
            detailUrl: 'https://coach.com.evil.example/x',
          ),
        ),
        isFalse,
      );
    });

    test('rejects an unparseable URL without throwing', () {
      final malformed =
          _item(brand: 'Coach', title: 'X', detailUrl: 'not a url');
      expect(() => isValidExternalDetailUrl(malformed), returnsNormally);
      expect(isValidExternalDetailUrl(malformed), isFalse);
    });

    test(
        'always false for a Monetta item (this check only applies to external items)',
        () {
      final monetta = CatalogItem(
        sourceScopedId: 'monetta:1',
        source: CatalogSourceType.monettaShopify,
        merchant: 'Monetta',
        title: 'X',
        brand: 'Guess',
        category: null,
        imageUrl: null,
        price: const Money(amount: 100, currency: Currency.mxn),
        availability: CatalogAvailability.inStock,
        detailUrl: 'https://monetta.mx/products/x',
        marketRestriction: MarketRestriction.mexico,
        lastObservedAt: DateTime.utc(2026, 8, 10),
        purchaseMode: PurchaseMode.monettaCheckout,
        shopifyProductId: '1',
      );
      expect(isValidExternalDetailUrl(monetta), isFalse);
    });
  });

  group('sourceLinkLabel', () {
    test('renders host + path so the provenance is visible as plain text', () {
      final item = _item(
        brand: 'Coach',
        title: 'X',
        detailUrl:
            'https://www.coach.com/products/tabby-shoulder-bag-26/CEN52.html',
      );
      expect(
        sourceLinkLabel(item),
        'www.coach.com/products/tabby-shoulder-bag-26/CEN52.html',
      );
    });

    test('falls back to the raw string for an unparseable URL', () {
      final item = _item(brand: 'Coach', title: 'X', detailUrl: 'not a url');
      expect(sourceLinkLabel(item), 'not a url');
    });
  });
}
