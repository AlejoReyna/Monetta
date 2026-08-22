import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/external_catalog/external_catalog_mapper.dart';
import 'package:monetta_app/domain/catalog_item.dart';

Map<String, dynamic> _coachItemJson({Map<String, dynamic>? overrides}) => {
      'sourceScopedId': 'coach_us:C8879',
      'source': 'coach_us',
      'merchant': 'Coach',
      'title': 'Tabby Shoulder Bag 26',
      'brand': 'Coach',
      'category': 'Handbags',
      'imageUrl': 'https://coach.com/images/c8879.jpg',
      'price': {'amount': 350.0, 'currency': 'USD'},
      'availability': 'inStock',
      'detailUrl': 'https://www.coach.com/tabby-shoulder-bag-26/C8879.html',
      'lastObservedAt': '2026-08-10T03:19:41.000Z',
      'variants': [
        {
          'variantId': 'C8879:B4BK',
          'sku': 'C8879 B4/BK',
          'colorName': 'Brass/Black',
          'colorCode': 'B4BK',
          'imageUrl': 'https://coach.com/images/c8879-black.jpg',
          'price': {'amount': 320.0, 'currency': 'USD'},
          'availability': 'outOfStock',
          'detailUrl':
              'https://www.coach.com/products/tabby/C8879-B4%2FBK.html',
        },
      ],
      ...?overrides,
    };

