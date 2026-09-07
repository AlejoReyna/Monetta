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
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'app/account_controller.dart';
import 'app/admin_config.dart';
import 'app/admin_controller.dart';
import 'app/admin_notification_controller.dart';
import 'app/app_build_metadata.dart';
import 'app/catalog_store.dart';
import 'app/cart_controller.dart';
import 'app/editorial_content_controller.dart';
import 'app/featured_catalog_controller.dart';
import 'app/home_content_controller.dart';
import 'app/notification_controller.dart';
import 'app/onboarding_controller.dart';
import 'app/product_telemetry.dart';
import 'app/runtime_config.dart';
import 'app/shopify_cart_composition.dart';
import 'app/shopify_checkout_coordinator.dart';
import 'app/theme.dart';
import 'app/theme_controller.dart';
import 'data/accounts_orders/accounts_orders_config.dart';
import 'data/accounts_orders/system_account_client.dart';
import 'data/accounts_orders/system_account_session_repository.dart';
import 'data/admin/admin_client.dart';
import 'data/customer_auth/customer_account_config.dart';
import 'data/customer_auth/customer_auth_gateway.dart';
import 'data/customer_auth/customer_identity.dart';
import 'data/customer_auth/customer_orders.dart';
import 'data/customer_auth/customer_session_repository.dart';
import 'data/customer_auth/device_identity.dart';
import 'data/customer_auth/secure_token_store.dart';
import 'data/firebase/firebase_app_bootstrap.dart';
import 'data/firestore/catalog_realtime_source.dart';
import 'data/firestore/firestore_catalog_config.dart';
import 'data/firestore/firestore_catalog_source.dart';
import 'data/local/account_store.dart';
import 'data/local/appearance_store.dart';
import 'data/local/bag_store.dart';
import 'data/local/database.dart';
import 'data/local/order_summary_store.dart';
import 'data/local/onboarding_preference_store.dart';
import 'data/local/wishlist_store.dart';
import 'data/notifications/firebase_notification_gateway.dart';
import 'data/notifications/admin_notification_client.dart';
import 'data/notifications/local_notification_scheduler.dart';
import 'data/notifications/notification_api_client.dart';
import 'data/notifications/notification_config.dart';
import 'data/notifications/notification_models.dart';
import 'data/repositories/order_history_repository.dart';
import 'data/reviews/loox_reviews_repository.dart';
import 'data/shopify/catalog_sync.dart' as shopify;
import 'data/shopify/cart_attribution.dart';
import 'data/shopify/editorial_content_repository.dart';
import 'data/shopify/featured_catalog_repository.dart';
import 'data/shopify/home_content_repository.dart';
import 'data/shopify/http_storefront_transport.dart';
import 'data/shopify/storefront_client.dart';
import 'data/shopify/storefront_config.dart';
import 'features/home/home_screen.dart';
import 'features/catalog/collection_screen.dart';
import 'features/product/product_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final accountsConfig = AccountsOrdersConfig.fromEnvironment();
  final notifications = NotificationConfig.fromEnvironment(
    fallbackBaseUrl: accountsConfig.baseUrl,
  );
  final firestoreCatalogConfig = FirestoreCatalogConfig.fromEnvironment();
  final storefrontConfig = StorefrontConfig.fromEnvironment();
  final runtimeConfig = RuntimeConfig.fromEnvironment();
  final configurationError = runtimeConfig.catalogConfigurationError(
    firestore: firestoreCatalogConfig,
    hasFirebaseOptions: notifications.hasFirebaseOptions,
    hasShopify: storefrontConfig.isUsable,
  );
  if (configurationError != null) {
    runApp(_ConfigurationErrorApp(message: configurationError));
    return;
  }
  CatalogRealtimeSource? realtimeCatalogSource;
  if (firestoreCatalogConfig.enabled && notifications.hasFirebaseOptions) {
    try {
      await FirebaseAppBootstrap.ensureInitialized(
        notifications.firebaseOptions,
      );
      realtimeCatalogSource = FirestoreCatalogSource(
        FirebaseFirestore.instance,
      );
    } catch (error) {
      if (runtimeConfig.requiresFirestore) {
        runApp(
          _ConfigurationErrorApp(
            message: 'No se pudo iniciar el catálogo de Firestore '
                '(${error.runtimeType}).',
          ),
        );
        return;
      }
      debugPrint('Firestore catalog bootstrap disabled: $error');
    }
  }
  ProductTelemetry telemetry = const DisabledProductTelemetry();
  if (TelemetryConfig.fromEnvironment().enabled) {
    if (notifications.hasFirebaseOptions) {
      try {
        await FirebaseAppBootstrap.ensureInitialized(
          notifications.firebaseOptions,
        );
        telemetry = await FirebaseProductTelemetry.start();
        _installTelemetryErrorHandlers(telemetry);
        await telemetry.log(
          ProductEvent.appOpen,
          parameters: const {
            'environment': String.fromEnvironment(
              'APP_ENV',
              defaultValue: 'local',
            ),
          },
        );
      } on Object catch (error, stackTrace) {
        debugPrint('Product telemetry bootstrap disabled: $error');
        await telemetry.recordError(
          error,
          stackTrace,
          reason: 'telemetry_bootstrap',
        );
      }
    } else {
      debugPrint('Product telemetry disabled: Firebase options are missing.');
    }
  }
  NotificationGateway? gateway;
  try {
    gateway = await FirebaseNotificationGateway.initialize(notifications);
  } catch (error) {
    // A missing Firebase native capability must not stop the storefront.
    debugPrint('Notifications bootstrap disabled: $error');
  }
  runApp(
    MonettaApp(
      notificationConfig: notifications,
      gateway: gateway,
      realtimeCatalogSource: realtimeCatalogSource,
      telemetry: telemetry,
    ),
  );
}

