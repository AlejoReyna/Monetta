/// App entry point.
///
/// Phase 1 demo build: the catalog comes from the bundled snapshot asset rather
/// than the Storefront API, because there is no access token yet. Everything
/// else — normalization, profiling, ranking, explanations — is the real code
/// from `data/normalize` and `reco`, running on the real 271-product catalog.
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
import 'data/customer_auth/customer_account_config.dart';
import 'data/customer_auth/customer_auth_gateway.dart';
import 'data/customer_auth/customer_session_repository.dart';
import 'data/customer_auth/device_identity.dart';
import 'data/customer_auth/secure_token_store.dart';
import 'data/local/account_store.dart';
import 'data/local/bag_store.dart';
import 'data/local/database.dart';
import 'data/local/order_summary_store.dart';
import 'data/local/wishlist_store.dart';
import 'data/repositories/order_history_repository.dart';
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
  late final CatalogStore _store = CatalogStore(database: _database);
  final ExternalCatalogController _externalCatalog = ExternalCatalogController(
    config: ExternalCatalogConfig.fromEnvironment(),
  );

  /// Built inside [_load], once the device id it depends on exists — see
  /// there. Only ever read from [build]'s `FutureBuilder`, after `_loading`
  /// has resolved, so it is always assigned by the time anything touches it.
  late final AccountController _account;
  late final Future<void> _loading = _load();

  Future<void> _load() async {
    // Seeds/hydrates the Drift database both `CatalogStore` and account
    // state share, so nothing below races it.
    await _store.loadFromAsset();

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

    final config = CustomerAccountConfig.fromEnvironment();
    _account = AccountController(
      sessionRepository: CustomerSessionRepository(
        authGateway: AppAuthCustomerGateway(config: config),
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
        config: AccountsOrdersConfig.fromEnvironment(),
      ),
      config: config,
      deviceId: deviceId,
    );
    await _account.restore();
    if (_account.isSignedIn) unawaited(_account.loadOrders());

    // Fire-and-forget: cache-first load, then a best-effort background
    // refresh. A failed or slow external fetch must never block or affect
    // the Monetta home screen — see ExternalCatalogRepository's contract.
    unawaited(_externalCatalog.loadAndRefresh());
  }

  @override
  void dispose() {
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
              return AccountScope(notifier: _account, child: const HomeScreen());
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
