import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:monetta_app/app/account_controller.dart';
import 'package:monetta_app/app/admin_config.dart';
import 'package:monetta_app/app/admin_controller.dart';
import 'package:monetta_app/app/admin_notification_controller.dart';
import 'package:monetta_app/app/cart_controller.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/editorial_content_controller.dart';
import 'package:monetta_app/app/featured_catalog_controller.dart';
import 'package:monetta_app/app/home_content_controller.dart';
import 'package:monetta_app/app/notification_controller.dart';
import 'package:monetta_app/app/onboarding_controller.dart';
import 'package:monetta_app/app/product_telemetry.dart';
import 'package:monetta_app/app/shopify_checkout_coordinator.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/app/theme_controller.dart';
import 'package:monetta_app/data/accounts_orders/accounts_orders_config.dart';
import 'package:monetta_app/data/customer_auth/secure_token_store.dart';
import 'package:monetta_app/data/local/account_store.dart';
import 'package:monetta_app/data/local/appearance_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/onboarding_preference_store.dart';
import 'package:monetta_app/data/local/order_summary_store.dart';
import 'package:monetta_app/data/local/wishlist_store.dart';
import 'package:monetta_app/data/notifications/notification_config.dart';
import 'package:monetta_app/data/repositories/order_history_repository.dart';
import 'package:monetta_app/data/shopify/cart/cart_api.dart';
import 'package:monetta_app/data/shopify/cart/cart_repository.dart';
import 'package:monetta_app/data/shopify/cart/cart_session_store.dart';
import 'package:monetta_app/data/shopify/cart/checkout_launcher.dart';
import 'package:monetta_app/data/shopify/cart/storefront_password_gate.dart';
import 'package:monetta_app/data/shopify/catalog_sync.dart' as shopify;
import 'package:monetta_app/data/shopify/editorial_content_repository.dart';
import 'package:monetta_app/data/shopify/featured_catalog_repository.dart';
import 'package:monetta_app/data/shopify/home_content_repository.dart';
import 'package:monetta_app/data/shopify/http_storefront_transport.dart';
import 'package:monetta_app/data/shopify/storefront_client.dart';
import 'package:monetta_app/data/shopify/storefront_config.dart';
import 'package:monetta_app/domain/cart.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/catalog/product_card.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/features/navigation/duo_workspace.dart';
import 'package:monetta_app/features/welcome/welcome_gate.dart';
import 'package:monetta_app/main.dart';
import 'package:monetta_app/platform/system_layout_context.dart';

const String _demoWebhookSecret = 'demo_webhook_secret_12345';
const String _demoToken = 'demo-shopify-token';
const int _demoCustomerId = 77001;
const String _demoShopDomain = 'monetta-staging.myshopify.com';

String _formatMoney(int cents) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  final whole = abs ~/ 100;
  final frac = (abs % 100).toString().padLeft(2, '0');
  return '$sign$whole.$frac';
}

int _centsFromDouble(double value) => (value * 100).round();

int _numericShopifyId(String gid, int fallback) {
  final tail = gid.split('/').last.trim();
  return int.tryParse(tail) ?? fallback;
}

class _MemoryTokenStore implements SecureTokenStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}

class _InMemoryCartSessionStore implements CartSessionStore {
  final Map<CartSessionScope, SensitiveCartId> _sessions = {};

  @override
  Future<void> delete(CartSessionScope scope) async => _sessions.remove(scope);

  @override
  Future<SensitiveCartId?> read(CartSessionScope scope) async =>
      _sessions[scope];

  @override
  Future<void> write(CartSessionScope scope, SensitiveCartId cartId) async {
    _sessions[scope] = cartId;
  }
}

class _DemoPasswordProbe implements StorefrontPasswordProbe {
  @override
  Future<StorefrontPasswordGate> checkHost(String host) async =>
      StorefrontPasswordGate.open;
}

class _DemoAccountController extends AccountController {
  _DemoAccountController({
    required super.accountStore,
    required super.deviceStore,
    required super.orderHistoryRepository,
    required super.deviceId,
    super.wishlistStore,
    super.onAccountScopeChanged,
  });

  @override
  bool get canLogin => false;

  @override
  Future<String?> accessTokenForBackend() async => _demoToken;

  @override
  Future<String?> accessTokenForShopifyCheckout() async => _demoToken;
}

class _DemoCartReconciler implements CartReconciler {
  _DemoCartReconciler({
    required this.store,
    required this.backendBaseUrl,
    required this.httpClient,
  });

  final CatalogStore store;
  final Uri backendBaseUrl;
  final http.Client httpClient;

