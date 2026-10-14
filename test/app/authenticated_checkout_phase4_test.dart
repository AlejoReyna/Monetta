// Fase 4 — checkout autenticado (Customer Account API + Checkout Kit).
//
// Locks the guest-first contract with fakes only: no network, no tokens in
// fixtures, no staging mutations. Live staging (real Storefront + real
// Checkout Kit + test orders) still needs the owner's point authorization.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/cart_controller.dart';
import 'package:monetta_app/app/shopify_checkout_coordinator.dart';
import 'package:monetta_app/data/customer_auth/secure_token_store.dart';
import 'package:monetta_app/data/local/secure_cart_session_store.dart';
import 'package:monetta_app/data/shopify/cart/cart_api.dart';
import 'package:monetta_app/data/shopify/cart/cart_repository.dart';
import 'package:monetta_app/data/shopify/cart/cart_session_store.dart';
import 'package:monetta_app/data/shopify/cart/checkout_launcher.dart';
import 'package:monetta_app/data/shopify/cart/storefront_cart_api.dart';
import 'package:monetta_app/data/shopify/shopify_gid.dart';
import 'package:monetta_app/data/shopify/storefront_client.dart';
import 'package:monetta_app/data/shopify/storefront_config.dart';
import 'package:monetta_app/domain/cart.dart';

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
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

Map<String, dynamic> _cartJson(String cartId) => {
      'id': cartId,
      'checkoutUrl': Uri(
        scheme: 'https',
        host: 'staging.invalid',
        path: '/${_opaque('checkout')}',
      ).toString(),
      'createdAt': '2026-08-27T00:00:00Z',
      'updatedAt': '2026-08-27T00:01:00Z',
      'totalQuantity': 0,
      'buyerIdentity': {'countryCode': 'MX', 'customer': null},
      'cost': {
        'checkoutChargeAmount': null,
        'subtotalAmount': {'amount': '0.00', 'currencyCode': 'MXN'},
        'subtotalAmountEstimated': false,
        'totalAmount': {'amount': '0.00', 'currencyCode': 'MXN'},
        'totalAmountEstimated': true,
      },
      'discountCodes': <dynamic>[],
      'discountApplications': <dynamic>[],
      'lines': {'edges': <dynamic>[]},
    };

final class _RecordingTransport {
  final List<Map<String, dynamic>> variables = [];
  final List<String> operations = [];
  Future<Map<String, dynamic>> Function(Map<String, dynamic> variables)?
      onBuyerIdentityUpdate;

  Future<Map<String, dynamic>> call(
    Uri endpoint,
    Map<String, String> headers,
    String body,
  ) async {
    final request = jsonDecode(body) as Map<String, dynamic>;
    final requestVariables = request['variables'] as Map<String, dynamic>;
    variables.add(requestVariables);
    final document = request['query'] as String;
    final operation =
        RegExp(r'(?:query|mutation) (\w+)').firstMatch(document)!.group(1)!;
    operations.add(operation);
    if (operation == 'CartBuyerIdentityUpdate' &&
        onBuyerIdentityUpdate != null) {
      return onBuyerIdentityUpdate!(requestVariables);
    }
    return {
      'data': {
        'cartBuyerIdentityUpdate': {
          'cart': _cartJson(_opaque('cart')),
          'userErrors': <dynamic>[],
          'warnings': <dynamic>[],
        },
      },
    };
  }
}

StorefrontClient _client(_RecordingTransport transport) {
  Future<Map<String, dynamic>> send(
    Uri endpoint,
    Map<String, String> headers,
    String body,
  ) =>
      transport.call(endpoint, headers, body);
  return StorefrontClient.forCart(
    config: StorefrontConfig(
      shopDomain: 'staging.invalid',
      accessToken: _opaque('public'),
    ),
    transport: _CallbackCartTransport(query: send, mutation: send),
  );
}

final class _CallbackCartTransport implements CartStorefrontTransport {
  const _CallbackCartTransport({required GraphQLTransport query, required GraphQLTransport mutation})
      : _query = query,
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

final class _CapturingReconciler implements CartReconciler {
  CartBuyerIdentity? seenBuyerIdentity;
  int calls = 0;

