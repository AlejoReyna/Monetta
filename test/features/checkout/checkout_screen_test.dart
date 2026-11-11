import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/account_controller.dart';
import 'package:monetta_app/app/cart_controller.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/accounts_orders/accounts_orders_config.dart';
import 'package:monetta_app/data/customer_auth/customer_account_config.dart';
import 'package:monetta_app/data/customer_auth/customer_auth_gateway.dart';
import 'package:monetta_app/data/customer_auth/customer_session_repository.dart';
import 'package:monetta_app/data/customer_auth/secure_token_store.dart';
import 'package:monetta_app/data/local/account_store.dart';
import 'package:monetta_app/data/local/bag_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/order_summary_store.dart';
import 'package:monetta_app/data/local/wishlist_store.dart';
import 'package:monetta_app/data/repositories/order_history_repository.dart';
import 'package:monetta_app/data/shopify/cart/cart_api.dart';
import 'package:monetta_app/data/shopify/cart/cart_repository.dart';
import 'package:monetta_app/data/shopify/cart/cart_session_store.dart';
import 'package:monetta_app/data/shopify/cart/checkout_launcher.dart';
import 'package:monetta_app/data/shopify/shopify_gid.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/domain/cart.dart';
import 'package:monetta_app/features/checkout/checkout_return.dart';
import 'package:monetta_app/features/checkout/checkout_screen.dart';
import 'package:monetta_app/features/checkout/shopify_cart_summary.dart';
import 'package:monetta_app/main.dart';

Future<CatalogStore> _loadedStore() async {
  final store = CatalogStore(database: openTestDatabase());
  await store.loadFromAsset();
  return store;
}

Widget _app(CatalogStore store, Widget child, {AccountController? account}) {
  final shop = StoreScope(notifier: store, child: child);
  return MaterialApp(
    theme: buildTheme(),
    home: account == null ? shop : AccountScope(notifier: account, child: shop),
  );
}

Future<void> _tapPay(WidgetTester tester) async {
  final pay = find.byKey(const ValueKey('checkout-pay-button'));
  await tester.ensureVisible(pay);
  await tester.pumpAndSettle();
  await tester.tap(pay);
  await tester.pumpAndSettle();
}