  Cart? latestCart;
  String? latestDiscountCode;
  int latestDiscountCents = 0;

  @override
  Future<CartReconciliation> reconcile({
    required CartSessionScope scope,
    required Iterable<LocalCartIntent> localIntent,
    CartBuyerIdentity? buyerIdentity,
    List<String>? desiredDiscountCodes,
  }) async {
    final now = DateTime.now().toUtc();
    final rawLines = <_PendingLine>[];
    var subtotalCents = 0;

    for (final intent in localIntent) {
      Product? matchedProduct;
      ProductVariant? matchedVariant;
      for (final p in store.products) {
        for (final v in p.variants) {
          if (v.id == intent.variantId) {
            matchedProduct = p;
            matchedVariant = v;
            break;
          }
        }
        if (matchedProduct != null) break;
      }
      if (matchedProduct == null || matchedVariant == null) continue;
      final unitCents = _centsFromDouble(matchedVariant.price);
      final lineSubtotalCents = unitCents * intent.quantity;
      subtotalCents += lineSubtotalCents;
      rawLines.add(
        _PendingLine(
          product: matchedProduct,
          variant: matchedVariant,
          quantity: intent.quantity,
          unitCents: unitCents,
          lineSubtotalCents: lineSubtotalCents,
        ),
      );
    }

    final discountCodes = <CartDiscountCode>[];
    final discountApplications = <CartDiscountApplication>[];
    var appliedDiscountCents = 0;
    String? appliedCode;

    if (desiredDiscountCodes != null) {
      for (final rawCode in desiredDiscountCodes) {
        final code = rawCode.trim().toUpperCase();
        if (code.isEmpty) continue;
        final uri = backendBaseUrl.resolve('/demo/coupons/$code');
        final res = await httpClient.get(uri);
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          final couponCents = (body['amountCents'] as num?)?.toInt() ?? 0;
          final effective = math.min(couponCents, subtotalCents);
          if (effective > 0) {
            appliedDiscountCents = effective;
            appliedCode = code;
            discountCodes.add(CartDiscountCode(code: code, applicable: true));
            discountApplications.add(
              CartDiscountApplication(
                kind: CartDiscountApplicationKind.code,
                allocationMethod: 'ACROSS',
                targetSelection: 'ALL',
                targetType: 'LINE_ITEM',
                amount: CartMoney(
                  amount: _formatMoney(effective),
                  currencyCode: 'MXN',
                ),
                code: code,
                title: code,
                totalAllocatedAmount: CartMoney(
                  amount: _formatMoney(effective),
                  currencyCode: 'MXN',
                ),
              ),
            );
          }
        }
      }
    }

    var remainingDiscount = appliedDiscountCents;
    final cartLines = <CartLine>[];
    for (var i = 0; i < rawLines.length; i++) {
      final line = rawLines[i];
      var lineDiscount = 0;
      if (appliedDiscountCents > 0 && subtotalCents > 0) {
        lineDiscount = i == rawLines.length - 1
            ? remainingDiscount
            : math.min(
                remainingDiscount,
                (appliedDiscountCents * line.lineSubtotalCents) ~/
                    subtotalCents,
              );
        remainingDiscount -= lineDiscount;
      }
      final lineTotalCents = line.lineSubtotalCents - lineDiscount;
      cartLines.add(
        CartLine(
          id: 'gid://shopify/CartLine/${i + 1}?cart=demo',
          variantId: line.variant.id,
          productId: line.product.id,
          title: line.product.title,
          variantTitle: line.variant.title,
          quantity: line.quantity,
          imageUrl: line.product.primaryImage,
          discountAllocations: lineDiscount > 0
              ? [
                  CartDiscountAllocation(
                    discountedAmount: CartMoney(
                      amount: _formatMoney(lineDiscount),
                      currencyCode: 'MXN',
                    ),
                  ),
                ]
              : const [],
          cost: CartLineCost(
            amountPerQuantity: CartMoney(
              amount: _formatMoney(line.unitCents),
              currencyCode: 'MXN',
            ),
            subtotal: CartMoney(
              amount: _formatMoney(line.lineSubtotalCents),
              currencyCode: 'MXN',
            ),
            total: CartMoney(
              amount: _formatMoney(lineTotalCents),
              currencyCode: 'MXN',
            ),
          ),
        ),
      );
    }

