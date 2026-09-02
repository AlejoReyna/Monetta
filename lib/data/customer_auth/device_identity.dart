/// Ensures this install has a stable anonymous device id, generating and
/// persisting one on first use.
///
/// This is the same id `CartAttribution.deviceId`
/// (`lib/data/shopify/cart_attribution.dart`) documents stamping onto every
/// cart — that wiring is still Phase 2 (real Shopify sync), but
/// `data/customer_auth`'s per-device account link needs the identical id
/// today, so it's generated here rather than invented twice.
library;

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../local/account_store.dart';
import 'secure_token_store.dart';

const String deviceIdSecureStoreKey = 'device_id';

Future<String> ensureDeviceId({
  required SecureTokenStore secureStore,
  required DeviceStore deviceStore,
  required String platform,
  required String appVersion,
  Uuid? uuid,
}) async {
  String? existing;
  try {
    existing = await secureStore.read(deviceIdSecureStoreKey);
  } on Object catch (error) {
    // The catalog is still usable when Keychain is unavailable (for example
    // an unsigned iOS Simulator build). Keep this install session alive and
    // let the next signed run persist the id normally.
    debugPrint('Secure device id read disabled: $error');
  }

  final deviceId = existing ?? (uuid ?? const Uuid()).v4();
  if (existing == null) {
    try {
      await secureStore.write(deviceIdSecureStoreKey, deviceId);
    } on Object catch (error) {
      // A volatile id is enough for local attribution and the database still
      // records the device. Secure storage is an enhancement, not a reason
      // to hide the storefront.
      debugPrint('Secure device id persistence disabled: $error');
    }
  }
  await deviceStore.upsert(
    deviceId: deviceId,
    platform: platform,
    appVersion: appVersion,
  );
  return deviceId;
}
