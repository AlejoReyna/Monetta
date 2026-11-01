import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/cart_controller.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/shopify/cart/cart_api.dart';
import 'package:monetta_app/data/shopify/cart/cart_repository.dart';
import 'package:monetta_app/data/shopify/cart/cart_session_store.dart';
import 'package:monetta_app/data/shopify/shopify_gid.dart';
import 'package:monetta_app/domain/cart.dart';
import 'package:monetta_app/features/checkout/shopify_cart_summary.dart';

void main() {
  const scope = CartSessionScope.guest(shopDomain: 'staging.invalid');
  final intent = [
    LocalCartIntent(variantId: shopifyVariantGid(4), quantity: 1),
  ];

  Future<void> pumpSummary(
    WidgetTester tester, {
    required CartController controller,
    VoidCallback? onContinue,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ShopifyCartSummary(
              controller: controller,
              scope: scope,
              localIntent: intent,
              onContinue: onContinue ?? () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
      'CHAR-BAG-01 summary matches the theme cart: item count, formatted '
      'amounts, discount row and estimated total', (tester) async {
    final controller = CartController(
      reconciler: _WidgetReconciler(totalEstimated: true),
    );
    await controller.reconcileLocalBag(scope: scope, localIntent: intent);
    await pumpSummary(tester, controller: controller);

    expect(find.text('Resumen de compra'), findsOneWidget);
    expect(find.text('Subtotal (1 artículo)'), findsOneWidget);
    expect(find.text(r'$ 4,842.00'), findsOneWidget);
    expect(find.text('Descuento automático'), findsOneWidget);
    expect(find.text('−\$ 149.50'), findsOneWidget);
    expect(find.text('Envío'), findsOneWidget);
    expect(find.text('Se calcula en Shopify'), findsOneWidget);
    expect(find.text('Total estimado'), findsOneWidget);
    expect(find.text(r'$ 4,692.50 MXN'), findsOneWidget);

    // The old Shopify-branded labels and raw decimal strings are gone.
    expect(find.textContaining('Subtotal de Shopify'), findsNothing);
    expect(find.textContaining('Total de Shopify'), findsNothing);
    expect(find.text('4842.0 MXN'), findsNothing);
    expect(find.text('4692.5000 MXN'), findsNothing);
    expect(find.text('−149.5000 MXN'), findsNothing);
    expect(find.text('Gratis'), findsNothing);
  });

  testWidgets(
      'CHAR-BAG-02 summary uses plain "Total" when the total is not '
      'estimated and pluralises the item count from line quantities',
      (tester) async {
    final controller = CartController(
      reconciler: _WidgetReconciler(quantities: const [2, 3]),
    );
    await controller.reconcileLocalBag(scope: scope, localIntent: intent);
    await pumpSummary(tester, controller: controller);

    expect(find.text('Subtotal (5 artículos)'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Total estimado'), findsNothing);
    expect(find.text(r'$ 4,692.50 MXN'), findsOneWidget);
    expect(find.textContaining('Total de Shopify'), findsNothing);
  });

  testWidgets(
      'CHAR-BAG-03 the bag summary has no discount code field and still '
      'continues to checkout', (tester) async {
    // The person decided the app bag equals the Shopify theme cart, which has
    // no discount-code field (codes are applied in Shopify's checkout), so the
    // field, its button and its feedback are retired from the bag summary.
    final controller = CartController(reconciler: _WidgetReconciler());
    await controller.reconcileLocalBag(scope: scope, localIntent: intent);
    var continued = 0;
    await pumpSummary(
      tester,
      controller: controller,
      onContinue: () => continued++,
    );

    expect(find.byKey(const ValueKey('discount-code-field')), findsNothing);
    expect(find.byKey(const ValueKey('apply-discount-button')), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Código de descuento'), findsNothing);
    expect(find.text('APLICAR CÓDIGO'), findsNothing);

    await tester.tap(find.text('Continuar al checkout'));
    await tester.pump();
    expect(continued, 1);
  });
}

final class _WidgetReconciler implements CartReconciler {
  _WidgetReconciler({this.totalEstimated = false, this.quantities = const [1]});

  final bool totalEstimated;
  final List<int> quantities;

  @override
  Future<CartReconciliation> reconcile({
    required CartSessionScope scope,
    required Iterable<LocalCartIntent> localIntent,
    CartBuyerIdentity? buyerIdentity,
    List<String>? desiredDiscountCodes,
  }) async {
    final desired = desiredDiscountCodes ?? const [];
    if (desired.contains('ERROR')) {
      return CartReconciliation(
        status: CartReconciliationStatus.unavailable,
        cart: null,
      );
    }
    if (desired.contains('INVALID')) {
      return CartReconciliation(
        status: CartReconciliationStatus.partiallyConfirmed,
        cart: _cart(const [], quantities, totalEstimated),
        issues: [
          CartMutationIssue(
            kind: CartMutationIssueKind.userError,
            code: 'INVALID',
            message: 'El código no es válido.',
          ),
        ],
      );
    }
    return CartReconciliation(
      status: CartReconciliationStatus.authoritative,
      cart: _cart(desired, quantities, totalEstimated),
    );
  }
}

Cart _cart(List<String> codes, List<int> quantities, bool totalEstimated) {
  const subtotal = CartMoney(amount: '4842.0', currencyCode: 'MXN');
  const total = CartMoney(amount: '4692.5000', currencyCode: 'MXN');
  const discounted = CartMoney(amount: '149.5000', currencyCode: 'MXN');
  final timestamp = DateTime.utc(2026, 8, 27);
  return Cart(
    id: _opaque('cart'),
    checkoutUrl: Uri(path: _opaque('checkout')).toString(),
    createdAt: timestamp,
    updatedAt: timestamp,
    lines: [
      for (final (index, quantity) in quantities.indexed)
        CartLine(
          id: _opaque('line$index'),
          variantId: shopifyVariantGid(4 + index),
          productId: shopifyProductGid(3),
          title: 'Bolsa',
          variantTitle: 'Única',
          quantity: quantity,
          cost: const CartLineCost(
            amountPerQuantity: subtotal,
            subtotal: subtotal,
            total: total,
          ),
          discountAllocations: const [
            CartDiscountAllocation(discountedAmount: discounted),
          ],
        ),
    ],
    totalQuantity: quantities.fold(0, (sum, item) => sum + item),
    buyerIdentity: const CartBuyerSummary(
      countryCode: 'MX',
      isAuthenticated: false,
    ),
    cost: CartCost(
      subtotal: subtotal,
      total: total,
      totalEstimated: totalEstimated,
    ),
    discountCodes: [
      for (final code in codes)
        CartDiscountCode(
          code: code,
          applicable: code != 'NOT_APPLICABLE',
        ),
    ],
    discountApplications: const [
      CartDiscountApplication(
        kind: CartDiscountApplicationKind.automatic,
        allocationMethod: 'ACROSS',
        targetSelection: 'ALL',
        targetType: 'LINE_ITEM',
        title: 'Automático',
        percentage: '11.9600',
        totalAllocatedAmount: discounted,
      ),
    ],
  );
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
