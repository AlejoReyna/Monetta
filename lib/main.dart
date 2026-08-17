/// App entry point.
///
/// Catalog cold-start still uses the bundled snapshot when Drift is empty.
/// When public Storefront credentials are supplied via `--dart-define` /
/// `--dart-define-from-file`, a background Shopify delta sync refreshes the
/// cache after load. Without credentials the app behaves as before: asset +
/// offline cache only.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'app/account_controller.dart';
import 'app/catalog_store.dart';
import 'app/external_catalog_config.dart';
import 'app/external_catalog_controller.dart';
import 'app/theme.dart';
import 'data/accounts_orders/accounts_orders_config.dart';
import 'data/accounts_orders/system_account_client.dart';
import 'data/accounts_orders/system_account_session_repository.dart';
import 'data/customer_auth/customer_account_config.dart';
import 'data/customer_auth/customer_auth_gateway.dart';
import 'data/customer_auth/customer_identity.dart';
import 'data/customer_auth/customer_session_repository.dart';
import 'data/customer_auth/device_identity.dart';
import 'data/customer_auth/secure_token_store.dart';
import 'data/local/account_store.dart';
import 'data/local/bag_store.dart';
import 'data/local/database.dart';
import 'data/local/order_summary_store.dart';
import 'data/local/wishlist_store.dart';
import 'data/repositories/order_history_repository.dart';
import 'data/shopify/catalog_sync.dart' as shopify;
import 'data/shopify/http_storefront_transport.dart';
import 'data/shopify/storefront_client.dart';
import 'data/shopify/storefront_config.dart';
import 'features/home/home_screen.dart';

void main() {
  runApp(const MonettaApp());
}

/// Exposes the store to the widget tree.
///
/// Deliberately plain Flutter rather than Riverpod for now: the store is a
/// single object and this keeps the demo free of state-management wiring that
/// will be rewritten anyway when `data/local` lands.
class StoreScope extends InheritedNotifier<CatalogStore> {
  const StoreScope({
    required CatalogStore super.notifier,
    required super.child,
    super.key,
  });

  static CatalogStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StoreScope>();
    assert(scope?.notifier != null, 'StoreScope is missing from the tree');
    return scope!.notifier!;
  }
}

/// Exposes the external-catalog prototype to the widget tree. Present in
/// every build, but inert — `ExternalCatalogController.items` is always
/// empty — unless the app was built with
/// `--dart-define=ENABLE_EXTERNAL_CATALOG=true` and a base URL. See
/// `app/external_catalog_config.dart`.
class ExternalCatalogScope
    extends InheritedNotifier<ExternalCatalogController> {
  const ExternalCatalogScope({
    required ExternalCatalogController super.notifier,
    required super.child,
    super.key,
  });

  static ExternalCatalogController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ExternalCatalogScope>();
    assert(
      scope?.notifier != null,
      'ExternalCatalogScope is missing from the tree',
    );
    return scope!.notifier!;
  }
}

/// Exposes account state to the widget tree. See `app/account_controller.dart`
/// — `account == null` is a normal, fully-functional state, not a loading
/// gap. Only mounted once `_MonettaAppState._loading` has resolved, since
/// [AccountController] needs an async-bootstrapped device id to exist at
/// all — see `_MonettaAppState._load`.
class AccountScope extends InheritedNotifier<AccountController> {
  const AccountScope({
    required AccountController super.notifier,
    required super.child,
    super.key,
  });

  static AccountController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AccountScope>();
    assert(scope?.notifier != null, 'AccountScope is missing from the tree');
    return scope!.notifier!;
  }
}

class MonettaApp extends StatefulWidget {
  const MonettaApp({super.key});

  @override
  State<MonettaApp> createState() => _MonettaAppState();
}

class _MonettaAppState extends State<MonettaApp> {
  final AppDatabase _database = AppDatabase.connect();

  /// Null when no usable public Storefront credentials were compiled in.
  final HttpStorefrontTransport? _storefrontTransport =
      _maybeStorefrontTransport();
  late final CatalogStore _store = CatalogStore(
    database: _database,
    catalogSync: _maybeCatalogSync(_storefrontTransport),
  );
  final ExternalCatalogController _externalCatalog = ExternalCatalogController(
    config: ExternalCatalogConfig.fromEnvironment(),
  );

  /// Built inside [_load], once the device id it depends on exists — see
  /// there. Only ever read from [build]'s `FutureBuilder`, after `_loading`
  /// has resolved, so it is always assigned by the time anything touches it.
  late final AccountController _account;
  late final Future<void> _loading = _load();

  /// Owns an HTTP client, so it needs closing — and it is built inside
  /// [_load] (nullable rather than `late final`, since [dispose] can run
  /// before that future completes, and since a build without Customer Account
  /// credentials never creates one at all).
  HttpCustomerIdentityService? _customerIdentityService;

  static HttpStorefrontTransport? _maybeStorefrontTransport() {
    final config = StorefrontConfig.fromEnvironment();
    if (!config.isUsable) return null;
    return HttpStorefrontTransport();
  }

