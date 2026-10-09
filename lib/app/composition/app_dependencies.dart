/// Composition root of the app: builds, scopes and disposes every dependency.
///
/// `MonettaApp` owns one [AppDependencies] for its lifetime and mounts the
/// scopes from `app_scopes.dart` above the Navigator. This file is the only
/// place outside `lib/data/` that is allowed to construct concrete `data/`
/// implementations (ARCH-04).
library;

import 'dart:async';
import 'dart:io' show Platform;

import '../../data/accounts_orders/accounts_orders_config.dart';
import '../../data/accounts_orders/system_account_client.dart';
import '../../data/accounts_orders/system_account_session_repository.dart';
import '../../data/admin/admin_client.dart';
import '../../data/customer_auth/customer_account_config.dart';
import '../../data/customer_auth/customer_api_discovery.dart';
import '../../data/customer_auth/customer_auth_gateway.dart';
import '../../data/customer_auth/customer_identity.dart';
import '../../data/customer_auth/customer_orders.dart';
import '../../data/customer_auth/customer_session_repository.dart';
import '../../data/customer_auth/device_identity.dart';
import '../../data/customer_auth/secure_token_store.dart';
import '../../data/firestore/catalog_realtime_source.dart';
import '../../data/local/account_store.dart';
import '../../data/local/appearance_store.dart';
import '../../data/local/bag_store.dart';
import '../../data/local/database.dart';
import '../../data/local/onboarding_preference_store.dart';
import '../../data/local/order_summary_store.dart';
import '../../data/local/wishlist_store.dart';
import '../../data/notifications/admin_notification_client.dart';
import '../../data/notifications/local_notification_scheduler.dart';
import '../../data/notifications/notification_api_client.dart';
import '../../data/notifications/firebase_notification_gateway.dart';
import '../../data/notifications/notification_config.dart';
import '../../data/notifications/notification_models.dart';
import '../../data/repositories/order_history_repository.dart';
import '../../data/reviews/loox_reviews_repository.dart';
import '../../data/shopify/cart_attribution.dart';
import '../../data/shopify/catalog_sync.dart' as shopify;
import '../../data/shopify/editorial_content_repository.dart';
import '../../data/shopify/featured_catalog_repository.dart';
import '../../data/shopify/home_content_repository.dart';
import '../../data/shopify/http_storefront_transport.dart';
import '../../data/shopify/storefront_client.dart';
import '../../data/shopify/storefront_config.dart';
import '../../domain/shopper_scope.dart';
import '../../features/catalog/search_history.dart';
import '../../features/catalog/search_history_persistence.dart';
import '../account_controller.dart';
import '../admin_config.dart';
import '../admin_controller.dart';
import '../admin_notification_controller.dart';
import '../app_build_metadata.dart';
import '../catalog_store.dart';
import '../change_account_scope.dart';
import '../editorial_content_controller.dart';
import '../featured_catalog_controller.dart';
import '../home_content_controller.dart';
import '../notification_controller.dart';
import '../onboarding_controller.dart';
import '../shopify_cart_composition.dart';
import '../theme_controller.dart';

class AppDependencies {
  AppDependencies({
    required this.notificationConfig,
    required this.onOpenNotificationRoute,
    this.gateway,
    this.realtimeCatalogSource,
  });

  final NotificationConfig notificationConfig;
  final NotificationGateway? gateway;
  final CatalogRealtimeSource? realtimeCatalogSource;

  /// Called by [NotificationController] when a notification asks to open a
  /// route. The widget layer owns the Navigator, so it owns the navigation.
  final void Function(NotificationRouteData route) onOpenNotificationRoute;

  final AppDatabase _database = AppDatabase.connect();
  late final ThemeController theme = ThemeController(
    store: AppearanceStore(_database),
  );
  late final OnboardingController onboarding = OnboardingController(
    store: OnboardingPreferenceStore(_database),
  );

  /// Null when no usable public Storefront credentials were compiled in.
  final HttpStorefrontTransport? _storefrontTransport =
      _maybeStorefrontTransport();
  late final CatalogStore store = CatalogStore(
    database: _database,
    catalogSync: _maybeCatalogSync(_storefrontTransport),
    realtimeSource: realtimeCatalogSource,
    shopDomain: shopDomain.trim().isEmpty ? null : shopDomain.trim(),
  );
  late final EditorialContentController editorialContent =
      EditorialContentController(
    repository: _maybeEditorialRepository(_storefrontTransport),
  );
  late final HomeContentController homeContent = HomeContentController(
    repository: _maybeHomeContentRepository(_storefrontTransport),
    reviewsRepository: _maybeLooxReviewsRepository(),
  );
  late final FeaturedCatalogController featuredCatalog =
      FeaturedCatalogController(
    repository: _maybeFeaturedCatalogRepository(_storefrontTransport),
    cacheProducts: store.upsertShopifyProducts,
  );

  /// Built inside [load], once the device id it depends on exists. Only read
  /// after [load] has resolved, so it is always assigned by then.
  late final AccountController account;
  AdminController? admin;
  AdminNotificationController? adminNotifications;
  NotificationController? notifications;
  ShopifyCartComposition? shopifyCart;

  /// Owns an HTTP client, so it needs closing — and it is built inside [load]
  /// (nullable rather than `late final`, since [dispose] can run before that
  /// future completes, and since a build without Customer Account credentials
  /// never creates one at all).
  CustomerApiDiscoveryService? _customerApiDiscovery;
  HttpCustomerIdentityService? _customerIdentityService;
  HttpCustomerOrdersService? _customerOrdersService;
  HttpAdminClient? _adminClient;
  bool _adminCapListenerAttached = false;

