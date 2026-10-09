/// Platform edges that `bootstrap()` needs before the widget tree exists.
///
/// They construct concrete `data/` implementations, so they live in the
/// composition root (ARCH-04) and `bootstrap()` only calls them.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/firestore/catalog_realtime_source.dart';
import '../../data/firestore/firestore_catalog_source.dart';
import '../../data/notifications/firebase_notification_gateway.dart';
import '../../data/notifications/notification_config.dart';

/// The Firestore-backed realtime catalog source. Firebase must already be
/// initialized.
CatalogRealtimeSource createFirestoreCatalogSource() =>
    FirestoreCatalogSource(FirebaseFirestore.instance);

/// The Firebase notification gateway for [config]. Throws when the native
/// Firebase capability is missing; the caller decides whether that is fatal.
Future<NotificationGateway?> initializeNotificationGateway(
  NotificationConfig config,
) =>
    FirebaseNotificationGateway.initialize(config);
