import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monetta_app/app/account_controller.dart';
import 'package:monetta_app/app/cart_controller.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/accounts_orders/accounts_orders_config.dart';
import 'package:monetta_app/data/local/account_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/order_summary_store.dart';
import 'package:monetta_app/data/repositories/order_history_repository.dart';
import 'package:monetta_app/data/shopify/cart/cart_api.dart';
import 'package:monetta_app/data/shopify/cart/cart_repository.dart';
import 'package:monetta_app/data/shopify/cart/cart_session_store.dart';
import 'package:monetta_app/data/shopify/shopify_gid.dart';
import 'package:monetta_app/domain/cart.dart';
import 'package:monetta_app/features/checkout/shopify_cart_summary.dart';
import 'package:monetta_app/features/rewards/rewards_api.dart';
import 'package:monetta_app/main.dart';

void main() {
  const scope = CartSessionScope.authenticated(
    shopDomain: 'staging.invalid',
    localAccountId: 'cust-77',
  );
  final intent = [
    LocalCartIntent(variantId: shopifyVariantGid(4), quantity: 1),
  ];

  testWidgets(
      'quotes, toggles, redeems, applies code with authenticated buyerIdentity, and releases on remove',
      (tester) async {
    var quoteCalls = 0;
    var redeemCalls = 0;
    var releaseCalls = 0;
    final mockHttp = MockClient((request) async {
      if (request.url.path == '/customers/me/rewards/quotes') {
        quoteCalls += 1;
        return http.Response(
          jsonEncode({
            'quoteId': 'quote-1',
            'cartRevision': 'rev',
            'subtotalEligibleCents': 100000,
            'availableCents': 6000,
            'maxAllowedCents': 6000,
            'estimatedEarnCents': 3000,
            'redemptionEnabled': true,
            'expiresAt': DateTime.now()
                .add(const Duration(minutes: 10))
                .toIso8601String(),
          }),
          201,
        );
      }
      if (request.url.path == '/customers/me/rewards/redemptions') {
        redeemCalls += 1;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['quoteId'], 'quote-1');
        expect(body['amountCents'], 6000);
        return http.Response(
          jsonEncode({
            'redemption': {
              'redemptionId': 'redemp-1',
              'state': 'applied',
              'requestedCents': 6000,
            },
            'reused': false,
            'discount': {'code': 'MRW-1234567890'},
          }),
          201,
        );
      }
      if (request.url.path ==
          '/customers/me/rewards/redemptions/redemp-1/release') {
        releaseCalls += 1;
        return http.Response(
          jsonEncode({
            'redemption': {'redemptionId': 'redemp-1', 'state': 'released'},
          }),
          200,
        );
      }
      return http.Response('not found', 404);
    });

    final database = openTestDatabase();
    final accountController = _FakeAccountController(database)
      ..account = Account(
        localAccountId: 'cust-77',
        authProvider: 'shopify',
        email: 'ana@example.com',
        createdAt: DateTime.utc(2026, 9, 1),
        lastSeenAt: DateTime.utc(2026, 9, 1),
      );
    final reconciler = _RewardsCartReconciler();
    final cartController = CartController(reconciler: reconciler);
    await cartController.reconcileLocalBag(scope: scope, localIntent: intent);

    final rewardsApi = RewardsApi(
      baseUrl: 'https://rewards.invalid',
      tokenProvider: () async => 'backend-token',
      client: mockHttp,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: AccountScope(
          notifier: accountController,
          child: Scaffold(
            body: SingleChildScrollView(
              child: ShopifyCartSummary(
                controller: cartController,
                scope: scope,
                localIntent: intent,
                rewardsApi: rewardsApi,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(quoteCalls, 1);
    expect(
      find.byKey(const ValueKey('checkout-rewards-panel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('rewards-redemption-control')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('rewards-redemption-toggle')));
    await tester.pump();
    expect(find.text('Usar \$60 Monetta'), findsOneWidget);

    await tester.tap(find.text('APLICAR REWARDS'));
    await tester.pumpAndSettle();

    expect(redeemCalls, 1);
    expect(reconciler.lastBuyerIdentity, isA<AuthenticatedCartBuyerIdentity>());
    expect(
      (reconciler.lastBuyerIdentity! as AuthenticatedCartBuyerIdentity)
          .accessToken
          .revealForStorefrontRequest(),
      'shopify-cust-token',
    );
    expect(
      find.byKey(const ValueKey('checkout-rewards-applied')),
      findsOneWidget,
    );
    expect(find.textContaining('MRW-1234567890'), findsWidgets);
    expect(cartController.snapshot?.cart?.cost.total.amount, '940.00');

    await tester.tap(find.byKey(const ValueKey('checkout-rewards-remove')));
    await tester.pumpAndSettle();

    expect(releaseCalls, 1);
    expect(
      find.byKey(const ValueKey('checkout-rewards-applied')),
      findsNothing,
    );
    expect(cartController.snapshot?.cart?.cost.total.amount, '1000.00');

    rewardsApi.close();
    cartController.dispose();
    accountController.dispose();
    await database.close();
  });

  testWidgets('displays honest error code when redemption fails',
      (tester) async {
    final mockHttp = MockClient((request) async {
      if (request.url.path == '/customers/me/rewards/quotes') {
        return http.Response(
          jsonEncode({
            'quoteId': 'quote-err',
            'cartRevision': 'rev',
            'subtotalEligibleCents': 100000,
            'availableCents': 6000,
            'maxAllowedCents': 6000,
            'estimatedEarnCents': 3000,
            'redemptionEnabled': true,
            'expiresAt': DateTime.now()
                .add(const Duration(minutes: 10))
                .toIso8601String(),
          }),
          201,
        );
      }
      if (request.url.path == '/customers/me/rewards/redemptions') {
        return http.Response(
          jsonEncode({'error': 'quote_expired'}),
          409,
        );
      }
      return http.Response('not found', 404);
    });

    final database = openTestDatabase();
    final accountController = _FakeAccountController(database)
      ..account = Account(
        localAccountId: 'cust-77',
        authProvider: 'shopify',
        createdAt: DateTime.utc(2026, 9, 1),
        lastSeenAt: DateTime.utc(2026, 9, 1),
      );
    final cartController = CartController(reconciler: _RewardsCartReconciler());
    await cartController.reconcileLocalBag(scope: scope, localIntent: intent);
    final rewardsApi = RewardsApi(
      baseUrl: 'https://rewards.invalid',
      tokenProvider: () async => 'backend-token',
      client: mockHttp,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: AccountScope(
          notifier: accountController,
          child: Scaffold(
            body: SingleChildScrollView(
              child: ShopifyCartSummary(
                controller: cartController,
                scope: scope,
                localIntent: intent,
                rewardsApi: rewardsApi,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('rewards-redemption-toggle')));
    await tester.pump();
    await tester.tap(find.text('APLICAR REWARDS'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('rewards-redemption-error')),
      findsOneWidget,
    );
    expect(
      find.text('Tu cotización venció; vuelve a calcular antes de pagar.'),
      findsOneWidget,
    );

    rewardsApi.close();
    cartController.dispose();
    accountController.dispose();
    await database.close();
  });
}

class _FakeAccountController extends AccountController {
  _FakeAccountController(AppDatabase database)
      : super(
          accountStore: AccountStore(database),
          deviceStore: DeviceStore(database),
          orderHistoryRepository: OrderHistoryRepository(
            store: OrderSummaryStore(database),
            config: AccountsOrdersConfig.disabled,
          ),
          deviceId: 'device-test',
        );

  @override
  Future<String?> accessTokenForShopifyCheckout() async => 'shopify-cust-token';
}

final class _RewardsCartReconciler implements CartReconciler {
  CartBuyerIdentity? lastBuyerIdentity;

  @override
  Future<CartReconciliation> reconcile({
    required CartSessionScope scope,
    required Iterable<LocalCartIntent> localIntent,
    CartBuyerIdentity? buyerIdentity,
    List<String>? desiredDiscountCodes,
  }) async {
    lastBuyerIdentity = buyerIdentity;
    final desired = desiredDiscountCodes ?? const [];
    final hasRewards = desired.any((c) => c.startsWith('MRW-'));
    const subtotal = CartMoney(amount: '1000.00', currencyCode: 'MXN');
    final total = hasRewards
        ? const CartMoney(amount: '940.00', currencyCode: 'MXN')
        : subtotal;
    const discountMoney = CartMoney(amount: '60.00', currencyCode: 'MXN');
    final timestamp = DateTime.utc(2026, 9, 1);
    return CartReconciliation(
      status: CartReconciliationStatus.authoritative,
      cart: Cart(
        id: 'gid://shopify/Cart/test-1',
        checkoutUrl: 'https://staging.invalid/checkout',
        createdAt: timestamp,
        updatedAt: timestamp,
        lines: [
          CartLine(
            id: 'gid://shopify/CartLine/1',
            variantId: shopifyVariantGid(4),
            productId: shopifyProductGid(3),
            title: 'Bolsa Demo',
            variantTitle: 'Negra',
            quantity: 1,
            cost: CartLineCost(
              amountPerQuantity: subtotal,
              subtotal: subtotal,
              total: total,
            ),
          ),
        ],
        totalQuantity: 1,
        buyerIdentity: const CartBuyerSummary(
          countryCode: 'MX',
          isAuthenticated: true,
        ),
        cost: CartCost(subtotal: subtotal, total: total),
        discountCodes: [
          for (final code in desired)
            CartDiscountCode(code: code, applicable: true),
        ],
        discountApplications: [
          if (hasRewards)
            CartDiscountApplication(
              kind: CartDiscountApplicationKind.code,
              allocationMethod: 'ACROSS',
              targetSelection: 'ALL',
              targetType: 'LINE_ITEM',
              code: desired.first,
              totalAllocatedAmount: discountMoney,
            ),
        ],
      ),
    );
  }
}
