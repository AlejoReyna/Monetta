/// Use case: rebind every per-shopper piece of local state to a new scope.
library;

import '../domain/shopper_scope.dart';
import '../features/catalog/search_history.dart';
import 'catalog_store.dart';

/// Login, logout and account switch all funnel through here.
///
/// The late-result guards live in the collaborators, not here:
/// `CatalogStore` drops a bag/wishlist hydration whose scope changed while it
/// awaited the database, and `SearchHistory` keeps one state per scope
/// (invariant 9). Order matters and is part of the contract.
class ChangeAccountScope {
  ChangeAccountScope({
    required CatalogStore store,
    SearchHistory? searchHistory,
    Future<void> Function()? invalidateCheckout,
  })  : _store = store,
        _searchHistory = searchHistory ?? SearchHistory.instance,
        _invalidateCheckout = invalidateCheckout;

  final CatalogStore _store;
  final SearchHistory _searchHistory;
  final Future<void> Function()? _invalidateCheckout;

  Future<void> call(ShopperScope next) async {
    await _store.setAccountScope(next.accountId);
    await _searchHistory.setScope(next.accountId);
    // Login/logout/account switch must never reuse a preloaded checkout
    // document that belonged to a previous buyer identity (F06/F18).
    await _invalidateCheckout?.call();
  }
}
