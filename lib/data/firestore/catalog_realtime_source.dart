library;

/// One Firestore catalog document without leaking plugin types into the
/// repository or its tests.
class CatalogRealtimeDocument {
  const CatalogRealtimeDocument({required this.documentId, required this.data});

  final String documentId;
  final Map<String, Object?> data;
}

abstract interface class CatalogRealtimeSource {
  Stream<List<CatalogRealtimeDocument>> watchProducts();
}