    final totalCents = math.max(0, subtotalCents - appliedDiscountCents);
    final cart = Cart(
      id: 'gid://shopify/Cart/demo-cart-1?key=demo_secret',
      checkoutUrl: 'https://$_demoShopDomain/cart/c/demo-checkout-1?key=demo',
      createdAt: now,
      updatedAt: now,
      lines: cartLines,
      totalQuantity: rawLines.fold<int>(0, (sum, l) => sum + l.quantity),
      buyerIdentity: const CartBuyerSummary(
        countryCode: 'MX',
        isAuthenticated: true,
      ),
      cost: CartCost(
        subtotal: CartMoney(
          amount: _formatMoney(subtotalCents),
          currencyCode: 'MXN',
        ),
        total: CartMoney(
          amount: _formatMoney(totalCents),
          currencyCode: 'MXN',
        ),
        checkoutCharge: CartMoney(
          amount: _formatMoney(totalCents),
          currencyCode: 'MXN',
        ),
      ),
      discountCodes: discountCodes,
      discountApplications: discountApplications,
    );

    latestCart = cart;
    latestDiscountCode = appliedCode;
    latestDiscountCents = appliedDiscountCents;

    return CartReconciliation(
      status: CartReconciliationStatus.authoritative,
      cart: cart,
    );
  }
}

class _PendingLine {
  const _PendingLine({
    required this.product,
    required this.variant,
    required this.quantity,
    required this.unitCents,
    required this.lineSubtotalCents,
  });

  final Product product;
  final ProductVariant variant;
  final int quantity;
  final int unitCents;
  final int lineSubtotalCents;
}

class _DemoCheckoutLauncher implements CheckoutLauncher {
  _DemoCheckoutLauncher({
    required this.reconciler,
    required this.backendBaseUrl,
    required this.httpClient,
  });

  final _DemoCartReconciler reconciler;
  final Uri backendBaseUrl;
  final http.Client httpClient;

  int _orderSequence = 0;
  final List<int> createdOrderIds = <int>[];
  final Map<int, String> orderTotals = <int, String>{};

  @override
  Future<void> invalidate() async {}

  @override
  Future<void> preload(ValidatedCheckoutUrl checkoutUrl) async {}

  @override
  Future<CheckoutResult> present(ValidatedCheckoutUrl checkoutUrl) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    final cart = reconciler.latestCart;
    if (cart == null || cart.lines.isEmpty) {
      return const CheckoutFailed(
        code: CheckoutFailureCode.invalidCart,
        userMessage: 'Carrito vacío en demo.',
      );
    }

    _orderSequence += 1;
    final orderId = 900100 + _orderSequence;
    createdOrderIds.add(orderId);
    orderTotals[orderId] = cart.cost.total.amount;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final discountCode = reconciler.latestDiscountCode;
    final discountCents = reconciler.latestDiscountCents;

    final lineItems = <Map<String, dynamic>>[];
    for (var i = 0; i < cart.lines.length; i++) {
      final line = cart.lines[i];
      final unitCents = _parseCents(line.cost.amountPerQuantity.amount);
      final lineAlloc = line.discountAllocations.fold<int>(
        0,
        (s, a) => s + _parseCents(a.discountedAmount.amount),
      );
      lineItems.add({
        'product_id': _numericShopifyId(line.productId, 1000 + i),
        'variant_id': _numericShopifyId(line.variantId, 2000 + i),
        'quantity': line.quantity,
        'price': _formatMoney(unitCents),
        'total_discount': _formatMoney(lineAlloc),
      });
    }

    final payload = <String, dynamic>{
      'id': orderId,
      'name': '#${1040 + _orderSequence}',
      'financial_status': 'paid',
      'fulfillment_status': null,
      'payment_gateway_names': ['shopify_payments'],
      'currency': 'MXN',
      'current_total_price': cart.cost.total.amount,
      'created_at': nowIso,
      'updated_at': nowIso,
      'customer': {
        'id': _demoCustomerId,
        'email': 'sofia.garza@monetta.mx',
        'first_name': 'Sofía',
        'last_name': 'Garza',
      },
      'line_items': lineItems,
      if (discountCode != null && discountCents > 0)
        'discount_codes': [
          {
            'code': discountCode,
            'amount': _formatMoney(discountCents),
          },
        ],
    };

    await _postSignedWebhook(
      httpClient: httpClient,
      backendBaseUrl: backendBaseUrl,
      path: '/webhooks/orders/create',
      webhookId: 'demo-order-create-$orderId',
      payload: payload,
    );

    return const CheckoutCompleted();
  }
}

int _parseCents(String raw) {
  final parts = raw.trim().split('.');
  final whole = int.tryParse(parts[0]) ?? 0;
  final fracStr = parts.length > 1 ? '${parts[1]}00'.substring(0, 2) : '00';
  final frac = int.tryParse(fracStr) ?? 0;
  return whole * 100 + frac;
}

