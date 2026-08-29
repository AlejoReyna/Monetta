import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/shopify/editorial_content_repository.dart';
import 'package:monetta_app/data/shopify/storefront_client.dart';
import 'package:monetta_app/data/shopify/storefront_config.dart';
import 'package:monetta_app/domain/editorial_content.dart';

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
  });
}
