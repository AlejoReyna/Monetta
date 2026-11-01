// Review findings of PR #46 «one-step checkout through Shopify».
//
// These are target (red) tests: each one fails today for the reason named in
// its description and passes once `checkout_screen.dart` is corrected.
//
//  - PR46-1  the identity row breaks with large text.
//  - PR46-2a/2b  signing in and paying can be started at the same time.
//  - PR46-3  the production launcher reads the account twice around an await.
//  - PR46-4  a profile photo that does not decode has no fallback.
import 'dart:async';
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
import 'package:monetta_app/data/customer_auth/customer_auth_gateway.dart';
import 'package:monetta_app/data/customer_auth/customer_profile.dart';
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
import 'package:monetta_app/domain/cart.dart';
import 'package:monetta_app/features/checkout/checkout_return.dart';
import 'package:monetta_app/features/checkout/checkout_screen.dart';
import 'package:monetta_app/features/checkout/reviewing_checkout.dart';
import 'package:monetta_app/main.dart';

import '../../support/bundled_fonts.dart';
import '../../support/shopify_cart_fakes.dart';

const _guestLabel = 'Comprando como invitado';
const _accountChangedMessage =
    'Tu cuenta cambió. Revisa tu bolsa e intenta de nuevo.';

void main() {
  setUpAll(() async {
    // Real faces: the square-glyph test font is wider than the shipped ones.
    await loadBundledFonts();
  });

  group('PR46-1 identity row under large text', () {
    for (final scale in [1.3, 1.5, 2.0, 3.0]) {
      for (final width in [320.0, 375.0, 440.0]) {
        testWidgets(
          'PR46-1 guest row fits at ${width.toInt()}x844, text x$scale',
          (tester) async {
            final store = await _loadedStore();
            await store.addToBag(
              store.products.firstWhere((item) => item.isInStock),
            );
            final database = openTestDatabase();
            addTearDown(database.close);
            final account =
                await _signInCapableController(database, _ShopGateway());
            addTearDown(account.dispose);
            expect(account.canLogin, isTrue);

            final watch = await _pumpScaled(
              tester,
              store,
              CheckoutFlowScreen(
                launchSecureCheckout: (_) async => const CheckoutCancelled(),
              ),
              account: account,
              width: width,
              scale: scale,
            );

            expect(watch.outsideOrderSummary, isEmpty);
            final identity =
                tester.getRect(find.byKey(const Key('checkout-identity')));
            final connect =
                tester.getRect(find.byKey(const Key('checkout-connect')));
            expect(
              _contains(identity, connect),
              isTrue,
              reason: 'checkout-connect $connect must sit inside '
                  'checkout-identity $identity',
            );
            final label = tester.getSize(find.text(_guestLabel));
            expect(
              label.width,
              greaterThanOrEqualTo(100),
              reason: '«$_guestLabel» must keep a readable width',
            );
          },
        );
      }
    }

    testWidgets(
      'PR46-1 connected row with a very long email survives x3.0 at 320',
      (tester) async {
        final store = await _loadedStore();
        await store.addToBag(
          store.products.firstWhere((item) => item.isInStock),
        );
        final database = openTestDatabase();
        addTearDown(database.close);
        const email = 'una.persona.con.un.correo.muy.largo.de.verdad@'
            'subdominio.empresa-ejemplo.com.mx';
        expect(email.length, greaterThan(40));
        final account = _plainController(database)
          ..account = _shopifyAccount('account-long', email: email);
        addTearDown(account.dispose);

        final watch = await _pumpScaled(
          tester,
          store,
          CheckoutFlowScreen(
            launchSecureCheckout: (_) async => const CheckoutCancelled(),
          ),
          account: account,
          width: 320,
          scale: 3.0,
        );

        expect(watch.outsideOrderSummary, isEmpty);
        final identity =
            tester.getRect(find.byKey(const Key('checkout-identity')));
        final emailRect =
            tester.getRect(find.byKey(const Key('checkout-identity-email')));
        expect(_contains(identity, emailRect), isTrue);
      },
    );
  });

  group('PR46-2 paying and signing in are mutually exclusive', () {
    testWidgets(
      'PR46-2a «Iniciar sesión» stays disabled while the payment is in '
      'progress',
      (tester) async {
        final store = await _loadedStore();
        await store.addToBag(
          store.products.firstWhere((item) => item.isInStock),
        );
        final database = openTestDatabase();
        addTearDown(database.close);
        final account =
            await _signInCapableController(database, _ShopGateway());
        addTearDown(account.dispose);
        final launch = Completer<CheckoutResult>();
        final lookup = _GatedLookup();

        await tester.pumpWidget(
          _app(
            store,
            CheckoutFlowScreen(
              launchSecureCheckout: (_) => launch.future,
              orderLookup: lookup,
              orderLookupTimeout: Duration.zero,
              correlationAvailable: true,
            ),
            account: account,
          ),
        );
        await tester.pump();
        expect(find.text('Iniciar sesión'), findsOneWidget);
        expect(_connectButton(tester).onPressed, isNotNull);

        // The checkout sheet is opening: the launcher has not answered yet.
        await _tapPayOnce(tester);
        expect(find.text('Abriendo checkout seguro…'), findsOneWidget);
        expect(
          _connectButton(tester).onPressed,
          isNull,
          reason: 'sign-in must be disabled while the sheet is opening',
        );

        // Shopify closed the sheet: the order is being confirmed.
        launch.complete(const CheckoutCancelled());
        await tester.pump();
        await tester.pump();
        expect(lookup.calls, 1);
        expect(
          _connectButton(tester).onPressed,
          isNull,
          reason: 'sign-in must be disabled while the order is confirmed',
        );

        // The final state: nothing is in progress any more.
        lookup.complete(null);
        await tester.pumpAndSettle();
        expect(find.text('No se completó tu pago'), findsOneWidget);
        expect(_connectButton(tester).onPressed, isNotNull);
      },
    );

    testWidgets(
      'PR46-2b «IR A PAGAR» does not start a checkout while sign-in is in '
      'progress',
      (tester) async {
        final store = await _loadedStore();
        await store.addToBag(
          store.products.firstWhere((item) => item.isInStock),
        );
        final database = openTestDatabase();
        addTearDown(database.close);
        final gateway = _ShopGateway();
        final account = await _signInCapableController(database, gateway);
        addTearDown(account.dispose);
        var launches = 0;

        await tester.pumpWidget(
          _app(
            store,
            CheckoutFlowScreen(
              launchSecureCheckout: (_) async {
                launches += 1;
                return const CheckoutCancelled();
              },
              orderLookup: const _NoOrders(),
              orderLookupTimeout: Duration.zero,
            ),
            account: account,
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('checkout-connect')));
        await tester.pump();
        expect(gateway.logins, 1);
        expect(account.isLoading, isTrue);

        await _tapPayOnce(tester);
        expect(
          launches,
          0,
          reason: 'the checkout must not open while sign-in is in progress',
        );

        gateway.succeed();
        await tester.pumpAndSettle();
        expect(account.isSignedIn, isTrue);
        expect(account.isLoading, isFalse);

        await _tapPayOnce(tester);
        await tester.pumpAndSettle();
        expect(launches, 1);
      },
    );
  });

  group('PR46-3 production launcher reads the account once', () {
    testWidgets(
      'PR46-3 an account that changes while the token is awaited never '
      'reconciles or presents',
      (tester) async {
        final store = await _loadedStore();
        await store.addToBag(
          store.products.firstWhere((item) => item.isInStock),
        );
        final database = openTestDatabase();
        addTearDown(database.close);
        final accounts = _TokenGateAccountController(database)
          ..account = _shopifyAccount('account-a', email: 'a@example.com');
        addTearDown(accounts.dispose);
        final reconciler = _RecordingReconciler();
        final cartController = CartController(reconciler: reconciler);
        addTearDown(cartController.dispose);
        final nativeLauncher =
            FakeCheckoutLauncher(const [CheckoutCancelled()]);
        final coordinator = ShopifyCheckoutCoordinator(
          launcher: nativeLauncher,
          urlPolicy: CheckoutUrlPolicy.forShopDomain(_shopDomain),
          sessions: InMemoryCartSessionStore(),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            builder: (context, navigator) => AppRouteScopes(
              accountController: accounts,
              cartController: cartController,
              checkoutCoordinator: coordinator,
              reviewingWarningStore: _MemoryWarningStore(),
              shopDomain: _shopDomain,
              child: navigator!,
            ),
            home: StoreScope(notifier: store, child: const BagScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final cta = find.text('Continuar al checkout').first;
        await tester.ensureVisible(cta);
        await tester.pumpAndSettle();
        await tester.tap(cta);
        await tester.pumpAndSettle();
        expect(find.byType(CheckoutFlowScreen), findsOneWidget);

        // From here on only the launcher's own calls count: the bag beneath
        // reconciles on its own without a buyer identity.
        reconciler.calls.clear();
        await _tapPayOnce(tester);
        expect(accounts.tokenRequests, 1, reason: 'token read for account A');

        // Account B signs in while the token of A is still being awaited.
        accounts.switchTo(
          _shopifyAccount('account-b', email: 'b@example.com'),
        );
        await tester.pump();
        accounts.tokenGate.complete('token-of-a');
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        final launcherCalls = [
          for (final call in reconciler.calls)
            if (call.buyerIdentity != null)
              'scope=${call.scope.buyerKey} '
                  'identity=${call.buyerIdentity.runtimeType}',
        ];
        expect(
          launcherCalls,
          isEmpty,
          reason: 'A launcher attempt that spans an account change must not '
              'reconcile: it mixes the identity of A with the scope of B',
        );
        expect(nativeLauncher.presentCalls, 0);
        expect(find.text('No pudimos abrir el pago'), findsOneWidget);
        expect(find.textContaining(_accountChangedMessage), findsOneWidget);
      },
    );
  });

  group('PR46-4 profile photo that does not decode', () {
    testWidgets(
      'PR46-4 shows the account glyph and raises no error',
      (tester) async {
        final store = await _loadedStore();
        await store.addToBag(
          store.products.firstWhere((item) => item.isInStock),
        );
        final database = openTestDatabase();
        addTearDown(database.close);
        final garbage = base64Encode(
          utf8.encode('this is text, not a PNG or a JPEG'),
        );
        final account = _plainController(database)
          ..account = _shopifyAccount('account-photo', email: 'p@example.com')
          ..profile = CustomerProfile(
            shopifyCustomerId: '1',
            photoDataUrl: 'data:image/png;base64,$garbage',
          );
        addTearDown(account.dispose);
        expect(account.profilePhotoBytes, isNotNull);

        await tester.pumpWidget(
          _app(
            store,
            CheckoutFlowScreen(
              launchSecureCheckout: (_) async => const CheckoutCancelled(),
            ),
            account: account,
          ),
        );
        // Let the engine try to decode the bytes.
        for (var i = 0; i < 5; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
        }

        expect(tester.takeException(), isNull);
        expect(
          find.descendant(
            of: find.byKey(const Key('checkout-identity')),
            matching: find.byIcon(Icons.person_outline),
          ),
          findsOneWidget,
        );
      },
    );
  });
}

const _shopDomain = 'checkout.invalid';

bool _contains(Rect outer, Rect inner) =>
    inner.left >= outer.left - 0.01 &&
    inner.right <= outer.right + 0.01 &&
    inner.top >= outer.top - 0.01 &&
    inner.bottom <= outer.bottom + 0.01;

TextButton _connectButton(WidgetTester tester) =>
    tester.widget<TextButton>(find.byKey(const Key('checkout-connect')));

/// One tap on the pay button, without settling: the opening spinner and a
/// pending sign-in are animations that never settle.
Future<void> _tapPayOnce(WidgetTester tester) async {
  final pay = find.byKey(const ValueKey('checkout-pay-button'));
  await tester.ensureVisible(pay);
  await tester.pump();
  await tester.tap(pay);
  await tester.pump();
}

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

Future<_ErrorWatch> _pumpScaled(
  WidgetTester tester,
  CatalogStore store,
  Widget child, {
  required AccountController account,
  required double width,
  required double scale,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final shop = StoreScope(notifier: store, child: child);
  // The binding insists that onError is back in place when the body ends, so
  // the watch lives only while the frames are pumped.
  final watch = _ErrorWatch.install();
  try {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        builder: (context, navigator) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: navigator!,
        ),
        home: AccountScope(notifier: account, child: shop),
      ),
    );
    await tester.pump();
  } finally {
    watch.uninstall();
  }
  return watch;
}

