/// Build-environment guardrails for catalog authority.
library;

import 'package:flutter/foundation.dart';

import '../data/firestore/firestore_catalog_config.dart';
import 'external_catalog_config.dart';

enum AppEnvironment { local, staging, production }

class RuntimeConfig {
  const RuntimeConfig({
    required this.environment,
    required this.allowOfflineCatalog,
    this.externalCatalogRequested = false,
  });

  final AppEnvironment? environment;
  final bool allowOfflineCatalog;

  /// True when the retired `ENABLE_EXTERNAL_CATALOG` dart-define is present.
  final bool externalCatalogRequested;

  factory RuntimeConfig.fromEnvironment({bool debugMode = kDebugMode}) {
    const raw = String.fromEnvironment('APP_ENV');
    final normalized = raw.trim().toLowerCase();
    final hasExplicitEnvironment = normalized.isNotEmpty;
    return RuntimeConfig(
      environment: switch (normalized) {
        'local' => AppEnvironment.local,
        'staging' => AppEnvironment.staging,
        'production' => AppEnvironment.production,
        _ when debugMode && !hasExplicitEnvironment => AppEnvironment.local,
        _ => null,
      },
      allowOfflineCatalog:
          const bool.fromEnvironment('ALLOW_OFFLINE_CATALOG') ||
              (debugMode && !hasExplicitEnvironment),
      externalCatalogRequested:
          ExternalCatalogConfig.flagRequestedInEnvironment,
    );
  }

  /// Firestore mirror is optional. Staging may run Storefront-direct (F25).
  bool get requiresFirestore => false;

  String? catalogConfigurationError({
    required FirestoreCatalogConfig firestore,
    required bool hasFirebaseOptions,
    required bool hasShopify,
  }) {
    if (environment == null) {
      return 'APP_ENV no está definido. Inicia la app con el archivo de '
          'configuración del entorno.';
    }
    if (externalCatalogRequested) {
      return 'El catálogo externo está retirado (WP-02). Quita '
          'ENABLE_EXTERNAL_CATALOG del build; Monetta solo vende productos '
          'propios de Shopify.';
    }
    if (allowOfflineCatalog && environment == AppEnvironment.local) return null;
    if (firestore.enabled && !hasFirebaseOptions) {
      return 'Firestore está habilitado pero faltan opciones públicas de '
          'Firebase.';
    }
    if (!(firestore.enabled && hasFirebaseOptions) && !hasShopify) {
      return 'No hay una fuente remota de catálogo configurada. Configura '
          'Shopify Storefront (recomendado) o Firestore, o habilita '
          'ALLOW_OFFLINE_CATALOG sólo para trabajo local intencional.';
    }
    return null;
  }
}