  @override
  Future<CartReconciliation> reconcile({
    required CartSessionScope scope,
    required Iterable<LocalCartIntent> localIntent,
    CartBuyerIdentity? buyerIdentity,
    List<String>? desiredDiscountCodes,
  }) async {
    calls += 1;
    seenBuyerIdentity = buyerIdentity;
    return CartReconciliation(
      status: CartReconciliationStatus.authoritative,
      cart: _authoritativeCart(),
    );
  }
}

Cart _authoritativeCart() {
  const money = CartMoney(amount: '10.00', currencyCode: 'MXN');
  final timestamp = DateTime.utc(2026, 8, 27);
  return Cart(
    id: _opaque('cart'),
    checkoutUrl: Uri(
      scheme: 'https',
      host: 'staging.invalid',
      path: '/${_opaque('checkout')}',
    ).toString(),
    createdAt: timestamp,
    updatedAt: timestamp,
    lines: [
      CartLine(
        id: _opaque('line'),
        variantId: shopifyVariantGid(1),
        productId: shopifyProductGid(1),
        title: 'Producto',
        variantTitle: 'Variante',
        quantity: 1,
        cost: const CartLineCost(
          amountPerQuantity: money,
          subtotal: money,
          total: money,
        ),
      ),
    ],
    totalQuantity: 1,
    buyerIdentity: const CartBuyerSummary(
      countryCode: 'MX',
      isAuthenticated: true,
    ),
    cost: const CartCost(subtotal: money, total: money),
  );
}

final class _CompletedLauncher implements CheckoutLauncher {
  int presentCalls = 0;

  @override
  Future<void> preload(ValidatedCheckoutUrl checkoutUrl) async {}

  @override
  Future<CheckoutResult> present(ValidatedCheckoutUrl checkoutUrl) async {
    presentCalls += 1;
    return const CheckoutCompleted();
  }

