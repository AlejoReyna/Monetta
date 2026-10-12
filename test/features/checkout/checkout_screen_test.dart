import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/account_controller.dart';
import 'package:monetta_app/app/cart_controller.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/accounts_orders/accounts_orders_config.dart';
import 'package:monetta_app/data/local/account_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/order_summary_store.dart';
import 'package:monetta_app/data/repositories/order_history_repository.dart';
import 'package:monetta_app/data/shopify/cart/cart_api.dart';
import 'package:monetta_app/data/shopify/cart/cart_repository.dart';
import 'package:monetta_app/data/shopify/cart/cart_session_store.dart';
import 'package:monetta_app/data/shopify/cart/checkout_launcher.dart';
import 'package:monetta_app/data/shopify/shopify_gid.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/domain/cart.dart';
import 'package:monetta_app/features/checkout/checkout_screen.dart';
import 'package:monetta_app/features/checkout/shopify_cart_summary.dart';
import 'package:monetta_app/main.dart';

Future<CatalogStore> _loadedStore() async {
  final store = CatalogStore(database: openTestDatabase());
  await store.loadFromAsset();
  return store;
}

Widget _app(CatalogStore store, Widget child) {
  return MaterialApp(
    theme: buildTheme(),
    home: StoreScope(notifier: store, child: child),
  );
}

void main() {
  testWidgets('an empty bag offers a clear route back to shopping',
      (tester) async {
    final store = await _loadedStore();
    await tester.pumpWidget(_app(store, const BagScreen()));

    expect(find.text('Tu bolsa está vacía'), findsOneWidget);
    expect(find.text('VOLVER A LA TIENDA'), findsOneWidget);
    expect(find.text('SEGURO'), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
  });

  testWidgets('bag quantities stay editable and update the order total',
      (tester) async {
    final store = await _loadedStore();
    final product = store.products.firstWhere((item) => item.isInStock);
    await store.addToBag(product);

    await tester.pumpWidget(_app(store, const BagScreen()));
    await tester.pump();

    expect(find.text(product.title), findsOneWidget);
    expect(find.text('Continuar al checkout'), findsOneWidget);

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Mi bolsa'),
      ),
      findsOneWidget,
    );
    final headingRow = find.byKey(const ValueKey('bag-heading-row'));
    expect(
      find.descendant(of: headingRow, matching: find.text('Mi bolsa')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: headingRow, matching: find.text('1 artículo')),
      findsOneWidget,
    );
    expect(
      find.text('Piezas originales importadas de Estados Unidos'),
      findsNothing,
    );

    final summary = find.byKey(const ValueKey('bag-order-summary'));
    expect(summary, findsOneWidget);
    // Boutique card: 20pt page margins, not full-bleed.
    expect(tester.getTopLeft(summary).dx, 20);
    expect(
      tester.getSize(summary).width,
      tester.getSize(find.byType(Scaffold).first).width - 40,
    );
    expect(store.bagQuantity, 1);

    await tester.tap(find.byTooltip('Agregar uno'));
    await tester.pump();

    expect(store.bagQuantity, 2);
    expect(find.text('2'), findsWidgets);
  });

  testWidgets('guest contact never simulates payment without a Shopify bridge',
      (tester) async {
    final store = await _loadedStore();
    await store.addToBag(store.products.firstWhere((item) => item.isInStock));

    await tester.pumpWidget(_app(store, const CheckoutFlowScreen()));
    await tester.pump();

    expect(find.text('SEGURO'), findsOneWidget);
    expect(find.text('¿Cómo te contactamos?'), findsOneWidget);
    expect(
      find.textContaining('dirección y el envío se capturan en el checkout'),
      findsOneWidget,
    );

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), 'ana@example.com');
    await tester.enterText(fields.at(1), '8112345678');

    await tester.ensureVisible(find.text('REVISAR PEDIDO'));
    await tester.tap(find.text('REVISAR PEDIDO'));
    await tester.pumpAndSettle();

    expect(find.text('Todo listo'), findsOneWidget);
    expect(find.text('CONTINUAR AL PAGO SEGURO'), findsOneWidget);
    expect(find.textContaining('Shopify procesa el pago'), findsOneWidget);

    await tester.ensureVisible(find.text('CONTINUAR AL PAGO SEGURO'));
    await tester.tap(find.text('CONTINUAR AL PAGO SEGURO'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('El checkout seguro no está disponible'),
      findsOneWidget,
    );
    expect(find.text('Pago protegido'), findsNothing);
    expect(store.bagQuantity, 1);
  });

  testWidgets('BagAction route inherits authenticated cart composition',
      (tester) async {
    final store = await _loadedStore();
    await store.addToBag(store.products.firstWhere((item) => item.isInStock));
    final database = openTestDatabase();
    final accountController = AccountController(
      accountStore: AccountStore(database),
      deviceStore: DeviceStore(database),
      orderHistoryRepository: OrderHistoryRepository(
        store: OrderSummaryStore(database),
        config: AccountsOrdersConfig.disabled,
      ),
      deviceId: 'device-local',
    )..account = Account(
        localAccountId: 'account-current',
        authProvider: 'monetta',
        createdAt: DateTime.utc(2026, 8, 27),
        lastSeenAt: DateTime.utc(2026, 8, 27),
      );
    final reconciler = _NavigationReconciler();
    final cartController = CartController(reconciler: reconciler);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        builder: (context, navigator) => AppRouteScopes(
          accountController: accountController,
          cartController: cartController,
          shopDomain: 'staging.invalid',
          child: navigator!,
        ),
        home: StoreScope(
          notifier: store,
          child: Scaffold(
            appBar: AppBar(actions: const [BagAction()]),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Mi bolsa, 1 artículos'));
    await tester.pumpAndSettle();

    expect(reconciler.scopes, hasLength(1));
    expect(
      reconciler.scopes.single,
      const CartSessionScope.authenticated(
        shopDomain: 'staging.invalid',
        localAccountId: 'account-current',
      ),
    );
    expect(find.byType(ShopifyCartSummary), findsOneWidget);

    cartController.dispose();
    accountController.dispose();
    await database.close();
  });

  testWidgets('bag refuses contact capture when secure checkout is unavailable',
      (tester) async {
    final store = await _loadedStore();
    await store.addToBag(store.products.firstWhere((item) => item.isInStock));

    await tester.pumpWidget(_app(store, const BagScreen()));
    await tester.pump();

    final cta = find.text('Continuar al checkout');
    await tester.scrollUntilVisible(cta, 300);
    await tester.pumpAndSettle();
    await tester.tap(cta);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('El checkout seguro no está disponible'),
      findsOneWidget,
    );
    expect(find.text('¿Cómo te contactamos?'), findsNothing);
    expect(store.bagQuantity, 1);
  });

  testWidgets('configured cancellation preserves bag and never shows preview',
      (tester) async {
    final store = await _loadedStore();
    await store.addToBag(store.products.firstWhere((item) => item.isInStock));
    var launches = 0;

    await tester.pumpWidget(
      _app(
        store,
        CheckoutFlowScreen(
          launchSecureCheckout: (_) async {
            launches += 1;
            return const CheckoutCancelled();
          },
        ),
      ),
    );
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), 'buyer@example.invalid');
    await tester.enterText(fields.at(1), '8112345678');
    await tester.ensureVisible(find.text('REVISAR PEDIDO'));
    await tester.tap(find.text('REVISAR PEDIDO'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('CONTINUAR AL PAGO SEGURO'));
    await tester.tap(find.text('CONTINUAR AL PAGO SEGURO'));
    await tester.pumpAndSettle();

    expect(launches, 1);
    expect(store.bagQuantity, 1);
    expect(find.text('Checkout cancelado. Tu bolsa se conserva.'), findsOne);
    expect(find.text('Pago protegido'), findsNothing);
  });
}

