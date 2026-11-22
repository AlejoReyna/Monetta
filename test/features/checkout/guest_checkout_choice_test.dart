import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/account_controller.dart';
import 'package:monetta_app/app/cart_controller.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/shopify_checkout_coordinator.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/accounts_orders/accounts_orders_config.dart';
import 'package:monetta_app/data/customer_auth/customer_account_config.dart';
import 'package:monetta_app/data/customer_auth/customer_auth_error.dart';
import 'package:monetta_app/data/customer_auth/customer_auth_gateway.dart';
import 'package:monetta_app/data/customer_auth/customer_session_repository.dart';
import 'package:monetta_app/data/customer_auth/secure_token_store.dart';
import 'package:monetta_app/data/local/account_store.dart';
import 'package:monetta_app/data/local/bag_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/order_summary_store.dart';
import 'package:monetta_app/data/local/wishlist_store.dart';
import 'package:monetta_app/data/repositories/order_history_repository.dart';
import 'package:monetta_app/data/shopify/cart/cart_repository.dart';
import 'package:monetta_app/data/shopify/cart/checkout_launcher.dart';
import 'package:monetta_app/data/shopify/cart_attribution.dart';
import 'package:monetta_app/features/boutique/client_guide_components.dart';
import 'package:monetta_app/features/checkout/checkout_screen.dart';
import 'package:monetta_app/features/checkout/reviewing_checkout.dart';
import 'package:monetta_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/shopify_cart_fakes.dart';

class _FakeGateway implements CustomerAuthGateway {
  Object? nextError;
  String email = 'cliente@monetta.example';

  @override
  Future<CustomerAuthResult> login() async {
    final error = nextError;
    if (error != null) throw error;
    final payload = base64Url
        .encode(
          utf8.encode(
            jsonEncode({
              'sub': 'gid://shopify/Customer/42',
              'email': email,
            }),
          ),
        )
        .replaceAll('=', '');
    return CustomerAuthResult(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      idToken: 'h.$payload.s',
      accessTokenExpiresAt: DateTime.utc(2027, 1, 1),
    );
  }

  @override
  Future<CustomerAuthResult> refresh(String refreshToken) => login();

  @override
  Future<void> endSession({required String idTokenHint}) async {}
}

class _MemoryTokenStore implements SecureTokenStore {
  final Map<String, String> _values = {};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}