/// Collects every framework error raised during a test so that the ones from
/// the identity row can be told apart from the order summary above it.
///
/// `_CheckoutSummary` overflows on its own at 320 pt and x3.0 (its trailing
/// price is not flexible). That is a separate layout from the one PR46-1 is
/// about, so it is filtered out by the creator chain Flutter prints with
/// every overflow and reported separately.
final class _ErrorWatch {
  _ErrorWatch._(this._previous);

  factory _ErrorWatch.install() {
    final watch = _ErrorWatch._(FlutterError.onError);
    FlutterError.onError = watch.reported.add;
    return watch;
  }

  final void Function(FlutterErrorDetails)? _previous;
  final List<FlutterErrorDetails> reported = [];

  void uninstall() => FlutterError.onError = _previous;

  /// One line per error that does not come from `_CheckoutSummary`.
  List<String> get outsideOrderSummary => [
        for (final details in reported)
          if (!_creatorChain(details).contains('_CheckoutSummary'))
            details.exceptionAsString().split('\n').first,
      ];
}

/// The full text of an error, including the creator chain of a render object.
String _creatorChain(FlutterErrorDetails details) {
  final node = details.toDiagnosticsNode().toStringDeep();
  final error = details.exception;
  final own = error is FlutterError
      ? error.diagnostics.map((node) => node.toStringDeep()).join('\n')
      : '';
  return '$node\n$own';
}

