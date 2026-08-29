library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'catalog_realtime_source.dart';

class FirestoreCatalogSource implements CatalogRealtimeSource {
  FirestoreCatalogSource(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<CatalogRealtimeDocument>> watchProducts() => _firestore
      .collection('products')
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => [
          for (final document in snapshot.docs)
            CatalogRealtimeDocument(
              documentId: document.id,
              data: document.data(),
            ),
        ],
      );
}
