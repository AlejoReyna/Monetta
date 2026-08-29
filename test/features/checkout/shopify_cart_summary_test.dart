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

  testWidgets('renders exact Shopify costs and automatic discounts',
      (tester) async {
    final controller = CartController(reconciler: _WidgetReconciler());
    await controller.reconcileLocalBag(scope: scope, localIntent: intent);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ShopifyCartSummary(
              controller: controller,
              scope: scope,
              localIntent: intent,
              onContinue: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('1250.0000 MXN'), findsOneWidget);
    expect(find.text('1100.5000 MXN'), findsOneWidget);
    expect(find.text('−149.5000 MXN'), findsOneWidget);
    expect(
      find.text('Incluye descuentos automáticos de Shopify'),
      findsOneWidget,
    );
    expect(find.text('Se calcula en Shopify'), findsOneWidget);
    expect(find.textContaining(r'$149'), findsNothing);
    expect(find.text('Gratis'), findsNothing);
  });

  testWidgets('discount field exposes applied, non-applicable and removed',
      (tester) async {
    final controller = CartController(reconciler: _WidgetReconciler());
    await controller.reconcileLocalBag(scope: scope, localIntent: intent);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ShopifyCartSummary(
              controller: controller,
              scope: scope,
              localIntent: intent,
              onContinue: () {},
            ),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('discount-code-field')),
      'save',
    );
    await tester.tap(find.byKey(const ValueKey('apply-discount-button')));
    await tester.pump();
    expect(find.text('Descuento aplicado.'), findsOneWidget);
    expect(find.text('Aplicado'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('discount-code-field')),
      'NOT_APPLICABLE',
    );
    await tester.tap(find.byKey(const ValueKey('apply-discount-button')));
    await tester.pump();
    expect(
      find.text('El código es válido, pero no aplica a esta bolsa.'),
      findsOneWidget,
    );
    expect(find.text('Válido, no aplicable'), findsOneWidget);

    await tester.tap(find.byTooltip('Eliminar código NOT_APPLICABLE'));
    await tester.pump();
    await tester.tap(find.byTooltip('Eliminar código SAVE'));
    await tester.pump();
    expect(find.text('Código eliminado.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('discount-code-field')),
      'ERROR',
    );
    await tester.tap(find.byKey(const ValueKey('apply-discount-button')));
    await tester.pump();
    expect(
      find.text('No se pudo confirmar el descuento. Inténtalo de nuevo.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('apply-discount-button')), findsOneWidget);
    expect(find.text('No confirmado'), findsOneWidget);
    await tester.tap(find.byTooltip('Eliminar código ERROR'));
    await tester.pump();
    expect(find.text('Código eliminado.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('discount-code-field')),
      'INVALID',
    );
    await tester.tap(find.byKey(const ValueKey('apply-discount-button')));
    await tester.pump();
    expect(
      find.text('Shopify no reconoció uno de los códigos.'),
      findsOneWidget,
    );
    expect(find.text('Inválido'), findsOneWidget);
  });
}

final class _WidgetReconciler implements CartReconciler {
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
        cart: _cart(const []),
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
      cart: _cart(desired),
    );
  }
}

Cart _cart(List<String> codes) {
  const subtotal = CartMoney(amount: '1250.0000', currencyCode: 'MXN');
  const total = CartMoney(amount: '1100.5000', currencyCode: 'MXN');
  const discounted = CartMoney(amount: '149.5000', currencyCode: 'MXN');
  final timestamp = DateTime.utc(2026, 8, 27);
  return Cart(
    id: _opaque('cart'),
    checkoutUrl: Uri(path: _opaque('checkout')).toString(),
    createdAt: timestamp,
    updatedAt: timestamp,
    lines: [
      CartLine(
        id: _opaque('line'),
        variantId: shopifyVariantGid(4),
        productId: shopifyProductGid(3),
        title: 'Bolsa',
        variantTitle: 'Única',
        quantity: 1,
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
    totalQuantity: 1,
    buyerIdentity: const CartBuyerSummary(
      countryCode: 'MX',
      isAuthenticated: false,
    ),
    cost: const CartCost(subtotal: subtotal, total: total),
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
