import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/shopify/editorial_content_repository.dart';
import 'package:monetta_app/data/shopify/storefront_client.dart';
import 'package:monetta_app/data/shopify/storefront_config.dart';
import 'package:monetta_app/domain/editorial_content.dart';
import 'package:monetta_app/domain/seasonal_campaign.dart';

void main() {
  test('valid Metaobjects override fallback copy and catalogs', () async {
    final repository = EditorialContentRepository(
      client: StorefrontClient(
        config: const StorefrontConfig(
          shopDomain: 'shop.example.com',
          accessToken: 'public-token',
        ),
        transport: (_, __, ___) async => {
          'data': {
            'about': {
              'fields': [
                {'key': 'headline', 'value': 'Una historia actualizada'},
                {
                  'key': 'trust_facts_json',
                  'value': jsonEncode(['Originales', 'Envíos nacionales']),
                },
              ],
            },
            'partner': {
              'fields': [
                {'key': 'headline', 'value': 'Haz crecer tu negocio'},
              ],
            },
            'catalogs': {
              'edges': [
                {
                  'node': {
                    'handle': 'bags-client',
                    'fields': [
                      {'key': 'category', 'value': 'bags'},
                      {'key': 'category_label', 'value': 'Bolsas'},
                      {'key': 'mode', 'value': 'con_precios'},
                      {
                        'key': 'url',
                        'value': 'https://canva.link/catalogo',
                      },
                      {'key': 'active', 'value': 'true'},
                    ],
                  },
                },
                {
                  'node': {
                    'handle': 'unsafe',
                    'fields': [
                      {'key': 'category', 'value': 'bags'},
                      {'key': 'category_label', 'value': 'Bolsas'},
                      {'key': 'mode', 'value': 'sin_precios'},
                      {'key': 'url', 'value': 'https://example.com/phishing'},
                    ],
                  },
                },
              ],
            },
          },
        },
      ),
    );

    final content = await repository.fetch();

    expect(content.about.headline, 'Una historia actualizada');
    expect(content.about.body, MonettaEditorialContent.fallback.about.body);
    expect(content.about.trustFacts, ['Originales', 'Envíos nacionales']);
    expect(content.partner.headline, 'Haz crecer tu negocio');
    expect(content.partner.catalogs, hasLength(1));
    expect(content.partner.catalogs.single.id, 'bags-client');
  });

  test('missing Metaobjects retain the complete offline fallback', () async {
    final repository = EditorialContentRepository(
      client: StorefrontClient(
        config: const StorefrontConfig(
          shopDomain: 'shop.example.com',
          accessToken: 'public-token',
        ),
        transport: (_, __, ___) async => {
          'data': {'about': null, 'partner': null, 'catalogs': null},
        },
      ),
    );

    final content = await repository.fetch();

    expect(
      content.about.headline,
      MonettaEditorialContent.fallback.about.headline,
    );
    expect(content.partner.catalogs, hasLength(9));
    expect(content.seasonalBanners, isEmpty);
  });

  test('seasonal banner reads file references and ignores unsafe images',
      () async {
    final repository = EditorialContentRepository(
      client: StorefrontClient(
        config: const StorefrontConfig(
          shopDomain: 'shop.example.com',
          accessToken: 'public-token',
        ),
        transport: (_, __, ___) async => {
          'data': {
            'about': null,
            'partner': null,
            'catalogs': null,
            'seasonalBanners': {
              'edges': [
                {
                  'node': {
                    'handle': 'otono-2026',
                    'fields': [
                      {'key': 'title', 'value': 'Nueva temporada'},
                      {'key': 'tag', 'value': 'Otoño'},
                      {'key': 'subtitle', 'value': 'Piezas nuevas'},
                      {'key': 'cta_text', 'value': 'VER COLECCIÓN'},
                      {
                        'key': 'image',
                        'value': 'gid://shopify/MediaImage/1',
                        'reference': {
                          'image': {
                            'url': 'https://cdn.shopify.com/banner.jpg',
                          },
                        },
                      },
                      {
                        'key': 'ipad_image',
                        'value': 'http://insecure.example/ipad.jpg',
                      },
                      {
                        'key': 'collection_id',
                        'value': 'gid://shopify/Collection/9',
                        'reference': {
                          'id': 'gid://shopify/Collection/9',
                          'handle': 'otono',
                        },
                      },
                      {
                        'key': 'starts_at',
                        'value': '2026-09-01T00:00:00Z',
                      },
                      {'key': 'ends_at', 'value': '2026-12-01T00:00:00Z'},
                    ],
                  },
                },
                {
                  'node': {
                    'handle': 'gid-only',
                    'fields': [
                      {'key': 'title', 'value': 'Sin handle'},
                      {
                        'key': 'collectionId',
                        'value': 'gid://shopify/Collection/3',
                      },
                    ],
                  },
                },
              ],
            },
          },
        },
      ),
    );

    final content = await repository.fetch();
    final banner = content.seasonalBanners.first;

    expect(content.seasonalBanners, hasLength(2));
    expect(banner.id, 'otono-2026');
    expect(banner.imageUrl, 'https://cdn.shopify.com/banner.jpg');
    expect(banner.ipadImageUrl, isNull);
    expect(banner.collectionHandle, 'otono');
    expect(banner.ctaText, 'VER COLECCIÓN');
    expect(banner.startsAt, DateTime.utc(2026, 9, 1));
    expect(content.seasonalBanners.last.collectionHandle, isNull);
    expect(
      content.seasonalBanners.last.collectionId,
      'gid://shopify/Collection/3',
    );
    expect(
      pickActiveSeasonalCampaign(
        content.seasonalBanners,
        DateTime.utc(2026, 10, 14),
      )?.title,
      'Nueva temporada',
    );
  });

  test('a missing seasonal definition does not drop the other content',
      () async {
    var calls = 0;
    final repository = EditorialContentRepository(
      client: StorefrontClient(
        config: const StorefrontConfig(
          shopDomain: 'shop.example.com',
          accessToken: 'public-token',
        ),
        transport: (_, __, ___) async {
          calls += 1;
          if (calls == 2) {
            return {
              'errors': [
                {'message': 'Type app_seasonal_banner does not exist'},
              ],
            };
          }
          return {
            'data': {
              'about': {
                'fields': [
                  {'key': 'headline', 'value': 'Sigue en pie'},
                ],
              },
              'partner': null,
              'catalogs': null,
            },
          };
        },
      ),
    );

    final content = await repository.fetch();

    expect(content.about.headline, 'Sigue en pie');
    expect(content.seasonalBanners, isEmpty);
  });
}