Future<void> _postSignedWebhook({
  required http.Client httpClient,
  required Uri backendBaseUrl,
  required String path,
  required String webhookId,
  required Map<String, dynamic> payload,
}) async {
  final body = jsonEncode(payload);
  final hmac =
      Hmac(sha256, utf8.encode(_demoWebhookSecret)).convert(utf8.encode(body));
  final sig = base64Encode(hmac.bytes);
  final res = await httpClient.post(
    backendBaseUrl.resolve(path),
    headers: {
      'Content-Type': 'application/json',
      'X-Shopify-Hmac-Sha256': sig,
      'X-Shopify-Webhook-Id': webhookId,
      'X-Shopify-Shop-Domain': _demoShopDomain,
    },
    body: body,
  );
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw StateError('Webhook $path failed (${res.statusCode}): ${res.body}');
  }
}

/// Pumps frames continuously over real wall-clock time so the screen recorder
/// captures smooth motion, network images, and legible holds.
Future<void> _hold(WidgetTester tester, Duration duration) async {
  final sw = Stopwatch()..start();
  while (sw.elapsed < duration) {
    await tester.pump(const Duration(milliseconds: 50));
    await Future<void>.delayed(const Duration(milliseconds: 40));
  }
}

Future<void> _waitForFinder(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final sw = Stopwatch()..start();
  while (sw.elapsed < timeout) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.hitTestable().evaluate().isNotEmpty) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 40));
  }
  throw TestFailure('Timed out waiting for finder: $finder');
}

Future<void> _scrollIntoView(WidgetTester tester, Finder finder) async {
  unawaited(
    Scrollable.ensureVisible(
      tester.element(finder.first),
      alignment: 0.35,
      duration: const Duration(milliseconds: 220),
    ),
  );
  await _hold(tester, const Duration(milliseconds: 350));
}

Future<void> _waitForAnyFinder(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final sw = Stopwatch()..start();
  while (sw.elapsed < timeout) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 40));
  }
  throw TestFailure('Timed out waiting for finder in tree: $finder');
}

