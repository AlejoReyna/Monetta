// Deterministic Shopify Storefront wire fixture. No network or real inventory.
import 'package:monetta_app/data/shopify/mappers.dart';
import 'package:monetta_app/domain/product.dart';

Map<String, dynamic> v41ProductJson() => {
      'id': 'gid://shopify/Product/9001',
      'handle': 'fixture-shoe',
      'title': 'Calzado Coach de prueba',
      'vendor': 'Coach',
      'productType': 'Calzado',
      'tags': ['Coach', 'Calzado'],
      'descriptionHtml':
          '<p>Descripción confirmada de la fuente de prueba.</p>',
      'createdAt': '2026-10-01T00:00:00Z',
      'updatedAt': '2026-11-01T00:00:00Z',
      'images': {
        'edges': [
          {
            'node': {'url': 'https://cdn.shopify.com/fixture/overview.jpg'},
          },
        ],
      },
      'variants': {
        'edges': [
          for (final row in [
            ('9101', 'Negro', '36', '1200.00', '1500.00', true, 'black'),
            ('9102', 'Negro', '37', '1400.00', null, false, 'black'),
            ('9103', 'Blanco', '36', '1600.00', null, true, 'white'),
          ])
            {
              'node': {
                'id': 'gid://shopify/ProductVariant/${row.$1}',
                'title': '${row.$2} / ${row.$3}',
                'availableForSale': row.$6,
                'price': {'amount': row.$4, 'currencyCode': 'MXN'},
                'compareAtPrice': row.$5 == null ? null : {'amount': row.$5},
                'selectedOptions': [
                  {'name': 'Color', 'value': row.$2},
                  {'name': 'Talla', 'value': row.$3},
                ],
                'image': {
                  'url': 'https://cdn.shopify.com/fixture/${row.$7}.jpg',
                },
              },
            },
        ],
      },
    };

Product v41Product() => productFromJson(v41ProductJson());
