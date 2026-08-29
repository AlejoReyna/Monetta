import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monetta_app/app/shopify_cart_composition.dart';
import 'package:monetta_app/app/cart_controller.dart';
import 'package:monetta_app/data/customer_auth/secure_token_store.dart';
import 'package:monetta_app/data/local/secure_cart_session_store.dart';
import 'package:monetta_app/data/shopify/cart/cart_api.dart';
import 'package:monetta_app/data/shopify/cart/cart_repository.dart';
import 'package:monetta_app/data/shopify/cart/cart_session_store.dart';
import 'package:monetta_app/data/shopify/cart_attribution.dart';
import 'package:monetta_app/data/shopify/http_storefront_transport.dart';
import 'package:monetta_app/data/shopify/shopify_gid.dart';
import 'package:monetta_app/data/shopify/storefront_config.dart';

void main() {
  test('production composition uses one mutation attempt then read recovery',
      () async {
    const scope = CartSessionScope.guest(shopDomain: 'staging.invalid');
    final cartId = _opaque('cart');
    final variantId = shopifyVariantGid(909);
    final secureStore = _MemorySecureStore();
    await SecureCartSessionStore(secureStore).write(
      scope,
      SensitiveCartId(cartId),
    );

    var httpCalls = 0;
    var mutationCalls = 0;
    var queryCalls = 0;
    final operations = <String>[];
    final transport = HttpStorefrontTransport(
      client: MockClient((request) async {
        httpCalls += 1;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final document = body['query'] as String;
        final operation =
            RegExp(r'(?:query|mutation) (\w+)').firstMatch(document)!.group(1)!;
        operations.add(operation);
        if (operation == 'CartLinesAdd') {
          mutationCalls += 1;
          return http.Response('unavailable', 503);
        }
        queryCalls += 1;
        return http.Response(
          jsonEncode({
            'data': {
              'cart': _cartJson(
                cartId: cartId,
                variantId: variantId,
                withLine: queryCalls > 1,
              ),
            },
          }),
          200,
        );
      }),
      maxAttempts: 3,
      baseBackoff: Duration.zero,
    );
    final composition = ShopifyCartComposition.production(
      config: StorefrontConfig(
        shopDomain: 'staging.invalid',
        accessToken: _opaque('public'),
      ),
      transport: transport,
      secureStore: secureStore,
      attribution: const CartAttribution(
        platform: 'test',
        deviceId: 'device-local',
        appVersion: '0',
      ),
    );

    expect(httpCalls, 0, reason: 'composition must not start network work');
    await composition.controller.reconcileLocalBag(
      scope: scope,
      localIntent: [LocalCartIntent(variantId: variantId, quantity: 1)],
    );

    expect(operations, ['Cart', 'CartLinesAdd', 'Cart']);
    expect(mutationCalls, 1);
    expect(queryCalls, 2);
    expect(httpCalls, 3);
    expect(
      composition.controller.snapshot?.status,
      CartReconciliationStatus.authoritative,
    );
    expect(composition.controller.snapshot?.cart?.lines.single.quantity, 1);

    composition.controller.dispose();
    transport.close();
  });

  test('discount timeout performs one write followed by authoritative read',
      () async {
    const scope = CartSessionScope.guest(shopDomain: 'staging.invalid');
    final cartId = _opaque('discount-cart');
    final variantId = shopifyVariantGid(919);
    final secureStore = _MemorySecureStore();
    await SecureCartSessionStore(secureStore).write(
      scope,
      SensitiveCartId(cartId),
    );
    var mutationCalls = 0;
    var queryCalls = 0;
    final operations = <String>[];
    final transport = HttpStorefrontTransport(
      client: MockClient((request) async {
        final document = (jsonDecode(request.body)
            as Map<String, dynamic>)['query'] as String;
        final operation =
            RegExp(r'(?:query|mutation) (\w+)').firstMatch(document)!.group(1)!;
        operations.add(operation);
        if (operation == 'CartDiscountCodesUpdate') {
          mutationCalls += 1;
          return http.Response('unavailable', 503);
        }
        queryCalls += 1;
        return http.Response(
          jsonEncode({
            'data': {
              'cart': _cartJson(
                cartId: cartId,
                variantId: variantId,
                withLine: true,
                discountCodes: queryCalls > 1 ? const ['SAVE'] : const [],
              ),
            },
          }),
          200,
        );
      }),
      maxAttempts: 3,
      baseBackoff: Duration.zero,
    );
    final composition = ShopifyCartComposition.production(
      config: StorefrontConfig(
        shopDomain: 'staging.invalid',
        accessToken: _opaque('public'),
      ),
      transport: transport,
      secureStore: secureStore,
      attribution: const CartAttribution(
        platform: 'test',
        deviceId: 'device-local',
        appVersion: '0',
      ),
    );

    await composition.controller.replaceDiscountCodes(
      scope: scope,
      localIntent: [LocalCartIntent(variantId: variantId, quantity: 1)],
      discountCodes: const ['SAVE'],
    );

    expect(operations, ['Cart', 'CartDiscountCodesUpdate', 'Cart']);
    expect(mutationCalls, 1);
    expect(queryCalls, 2);
    expect(
      composition.controller.discountStatus,
      CartDiscountUpdateStatus.applied,
    );
    composition.controller.dispose();
    transport.close();
  });
}

Map<String, dynamic> _cartJson({
  required String cartId,
  required String variantId,
  required bool withLine,
  List<String> discountCodes = const [],
}) =>
    {
      'id': cartId,
      'checkoutUrl': Uri(path: _opaque('checkout')).toString(),
      'createdAt': '2026-08-27T00:00:00Z',
      'updatedAt': '2026-08-27T00:01:00Z',
      'totalQuantity': withLine ? 1 : 0,
      'buyerIdentity': {'countryCode': 'MX', 'customer': null},
      'cost': {
        'checkoutChargeAmount': null,
        'subtotalAmount': {'amount': '10.00', 'currencyCode': 'MXN'},
        'subtotalAmountEstimated': false,
        'totalAmount': {'amount': '10.00', 'currencyCode': 'MXN'},
        'totalAmountEstimated': true,
      },
      'discountCodes': [
        for (final code in discountCodes) {'code': code, 'applicable': true},
      ],
      'discountApplications': <dynamic>[],
      'lines': {
        'edges': withLine
            ? [
                {
                  'node': {
                    'id': _opaque('line'),
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
                      'id': variantId,
                      'title': 'Variante',
                      'image': null,
                      'product': {
                        'id': shopifyProductGid(90),
                        'title': 'Producto',
                        'handle': 'producto',
                      },
                    },
                  },
                },
              ]
            : <dynamic>[],
      },
    };

String _opaque(String suffix) => String.fromCharCodes([
      111,
      112,
      97,
      113,
      117,
      101,
      ...suffix.codeUnits,
    ]);

final class _MemorySecureStore implements SecureTokenStore {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