  @override
  Future<void> invalidate() async {}
}

void main() {
  group('fase 4: identidad autenticada', () {
    test('buyerIdentity autenticada lleva token + contacto + país', () async {
      final transport = _RecordingTransport();
      final api = StorefrontCartApi(_client(transport));
      const token = 'fase4-fake-token';
      final result = await api.updateBuyerIdentity(
        SensitiveCartId(_opaque('cart')),
        AuthenticatedCartBuyerIdentity(
          accessToken: SensitiveCustomerAccessToken(token),
          email: 'compradora@example.invalid',
          phone: '8111111111',
          countryCode: 'MX',
        ),
      );

      expect(result.cart, isNotNull);
      expect(transport.operations, ['CartBuyerIdentityUpdate']);
      final identity = transport.variables.single['buyerIdentity']
          as Map<String, dynamic>;
      expect(identity['customerAccessToken'], token);
      expect(identity['email'], 'compradora@example.invalid');
      expect(identity['phone'], '8111111111');
      expect(identity['countryCode'], 'MX');
    });

    test('token rechazado: conserva carrito, pide login y no filtra detalle',
        () async {
      const decoy = 'fase4-raw-shopify-detail';
      final transport = _RecordingTransport()
        ..onBuyerIdentityUpdate = (variables) async => {
              'data': {
                'cartBuyerIdentityUpdate': {
                  'cart': _cartJson(_opaque('cart')),
                  'userErrors': [
                    {
                      'field': ['buyerIdentity', 'customerAccessToken'],
                      'code': 'INVALID_CUSTOMER_ACCESS_TOKEN',
                      'message': decoy,
                    },
                  ],
                  'warnings': <dynamic>[],
                },
              },
            };
      final api = StorefrontCartApi(_client(transport));
      final result = await api.updateBuyerIdentity(
        SensitiveCartId(_opaque('cart')),
        AuthenticatedCartBuyerIdentity(
          accessToken: SensitiveCustomerAccessToken(_opaque('expired')),
        ),
      );

      // La bolsa se conserva: hay snapshot de carrito, no excepción.
      expect(result.cart, isNotNull);
      expect(result.issues, hasLength(1));
      final issue = result.issues.single;
      expect(issue.kind, CartMutationIssueKind.userError);
      expect(issue.code, 'INVALID_CUSTOMER_ACCESS_TOKEN');
      expect(issue.field, contains('customerAccessToken'));
      expect(issue.isAuthenticationIssue, isTrue);
      expect(issue.message, contains('sesión'));
      expect(issue.message, contains('bolsa se conserva'));
      expect(issue.message, isNot(contains(decoy)));
      expect(result.toString(), isNot(contains(decoy)));
    });

    test('errores de línea/inventario no se confunden con auth', () {
      expect(
        CartMutationIssue.isAuthenticationSignal(
          code: 'INVALID_MERCHANDISE_LINE',
        ),
        isFalse,
      );
      expect(
        CartMutationIssue.isAuthenticationSignal(
          code: 'MERCHANDISE_OUT_OF_STOCK',
        ),
        isFalse,
      );
      expect(
        CartMutationIssue.isAuthenticationSignal(code: 'MAXIMUM_EXCEEDED'),
        isFalse,
      );
      expect(
        CartMutationIssue(
          kind: CartMutationIssueKind.userError,
          code: 'INVALID_MERCHANDISE_LINE',
          message: 'x',
        ).isAuthenticationIssue,
        isFalse,
      );
    });

    test('coordinador propaga buyerIdentity autenticada al reconciliar',
        () async {
      final reconciler = _CapturingReconciler();
      final controller = CartController(reconciler: reconciler);
      addTearDown(controller.dispose);
      final sessions = _ScopedSessions();
      final coordinator = ShopifyCheckoutCoordinator(
        launcher: _CompletedLauncher(),
        urlPolicy: CheckoutUrlPolicy.forShopDomain('staging.invalid'),
        sessions: sessions,
      );
      const scope = CartSessionScope.authenticated(
        shopDomain: 'staging.invalid',
        localAccountId: 'local-fase4',
      );
      final identity = AuthenticatedCartBuyerIdentity(
        accessToken: SensitiveCustomerAccessToken(_opaque('token')),
        email: 'compradora@example.invalid',
        countryCode: 'MX',
      );

      final result = await coordinator.present(
        controller: controller,
        scope: scope,
        localIntent: [
          LocalCartIntent(variantId: shopifyVariantGid(1), quantity: 1),
        ],
        buyerIdentity: identity,
        onCompleted: (_) async {},
      );

      expect(result, isA<CheckoutCompleted>());
      expect(reconciler.calls, 1);
      expect(identical(reconciler.seenBuyerIdentity, identity), isTrue);
      expect(reconciler.seenBuyerIdentity?.isAuthenticated, isTrue);
      expect(await sessions.read(scope), isNull);
    });

    test('sesiones separan guest/cuentas sin reutilizar carrito ajeno',
        () async {
      final backing = _MemorySecureStore();
      final sessions = SecureCartSessionStore(backing);
      const guest = CartSessionScope.guest(shopDomain: 'staging.invalid');
      const accountA = CartSessionScope.authenticated(
        shopDomain: 'staging.invalid',
        localAccountId: 'local-a',
      );
      const accountB = CartSessionScope.authenticated(
        shopDomain: 'staging.invalid',
        localAccountId: 'local-b',
      );

      await sessions.write(guest, SensitiveCartId(_opaque('guest-cart')));
      await sessions.write(accountA, SensitiveCartId(_opaque('cart-a')));

      expect((await sessions.read(guest))?.toString(), contains('<redacted>'));
      expect(await sessions.read(accountA), isNotNull);
      expect(await sessions.read(accountB), isNull);
      expect(
        (await sessions.read(accountA))!
            .revealForStorefrontRequest()
            .contains('guest'),
        isFalse,
      );

      await sessions.delete(guest);
      expect(await sessions.read(guest), isNull);
      expect(await sessions.read(accountA), isNotNull);
    });

    test('credenciales nunca aparecen en toString ni en scopes', () {
      const token = 'fase4-sensitive-token';
      final credential = SensitiveCustomerAccessToken(token);
      final identity = AuthenticatedCartBuyerIdentity(
        accessToken: credential,
        email: 'compradora@example.invalid',
      );
      const scope = CartSessionScope.authenticated(
        shopDomain: 'staging.invalid',
        localAccountId: 'local-fase4',
      );

      for (final rendered in [
        '$credential',
        '$identity',
        '$scope',
        identity.toString(),
      ]) {
        expect(rendered, isNot(contains(token)));
      }
      expect('$credential', contains('<redacted>'));
      expect('$identity', contains('<redacted>'));
      expect('$scope', isNot(contains('local-fase4')));
    });
  });
}

final class _ScopedSessions implements CartSessionStore {
  final Map<CartSessionScope, SensitiveCartId> _values = {};

  @override
  Future<SensitiveCartId?> read(CartSessionScope scope) async =>
      _values[scope];

  @override
  Future<void> write(CartSessionScope scope, SensitiveCartId cartId) async {
    _values[scope] = cartId;
  }

  @override
  Future<void> delete(CartSessionScope scope) async {
    _values.remove(scope);
  }
}