  static shopify.CatalogSync? _maybeCatalogSync(
    HttpStorefrontTransport? transport,
  ) {
    if (transport == null) return null;
    final config = StorefrontConfig.fromEnvironment();
    if (!config.isUsable) return null;
    return shopify.CatalogSync(
      client: StorefrontClient(config: config, transport: transport.send),
    );
  }

  Future<void> _load() async {
    // Seeds/hydrates the Drift database both `CatalogStore` and account
    // state share, so nothing below races it.
    await _store.loadFromAsset();

    // Best-effort Shopify refresh. Offline / missing credentials / API
    // errors must never block first paint — CatalogStore already has asset
    // or cache data from loadFromAsset.
    unawaited(_store.syncWithShopify());

    const secureStore = FlutterSecureTokenStore();
    final deviceStore = DeviceStore(_database);
    final deviceId = await ensureDeviceId(
      secureStore: secureStore,
      deviceStore: deviceStore,
      platform: Platform.isIOS ? 'ios' : 'android',
      // TODO(accounts): read from package_info_plus once that dependency
      // exists — see `lib/data/shopify/cart_attribution.dart`'s
      // `_app_version` attribute, which has the same gap.
      appVersion: '0.1.0',
    );

    // Shopify Customer Account login. Deliberately independent of
    // `AccountsOrdersConfig` below: OAuth talks to Shopify directly, so a
    // missing or unreachable Monetta accounts service must not disable login.
    // A build with no Customer Account credentials leaves both of these null,
    // `canLogin` false, and the account screen honest about it.
    final customerConfig = CustomerAccountConfig.fromEnvironment();
    CustomerSessionRepository? customerSession;
    if (customerConfig.isUsable) {
      final identityService = HttpCustomerIdentityService(
        config: customerConfig,
      );
      _customerIdentityService = identityService;
      customerSession = CustomerSessionRepository(
        authGateway: AppAuthCustomerGateway(config: customerConfig),
        identityService: identityService,
        accountStore: AccountStore(_database),
        sessionStore: SessionStore(_database),
        deviceStore: deviceStore,
        wishlistStore: WishlistStore(_database),
        bagStore: BagStore(_database),
        secureStore: secureStore,
        deviceId: deviceId,
      );
    }

    final accountsConfig = AccountsOrdersConfig.fromEnvironment();
    final accountsBaseUrl = accountsConfig.baseUrl;
    _account = AccountController(
      sessionRepository: customerSession,
      config: customerConfig.isUsable ? customerConfig : null,
      systemSessionRepository: SystemAccountSessionRepository(
        client: accountsBaseUrl == null
            ? null
            : HttpSystemAccountClient(baseUrl: accountsBaseUrl),
        accountStore: AccountStore(_database),
        sessionStore: SessionStore(_database),
        deviceStore: deviceStore,
        wishlistStore: WishlistStore(_database),
        bagStore: BagStore(_database),
        secureStore: secureStore,
        deviceId: deviceId,
      ),
      accountStore: AccountStore(_database),
      deviceStore: deviceStore,
      orderHistoryRepository: OrderHistoryRepository(
        store: OrderSummaryStore(_database),
        config: accountsConfig,
      ),
      deviceId: deviceId,
    );
    await _account.restore();
    if (_account.isSignedIn) {
      unawaited(_account.loadOrders());
      // Best-effort, never awaited: confirms with Shopify that the restored
      // refresh token still works, and drops to a clean guest state if it was
      // revoked. Offline is explicitly not treated as signed out — see
      // `AccountController.revalidateSession`.
      unawaited(_account.revalidateSession());
    }

    // Fire-and-forget: cache-first load, then a best-effort background
    // refresh. A failed or slow external fetch must never block or affect
    // the Monetta home screen — see ExternalCatalogRepository's contract.
    // External catalog stays off in public builds unless explicitly enabled.
    unawaited(_externalCatalog.loadAndRefresh());
  }

  @override
  void dispose() {
    _storefrontTransport?.close();
    _customerIdentityService?.close();
    _store.dispose();
    _externalCatalog.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monetta',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: StoreScope(
        notifier: _store,
        child: ExternalCatalogScope(
          notifier: _externalCatalog,
          child: FutureBuilder<void>(
            future: _loading,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _ErrorScreen(error: '${snapshot.error}');
              }
              if (snapshot.connectionState != ConnectionState.done) {
                return const _SplashScreen();
              }
              return AccountScope(
                notifier: _account,
                child: const HomeScreen(),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Wordmark centred over a thin gold rule instead of a spinner. A Material
/// spinner is the loudest possible "this is an app" signal, and this is the
/// first frame the shopper ever sees.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MonettaWordmark(height: 34),
            const SizedBox(height: 18),
            Text('Originales importados'.toUpperCase(), style: eyebrow()),
            const SizedBox(height: 36),
            const SizedBox(
              width: 64,
              height: 1,
              child: ColoredBox(color: kGold),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('No se pudo cargar el catálogo.', style: display(20)),
              const SizedBox(height: 12),
              Text(
                error,
                textAlign: TextAlign.center,
                style: sans(size: 12, color: kInkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
