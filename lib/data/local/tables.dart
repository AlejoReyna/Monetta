/// Drift table definitions for `data/local`.
///
/// Column shapes mirror `domain/product.dart`, `domain/cart.dart` and
/// `reco/events.dart` deliberately closely — this layer caches and persists
/// those types, it does not reinterpret them. JSON-encoded list columns
/// (`tags`, `images`, `collectionHandles`) trade a normalized join table for
/// less machinery, matching this codebase's stated preference (see
/// `lib/data/shopify/README.md` § 3) for hand-written simplicity over
/// generated ceremony where the surface is this small.
library;

import 'package:drift/drift.dart';

/// A cached `Product` (`domain/product.dart`). One row per Shopify product id.
class CachedProducts extends Table {
  TextColumn get id => text()();
  TextColumn get handle => text()();
  TextColumn get title => text()();
  TextColumn get vendor => text()();
  TextColumn get productType => text()();

  /// JSON-encoded `List<String>`.
  TextColumn get tags => text().withDefault(const Constant('[]'))();

  /// JSON-encoded `List<String>`.
  TextColumn get images => text().withDefault(const Constant('[]'))();

  TextColumn get descriptionHtml => text().withDefault(const Constant(''))();

  /// JSON-encoded `List<String>`.
  TextColumn get collectionHandles =>
      text().withDefault(const Constant('[]'))();