void _installTelemetryErrorHandlers(ProductTelemetry telemetry) {
  final previousFlutterHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    previousFlutterHandler?.call(details);
    unawaited(
      telemetry.recordError(
        details.exception,
        details.stack ?? StackTrace.current,
        fatal: true,
        reason: 'flutter_framework',
      ),
    );
  };

  final previousPlatformHandler = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    unawaited(
      telemetry.recordError(
        error,
        stackTrace,
        fatal: true,
        reason: 'platform_dispatcher',
      ),
    );
    return previousPlatformHandler?.call(error, stackTrace) ?? false;
  };
}

class _ConfigurationErrorApp extends StatelessWidget {
  const _ConfigurationErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Configuración incompleta',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(message),
                    const SizedBox(height: 14),
                    const SelectableText(
                      'make run-staging',
                      style: TextStyle(fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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

  static CatalogStore? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<StoreScope>()?.notifier;
  }
}

/// Exposes owner-editable About and reseller content. The controller always
/// contains a complete bundled fallback, so this scope never represents a
/// loading gate.
class EditorialContentScope
    extends InheritedNotifier<EditorialContentController> {
  const EditorialContentScope({
    required EditorialContentController super.notifier,
    required super.child,
    super.key,
  });

  static EditorialContentController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<EditorialContentScope>()
        ?.notifier;
  }
}

/// Exposes the Shopify/Loox-backed home composition. Like editorial content,
/// it always starts with a complete bundled fallback and never gates startup.
class HomeContentScope extends InheritedNotifier<HomeContentController> {
  const HomeContentScope({
    required HomeContentController super.notifier,
    required super.child,
    super.key,
  });

  static HomeContentController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<HomeContentScope>()
        ?.notifier;
  }
}

/// Shopify-backed Today's Picks. It is separate from [HomeContentScope]
/// because membership is a mutable commerce collection, not editorial copy.
class FeaturedCatalogScope
    extends InheritedNotifier<FeaturedCatalogController> {
  const FeaturedCatalogScope({
    required FeaturedCatalogController super.notifier,
    required super.child,
    super.key,
  });

  static FeaturedCatalogController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<FeaturedCatalogScope>()
      ?.notifier;
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

  static AccountController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccountScope>()?.notifier;
}

