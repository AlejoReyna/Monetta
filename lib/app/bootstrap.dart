/// App startup: configuration gate, optional Firebase services and `runApp`.
///
/// Catalog cold-start still uses the bundled snapshot when Drift is empty.
/// When public Storefront credentials are supplied via `--dart-define` /
/// `--dart-define-from-file`, a background Shopify delta sync refreshes the
/// cache after load. Without credentials the app behaves as before: asset +
/// offline cache only.
library;

import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import '../data/accounts_orders/accounts_orders_config.dart';
import '../data/firebase/firebase_app_bootstrap.dart';
import '../data/firestore/catalog_realtime_source.dart';
import '../data/firestore/firestore_catalog_config.dart';
import '../data/notifications/firebase_notification_gateway.dart';
import '../data/notifications/notification_config.dart';
import '../data/shopify/storefront_config.dart';
import 'composition/platform_services.dart';
import 'monetta_app.dart';
import 'product_telemetry.dart';
import 'runtime_config.dart';

Future<void> bootstrap() async {
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
      realtimeCatalogSource = createFirestoreCatalogSource();
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
    gateway = await initializeNotificationGateway(notifications);
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
