library;

class FirestoreCatalogConfig {
  const FirestoreCatalogConfig({required this.enabled});

  final bool enabled;

  factory FirestoreCatalogConfig.fromEnvironment() =>
      const FirestoreCatalogConfig(
        enabled: bool.fromEnvironment('FIRESTORE_CATALOG_ENABLED'),
      );
}