Account _shopifyAccount(String id, {required String email}) => Account(
      localAccountId: id,
      authProvider: 'shopify',
      email: email,
      createdAt: DateTime.utc(2026, 10, 30),
      lastSeenAt: DateTime.utc(2026, 10, 30),
    );

AccountController _plainController(AppDatabase database) => AccountController(
      accountStore: AccountStore(database),
      deviceStore: DeviceStore(database),
      orderHistoryRepository: OrderHistoryRepository(
        store: OrderSummaryStore(database),
        config: AccountsOrdersConfig.disabled,
      ),
      deviceId: 'device-local',
    );

/// An account whose checkout token is held until the test releases it.
final class _TokenGateAccountController extends AccountController {
  _TokenGateAccountController(AppDatabase database)
      : super(
          accountStore: AccountStore(database),
          deviceStore: DeviceStore(database),
          orderHistoryRepository: OrderHistoryRepository(
            store: OrderSummaryStore(database),
            config: AccountsOrdersConfig.disabled,
          ),
          deviceId: 'device-local',
        );

  final tokenGate = Completer<String?>();
  int tokenRequests = 0;

  @override
  Future<String?> accessTokenForShopifyCheckout() {
    tokenRequests += 1;
    return tokenGate.future;
  }

  void switchTo(Account next) {
    account = next;
    notifyListeners();
  }
}