Future<void> _waitAndReveal(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  // Let short animations/network calls settle before scrolling down.
  await _hold(tester, const Duration(milliseconds: 450));
  final sw = Stopwatch()..start();
  while (sw.elapsed < timeout) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) {
      await _scrollIntoView(tester, finder);
      return;
    }
    final vertical = find.byWidgetPredicate(
      (w) =>
          w is Scrollable &&
          (w.axisDirection == AxisDirection.down ||
              w.axisDirection == AxisDirection.up),
    );
    if (vertical.evaluate().isNotEmpty) {
      await tester.drag(vertical.last, const Offset(0, -260));
      await _hold(tester, const Duration(milliseconds: 180));
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
  }
  throw TestFailure('Timed out waiting for finder in tree: $finder');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Full Monetta Rewards iPhone demo walkthrough',
      timeout: const Timeout(Duration(minutes: 4)), (tester) async {
    final httpClient = http.Client();
    addTearDown(httpClient.close);

    final accountsConfig = AccountsOrdersConfig.fromEnvironment();
    final backendUri = Uri.parse(
      accountsConfig.baseUrl ?? 'http://127.0.0.1:8099',
    );
    final storefrontConfig = StorefrontConfig.fromEnvironment();
    final transport =
        storefrontConfig.isUsable ? HttpStorefrontTransport() : null;

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final theme = ThemeController(store: AppearanceStore(db));
    final onboarding =
        OnboardingController(store: OnboardingPreferenceStore(db));
    await Future.wait([theme.restore(), onboarding.restore()]);

    final catalogStore = CatalogStore(
      database: db,
      catalogSync: transport == null
          ? null
          : shopify.CatalogSync(
              client: StorefrontClient(
                config: storefrontConfig,
                transport: transport.send,
              ),
            ),
      shopDomain: storefrontConfig.shopDomain.trim().isEmpty
          ? _demoShopDomain
          : storefrontConfig.shopDomain.trim(),
    );

    await catalogStore.loadFromAsset();
    unawaited(catalogStore.syncWithShopify());

    final emptyClient = StorefrontClient(
      config: storefrontConfig,
      transport: transport?.send ??
          ((_, __, ___) async =>
              <String, dynamic>{'data': <String, dynamic>{}}),
    );
    final editorialContent = EditorialContentController(
      repository: EditorialContentRepository(client: emptyClient),
    );
    final homeContent = HomeContentController(
      repository: HomeContentRepository(client: emptyClient),
    );
    final featuredCatalog = FeaturedCatalogController(
      repository: FeaturedCatalogRepository(client: emptyClient),
      cacheProducts: catalogStore.upsertShopifyProducts,
    );
    unawaited(editorialContent.refresh());
    unawaited(homeContent.refresh());
    unawaited(featuredCatalog.refresh());

    const deviceId = 'demo-iphone-18-pro';
    final accountStore = AccountStore(db);
    final deviceStore = DeviceStore(db);
    await deviceStore.upsert(
      deviceId: deviceId,
      platform: 'ios',
      appVersion: '4.1.0-demo',
    );
    await accountStore.upsert(
      localAccountId: 'acct-demo-77001',
      shopifyCustomerId: '$_demoCustomerId',
      email: 'sofia.garza@monetta.mx',
      displayName: 'Sofía Garza',
      authProvider: 'shopify',
      createdAt: DateTime.now().toUtc(),
    );
    final seededAccount = await accountStore.byLocalId('acct-demo-77001');

    final accountController = _DemoAccountController(
      accountStore: accountStore,
      deviceStore: deviceStore,
      wishlistStore: WishlistStore(db),
      orderHistoryRepository: OrderHistoryRepository(
        store: OrderSummaryStore(db),
        config: AccountsOrdersConfig(
          enabled: true,
          baseUrl: backendUri.toString(),
        ),
        customerOrders: null,
      ),
      deviceId: deviceId,
      onAccountScopeChanged: (id) async {
        await catalogStore.setAccountScope(id);
      },
    )..account = seededAccount;
    await catalogStore.setAccountScope('acct-demo-77001');

    final navigatorKey = GlobalKey<NavigatorState>();
    final duoRoutes = DuoRouteObserver();
    final cartSessions = _InMemoryCartSessionStore();
    final cartReconciler = _DemoCartReconciler(
      store: catalogStore,
      backendBaseUrl: backendUri,
      httpClient: httpClient,
    );
    final cartController = CartController(reconciler: cartReconciler);
    final checkoutLauncher = _DemoCheckoutLauncher(
      reconciler: cartReconciler,
      backendBaseUrl: backendUri,
      httpClient: httpClient,
    );
    final checkoutCoordinator = ShopifyCheckoutCoordinator(
      launcher: checkoutLauncher,
      urlPolicy: CheckoutUrlPolicy.forShopDomain(
        storefrontConfig.shopDomain.trim().isEmpty
            ? _demoShopDomain
            : storefrontConfig.shopDomain.trim(),
      ),
      sessions: cartSessions,
      passwordProbe: _DemoPasswordProbe(),
    );

    final notificationController = NotificationController(
      config: const NotificationConfig(
        enabled: false,
        apiBaseUrl: null,
        firebaseApiKey: '',
        firebaseAppId: '',
        firebaseProjectId: '',
        firebaseMessagingSenderId: '',
        firebaseStorageBucket: '',
        iosBundleId: '',
        timezone: 'America/Mexico_City',
      ),
      deviceId: deviceId,
      catalogStore: catalogStore,
      secureStore: _MemoryTokenStore(),
      onOpenRoute: (_) {},
    );
    await notificationController.restore();

    final adminController = AdminController(
      config: AdminConfig.fromEnvironment(),
    );
    final adminNotifications = AdminNotificationController(deviceId: deviceId);

    await tester.pumpWidget(
      ProductTelemetryScope(
        telemetry: const DisabledProductTelemetry(),
        child: ThemeScope(
          notifier: theme,
          child: MaterialApp(
            navigatorKey: navigatorKey,
            navigatorObservers: [duoRoutes],
            title: 'Monetta',
            debugShowCheckedModeBanner: false,
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: theme.mode,
            builder: (context, navigator) => SystemLayoutHost(
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle.dark,
                child: AppRouteScopes(
                  accountController: accountController,
                  cartController: cartController,
                  checkoutCoordinator: checkoutCoordinator,
                  catalogStore: catalogStore,
                  notificationController: notificationController,
                  shopDomain: _demoShopDomain,
                  child: DuoWorkspace(
                    navigatorKey: navigatorKey,
                    routes: duoRoutes,
                    paneRoot: (_) => const SizedBox.shrink(),
                    child: navigator!,
                  ),
                ),
              ),
            ),
            home: StoreScope(
              notifier: catalogStore,
              child: EditorialContentScope(
                notifier: editorialContent,
                child: HomeContentScope(
                  notifier: homeContent,
                  child: FeaturedCatalogScope(
                    notifier: featuredCatalog,
                    child: NotificationScope(
                      notifier: notificationController,
                      child: AdminNotificationScope(
                        notifier: adminNotifications,
                        child: AdminScope(
                          notifier: adminController,
                          child: OnboardingScope(
                            notifier: onboarding,
                            child: const WelcomeGate(
                              child: HomeScreen(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await catalogStore.waitForInitialCatalog();

    // ── SCENE 1: Welcome & Home ──────────────────────────────────────────────
    debugPrint('DEMO_SCENE:1 Welcome & Home');
    final welcomeBtn = find.byKey(const ValueKey('welcome-start-button'));
    await _waitForFinder(tester, welcomeBtn);
    await _hold(tester, const Duration(milliseconds: 1600));
    await tester.tap(welcomeBtn);

    final onboardingSkip = find.byKey(const ValueKey('onboarding-skip'));
    await _waitForFinder(tester, onboardingSkip);
    await _hold(tester, const Duration(milliseconds: 900));
    await tester.tap(onboardingSkip);

    final bottomNavAccount = find.byKey(const Key('bottom-nav-account'));
    await _waitForFinder(tester, bottomNavAccount);
    await _hold(tester, const Duration(milliseconds: 2200));

    // ── SCENE 2: Account initial balance ($0 Monetta) + PRO 0% arc + Benefits
    debugPrint('DEMO_SCENE:2 Account initial \$0, PRO 0% arc & Benefits');
    await tester.tap(bottomNavAccount);
    await _waitForAnyFinder(
      tester,
      find.byKey(const ValueKey('account-rewards-balance')),
    );
    await _waitForAnyFinder(tester, find.textContaining('\$0 Monetta'));
    await _hold(tester, const Duration(milliseconds: 1800));

    final openRewardsGuide =
        find.byKey(const ValueKey('account-open-rewards-guide'));
    await tester.tap(openRewardsGuide.hitTestable().last);
    await _waitForFinder(
      tester,
      find.byKey(const ValueKey('rewards-progress-arc')),
    );
    await _hold(tester, const Duration(milliseconds: 1800));

    final openBenefits = find.byKey(const ValueKey('rewards-open-benefits'));
    await _waitAndReveal(tester, openBenefits);
    await tester.tap(openBenefits.hitTestable().last);
    final dismissBenefits =
        find.byKey(const ValueKey('rewards-benefits-dismiss'));
    await _waitForFinder(tester, dismissBenefits);
    await _hold(tester, const Duration(milliseconds: 2200));
    await tester.tap(dismissBenefits);
    await _hold(tester, const Duration(milliseconds: 450));

    navigatorKey.currentState?.popUntil((r) => r.isFirst);
    await _hold(tester, const Duration(milliseconds: 450));

    Future<void> openBagsCatalog() async {
      final navCat = find.byKey(const Key('bottom-nav-catalog'));
      await _waitForFinder(tester, navCat.hitTestable());
      await tester.tap(navCat.hitTestable().last);
      final bagsTile = find.text('Bolsos');
      await _waitForFinder(tester, bagsTile);
      await _hold(tester, const Duration(milliseconds: 600));
      await tester.tap(bagsTile.first);
      final exploreBags = find.byKey(const ValueKey('category-open-bags'));
      await _waitForFinder(tester, exploreBags);
      await _hold(tester, const Duration(milliseconds: 500));
      await tester.tap(exploreBags.hitTestable().last);
      await _waitForFinder(tester, find.byType(ProductCard));
      await _hold(tester, const Duration(milliseconds: 1200));
    }

    // ── SCENE 3: Catalog → High-value Product Page with 3% Rewards Estimate ──
    debugPrint('DEMO_SCENE:3 Catalog & Product 3% estimate');
    await openBagsCatalog();

    // Pick two in-stock, hit-testable products directly from the visible grid
    // (prefer >= $2,000 MXN so 3% Rewards is vivid, no off-screen dragging).
    final hitVisibleCards = tester
        .widgetList<ProductCard>(find.byType(ProductCard).hitTestable())
        .map((c) => c.product)
        .where((p) => p.isInStock)
        .toList();
    final highValueVisible =
        hitVisibleCards.where((p) => p.price >= 2000).toList();

    final p1 = highValueVisible.isNotEmpty
        ? highValueVisible.first
        : hitVisibleCards.first;
    final p2 = highValueVisible.length > 1
        ? highValueVisible[1]
        : hitVisibleCards.firstWhere(
            (p) => p.id != p1.id,
            orElse: () => p1,
          );

    Future<void> openProductFromCatalog(Product target) async {
      final cardFinder = find
          .byWidgetPredicate(
            (w) => w is ProductCard && w.product.id == target.id,
          )
          .hitTestable();
      final targetCard = cardFinder.evaluate().isNotEmpty
          ? cardFinder.first
          : find.byType(ProductCard).hitTestable().first;
      await _scrollIntoView(tester, targetCard);
      await _hold(tester, const Duration(milliseconds: 400));
      await tester.tap(targetCard);

      final quickViewBtn = find.byKey(const Key('quick-view-view-product'));
      final pdpBuyBtn = find.byKey(const Key('purchase-dock-primary'));
      final sw = Stopwatch()..start();
      while (sw.elapsed < const Duration(seconds: 15)) {
        await tester.pump(const Duration(milliseconds: 50));
        if (quickViewBtn.evaluate().isNotEmpty ||
            pdpBuyBtn.evaluate().isNotEmpty) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
      if (quickViewBtn.evaluate().isNotEmpty) {
        await _hold(tester, const Duration(milliseconds: 800));
        await _scrollIntoView(tester, quickViewBtn);
        await _hold(tester, const Duration(milliseconds: 500));
        await tester.tap(quickViewBtn.first);
      }

      await _waitForFinder(tester, pdpBuyBtn);
      final est = find.textContaining('Gana ');
      if (est.evaluate().isNotEmpty) {
        await _scrollIntoView(tester, est.first);
      }
      await _hold(tester, const Duration(milliseconds: 2400));
    }

    await openProductFromCatalog(p1);

    // ── SCENE 4: Purchase #1 → Checkout → Confirmation → Pending Rewards ─────
    debugPrint('DEMO_SCENE:4 Purchase #1 & Pending Rewards');
    await tester.tap(find.byKey(const Key('purchase-dock-primary')));
    final miniCartContinue = find.text('Continuar al pago');
    await _waitAndReveal(tester, miniCartContinue);
    await _hold(tester, const Duration(milliseconds: 1200));
    await tester.tap(miniCartContinue.first);

    final payButton = find.byKey(const ValueKey('checkout-pay-button'));
    await _waitAndReveal(tester, payButton);
    await _hold(tester, const Duration(milliseconds: 1200));
    await tester.tap(payButton.first);

    final viewOrderBtn = find.text('Ver detalles del pedido');
    await _waitAndReveal(tester, viewOrderBtn);
    await _hold(tester, const Duration(milliseconds: 2200));

    // Tap «Ver detalles del pedido» → returns to Account automatically!
    await tester.tap(viewOrderBtn.first);
    await _waitForFinder(tester, openRewardsGuide.hitTestable());
    await _hold(tester, const Duration(milliseconds: 1200));

    // Open Mis pedidos → Order #1 Detail (Pending).
    final openOrders = find.byKey(const ValueKey('account-open-orders'));
    await _waitForFinder(tester, openOrders.hitTestable());
    await _hold(tester, const Duration(milliseconds: 400));
    await tester.tap(openOrders.hitTestable().last);

    final orderCards = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('order-card-'),
    );
    await _waitForFinder(tester, orderCards);
    await _hold(tester, const Duration(milliseconds: 1000));
    await tester.tap(orderCards.first);

    await _waitAndReveal(
      tester,
      find.byKey(const ValueKey('order-rewards-status')),
    );
    await _hold(tester, const Duration(milliseconds: 2400));

    // ── SCENE 5: Delivery Webhook → Released / Available Green + PRO 10% Arc ─
    debugPrint('DEMO_SCENE:5 Delivery webhook & Available green balance');
    final order1Id = checkoutLauncher.createdOrderIds.first;
    await _postSignedWebhook(
      httpClient: httpClient,
      backendBaseUrl: backendUri,
      path: '/webhooks/fulfillment_events/create',
      webhookId: 'demo-delivered-$order1Id',
      payload: {
        'order_id': order1Id,
        'status': 'delivered',
        'happened_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
    await _postSignedWebhook(
      httpClient: httpClient,
      backendBaseUrl: backendUri,
      path: '/webhooks/orders/updated',
      webhookId: 'demo-order-updated-$order1Id',
      payload: {
        'id': order1Id,
        'name': '#1041',
        'financial_status': 'paid',
        'fulfillment_status': 'fulfilled',
        'currency': 'MXN',
        'current_total_price':
            checkoutLauncher.orderTotals[order1Id] ?? '1399.00',
        'updated_at': DateTime.now()
            .toUtc()
            .add(const Duration(seconds: 2))
            .toIso8601String(),
        'customer': {
          'id': _demoCustomerId,
          'email': 'sofia.garza@monetta.mx',
        },
      },
    );
    await accountController.loadOrders();

    // Pop Order #1 Detail → Orders list → Reopen Order #1 Detail to show Liberados!
    navigatorKey.currentState?.pop();
    await _waitForFinder(tester, orderCards);
    await _hold(tester, const Duration(milliseconds: 800));
    await tester.tap(orderCards.first);
    await _waitAndReveal(tester, find.textContaining('Liberados'));
    await _hold(tester, const Duration(milliseconds: 2200));

    // Back to Account (fresh mount so Miembro · PRO + green balance update) & Rewards Guide!
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
    await _hold(tester, const Duration(milliseconds: 450));
    await _waitForFinder(tester, bottomNavAccount.hitTestable());
    await tester.tap(bottomNavAccount.hitTestable().last);
    await _waitForFinder(tester, openRewardsGuide.hitTestable());
    await _hold(tester, const Duration(milliseconds: 1600));

    await tester.tap(openRewardsGuide.hitTestable().last);
    await _waitForFinder(
      tester,
      find.byKey(const ValueKey('rewards-progress-arc')),
    );
    await _hold(tester, const Duration(milliseconds: 2000));

    final openMovements = find.byKey(const ValueKey('rewards-open-movements'));
    await _waitAndReveal(tester, openMovements);
    await tester.tap(openMovements.hitTestable().last);
    await _waitForFinder(
      tester,
      find.byKey(const ValueKey('rewards-movements-balance')),
    );
    await _hold(tester, const Duration(milliseconds: 2200));

    // Close Rewards Guide & return to Catalog for Purchase #2.
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
    await _hold(tester, const Duration(milliseconds: 450));
    await openBagsCatalog();

    // ── SCENE 6: Purchase #2 Redeeming Rewards via CheckoutRewardsPanel ──────
    debugPrint('DEMO_SCENE:6 Purchase #2 redeeming Rewards');
    await openProductFromCatalog(p2);
    await tester
        .tap(find.byKey(const Key('purchase-dock-primary')).hitTestable().last);
    await _waitForFinder(tester, find.text('Resumen de compra').hitTestable());
    await _hold(tester, const Duration(milliseconds: 700));

    final rewardsPanel = find.byKey(const ValueKey('checkout-rewards-panel'));
    await _waitAndReveal(tester, rewardsPanel);
    await _hold(tester, const Duration(milliseconds: 1500));

    final toggle = find.byKey(const ValueKey('rewards-redemption-toggle'));
    await _waitAndReveal(tester, toggle);
    await tester.tap(toggle.hitTestable().last);
    await _hold(tester, const Duration(milliseconds: 1200));

    final applyBtn = find.text('APLICAR REWARDS');
    await _waitAndReveal(tester, applyBtn);
    await tester.tap(applyBtn.hitTestable().last);

    final appliedCard = find.byKey(const ValueKey('checkout-rewards-applied'));
    await _waitAndReveal(tester, appliedCard);
    await _hold(tester, const Duration(milliseconds: 2400));

    await _waitAndReveal(tester, miniCartContinue);
    await tester.tap(miniCartContinue.hitTestable().last);

    await _waitAndReveal(tester, payButton);
    await _hold(tester, const Duration(milliseconds: 1100));
    await tester.tap(payButton.hitTestable().last);

    await _waitAndReveal(tester, viewOrderBtn);
    await _hold(tester, const Duration(milliseconds: 2000));

    // ── SCENE 7: Final Account, Movimientos & Order #2 Detail ────────────────
    debugPrint('DEMO_SCENE:7 Final Account, Movimientos & Order #2 Detail');
    await tester.tap(viewOrderBtn.hitTestable().last);
    await _waitForFinder(tester, openRewardsGuide.hitTestable());
    await _hold(tester, const Duration(milliseconds: 1200));

    await tester.tap(openRewardsGuide.hitTestable().last);
    await _waitForFinder(
      tester,
      find.byKey(const ValueKey('rewards-progress-arc')),
    );
    await _hold(tester, const Duration(milliseconds: 1400));
    await _waitAndReveal(tester, openMovements);
    await tester.tap(openMovements.hitTestable().last);
    await _waitForFinder(
      tester,
      find.byKey(const ValueKey('rewards-movements-balance')),
    );
    await _hold(tester, const Duration(milliseconds: 2400));

    navigatorKey.currentState?.pop(); // movements
    await _hold(tester, const Duration(milliseconds: 350));
    navigatorKey.currentState?.pop(); // rewards guide
    await _waitForFinder(tester, openOrders.hitTestable());
    await tester.tap(openOrders.hitTestable().last);
    await _waitForFinder(tester, orderCards.hitTestable());
    await _hold(tester, const Duration(milliseconds: 900));
    await tester.tap(orderCards.hitTestable().first);

    await _waitAndReveal(tester, find.textContaining('Usaste'));
    await _hold(tester, const Duration(milliseconds: 2800));
    debugPrint('DEMO_SCENE:DONE');
  });
}
