/// Connects the G12 restock sheet to the automatic push notification alert service.
library;

import '../../app/notification_controller.dart';
import 'restock_request.dart';

Future<RestockSubmitResult> submitRestockViaPushNotifications(
  NotificationController? controller,
  RestockRequestPayload payload,
) async {
  if (controller == null || !controller.variantRestockAvailable) {
    return RestockSubmitResult.unavailable;
  }
  final created = await controller.createRestockAlert(payload.product.id);
  return created ? RestockSubmitResult.created : RestockSubmitResult.error;
}
