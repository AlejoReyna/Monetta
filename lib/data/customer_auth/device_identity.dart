/// Ensures this install has a stable anonymous device id, generating and
/// persisting one on first use.
///
/// This is the same id `CartAttribution.deviceId`
/// (`lib/data/shopify/cart_attribution.dart`) documents stamping onto every
/// cart — that wiring is still Phase 2 (real Shopify sync), but
/// `data/customer_auth`'s per-device account link needs the identical id
/// today, so it's generated here rather than invented twice.
library;

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
  final existing = await secureStore.read(deviceIdSecureStoreKey);
  final deviceId = existing ?? (uuid ?? const Uuid()).v4();
  if (existing == null) {
    await secureStore.write(deviceIdSecureStoreKey, deviceId);
  }
  await deviceStore.upsert(
      deviceId: deviceId, platform: platform, appVersion: appVersion);
  return deviceId;
}