  /// The configured Shopify domain (from the compile-time Storefront config).
  String get shopDomain => StorefrontConfig.fromEnvironment().shopDomain;

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

  /// Restores persisted state, seeds the catalog and builds every dependency
  /// that needs the device id. The order matters and is the app's startup
  /// order: do not reorder without a characterization test.
  Future<void> load() async {
    await Future.wait([theme.restore(), onboarding.restore()]);
    // Recent searches survive a restart via a file adapter (no Drift schema
    // bump). Best-effort: search still works session-scoped if this fails.
    try {
      SearchHistory.configureSharedPersistence(
        SearchHistoryFilePersistence(),
      );
    } on Object {
      // Keep the in-memory default.
    }
    final buildMetadata = await AppBuildMetadata.load();

    // Seeds/hydrates the Drift database both `CatalogStore` and account
    // state share, so nothing below races it.
    await store.loadFromAsset();

    // Best-effort Shopify refresh. Offline / missing credentials / API
    // errors must never block first paint — CatalogStore already has asset
    // or cache data from loadFromAsset.
    unawaited(store.syncWithShopify());
    unawaited(featuredCatalog.refresh());

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
      shopifyCart = ShopifyCartComposition.production(
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
      final discovery = CustomerApiDiscoveryService(config: customerConfig);
      _customerApiDiscovery = discovery;
      final identityService = HttpCustomerIdentityService(
        config: customerConfig,
        discovery: discovery,
      );
      _customerIdentityService = identityService;
      final ordersService = HttpCustomerOrdersService(
        config: customerConfig,
        discovery: discovery,
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

    final changeAccountScope = ChangeAccountScope(
      store: store,
      // Read lazily: the checkout exists only when the Storefront is usable.
      invalidateCheckout: () async {
        await shopifyCart?.checkout.invalidate();
      },
    );

    final accountsConfig = AccountsOrdersConfig.fromEnvironment();
    final accountsBaseUrl = accountsConfig.baseUrl;
    account = AccountController(
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
      onAccountScopeChanged: (accountId) => changeAccountScope(
        ShopperScope(shopDomain: shopDomain, accountId: accountId),
      ),
    );

    final adminConfig = AdminConfig.fromEnvironment();
    final adminBaseUrl = adminConfig.baseUrl;
    if (adminBaseUrl != null) {
      _adminClient = HttpAdminClient(
        baseUrl: adminBaseUrl,
        accessTokenProvider: account.accessTokenForAdmin,
      );
    }
    admin = AdminController(
      config: adminConfig,
      client: _adminClient,
      refreshApp: () async {
        await store.syncWithShopify();
        await editorialContent.refresh();
        await homeContent.refresh();
        await featuredCatalog.refresh();
      },
    );
    account.addListener(_refreshAdminCapabilities);
    _adminCapListenerAttached = true;
    final notificationBaseUrl = notificationConfig.apiBaseUrl;
    notifications = NotificationController(
      config: notificationConfig,
      deviceId: deviceId,
      catalogStore: store,
      secureStore: secureStore,
      gateway: gateway,
      apiClient: notificationBaseUrl == null || gateway == null
          ? null
          : NotificationApiClient(
              baseUrl: notificationBaseUrl,
              appCheckTokenProvider: gateway!.appCheckToken,
            ),
      localScheduler: gateway == null
          ? null
          : PluginLocalNotificationScheduler(
              timezone: notificationConfig.timezone,
            ),
      onOpenRoute: onOpenNotificationRoute,
    );
    final notificationAdminBaseUrl =
        notificationConfig.apiBaseUrl ?? adminBaseUrl;
    adminNotifications = AdminNotificationController(
      deviceId: deviceId,
      client: notificationAdminBaseUrl == null
          ? null
          : AdminNotificationClient(
              baseUrl: notificationAdminBaseUrl,
              accessTokenProvider: account.accessTokenForAdmin,
            ),
    );
    await account.restore();
    if (account.isSignedIn) {
      unawaited(admin?.refreshCapabilities());
      unawaited(account.loadOrders());
      // Best-effort, never awaited: confirms with Shopify that the restored
      // refresh token still works, and drops to a clean guest state if it was
      // revoked. Offline is explicitly not treated as signed out — see
      // `AccountController.revalidateSession`.
      unawaited(account.revalidateSession());
    }

    // Fire-and-forget content refresh. External catalog retired (WP-02).
    unawaited(editorialContent.refresh());
    unawaited(homeContent.refresh());
    unawaited(featuredCatalog.refresh());
    // Notifications initialize in the background: restore() never throws and
    // talks to the OS and the network, so the first paint must not wait on it.
    // A route it delivers before the Navigator exists is held by the widget
    // layer's `onOpenNotificationRoute`.
    unawaited(notifications!.restore());
    await store.waitForInitialCatalog();
  }

  void _refreshAdminCapabilities() {
    unawaited(admin?.refreshCapabilities());
  }

  void dispose() {
    if (_adminCapListenerAttached) {
      account.removeListener(_refreshAdminCapabilities);
      _adminCapListenerAttached = false;
    }
    _storefrontTransport?.close();
    _customerIdentityService?.close();
    _customerOrdersService?.close();
    _customerApiDiscovery?.close();
    _adminClient?.close();
    admin?.dispose();
    notifications?.dispose();
    adminNotifications?.dispose();
    shopifyCart?.controller.dispose();
    store.dispose();
    editorialContent.dispose();
    homeContent.dispose();
    featuredCatalog.dispose();
    onboarding.dispose();
    theme.dispose();
  }
}
