import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monetta_app/data/admin/admin_client.dart';
import 'package:monetta_app/domain/admin_control.dart';

void main() {
  test(
      'canonical product save targets title, selected variant, and publication separately',
      () async {
    final requests = <http.Request>[];
    var step = 0;
    final client = HttpAdminClient(
      baseUrl: Uri.parse('https://admin.monetta.test'),
      accessTokenProvider: () async => 'owner-token',
      client: MockClient((request) async {
        requests.add(request);
        step += 1;
        final title = step >= 1 ? 'Nuevo título' : 'Original';
        final price = step >= 2 ? '125.00' : '100.00';
        final published = step < 3;
        final updatedAt = '2026-08-30T12:00:0${step + 2}.000Z';
        return http.Response.bytes(
          utf8.encode(
            jsonEncode(
              {
                'product': {
                  'id': 'gid://shopify/Product/1',
                  'title': title,
                  'descriptionHtml': '<p>Shopify</p>',
                  'imageUrl': null,
                  'price': double.parse(price),
                  'inStock': true,
                  'visible': published,
                  'variantCount': 1,
                  'status': 'ACTIVE',
                  'publishedToMonetta': published,
                  'updatedAt': updatedAt,
                  'variants': [
                    {
                      'id': 'gid://shopify/ProductVariant/1',
                      'title': 'Default Title',
                      'price': price,
                      'compareAtPrice': null,
                      'availableForSale': true,
                      'currencyCode': 'MXN',
                    },
                  ],
                },
              },
            ),
          ),
          200,
        );
      }),
    );
    final before = AdminProductRecord(
      id: 'gid://shopify/Product/1',
      title: 'Original',
      price: 100,
      inStock: true,
      visible: true,
      variantCount: 1,
      publishedToMonetta: true,
      updatedAt: DateTime.parse('2026-08-30T12:00:01.000Z'),
      variants: [
        const AdminProductVariant(
          id: 'gid://shopify/ProductVariant/1',
          title: 'Default Title',
          price: 100,
          availableForSale: true,
        ),
      ],
    );
    final next =
        before.copyWith(title: 'Nuevo título', price: 125, visible: false);

    final canonical =
        await client.updateProductCanonical(before: before, next: next);

    expect(canonical.title, 'Nuevo título');
    expect(canonical.variants.single.price, 125);
    expect(canonical.publishedToMonetta, isFalse);
    expect(requests.map((request) => '${request.method} ${request.url.path}'), [
      'PATCH /admin/products/gid%3A%2F%2Fshopify%2FProduct%2F1',
      'PATCH /admin/products/gid%3A%2F%2Fshopify%2FProduct%2F1/variants/gid%3A%2F%2Fshopify%2FProductVariant%2F1',
      'PUT /admin/products/gid%3A%2F%2Fshopify%2FProduct%2F1/publication',
    ]);
    expect(
      requests.map((request) => request.headers['Idempotency-Key']),
      everyElement(isNotEmpty),
    );
    expect(
      requests.map((request) => request.headers['Idempotency-Key']).toSet(),
      hasLength(3),
    );
    expect(jsonDecode(requests[1].body), {
      'price': '125.00',
      'expectedProductUpdatedAt': '2026-08-30T12:00:03.000Z',
    });
    client.close();
  });
}
