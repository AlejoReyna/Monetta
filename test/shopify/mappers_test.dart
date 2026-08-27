/// Mappers are the hand-written replacement for GraphQL codegen, so they carry
/// the type-safety burden and are tested against real response shapes.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/shopify/mappers.dart';

void main() {
  group('money', () {
    test('parses MoneyV2 amounts, which arrive as decimal strings', () {
      // Shopify sends "1749.00", not 1749. Casting to num throws.
      expect(money({'amount': '1749.00', 'currencyCode': 'MXN'}), 1749.0);
    });

    test('returns null rather than throwing on absent or malformed money', () {
      expect(money(null), isNull);
      expect(money({'amount': null}), isNull);
      expect(money({'amount': 'not-a-number'}), isNull);
    });
  });

  group('metafieldValue', () {
    test('reads a set override', () {
      expect(metafieldValue({'value': 'Guess'}), 'Guess');
    });

    test('treats unset, empty and whitespace metafields as absent', () {
      // Shopify omits the object entirely when the owner never set it.
      expect(metafieldValue(null), isNull);
      expect(metafieldValue({'value': ''}), isNull);
      expect(metafieldValue({'value': '   '}), isNull);
    });
  });

  group('edgeNodes', () {
    test('unwraps the edges/node shape', () {
      final nodes = edgeNodes({
        'edges': [
          {
            'node': {'id': '1'},
          },
          {
            'node': {'id': '2'},
          },
        ],
      });
      expect(nodes.map((n) => n['id']), ['1', '2']);
    });

    test('survives a null or missing connection', () {
      expect(edgeNodes(null), isEmpty);
      expect(edgeNodes(<String, dynamic>{}), isEmpty);
    });
  });

  group('productFromJson', () {
    Map<String, dynamic> baseJson() => <String, dynamic>{
          'id': 'gid://shopify/Product/9683379781783',
          'handle': 'bolsa-steve-madden-tote-crossbody-cafe',
          'title': 'Bolsa Steve Madden Tote Crossbody Cafe',
          'vendor': 'Monetta ',
          'productType': '',
          'tags': <String>[],
          'descriptionHtml': '<p>x</p>',
          'createdAt': '2026-07-29T16:23:55-06:00',
          'updatedAt': '2026-08-05T01:24:53-06:00',
          'images': {
            'edges': [
              {
                'node': {'url': 'https://cdn.shopify.com/a.jpg'},
              },
            ],
          },
          'variants': {
            'edges': [
              {
                'node': {
                  'id': 'gid://shopify/ProductVariant/48087674421399',
                  'title': 'Default Title',
                  'availableForSale': true,
                  'price': {'amount': '1589.00', 'currencyCode': 'MXN'},
                  'compareAtPrice': {'amount': '1749.00'},
                  'sku': null,
                },
              },
            ],
          },
          'collections': {
            'edges': [
              {
                'node': {'handle': 'steve-madden'},
              },
            ],
          },
        };

    test('maps a real product, preserving the raw vendor exactly', () {
      final product = productFromJson(baseJson());

      // The trailing space must survive mapping — data/normalize relies on
      // recognising it to avoid treating the store name as a brand.
      expect(product.vendor, 'Monetta ');
      expect(product.title, 'Bolsa Steve Madden Tote Crossbody Cafe');
      expect(product.price, 1589.0);
      expect(product.compareAtPrice, 1749.0);
      expect(product.isOnSale, isTrue);
      expect(product.isInStock, isTrue);
      expect(product.collectionHandles, ['steve-madden']);
      expect(product.id, 'gid://shopify/Product/9683379781783');
      expect(
        product.variants.single.id,
        'gid://shopify/ProductVariant/48087674421399',
      );
      expect(product.variants.single.isDefault, isTrue);
    });

    test('rejects non-GID identities from Storefront', () {
      final json = baseJson()..['id'] = 'not-a-shopify-id';
      expect(() => productFromJson(json), throwsFormatException);
    });

    test('computes the discount fraction', () {
      final product = productFromJson(baseJson());
      // (1749 - 1589) / 1749
      expect(product.discountFraction, closeTo(0.0915, 0.001));
    });

    test('handles a product with no images without throwing', () {
      final json = baseJson()..['images'] = {'edges': <dynamic>[]};
      final product = productFromJson(json);
      expect(product.images, isEmpty);
      expect(product.primaryImage, isNull);
    });

    test('handles absent metafields', () {
      final product = productFromJson(baseJson());
      expect(product.brandOverride, isNull);
      expect(product.categoryOverride, isNull);
    });

    test('reads owner overrides when present', () {
      final json = baseJson()
        ..['brandOverride'] = {'value': 'Steve Madden'}
        ..['categoryOverride'] = {'value': 'Bolsa'};
      final product = productFromJson(json);
      expect(product.brandOverride, 'Steve Madden');
      expect(product.categoryOverride, 'Bolsa');
    });

    test('falls back to the epoch on a malformed date', () {
      // A bad timestamp must not take down a whole catalog sync.
      final json = baseJson()..['updatedAt'] = 'not-a-date';
      expect(productFromJson(json).updatedAt.millisecondsSinceEpoch, 0);
    });

    test('marks a product out of stock when no variant is available', () {
      final json = baseJson();
      final variants = (json['variants'] as Map)['edges'] as List;
      ((variants.first as Map)['node'] as Map)['availableForSale'] = false;
      expect(productFromJson(json).isInStock, isFalse);
    });
  });

  group('cartFromJson', () {
    test('maps lines, subtotal and the checkout URL', () {
      final cart = cartFromJson(<String, dynamic>{
        'id': 'gid://shopify/Cart/abc',
        'checkoutUrl': 'https://monetta.mx/cart/c/abc?key=xyz',
        'totalQuantity': 2,
        'cost': {
          'subtotalAmount': {'amount': '3178.00', 'currencyCode': 'MXN'},
        },
        'lines': {
          'edges': [
            {
              'node': {
                'id': 'line-1',
                'quantity': 2,
                'cost': {
                  'amountPerQuantity': {'amount': '1589.00'},
                },
                'merchandise': {
                  'id': 'variant-1',
                  'title': 'Default Title',
                  'image': {'url': 'https://cdn.shopify.com/a.jpg'},
                  'product': {
                    'id': 'product-1',
                    'title': 'Bolsa Steve Madden',
                    'handle': 'bolsa-steve-madden',
                  },
                },
              },
            },
          ],
        },
      });

      expect(cart.checkoutUrl, contains('/cart/c/abc'));
      expect(cart.totalQuantity, 2);
      expect(cart.subtotalAmount, 3178.0);
      expect(cart.currencyCode, 'MXN');
      expect(cart.lines.single.lineTotal, 3178.0);
      expect(cart.lines.single.title, 'Bolsa Steve Madden');
    });
  });

  group('collectionFromJson', () {
    test('detects an empty collection', () {
      // 7 of the store's 21 collections are empty and must not render.
      final collection = collectionFromJson(<String, dynamic>{
        'id': 'gid://shopify/Collection/1',
        'handle': 'anne-klein',
        'title': 'anne klein',
        'products': {
          'pageInfo': {'hasNextPage': false},
          'edges': <dynamic>[],
        },
      });
      expect(collection.productCount, 0);
      expect(collection.isEmpty, isTrue);
    });

    test('leaves the count unknown for a non-empty collection', () {
      final collection = collectionFromJson(<String, dynamic>{
        'id': 'gid://shopify/Collection/2',
        'handle': 'coach',
        'title': 'COACH',
        'products': {
          'pageInfo': {'hasNextPage': true},
          'edges': [
            {
              'node': {'id': 'p1'},
            },
          ],
        },
      });
      // We only ask for first:1 — this is emptiness detection, not a real count.
      expect(collection.productCount, isNull);
      expect(collection.isEmpty, isFalse);
    });
  });
}