/// The words of the old checkout, none of which may come back.
void _expectMinimalCheckout() {
  expect(find.byType(TextFormField), findsNothing);
  for (final text in [
    '¿Cómo te contactamos?',
    'Todo listo',
    'REVISAR PEDIDO',
    'Entrega',
    'Confirmación',
    'Envío estándar',
  ]) {
    expect(find.text(text), findsNothing, reason: text);
  }
  expect(find.textContaining('Paso '), findsNothing);
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

    expect(find.text('Mi bolsa'), findsOneWidget);
    expect(find.text(product.title), findsOneWidget);
    expect(find.text('Continuar al checkout'), findsOneWidget);

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

  testWidgets(
      'checkout asks for nothing and never simulates payment without a '
      'Shopify bridge', (tester) async {
    final store = await _loadedStore();
    await store.addToBag(store.products.firstWhere((item) => item.isInStock));

    await tester.pumpWidget(_app(store, const CheckoutFlowScreen()));
    await tester.pump();

    expect(find.text('SEGURO'), findsOneWidget);
    expect(find.text('Tu pedido'), findsOneWidget);
    expect(find.text('IR A PAGAR'), findsOneWidget);
    expect(find.text('Pagos seguros con Shopify.'), findsOneWidget);
    _expectMinimalCheckout();

    await _tapPay(tester);

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

  testWidgets('bag never opens checkout when secure checkout is unavailable',
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
    expect(find.byType(CheckoutFlowScreen), findsNothing);
    expect(store.bagQuantity, 1);
  });

  testWidgets('the bag shows no checkout steps', (tester) async {
    final store = await _loadedStore();
    await store.addToBag(store.products.firstWhere((item) => item.isInStock));

    await tester.pumpWidget(_app(store, const BagScreen()));
    await tester.pump();

    expect(find.text('Mi bolsa'), findsOneWidget);
    expect(find.textContaining('Paso '), findsNothing);
    for (final step in ['Entrega', 'Pago', 'Confirmación']) {
      expect(find.text(step), findsNothing, reason: step);
    }
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
    _expectMinimalCheckout();
    await _tapPay(tester);

    expect(launches, 1);
    expect(store.bagQuantity, 1);
    expect(find.text('Estamos revisando tu pago'), findsOneWidget);
    expect(find.text('Intentar de nuevo'), findsNothing);
    expect(find.text('Pago protegido'), findsNothing);
    expect(find.textContaining('rechaz'), findsNothing);
  });

  testWidgets(
      'a shopper connected with Shopify is not asked for contact and pays '
      'with the account', (tester) async {
    final store = await _loadedStore();
    await store.addToBag(store.products.firstWhere((item) => item.isInStock));
    final database = openTestDatabase();
    addTearDown(database.close);
    final account = AccountController(
      accountStore: AccountStore(database),
      deviceStore: DeviceStore(database),
      orderHistoryRepository: OrderHistoryRepository(
        store: OrderSummaryStore(database),
        config: AccountsOrdersConfig.disabled,
      ),
      deviceId: 'device-local',
    )..account = Account(
        localAccountId: 'account-current',
        authProvider: 'shopify',
        email: 'ana@example.com',
        createdAt: DateTime.utc(2026, 10, 30),
        lastSeenAt: DateTime.utc(2026, 10, 30),
      );
    addTearDown(account.dispose);
    final drafts = <CheckoutDraft>[];

    await tester.pumpWidget(
      _app(
        store,
        CheckoutFlowScreen(
          launchSecureCheckout: (draft) async {
            drafts.add(draft);
            return const CheckoutCancelled();
          },
          orderLookup: const _NoOrders(),
          orderLookupTimeout: Duration.zero,
        ),
        account: account,
      ),
    );
    await tester.pump();

    expect(find.text('ana@example.com'), findsOneWidget);
    expect(find.text('Conectado con Shopify'), findsOneWidget);
    expect(find.text('Comprando como invitado'), findsNothing);
    _expectMinimalCheckout();

    await _tapPay(tester);
    expect(drafts.single.email, 'ana@example.com');
    expect(drafts.single.phone, isEmpty);
  });

  testWidgets(
      'a guest pays as a guest, or signs in with Shopify first without '
      'losing the bag', (tester) async {
    final store = await _loadedStore();
    await store.addToBag(store.products.firstWhere((item) => item.isInStock));
    final database = openTestDatabase();
    addTearDown(database.close);
    final gateway = _ShopGateway();
    final account = await _signInCapableController(database, gateway);
    addTearDown(account.dispose);
    expect(account.canLogin, isTrue);
    final drafts = <CheckoutDraft>[];

    await tester.pumpWidget(
      _app(
        store,
        CheckoutFlowScreen(
          launchSecureCheckout: (draft) async {
            drafts.add(draft);
            return const CheckoutCancelled();
          },
          orderLookup: const _NoOrders(),
          orderLookupTimeout: Duration.zero,
        ),
        account: account,
      ),
    );
    await tester.pump();

    expect(find.text('Comprando como invitado'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    _expectMinimalCheckout();

    // Nothing forces an account: Shopify's checkout applies the store's rule.
    await _tapPay(tester);
    expect(drafts.single.email, isEmpty);

    await tester.tap(find.byKey(const Key('checkout-connect')));
    await tester.pump();
    expect(gateway.logins, 1);
    gateway.succeed();
    await tester.pumpAndSettle();

    expect(account.isSignedIn, isTrue);
    expect(find.text('ana@example.com'), findsOneWidget);
    expect(find.text('Conectado con Shopify'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsNothing);
    expect(store.bagQuantity, 1);
  });
}

final class _NoOrders implements CheckoutOrderLookup {
  const _NoOrders();

  @override
  Future<CheckoutOrderMatch?> findOrder(
    CheckoutAttemptIdentity attempt,
  ) async {
    return null;
  }
}

class _SecureStore implements SecureTokenStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _ShopGateway implements CustomerAuthGateway {
  final _login = Completer<CustomerAuthResult>();
  int logins = 0;

  @override
  Future<CustomerAuthResult> login() {
    logins += 1;
    return _login.future;
  }

  void succeed() => _login.complete(_authResult());

  @override
  Future<CustomerAuthResult> refresh(String refreshToken) async =>
      _authResult();

  @override
  Future<void> endSession({required String idTokenHint}) async {}
}

CustomerAuthResult _authResult() {
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({
            'sub': 'gid://shopify/Customer/1',
            'email': 'ana@example.com',
          }),
        ),
      )
      .replaceAll('=', '');
  return CustomerAuthResult(
    accessToken: 'access',
    refreshToken: 'refresh',
    idToken: 'header.$payload.signature',
    accessTokenExpiresAt: DateTime.utc(2027),
  );
}

Future<AccountController> _signInCapableController(
  AppDatabase db,
  CustomerAuthGateway gateway,
) async {
  final deviceStore = DeviceStore(db);
  await deviceStore.upsert(
    deviceId: 'dev-1',
    platform: 'ios',
    appVersion: '1',
  );
  return AccountController(
    sessionRepository: CustomerSessionRepository(
      authGateway: gateway,
      accountStore: AccountStore(db),
      sessionStore: SessionStore(db),
      deviceStore: deviceStore,
      wishlistStore: WishlistStore(db),
      bagStore: BagStore(db),
      secureStore: _SecureStore(),
      deviceId: 'dev-1',
    ),
    accountStore: AccountStore(db),
    deviceStore: deviceStore,
    orderHistoryRepository: OrderHistoryRepository(
      store: OrderSummaryStore(db),
      config: AccountsOrdersConfig.disabled,
    ),
    config: const CustomerAccountConfig(
      shopDomain: 'shop.example.com',
      shopId: '1',
      clientId: 'client-id',
      redirectUri: 'shop.1.oauth://callback',
    ),
    deviceId: 'dev-1',
  );
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