/// Optional production Shopify cart stack. It is absent in builds without
/// public Storefront configuration and performs no work merely by being built.
class CartScope extends InheritedNotifier<CartController> {
  const CartScope({
    required this.shopDomain,
    this.checkoutCoordinator,
    required CartController super.notifier,
    required super.child,
    super.key,
  });

  final String shopDomain;
  final ShopifyCheckoutCoordinator? checkoutCoordinator;

  static CartScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CartScope>();
}

/// Places account and cart dependencies above the app Navigator so every
/// sibling route observes the same configured controller and buyer scope.
class AppRouteScopes extends StatelessWidget {
  const AppRouteScopes({
    required this.accountController,
    required this.cartController,
    this.checkoutCoordinator,
    this.catalogStore,
    this.notificationController,
    required this.shopDomain,
    required this.child,
    super.key,
  });

  final AccountController accountController;
  final CartController? cartController;
  final ShopifyCheckoutCoordinator? checkoutCoordinator;
  final CatalogStore? catalogStore;
  final NotificationController? notificationController;
  final String shopDomain;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cart = cartController;
    Widget routedApp = cart == null
        ? child
        : CartScope(
            shopDomain: shopDomain,
            notifier: cart,
            checkoutCoordinator: checkoutCoordinator,
            child: child,
          );
    final notifications = notificationController;
    if (notifications != null) {
      routedApp = NotificationScope(
        notifier: notifications,
        child: routedApp,
      );
    }
    final store = catalogStore;
    if (store != null) {
      routedApp = StoreScope(notifier: store, child: routedApp);
    }
    return AccountScope(notifier: accountController, child: routedApp);
  }
}

/// Exposes owner administration alongside account and catalog state. The
/// controller is always mounted, but its entry point remains hidden unless
/// the signed-in email matches [AdminConfig.ownerEmails] (or an explicit
/// preview build was requested).
class AdminScope extends InheritedNotifier<AdminController> {
  const AdminScope({
    required AdminController super.notifier,
    required super.child,
    super.key,
  });

  static AdminController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AdminScope>();
    assert(scope?.notifier != null, 'AdminScope is missing from the tree');
    return scope!.notifier!;
  }

  static AdminController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AdminScope>()?.notifier;
  }
}

/// Exposes opt-in notification state without coupling feature widgets to FCM.
class NotificationScope extends InheritedNotifier<NotificationController> {
  const NotificationScope({
    required NotificationController super.notifier,
    required super.child,
    super.key,
  });

  static NotificationController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<NotificationScope>();
    assert(scope?.notifier != null, 'NotificationScope is missing');
    return scope!.notifier!;
  }

  static NotificationController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<NotificationScope>()
        ?.notifier;
  }
}

class AdminNotificationScope
    extends InheritedNotifier<AdminNotificationController> {
  const AdminNotificationScope({
    required AdminNotificationController super.notifier,
    required super.child,
    super.key,
  });

  static AdminNotificationController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AdminNotificationScope>()
        ?.notifier;
  }
}

class MonettaApp extends StatefulWidget {
  const MonettaApp({
    this.notificationConfig = NotificationConfig.disabled,
    this.gateway,
    this.realtimeCatalogSource,
    this.telemetry = const DisabledProductTelemetry(),
    super.key,
  });

  final NotificationConfig notificationConfig;
  final NotificationGateway? gateway;
  final CatalogRealtimeSource? realtimeCatalogSource;
  final ProductTelemetry telemetry;

  @override
  State<MonettaApp> createState() => _MonettaAppState();
}