  TextColumn get brandOverride => text().nullable()();
  TextColumn get categoryOverride => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  /// Drives delta sync — see `SyncCursors` and
  /// `lib/data/shopify/catalog_sync.dart`.
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A cached `ProductVariant`, one row per Shopify variant id.
class CachedVariants extends Table {
  TextColumn get id => text()();
  TextColumn get productId =>
      text().references(CachedProducts, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  RealColumn get price => real()();
  RealColumn get compareAtPrice => real().nullable()();
  BoolColumn get available => boolean()();
  TextColumn get sku => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A cached `Collection` (`domain/collection.dart`).
class CachedCollections extends Table {
  TextColumn get id => text()();
  TextColumn get handle => text()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get imageUrl => text().nullable()();
  IntColumn get productCount => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Singleton row (id is always 0) holding the delta-sync high-water mark —
/// the persisted form of `lib/data/shopify/catalog_sync.dart`'s `SyncCursor`.
///
/// [shopDomain] namespaces the cursor by Storefront host so a flavor or shop
/// switch cannot resume against foreign product/variant IDs.
class SyncCursors extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();
  DateTimeColumn get lastFullSyncAt => dateTime().nullable()();
  TextColumn get shopDomain => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Singleton provenance and health record for the catalog cached on device.
///
/// Counts are observations, never release constants. The fingerprint makes it
/// possible to compare snapshots without persisting URLs or product payloads
/// in logs, while [source] prevents the bundled fallback from mutating a cache
/// that has already been replaced by an authoritative remote snapshot.
class CatalogStates extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();
  TextColumn get source => text()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  IntColumn get productCount => integer()();
  TextColumn get fingerprint => text()();
  TextColumn get status => text()();
  TextColumn get detail => text().nullable()();
  TextColumn get shopDomain => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Device-scoped, non-sensitive application preferences. The singleton row
/// survives sign-in and sign-out so appearance never depends on an account.
class AppPreferences extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();
  TextColumn get themeMode => text().withDefault(const Constant('system'))();
  TextColumn get onboardingState =>
      text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// One product on a shopper's wishlist.
///
/// Guest rows use empty-string [accountId]; signed-in rows use the local
/// account id. The composite primary key keeps account A and account B
/// isolated on the same device. Login merges guest (`''`) rows into the
/// signed-in account (see `WishlistStore.mergeDeviceItemsIntoAccount`).
class WishlistItems extends Table {
  TextColumn get productId => text()();
  TextColumn get accountId => text().withDefault(const Constant(''))();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {productId, accountId};
}

/// A line in the shopper's pre-checkout bag. Persisted so it survives an app
/// restart — replaces `CatalogStore`'s in-memory bag map.
///
/// Primary key is `(variantId, accountId)` so two variants of the same product
/// can coexist, and account scopes stay isolated. Guest scope uses `''`.
class BagLines extends Table {
  TextColumn get productId => text()();
  TextColumn get variantId => text()();
  TextColumn get accountId => text().withDefault(const Constant(''))();
  IntColumn get quantity => integer()();

  @override
  Set<Column> get primaryKey => {variantId, accountId};
}

/// One recorded `InteractionEvent` (`reco/events.dart`). Device-scoped only —
/// never gains an `accountId` column. `reco/README.md` states this data never
/// leaves the device; syncing it across devices on login would be a privacy
/// posture change and needs its own explicit opt-in
/// (`docs/ACCOUNTS_AND_SYNC_PLAN.md` § 4, Phase 4, deliberately deferred).
class InteractionEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get productId => text().nullable()();
  IntColumn get dwellMs => integer().nullable()();
  TextColumn get facetHint => text().nullable()();
}

/// This install, independent of whether anyone has signed in. Formalizes the
/// anonymous `_device_id` already stamped on every cart
/// (`lib/data/shopify/cart_attribution.dart`) instead of generating it ad hoc.
class Devices extends Table {
  TextColumn get deviceId => text()();
  TextColumn get accountId => text().nullable()();
  TextColumn get platform => text()();
  TextColumn get appVersion => text()();
  TextColumn get pushToken => text().nullable()();
  DateTimeColumn get installedAt => dateTime()();
  DateTimeColumn get lastSeenAt => dateTime()();

  @override
  Set<Column> get primaryKey => {deviceId};
}

/// A local reflection of the signed-in identity. `shopifyCustomerId` is
/// nullable until the first successful Customer Account API login
/// completes — see Phase 1 of `docs/ACCOUNTS_AND_SYNC_PLAN.md`.
class Accounts extends Table {
  TextColumn get localAccountId => text()();
  TextColumn get shopifyCustomerId => text().nullable().unique()();
  TextColumn get email => text().nullable()();
  TextColumn get displayName => text().nullable()();
  TextColumn get authProvider => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastSeenAt => dateTime()();

  @override
  Set<Column> get primaryKey => {localAccountId};
}

/// A reference to an auth session. The token itself lives in
/// `flutter_secure_storage`, keyed by `secureStorageKeyRef` — it is never
/// written to this (unencrypted-by-default) SQLite file. See the ERD's
/// `Session` entity.
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get accountId => text()
      .references(Accounts, #localAccountId, onDelete: KeyAction.cascade)();
  TextColumn get secureStorageKeyRef => text()();

  /// The *access* token's expiry, not the id token's — they carry separate
  /// lifetimes in OIDC, and it's the access token that gates whether an
  /// API call needs a silent refresh first.
  DateTimeColumn get accessTokenExpiresAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
}

/// A local read cache of order history, unifying real Shopify checkout
/// orders and hand-entered WhatsApp *apartado* orders — see Phase 3 of
/// `docs/ACCOUNTS_AND_SYNC_PLAN.md`.
class OrderSummaries extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text()
      .references(Accounts, #localAccountId, onDelete: KeyAction.cascade)();

  /// Null for an apartado order — those have no Shopify order id until the
  /// owner manually enters one, and some never get one recorded here at all.
  TextColumn get displayNumber => text().nullable()();
  TextColumn get fulfillmentStatus => text().nullable()();

  TextColumn get shopifyOrderId => text().nullable()();

  /// `shopifyCheckout` | `whatsappApartado`.
  TextColumn get source => text()();

  /// The `MN-XXXX` code from `AttributionCodeGenerator`, set only for
  /// apartado orders.
  TextColumn get attributionCode => text().nullable()();

  TextColumn get status => text()();

  /// Shopify Customer Account `Order.transactions.type` values, joined
  /// with commas (`bank_deposit`, `manual`, `card`, …). Null when the
  /// order history query did not return a transaction type — never guessed.
  TextColumn get paymentMethod => text().nullable()();

  /// Shopify `cancelledAt`. Null when the order was not canceled.
  DateTimeColumn get cancelledAt => dateTime().nullable()();

  /// Shopify `cancelReason`. Null when absent; never inferred.
  TextColumn get cancelReason => text().nullable()();

  /// Shopify `totalRefunded`. Null when the query did not return an amount.
  RealColumn get refundedAmount => real().nullable()();
  RealColumn get totalAmount => real()();
  TextColumn get currencyCode => text()();
  DateTimeColumn get placedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id, accountId};
}

/// Receipt and bag subtraction commit together, making repeated callbacks safe.
class CheckoutReceipts extends Table {
  TextColumn get operationId => text()();
  TextColumn get shopDomain => text()();
  TextColumn get accountId => text()();
  @override
  Set<Column> get primaryKey => {operationId};
}
