import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/shopify/cart/cart_api.dart';
import 'package:monetta_app/data/shopify/cart/cart_write_coordinator.dart';
import 'package:monetta_app/data/shopify/cart/storefront_cart_api.dart';
import 'package:monetta_app/data/shopify/queries.dart';
import 'package:monetta_app/data/shopify/shopify_gid.dart';
import 'package:monetta_app/data/shopify/storefront_client.dart';
import 'package:monetta_app/data/shopify/storefront_config.dart';

void main() {
  test('2026-07 cart documents request authoritative fields and feedback', () {
    expect(kCartFragment, contains('updatedAt'));
    expect(kCartFragment, contains('buyerIdentity'));
    expect(kCartFragment, contains('totalAmount'));
    expect(kCartFragment, contains('discountCodes'));
    expect(kCartFragment, contains('discountApplications'));
    expect(
      kCartFragment,
      contains('discountAllocations(lineLevelOnly: false)'),
    );
    expect(kCartFragment, contains('lines(first: 250)'));
    for (final document in [
      kCartCreateMutation,
      kCartLinesAddMutation,
      kCartLinesUpdateMutation,
      kCartLinesRemoveMutation,
      kCartBuyerIdentityUpdateMutation,
      kCartDiscountCodesUpdateMutation,
    ]) {
      expect(document, contains('userErrors { field code message }'));
      expect(document, contains('warnings { code message target }'));
    }
  });

  test('maps create/get/add/update/remove/buyer identity and safe issues',
      () async {
    final transport = _CartTransport();
    final api = StorefrontCartApi(_client(transport.call, transport.call));
    final cartId = SensitiveCartId(transport.cartId);
    final variant = shopifyVariantGid(707);
    final customerCredential = SensitiveCustomerAccessToken(_opaque('buyer'));

    final created = await api.create(
      lines: [CartLineCreateInput(merchandiseId: variant, quantity: 1)],
      attributes: const {'_channel': 'app'},
      buyerIdentity: const GuestCartBuyerIdentity(),
    );
    final fetched = await api.get(cartId);
    await api.addLines(
      cartId,
      [CartLineCreateInput(merchandiseId: variant, quantity: 1)],
    );
    await api.updateLines(
      cartId,
      [CartLineUpdateInput(lineId: transport.lineId, quantity: 2)],
    );
    await api.removeLines(cartId, [transport.lineId]);
    await api.updateBuyerIdentity(
      cartId,
      AuthenticatedCartBuyerIdentity(accessToken: customerCredential),
    );
    await api.replaceDiscountCodes(cartId, const ['WELCOME', 'VIP']);

    expect(created.cart, isNotNull);
    expect(fetched?.cost.total.amount, '10.00');
    expect(created.issues, hasLength(2));
    expect(created.issues.first.message, 'Una variante ya no está disponible.');
    expect(created.issues.last.message, 'Una variante está agotada.');
    expect(created.issues.join(), isNot(contains(transport.cartId)));
    expect(transport.operations, [
      'CartCreate',
      'Cart',
      'CartLinesAdd',
      'CartLinesUpdate',
      'CartLinesRemove',
      'CartBuyerIdentityUpdate',
      'CartDiscountCodesUpdate',
    ]);
    expect(transport.requestBodies.join(), isNotEmpty);
    expect(
      transport.requestedVariables[transport.operations
          .indexOf('CartBuyerIdentityUpdate')]['buyerIdentity'],
      containsPair(
        'customerAccessToken',
        customerCredential.revealForStorefrontRequest(),
      ),
    );
  });

  test('ambiguous mutation is surfaced for read recovery, never retried',
      () async {
    var mutationCalls = 0;
    Future<Map<String, dynamic>> ambiguous(
      Uri endpoint,
      Map<String, String> headers,
      String body,
    ) async {
      mutationCalls += 1;
      throw const StorefrontException(
        'Storefront request timed out',
        isAmbiguous: true,
      );
    }

    final api = StorefrontCartApi(_client(_CartTransport().call, ambiguous));
    await expectLater(
      api.addLines(
        SensitiveCartId(_opaque('cart')),
        [
          CartLineCreateInput(
            merchandiseId: shopifyVariantGid(808),
            quantity: 1,
          ),
        ],
      ),
      throwsA(
        isA<AmbiguousCartWriteException>().having(
          (error) => error.operation,
          'operation',
          CartWriteOperation.addLines,
        ),
      ),
    );
    expect(mutationCalls, 1);
  });

  test('discount mutation sends the complete requested set', () async {
    final transport = _CartTransport();
    final api = StorefrontCartApi(_client(transport.call, transport.call));
    await api.replaceDiscountCodes(
      SensitiveCartId(transport.cartId),
      const ['FIRST', 'SECOND'],
    );

    expect(transport.operations, ['CartDiscountCodesUpdate']);
    expect(
      transport.requestedVariables.single['discountCodes'],
      ['FIRST', 'SECOND'],
    );
  });
}

