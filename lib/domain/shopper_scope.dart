/// The identity a shopper's local state is scoped to: one store plus one
/// account (or the guest).
library;

/// Store and account travel together so a scope switch cannot pair the
/// account of one store with the cache of another (invariants 1 and 9).
///
/// Immutable value object. It does not normalize anything: [shopDomain] is
/// whatever the composition already derived and [accountId] is the stored
/// account id, or null for the guest.
class ShopperScope {
  const ShopperScope({required this.shopDomain, this.accountId});

  final String shopDomain;

  /// Null while browsing as a guest.
  final String? accountId;

  bool get isGuest => accountId == null;

  /// Bag and wishlist key for this scope; the guest uses `''` (invariant 4).
  String get bagAccountKey => accountId ?? '';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShopperScope &&
          other.shopDomain == shopDomain &&
          other.accountId == accountId;

  @override
  int get hashCode => Object.hash(shopDomain, accountId);

  @override
  String toString() =>
      'ShopperScope(shopDomain: $shopDomain, accountId: $accountId)';
}