final class _NavigationReconciler implements CartReconciler {
  final List<CartSessionScope> scopes = [];

  @override
  Future<CartReconciliation> reconcile({
    required CartSessionScope scope,
    required Iterable<LocalCartIntent> localIntent,
    CartBuyerIdentity? buyerIdentity,
    List<String>? desiredDiscountCodes,
  }) async {
    scopes.add(scope);
    final local = localIntent.single;
    const money = CartMoney(amount: '10.00', currencyCode: 'MXN');
    final timestamp = DateTime.utc(2026, 8, 27);
    return CartReconciliation(
      status: CartReconciliationStatus.authoritative,
      cart: Cart(
        id: _opaque('cart'),
        checkoutUrl: Uri(path: _opaque('checkout')).toString(),
        createdAt: timestamp,
        updatedAt: timestamp,
        lines: [
          CartLine(
            id: _opaque('line'),
            variantId: local.variantId,
            productId: shopifyProductGid(1),
            title: 'Producto',
            variantTitle: 'Variante',
            quantity: local.quantity,
            cost: const CartLineCost(
              amountPerQuantity: money,
              subtotal: money,
              total: money,
            ),
          ),
        ],
        totalQuantity: local.quantity,
        buyerIdentity: const CartBuyerSummary(
          countryCode: 'MX',
          isAuthenticated: false,
        ),
        cost: const CartCost(subtotal: money, total: money),
      ),
    );
  }
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
