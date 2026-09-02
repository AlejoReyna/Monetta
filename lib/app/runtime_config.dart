/// Build-environment guardrails for catalog authority.
library;

import 'package:flutter/foundation.dart';

import '../data/firestore/firestore_catalog_config.dart';

enum AppEnvironment { local, staging, production }

class RuntimeConfig {
  const RuntimeConfig({
    required this.environment,
    required this.allowOfflineCatalog,
  });

  final AppEnvironment? environment;
  final bool allowOfflineCatalog;

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
    );
  }

  bool get requiresFirestore => environment == AppEnvironment.staging;

  String? catalogConfigurationError({
    required FirestoreCatalogConfig firestore,
    required bool hasFirebaseOptions,
    required bool hasShopify,
  }) {
    if (environment == null) {
      return 'APP_ENV no está definido. Inicia la app con el archivo de '
          'configuración del entorno.';
    }
    if (allowOfflineCatalog && environment == AppEnvironment.local) return null;
    if (requiresFirestore && !firestore.enabled) {
      return 'Staging requiere FIRESTORE_CATALOG_ENABLED=true.';
    }
    if (requiresFirestore && !hasFirebaseOptions) {
      return 'Staging requiere la configuración pública completa de Firebase.';
    }
    if (firestore.enabled && !hasFirebaseOptions) {
      return 'Firestore está habilitado pero faltan opciones públicas de '
          'Firebase.';
    }
    if (!(firestore.enabled && hasFirebaseOptions) && !hasShopify) {
      return 'No hay una fuente remota de catálogo configurada. Configura '
          'Firestore o Shopify, o habilita ALLOW_OFFLINE_CATALOG sólo para '
          'trabajo local intencional.';
    }
    return null;
  }
}