Future<
    ({
      AppDatabase db,
      CatalogStore store,
      AccountController account,
      CartController cart,
      ShopifyCheckoutCoordinator coordinator,
      _FakeGateway gateway,
    })> _createHarness() async {
  final db = openTestDatabase();
  final store = CatalogStore(database: db);
  await store.loadFromAsset();
  await store.addToBag(store.products.firstWhere((item) => item.isInStock));

  final deviceStore = DeviceStore(db);
  await deviceStore.upsert(
    deviceId: 'dev-g39',
    platform: 'ios',
    appVersion: '1',
  );
  final gateway = _FakeGateway();
  final sessionRepo = CustomerSessionRepository(
    authGateway: gateway,
    accountStore: AccountStore(db),
    sessionStore: SessionStore(db),
    deviceStore: deviceStore,
    wishlistStore: WishlistStore(db),
    bagStore: BagStore(db),
    secureStore: _MemoryTokenStore(),
    deviceId: 'dev-g39',
  );
  final account = AccountController(
    sessionRepository: sessionRepo,
    accountStore: AccountStore(db),
    deviceStore: deviceStore,
    orderHistoryRepository: OrderHistoryRepository(
      store: OrderSummaryStore(db),
      config: AccountsOrdersConfig.disabled,
    ),
    config: const CustomerAccountConfig(
      shopDomain: 'monetta.example',
      shopId: '1',
      clientId: 'client-id',
      redirectUri: 'shop.1.oauth://callback',
    ),
    deviceId: 'dev-g39',
  );
  final sessions = InMemoryCartSessionStore();
  final cart = CartController(
    reconciler: CartRepository(
      api: FakeCartApi(),
      sessions: sessions,
      writes: RecoveringCartWriteCoordinator(),
      attribution: const CartAttribution(
        platform: 'test',
        deviceId: 'dev-g39',
        appVersion: '1',
      ),
    ),
  );
  final coordinator = ShopifyCheckoutCoordinator(
    launcher: FakeCheckoutLauncher(const []),
    urlPolicy: CheckoutUrlPolicy.forShopDomain('monetta.example'),
    sessions: sessions,
  );
  return (
    db: db,
    store: store,
    account: account,
    cart: cart,
    coordinator: coordinator,
    gateway: gateway,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'G39 invitado abre modal con Halo C en Iniciar sesión, conserva bolsa al cancelar y permite continuar como invitado',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final h = await _createHarness();
    addTearDown(() async {
      h.cart.dispose();
      h.account.dispose();
      h.store.dispose();
      await h.db.close();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        builder: (context, navigator) => AppRouteScopes(
          accountController: h.account,
          cartController: h.cart,
          checkoutCoordinator: h.coordinator,
          catalogStore: h.store,
          reviewingCheckout: ReviewingCheckoutCart(),
          shopDomain: 'monetta.example',
          child: navigator!,
        ),
        home: StoreScope(
          notifier: h.store,
          child: const BagScreen(drawerTitle: 'Carrito'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cta = find.text('Continuar al pago');
    await tester.scrollUntilVisible(
      cta,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(cta);
    await tester.pumpAndSettle();
    await tester.tap(cta);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('g39-choice-sheet')), findsOneWidget);
    final signInFinder = find.byKey(const ValueKey('g39-sign-in'));
    final guestFinder = find.byKey(const ValueKey('g39-continue-guest'));
    expect(signInFinder, findsOneWidget);
    expect(guestFinder, findsOneWidget);

    final signInGlass = tester.widget<GuideGlassSurface>(
      find.descendant(
        of: signInFinder,
        matching: find.byType(GuideGlassSurface),
      ),
    );
    expect(signInGlass.halo, isTrue);
    expect(
      find.descendant(
        of: guestFinder,
        matching: find.byType(GuideGlassSurface),
      ),
      findsNothing,
    );

    h.gateway.nextError =
        const CustomerAuthException(CustomerAuthErrorKind.cancelled);
    await tester.tap(signInFinder);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('g39-choice-sheet')), findsOneWidget);
    expect(h.store.bagQuantity, 1);

    await tester.tap(guestFinder);
    await tester.pumpAndSettle();

    expect(find.byType(CheckoutFlowScreen), findsOneWidget);
    expect(h.store.bagQuantity, 1);
  });

  testWidgets(
      'G39 Iniciar sesión autentica y prellena el correo en CheckoutFlowScreen; usuario ya autenticado salta modal',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final h = await _createHarness();
    addTearDown(() async {
      h.cart.dispose();
      h.account.dispose();
      h.store.dispose();
      await h.db.close();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        builder: (context, navigator) => AppRouteScopes(
          accountController: h.account,
          cartController: h.cart,
          checkoutCoordinator: h.coordinator,
          catalogStore: h.store,
          reviewingCheckout: ReviewingCheckoutCart(),
          shopDomain: 'monetta.example',
          child: navigator!,
        ),
        home: StoreScope(
          notifier: h.store,
          child: const BagScreen(drawerTitle: 'Carrito'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cta = find.text('Continuar al pago');
    await tester.scrollUntilVisible(
      cta,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(cta);
    await tester.pumpAndSettle();
    await tester.tap(cta);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('g39-sign-in')));
    await tester.pumpAndSettle();

    expect(h.account.isSignedIn, isTrue);
    expect(find.byKey(const ValueKey('g39-choice-sheet')), findsNothing);
    expect(find.byType(CheckoutFlowScreen), findsOneWidget);
    expect(find.text('cliente@monetta.example'), findsOneWidget);

    Navigator.of(tester.element(find.byType(CheckoutFlowScreen))).pop();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      cta,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(cta);
    await tester.pumpAndSettle();
    await tester.tap(cta);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('g39-choice-sheet')), findsNothing);
    expect(find.byType(CheckoutFlowScreen), findsOneWidget);
  });
}
