/// The app widget: Navigator, theme, startup reveal and scope mounting.
///
/// It owns no dependency construction: [AppDependencies] (the composition
/// root) builds and disposes them, and `AppRouteScopes` mounts them above the
/// Navigator.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/notifications/firebase_notification_gateway.dart';
import '../data/notifications/notification_config.dart';
import '../data/notifications/notification_models.dart';
import '../data/firestore/catalog_realtime_source.dart';
import '../features/catalog/collection_screen.dart';
import '../features/home/home_screen.dart';
import '../features/product/product_screen.dart';
import '../features/welcome/welcome_gate.dart';
import 'composition/app_dependencies.dart';
import 'composition/app_scopes.dart';
import 'font_licenses.dart';
import 'product_telemetry.dart';
import 'startup_reveal.dart';
import 'text_scale_policy.dart';
import 'theme.dart';
import 'theme_controller.dart';

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
  late final AppDependencies _deps;
  late final Future<void> _loading = _deps.load();

  /// Latest notification route that arrived before the Navigator existed.
  NotificationRouteData? _pendingNotificationRoute;
  bool _pendingNotificationRouteScheduled = false;

  void _openNotificationRoute(NotificationRouteData route) {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      // Cold start: the Navigator is only mounted once `_loading` finishes.
      // Keep the latest route and open it after the frame that mounts it.
      _pendingNotificationRoute = route;
      if (!_pendingNotificationRouteScheduled) {
        _pendingNotificationRouteScheduled = true;
        unawaited(
          _loading.then<void>(
            (_) => WidgetsBinding.instance.addPostFrameCallback(
              (_) => _openPendingNotificationRoute(),
            ),
            onError: (Object _, StackTrace __) {
              _pendingNotificationRoute = null;
            },
          ),
        );
      }
      return;
    }
    _pendingNotificationRoute = null;
    _navigateToNotificationRoute(navigator, route);
  }

  void _openPendingNotificationRoute() {
    final route = _pendingNotificationRoute;
    _pendingNotificationRoute = null;
    _pendingNotificationRouteScheduled = false;
    if (route == null || !mounted) return;
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    _navigateToNotificationRoute(navigator, route);
  }

  void _navigateToNotificationRoute(
    NavigatorState navigator,
    NotificationRouteData route,
  ) {
    if (route.type == 'product' && route.productKey != null) {
      final key = route.productKey!;
      // external:* notification routes are ignored — monitor catalog retired.
      if (key.startsWith('external:')) {
        navigator.popUntil((candidate) => candidate.isFirst);
        return;
      }
      final rawId =
          key.startsWith('shopify:') ? key.substring('shopify:'.length) : key;
      final exists = _deps.store.products.any((product) => product.id == rawId);
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

  @override
  void initState() {
    super.initState();
    _deps = AppDependencies(
      notificationConfig: widget.notificationConfig,
      gateway: widget.gateway,
      realtimeCatalogSource: widget.realtimeCatalogSource,
      onOpenNotificationRoute: _openNotificationRoute,
    );
    registerFontLicenses();
  }

  @override
  void dispose() {
    _deps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = _deps.theme;
    return ListenableBuilder(
      listenable: theme,
      builder: (context, _) => ProductTelemetryScope(
        telemetry: widget.telemetry,
        child: ThemeScope(
          notifier: theme,
          child: MaterialApp(
            navigatorKey: _navigatorKey,
            title: 'Monetta',
            debugShowCheckedModeBanner: false,
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: theme.mode,
            builder: (context, navigator) {
              final overlay =
                  Theme.of(context).appBarTheme.systemOverlayStyle ??
                      SystemUiOverlayStyle.light;
              final region = AnnotatedRegion<SystemUiOverlayStyle>(
                value: overlay,
                child: FutureBuilder<void>(
                  future: _loading,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _ErrorScreen(error: '${snapshot.error}');
                    }
                    final ready =
                        snapshot.connectionState == ConnectionState.done;
                    return StartupReveal(
                      ready: ready,
                      child: ready
                          ? AppRouteScopes(
                              accountController: _deps.account,
                              cartController: _deps.shopifyCart?.controller,
                              checkoutCoordinator: _deps.shopifyCart?.checkout,
                              catalogStore: _deps.store,
                              notificationController: _deps.notifications,
                              editorialContentController:
                                  _deps.editorialContent,
                              homeContentController: _deps.homeContent,
                              featuredCatalogController: _deps.featuredCatalog,
                              adminController: _deps.admin,
                              adminNotificationController:
                                  _deps.adminNotifications,
                              onboardingController: _deps.onboarding,
                              shopDomain: _deps.shopDomain,
                              child: navigator!,
                            )
                          : const SizedBox.expand(),
                    );
                  },
                ),
              );
              // RF-17 (E-T1 / D-12): one bounded scaler at the root, so no
              // call site has to clamp the system text scale on its own.
              final media = MediaQuery.of(context);
              return MediaQuery(
                data: media.copyWith(
                  textScaler: BoundedTextScaler(media.textScaler),
                ),
                child: region,
              );
            },
            // PACKAGE A — startup integration point.
            // `WelcomeGate` decides, from the persisted onboarding state
            // alone, whether this launch is a first visit. It renders the home
            // immediately underneath either way, so nothing here waits on it.
            // See features/welcome/welcome_gate.dart. Every app scope is
            // mounted above the Navigator, so the home needs none of its own.
            home: const WelcomeGate(child: HomeScreen()),
          ),
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
