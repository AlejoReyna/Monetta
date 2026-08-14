/// CRUD for `Accounts`, `Devices` and `Sessions` — the schema Phase 1's
/// Customer Account API login will populate (`docs/ACCOUNTS_AND_SYNC_PLAN.md`).
/// Built now, alongside the rest of `data/local`, so that schema change
/// doesn't land as a second migration once login exists.
///
/// The session's actual token never passes through this class — only
/// `secureStorageKeyRef`, a reference into `flutter_secure_storage`. See
/// `tables.dart`'s `Sessions` doc comment.
library;

import 'package:drift/drift.dart';

import 'database.dart';

class AccountStore {
  AccountStore(this._db);

  final AppDatabase _db;

  Future<Account?> byShopifyCustomerId(String shopifyCustomerId) {
    return (_db.select(_db.accounts)
          ..where((t) => t.shopifyCustomerId.equals(shopifyCustomerId)))
        .getSingleOrNull();
  }

  Future<Account?> byLocalId(String localAccountId) {
    return (_db.select(_db.accounts)
          ..where((t) => t.localAccountId.equals(localAccountId)))
        .getSingleOrNull();
  }

  Future<void> upsert({
    required String localAccountId,
    String? shopifyCustomerId,
    String? email,
    String? displayName,
    String? authProvider,
    required DateTime createdAt,
  }) {
    return _db.into(_db.accounts).insertOnConflictUpdate(
          AccountsCompanion.insert(
            localAccountId: localAccountId,
            shopifyCustomerId: Value(shopifyCustomerId),
            email: Value(email),
            displayName: Value(displayName),
            authProvider: Value(authProvider),
            createdAt: createdAt,
            lastSeenAt: DateTime.now().toUtc(),
          ),
        );
  }

  Future<void> touchLastSeen(String localAccountId) {
    return (_db.update(_db.accounts)
          ..where((t) => t.localAccountId.equals(localAccountId)))
        .write(AccountsCompanion(lastSeenAt: Value(DateTime.now().toUtc())));
  }
}

class DeviceStore {
  DeviceStore(this._db);

  final AppDatabase _db;

  Future<Device?> byId(String deviceId) {
    return (_db.select(_db.devices)..where((t) => t.deviceId.equals(deviceId)))
        .getSingleOrNull();
  }

  Future<void> upsert({
    required String deviceId,
    required String platform,
    required String appVersion,
    String? accountId,
    String? pushToken,
  }) async {
    final existing = await byId(deviceId);
    await _db.into(_db.devices).insertOnConflictUpdate(
          DevicesCompanion.insert(
            deviceId: deviceId,
            accountId: Value(accountId),
            platform: platform,
            appVersion: appVersion,
            pushToken: Value(pushToken),
            installedAt: existing?.installedAt ?? DateTime.now().toUtc(),
            lastSeenAt: DateTime.now().toUtc(),
          ),
        );
  }

  /// Called once login succeeds, so a subsequent push notification or
  /// order-history request can be attributed to the account, not just the
  /// anonymous install.
  Future<void> attachAccount(String deviceId, String accountId) {
    return (_db.update(_db.devices)..where((t) => t.deviceId.equals(deviceId)))
        .write(DevicesCompanion(accountId: Value(accountId)));
  }

  /// Called on logout — the device stays known (install history, push
  /// token) but is no longer attributed to the account that just signed out.
  Future<void> detachAccount(String deviceId) {
    return (_db.update(_db.devices)..where((t) => t.deviceId.equals(deviceId)))
        .write(const DevicesCompanion(accountId: Value(null)));
  }
}

class SessionStore {
  SessionStore(this._db);

  final AppDatabase _db;

  Future<Session?> latestFor(String accountId) {
    return (_db.select(_db.sessions)
          ..where((t) => t.accountId.equals(accountId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// A device only ever has one *current* session per account: this updates
  /// that row in place (on every silent refresh, most commonly) rather than
  /// inserting a new one, so the table doesn't accumulate a row per refresh
  /// for the life of the install.
  Future<void> save({
    required String accountId,
    required String secureStorageKeyRef,
    required DateTime accessTokenExpiresAt,
  }) async {
    final existing = await latestFor(accountId);
    if (existing != null) {
      await (_db.update(_db.sessions)..where((t) => t.id.equals(existing.id))).write(
        SessionsCompanion(
          secureStorageKeyRef: Value(secureStorageKeyRef),
          accessTokenExpiresAt: Value(accessTokenExpiresAt),
        ),
      );
      return;
    }
    await _db.into(_db.sessions).insert(
          SessionsCompanion.insert(
            accountId: accountId,
            secureStorageKeyRef: secureStorageKeyRef,
            accessTokenExpiresAt: accessTokenExpiresAt,
            createdAt: DateTime.now().toUtc(),
          ),
        );
  }

  /// Deleting the account row cascades to its sessions (`tables.dart`), but
  /// logout without deleting the account (the common case) goes through
  /// here instead.
  Future<void> deleteFor(String accountId) {
    return (_db.delete(_db.sessions)..where((t) => t.accountId.equals(accountId)))
        .go();
  }
}
