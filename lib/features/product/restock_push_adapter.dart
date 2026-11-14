/// G12 remains unavailable until an exact-variant channel is implemented.
library;

import '../../app/notification_controller.dart';
import 'restock_request.dart';

/// The existing notification transport accepts product-level subscriptions.
/// Passing a variant ID to that endpoint does not make it variant-aware.
/// Keep the legacy callback signature for callers, but do not request system
/// permission, record consent, subscribe, or report success through it.
/// The production entry stays hidden while variantRestockAvailable is false.
Future<RestockSubmitResult> submitRestockViaPushNotifications(
  NotificationController? controller,
  RestockRequestPayload payload,
) async {
  return RestockSubmitResult.unavailable;
}