StorefrontClient _client(
  GraphQLTransport query,
  GraphQLTransport? mutation,
) {
  final config = StorefrontConfig(
    shopDomain: 'staging.invalid',
    accessToken: _opaque('public'),
  );
  if (mutation == null) {
    return StorefrontClient(config: config, transport: query);
  }
  return StorefrontClient.forCart(
    config: config,
    transport: _CallbackCartTransport(query: query, mutation: mutation),
  );
}

final class _CallbackCartTransport implements CartStorefrontTransport {
  const _CallbackCartTransport({
    required GraphQLTransport query,
    required GraphQLTransport mutation,
  })  : _query = query,
        _mutation = mutation;

  final GraphQLTransport _query;
  final GraphQLTransport _mutation;

  @override
  Future<Map<String, dynamic>> query(
    Uri endpoint,
    Map<String, String> headers,
    String body,
  ) =>
      _query(endpoint, headers, body);

  @override
  Future<Map<String, dynamic>> mutate(
    Uri endpoint,
    Map<String, String> headers,
    String body,
  ) =>
      _mutation(endpoint, headers, body);
}

String _opaque(String suffix) => String.fromCharCodes([
      111,
      112,
      97,
      113,
      117,
      101,
      ...suffix.codeUnits,
    ]);

final class _CartTransport {
  final String cartId = _opaque('cart');
  final String lineId = _opaque('line');
  final List<String> operations = [];
  final List<String> requestBodies = [];
  final List<Map<String, dynamic>> requestedVariables = [];

  Future<Map<String, dynamic>> call(
    Uri endpoint,
    Map<String, String> headers,
    String body,
  ) async {
    requestBodies.add(body);
    final request = jsonDecode(body) as Map<String, dynamic>;
    requestedVariables.add(request['variables'] as Map<String, dynamic>);
    final document = request['query'] as String;
    final operation =
        RegExp(r'(?:query|mutation) (\w+)').firstMatch(document)!.group(1)!;
    operations.add(operation);
    if (operation == 'Cart') {
      return {
        'data': {'cart': _cartJson()},
      };
    }
    final payloadKey = switch (operation) {
      'CartCreate' => 'cartCreate',
      'CartLinesAdd' => 'cartLinesAdd',
      'CartLinesUpdate' => 'cartLinesUpdate',
      'CartLinesRemove' => 'cartLinesRemove',
      'CartBuyerIdentityUpdate' => 'cartBuyerIdentityUpdate',
      'CartDiscountCodesUpdate' => 'cartDiscountCodesUpdate',
      _ => throw StateError('unexpected operation'),
    };
    return {
      'data': {
        payloadKey: {
          'cart': _cartJson(),
          'userErrors': operation == 'CartCreate'
              ? [
                  {
                    'field': ['lines'],
                    'code': 'INVALID_MERCHANDISE_LINE',
                    'message': cartId,
                  },
                ]
              : <dynamic>[],
          'warnings': operation == 'CartCreate'
              ? [
                  {
                    'code': 'MERCHANDISE_OUT_OF_STOCK',
                    'message': cartId,
                    'target': lineId,
                  },
                ]
              : <dynamic>[],
        },
      },
    };
  }

  Map<String, dynamic> _cartJson() => {
        'id': cartId,
        'checkoutUrl': Uri(path: _opaque('checkout')).toString(),
        'createdAt': '2026-08-27T00:00:00Z',
        'updatedAt': '2026-08-27T00:01:00Z',
        'totalQuantity': 1,
        'buyerIdentity': {'countryCode': 'MX', 'customer': null},
        'cost': {
          'checkoutChargeAmount': null,
          'subtotalAmount': {'amount': '10.00', 'currencyCode': 'MXN'},
          'subtotalAmountEstimated': false,
          'totalAmount': {'amount': '10.00', 'currencyCode': 'MXN'},
          'totalAmountEstimated': true,
        },
        'discountCodes': <dynamic>[],
        'discountApplications': <dynamic>[],
        'lines': {
          'edges': [
            {
              'node': {
                'id': lineId,
                'quantity': 1,
                'cost': {
                  'amountPerQuantity': {
                    'amount': '10.00',
                    'currencyCode': 'MXN',
                  },
                  'compareAtAmountPerQuantity': null,
                  'subtotalAmount': {
                    'amount': '10.00',
                    'currencyCode': 'MXN',
                  },
                  'totalAmount': {
                    'amount': '10.00',
                    'currencyCode': 'MXN',
                  },
                },
                'merchandise': {
                  'id': shopifyVariantGid(707),
                  'title': 'Variante',
                  'image': null,
                  'product': {
                    'id': shopifyProductGid(70),
                    'title': 'Producto',
                    'handle': 'producto',
                  },
                },
              },
            },
          ],
        },
      };
}