final class _ReconcileCall {
  const _ReconcileCall(this.scope, this.buyerIdentity);

  final CartSessionScope scope;
  final CartBuyerIdentity? buyerIdentity;
}

final class _RecordingReconciler implements CartReconciler {
  final List<_ReconcileCall> calls = [];

  @override
  Future<CartReconciliation> reconcile({
    required CartSessionScope scope,
    required Iterable<LocalCartIntent> localIntent,
    CartBuyerIdentity? buyerIdentity,
    List<String>? desiredDiscountCodes,
  }) async {
    calls.add(_ReconcileCall(scope, buyerIdentity));
    const money = CartMoney(amount: '10.00', currencyCode: 'MXN');
    final timestamp = DateTime.utc(2026, 10, 30);
    final lines = [
      for (final intent in localIntent)
        CartLine(
          id: _opaque('line-${intent.variantId}'),
          variantId: intent.variantId,
          productId: shopifyProductGid(1),
          title: 'Producto',
          variantTitle: 'Variante',
          quantity: intent.quantity,
          cost: const CartLineCost(
            amountPerQuantity: money,
            subtotal: money,
            total: money,
          ),
        ),
    ];
    return CartReconciliation(
      status: CartReconciliationStatus.authoritative,
      cart: Cart(
        id: _opaque('cart'),
        checkoutUrl: Uri(
          scheme: 'https',
          host: _shopDomain,
          path: '/cart/c/opaque',
          queryParameters: const {'key': 'redacted-fixture'},
        ).toString(),
        createdAt: timestamp,
        updatedAt: timestamp,
        lines: lines,
        totalQuantity: lines.fold(0, (sum, line) => sum + line.quantity),
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

/// Keeps the «reviewing» warning in memory instead of shared preferences.
final class _MemoryWarningStore implements ReviewingWarningStore {
  ReviewingWarningRecord? record;

  @override
  Future<ReviewingWarningRecord?> read() async => record;

  @override
  Future<void> write(ReviewingWarningRecord? record) async {
    this.record = record;
  }
}

class _NoOrders implements CheckoutOrderLookup {
  const _NoOrders();

  @override
  Future<CheckoutOrderMatch?> findOrder(
    CheckoutAttemptIdentity attempt,
  ) async {
    return null;
  }
}

/// An order lookup that answers when the test says so.
class _GatedLookup implements CheckoutOrderLookup {
  final _answer = Completer<CheckoutOrderMatch?>();
  int calls = 0;

  @override
  Future<CheckoutOrderMatch?> findOrder(CheckoutAttemptIdentity attempt) {
    calls += 1;
    return _answer.future;
  }

  void complete(CheckoutOrderMatch? match) => _answer.complete(match);
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
