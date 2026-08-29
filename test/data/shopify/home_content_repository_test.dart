import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/shopify/home_content_repository.dart';
import 'package:monetta_app/data/shopify/storefront_client.dart';
import 'package:monetta_app/data/shopify/storefront_config.dart';
import 'package:monetta_app/domain/home_content.dart';

void main() {
  test('offline order matches the mobile Shopify storefront', () {
    expect(
      HomeContent.fallback.sectionOrder,
      const [
        HomeSectionId.collections,
        HomeSectionId.newProducts,
        HomeSectionId.bagTypes,
        HomeSectionId.brands,
        HomeSectionId.about,
        HomeSectionId.social,
        HomeSectionId.testimonials,
      ],
    );
  });

  test('Shopify controls home order, links and collection artwork', () async {
    late String requestBody;
    final repository = HomeContentRepository(
      client: StorefrontClient(
        config: const StorefrontConfig(
          shopDomain: 'shop.example.com',
          accessToken: 'public-token',
        ),
        transport: (_, __, body) async {
          requestBody = body;
          return {
            'data': {
              'shop': {
                'homeSections': {
                  'value': jsonEncode([
                    'new_products',
                    'collections',
                    'social',
                  ]),
                },
                'homeCollections': {
                  'value': jsonEncode(['guess', 'carteras-1']),
                },
                'homeBagTypes': null,
                'socialLinks': {
                  'value': jsonEncode({
                    'instagram': 'https://instagram.com/monetta-synced',
                  }),
                },
                'aboutImageUrl': {
                  'value': 'https://cdn.shopify.com/about.jpg',
                },
              },
              'collections': {
                'edges': [
                  {
                    'node': {
                      'id': 'gid://Collection/1',
                      'handle': 'guess',
                      'title': 'Bolsas de diseñador',
                      'description': '',
                      'image': {
                        'url': 'https://cdn.shopify.com/bags.jpg',
                      },
                      'products': {
                        'pageInfo': {'hasNextPage': false},
                        'edges': [
                          {
                            'node': {'id': 'gid://Product/1'},
                          },
                        ],
                      },
                    },
                  },
                  {
                    'node': {
                      'id': 'gid://Collection/2',
                      'handle': 'carteras-1',
                      'title': 'Carteras',
                      'description': '',
                      'image': null,
                      'products': {
                        'pageInfo': {'hasNextPage': false},
                        'edges': [
                          {
                            'node': {'id': 'gid://Product/2'},
                          },
                        ],
                      },
                    },
                  },
                ],
              },
            },
          };
        },
      ),
    );

    final content = await repository.fetch();

    expect(content.sectionOrder, [
      HomeSectionId.newProducts,
      HomeSectionId.collections,
      HomeSectionId.social,
    ]);
    expect(content.collections, hasLength(2));
    expect(content.collections.first.title, 'Bolsas de diseñador');
    expect(
      content.collections.first.imageUrl,
      'https://cdn.shopify.com/bags.jpg',
    );
    expect(
      content.collections[1].fallbackAsset,
      'assets/images/home_collection_wallets.webp',
    );
    expect(
      content.socialLinks.first.url,
      'https://instagram.com/monetta-synced',
    );
    expect(content.aboutImageUrl, 'https://cdn.shopify.com/about.jpg');
    expect(requestBody, contains('home_sections'));
    expect(requestBody, contains('collections(first: 50'));
  });

  test('missing or malformed metafields retain the mobile-store fallback',
      () async {
    final repository = HomeContentRepository(
      client: StorefrontClient(
        config: const StorefrontConfig(
          shopDomain: 'shop.example.com',
          accessToken: 'public-token',
        ),
        transport: (_, __, ___) async => {
          'data': {
            'shop': {
              'homeSections': {'value': 'unknown'},
              'homeCollections': null,
              'homeBagTypes': null,
              'socialLinks': {'value': 'not-json'},
              'aboutImageUrl': null,
            },
            'collections': {'edges': <Object>[]},
          },
        },
      ),
    );

    final content = await repository.fetch();

    expect(content.sectionOrder, HomeContent.fallback.sectionOrder);
    expect(
      content.collections.map((item) => item.handle),
      HomeContent.fallback.collections.map((item) => item.handle),
    );
    expect(
      content.collections.map((item) => item.fallbackAsset),
      HomeContent.fallback.collections.map((item) => item.fallbackAsset),
    );
    expect(content.socialLinks.first.url, contains('instagram.com'));
  });
}