void main() {
  group('catalogItemFromExternalJson', () {
    test('maps a Coach item to an ownerProcurement, USD CatalogItem', () {
      final item = catalogItemFromExternalJson(_coachItemJson());

      expect(item.sourceScopedId, 'coach_us:C8879');
      expect(item.source, CatalogSourceType.coachUs);
      expect(item.purchaseMode, PurchaseMode.ownerProcurement);
      expect(item.marketRestriction, MarketRestriction.unitedStates);
      expect(item.price, isNotNull);
      expect(item.price!.currency, Currency.usd);
      expect(item.price!.amount, 350.0);
      expect(item.availability, CatalogAvailability.inStock);
      expect(item.shopifyProductId, isNull);
      expect(item.variants, hasLength(1));
      expect(item.variants.single.colorName, 'Brass/Black');
      expect(item.variants.single.price!.amount, 320);
      expect(
        item.variants.single.availability,
        CatalogAvailability.outOfStock,
      );
      expect(
        item.detailUrl,
        'https://www.coach.com/tabby-shoulder-bag-26/C8879.html',
      );
    });

    test('maps michael_kors_us to CatalogSourceType.michaelKorsUs', () {
      final item = catalogItemFromExternalJson(
        _coachItemJson(
          overrides: {
            'source': 'michael_kors_us',
            'merchant': 'Michael Kors',
          },
        ),
      );
      expect(item.source, CatalogSourceType.michaelKorsUs);
    });

    test('maps guess_us to CatalogSourceType.guessUs', () {
      final item = catalogItemFromExternalJson(
        _coachItemJson(
          overrides: {
            'source': 'guess_us',
            'merchant': 'GUESS',
          },
        ),
      );
      expect(item.source, CatalogSourceType.guessUs);
    });

    test('maps steve_madden_us to CatalogSourceType.steveMaddenUs', () {
      final item = catalogItemFromExternalJson(
        _coachItemJson(
          overrides: {
            'source': 'steve_madden_us',
            'merchant': 'Steve Madden',
          },
        ),
      );
      expect(item.source, CatalogSourceType.steveMaddenUs);
    });

    test('maps the new fashion and perfume sources', () {
      final cases = {
        'marc_jacobs_us': CatalogSourceType.marcJacobsUs,
        'tory_burch_us': CatalogSourceType.toryBurchUs,
        'kate_spade_us': CatalogSourceType.kateSpadeUs,
        'guess_factory_us': CatalogSourceType.guessFactoryUs,
        'gp_mcallen_perfumes': CatalogSourceType.gpMcallenPerfumes,
      };
      for (final entry in cases.entries) {
        final item = catalogItemFromExternalJson(
          _coachItemJson(overrides: {'source': entry.key}),
        );
        expect(item.source, entry.value);
      }
    });

    test('uses suggested MXN retail price while preserving the USD source cost',
        () {
      final item = catalogItemFromExternalJson(
        _coachItemJson(
          overrides: {
            'vertical': 'bags_wallets',
            'suggestedRetailPrice': {'amount': 7980, 'currency': 'MXN'},
            'commission': {'rate': 0.14, 'rule': 'high_value'},
            'variants': [
              {
                'variantId': 'C8879:B4BK',
                'sku': 'C8879 B4/BK',
                'colorName': 'Black',
                'colorCode': 'B4BK',
                'imageUrl': null,
                'price': {'amount': 320, 'currency': 'USD'},
                'suggestedRetailPrice': {'amount': 7296, 'currency': 'MXN'},
                'availability': 'inStock',
                'detailUrl': 'https://www.coach.com/products/tabby/C8879.html',
              },
            ],
          },
        ),
      );

      expect(item.price!.currency, Currency.mxn);
      expect(item.price!.amount, 7980);
      expect(item.sourcePrice!.currency, Currency.usd);
      expect(item.sourcePrice!.amount, 350);
      expect(item.commissionRate, 0.14);
      expect(item.commissionRule, 'high_value');
      expect(item.vertical, CatalogVertical.bagsWallets);
      expect(item.variants.single.price!.currency, Currency.mxn);
      expect(item.variants.single.sourcePrice!.currency, Currency.usd);
    });

    test('maps GP McAllen listings to the perfume vertical', () {
      final item = catalogItemFromExternalJson(
        _coachItemJson(overrides: {'vertical': 'perfumes'}),
      );
      expect(item.vertical, CatalogVertical.perfumes);
    });

    test('maps a null price to null rather than a fabricated \$0', () {
      final item = catalogItemFromExternalJson(
        _coachItemJson(overrides: {'price': null}),
      );
      expect(item.price, isNull);
    });

    test('maps a malformed price (non-numeric amount) to null', () {
      final item = catalogItemFromExternalJson(
        _coachItemJson(
          overrides: {
            'price': {'amount': 'not-a-number', 'currency': 'USD'},
          },
        ),
      );
      expect(item.price, isNull);
    });

    test('maps a price missing its amount field to null', () {
      final item = catalogItemFromExternalJson(
        _coachItemJson(
          overrides: {
            'price': {'currency': 'USD'},
          },
        ),
      );
      expect(item.price, isNull);
    });

    test(
        'validates the declared currency rather than blindly forcing USD — an '
        'unexpected currency maps to null, not a mislabeled USD amount', () {
      final item = catalogItemFromExternalJson(
        _coachItemJson(
          overrides: {
            'price': {'amount': 350.0, 'currency': 'MXN'},
          },
        ),
      );
      expect(item.price, isNull);
    });

    test('accepts a well-formed USD price', () {
      final item = catalogItemFromExternalJson(
        _coachItemJson(
          overrides: {
            'price': {'amount': 228.5, 'currency': 'USD'},
          },
        ),
      );
      expect(item.price, isNotNull);
      expect(item.price!.amount, 228.5);
      expect(item.price!.currency, Currency.usd);
    });

    test('maps an unknown availability string to unknown', () {
      final item = catalogItemFromExternalJson(
        _coachItemJson(overrides: {'availability': 'weird'}),
      );
      expect(item.availability, CatalogAvailability.unknown);
    });

    test(
        'throws on an unrecognized source id rather than silently mismapping it',
        () {
      expect(
        () => catalogItemFromExternalJson(
          _coachItemJson(overrides: {'source': 'some_new_brand'}),
        ),
        throwsArgumentError,
      );
    });
  });
}