class _MonettaAppState extends State<MonettaApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final AppDatabase _database = AppDatabase.connect();
  late final ThemeController _theme = ThemeController(
    store: AppearanceStore(_database),
  );
  late final OnboardingController _onboarding = OnboardingController(
    store: OnboardingPreferenceStore(_database),
  );

  /// Null when no usable public Storefront credentials were compiled in.
  final HttpStorefrontTransport? _storefrontTransport =
      _maybeStorefrontTransport();
  late final CatalogStore _store = CatalogStore(
    database: _database,
    catalogSync: _maybeCatalogSync(_storefrontTransport),
    realtimeSource: widget.realtimeCatalogSource,
    shopDomain: StorefrontConfig.fromEnvironment().shopDomain.trim().isEmpty
        ? null
        : StorefrontConfig.fromEnvironment().shopDomain.trim(),
  );
  late final EditorialContentController _editorialContent =
      EditorialContentController(
    repository: _maybeEditorialRepository(_storefrontTransport),
  );
  late final HomeContentController _homeContent = HomeContentController(
    repository: _maybeHomeContentRepository(_storefrontTransport),
    reviewsRepository: _maybeLooxReviewsRepository(),
  );
  late final FeaturedCatalogController _featuredCatalog =
      FeaturedCatalogController(
    repository: _maybeFeaturedCatalogRepository(_storefrontTransport),
    cacheProducts: _store.upsertShopifyProducts,
  );

  /// Built inside [_load], once the device id it depends on exists — see
  /// there. Only ever read from [build]'s `FutureBuilder`, after `_loading`
  /// has resolved, so it is always assigned by the time anything touches it.
  late final AccountController _account;
  AdminController? _admin;
  AdminNotificationController? _adminNotifications;
  NotificationController? _notifications;
  ShopifyCartComposition? _shopifyCart;
  late final Future<void> _loading = _load();

  /// Owns an HTTP client, so it needs closing — and it is built inside
  /// [_load] (nullable rather than `late final`, since [dispose] can run
  /// before that future completes, and since a build without Customer Account
  /// credentials never creates one at all).
  HttpCustomerIdentityService? _customerIdentityService;
  HttpCustomerOrdersService? _customerOrdersService;
  HttpAdminClient? _adminClient;
  bool _adminCapListenerAttached = false;

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

  static EditorialContentRepository? _maybeEditorialRepository(
    HttpStorefrontTransport? transport,
  ) {
    if (transport == null) return null;
    final config = StorefrontConfig.fromEnvironment();
    if (!config.isUsable) return null;
    return EditorialContentRepository(
      client: StorefrontClient(config: config, transport: transport.send),
    );
  }

  static HomeContentRepository? _maybeHomeContentRepository(
    HttpStorefrontTransport? transport,
  ) {
    if (transport == null) return null;
    final config = StorefrontConfig.fromEnvironment();
    if (!config.isUsable) return null;
    return HomeContentRepository(
      client: StorefrontClient(config: config, transport: transport.send),
    );
  }

  static FeaturedCatalogRepository _maybeFeaturedCatalogRepository(
    HttpStorefrontTransport? transport,
  ) {
    final config = StorefrontConfig.fromEnvironment();
    // The controller's repository is only used when the public Storefront
    // config is valid. Keep a transport-backed repository here; the startup
    // configuration gate already handles invalid builds.
    return FeaturedCatalogRepository(
      client: StorefrontClient(
        config: config,
        transport: transport?.send ??
            ((endpoint, headers, body) async =>
                <String, dynamic>{'data': <String, dynamic>{}}),
      ),
    );
  }

  static LooxReviewsRepository? _maybeLooxReviewsRepository() {
    final config = LooxConfig.fromEnvironment();
    if (!config.isUsable) return null;
    return LooxReviewsRepository(config: config);
  }

  Future<void> _load() async {
    await Future.wait([_theme.restore(), _onboarding.restore()]);
    final buildMetadata = await AppBuildMetadata.load();

    // Seeds/hydrates the Drift database both `CatalogStore` and account
    // state share, so nothing below races it.
    await _store.loadFromAsset();

    // Best-effort Shopify refresh. Offline / missing credentials / API
    // errors must never block first paint — CatalogStore already has asset
    // or cache data from loadFromAsset.
    unawaited(_store.syncWithShopify());
    unawaited(_featuredCatalog.refresh());

    const secureStore = FlutterSecureTokenStore();
    final deviceStore = DeviceStore(_database);
    final deviceId = await ensureDeviceId(
      secureStore: secureStore,
      deviceStore: deviceStore,
      platform: Platform.isIOS ? 'ios' : 'android',
      appVersion: buildMetadata.displayVersion,
    );

    final storefrontConfig = StorefrontConfig.fromEnvironment();
    final storefrontTransport = _storefrontTransport;
    if (storefrontTransport != null && storefrontConfig.isUsable) {
      _shopifyCart = ShopifyCartComposition.production(
        config: storefrontConfig,
        transport: storefrontTransport,
        secureStore: secureStore,
        attribution: CartAttribution(
          platform: Platform.isIOS ? 'ios' : 'android',
          deviceId: deviceId,
          appVersion: buildMetadata.displayVersion,
        ),
      );
    }

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
      final ordersService = HttpCustomerOrdersService(
        config: customerConfig,
      );
      _customerOrdersService = ordersService;
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
        customerOrders: _customerOrdersService,
      ),
      deviceId: deviceId,
      onAccountScopeChanged: (accountId) async {
        await _store.setAccountScope(accountId);
        // Login/logout/account switch must never reuse a preloaded checkout
        // document that belonged to a previous buyer identity (F06/F18).
        await _shopifyCart?.checkout.invalidate();
      },
    );

    final adminConfig = AdminConfig.fromEnvironment();
    final adminBaseUrl = adminConfig.baseUrl;
    if (adminBaseUrl != null) {
      _adminClient = HttpAdminClient(
        baseUrl: adminBaseUrl,
        accessTokenProvider: _account.accessTokenForAdmin,
      );
    }
    _admin = AdminController(
      config: adminConfig,
      client: _adminClient,
      refreshApp: () async {
        await _store.syncWithShopify();
        await _editorialContent.refresh();
        await _homeContent.refresh();
        await _featuredCatalog.refresh();
      },
    );
    _account.addListener(_refreshAdminCapabilities);
    _adminCapListenerAttached = true;
    final notificationBaseUrl = widget.notificationConfig.apiBaseUrl;
    _notifications = NotificationController(
      config: widget.notificationConfig,
      deviceId: deviceId,
      catalogStore: _store,
      secureStore: secureStore,
      gateway: widget.gateway,
      apiClient: notificationBaseUrl == null || widget.gateway == null
          ? null
          : NotificationApiClient(
              baseUrl: notificationBaseUrl,
              appCheckTokenProvider: widget.gateway!.appCheckToken,
            ),
      localScheduler: widget.gateway == null
          ? null
          : PluginLocalNotificationScheduler(
              timezone: widget.notificationConfig.timezone,
            ),
      onOpenRoute: _openNotificationRoute,
    );
    final notificationAdminBaseUrl =
        widget.notificationConfig.apiBaseUrl ?? adminBaseUrl;
    _adminNotifications = AdminNotificationController(
      deviceId: deviceId,
      client: notificationAdminBaseUrl == null
          ? null
          : AdminNotificationClient(
              baseUrl: notificationAdminBaseUrl,
              accessTokenProvider: _account.accessTokenForAdmin,
            ),
    );
    await _account.restore();
    if (_account.isSignedIn) {
      unawaited(_admin?.refreshCapabilities());
      unawaited(_account.loadOrders());
      // Best-effort, never awaited: confirms with Shopify that the restored
      // refresh token still works, and drops to a clean guest state if it was
      // revoked. Offline is explicitly not treated as signed out — see
      // `AccountController.revalidateSession`.
      unawaited(_account.revalidateSession());
    }

    // Fire-and-forget content refresh. External catalog retired (WP-02).
    unawaited(_editorialContent.refresh());
    unawaited(_homeContent.refresh());
    unawaited(_featuredCatalog.refresh());
    await _notifications!.restore();
  }

  void _openNotificationRoute(NotificationRouteData route) {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    if (route.type == 'product' && route.productKey != null) {
      final key = route.productKey!;
      // external:* notification routes are ignored — monitor catalog retired.
      if (key.startsWith('external:')) {
        navigator.popUntil((candidate) => candidate.isFirst);
        return;
      }
      final rawId =
          key.startsWith('shopify:') ? key.substring('shopify:'.length) : key;
      final exists = _store.products.any((product) => product.id == rawId);
      if (exists) {
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => ProductScreen(productId: rawId),
          ),
        );
        return;
      }
    }
    if (route.type == 'collection' && route.collectionHandle != null) {
      final handle = route.collectionHandle!;
      // Collection identity is the Shopify handle, not a facet category slug.
      // Using category here opened the wrong (or empty) result set (F28).
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => CollectionScreen(
            title: handle,
            filter: CollectionFilter(collectionHandle: handle),
          ),
        ),
      );
      return;
    }
    navigator.popUntil((candidate) => candidate.isFirst);
  }

  void _refreshAdminCapabilities() {
    unawaited(_admin?.refreshCapabilities());
  }

  @override
  void dispose() {
    if (_adminCapListenerAttached) {
      _account.removeListener(_refreshAdminCapabilities);
      _adminCapListenerAttached = false;
    }
    _storefrontTransport?.close();
    _customerIdentityService?.close();
    _customerOrdersService?.close();
    _adminClient?.close();
    _admin?.dispose();
    _notifications?.dispose();
    _adminNotifications?.dispose();
    _shopifyCart?.controller.dispose();
    _store.dispose();
    _editorialContent.dispose();
    _homeContent.dispose();
    _featuredCatalog.dispose();
    _onboarding.dispose();
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _theme,
      builder: (context, _) => ProductTelemetryScope(
        telemetry: widget.telemetry,
        child: ThemeScope(
          notifier: _theme,
          child: MaterialApp(
            navigatorKey: _navigatorKey,
            title: 'Monetta',
            debugShowCheckedModeBanner: false,
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: _theme.mode,
            builder: (context, navigator) {
              final overlay =
                  Theme.of(context).appBarTheme.systemOverlayStyle ??
                      SystemUiOverlayStyle.light;
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: overlay,
                child: FutureBuilder<void>(
                  future: _loading,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _ErrorScreen(error: '${snapshot.error}');
                    }
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const _SplashScreen();
                    }
                    return AppRouteScopes(
                      accountController: _account,
                      cartController: _shopifyCart?.controller,
                      checkoutCoordinator: _shopifyCart?.checkout,
                      catalogStore: _store,
                      notificationController: _notifications,
                      shopDomain: StorefrontConfig.fromEnvironment().shopDomain,
                      child: navigator!,
                    );
                  },
                ),
              );
            },
            home: StoreScope(
              notifier: _store,
              child: EditorialContentScope(
                notifier: _editorialContent,
                child: HomeContentScope(
                  notifier: _homeContent,
                  child: FeaturedCatalogScope(
                    notifier: _featuredCatalog,
                    child: FutureBuilder<void>(
                      future: _loading,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const SizedBox.shrink();
                        }
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const SizedBox.shrink();
                        }
                        return NotificationScope(
                          notifier: _notifications!,
                          child: AdminNotificationScope(
                            notifier: _adminNotifications!,
                            child: AdminScope(
                              notifier: _admin!,
                              child: OnboardingScope(
                                notifier: _onboarding,
                                child: const HomeScreen(),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
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
    final colors = context.monettaColors;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MonettaWordmark(height: 34),
            const SizedBox(height: 18),
            Text(
              'Originales importados'.toUpperCase(),
              style: eyebrow(color: colors.contentMuted),
            ),
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
    final colors = context.monettaColors;
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
                style: sans(size: 12, color: colors.contentMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
