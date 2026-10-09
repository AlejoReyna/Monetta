/// State and selection of the product page, away from its widgets.
///
/// The view model listens to the catalog store and derives one immutable
/// [ProductViewState] from it, the page being viewed and the chosen variant.
/// It notifies only when that state changed by value, so a store notification
/// that does not concern the page (an event recorded about some other piece,
/// say) no longer rebuilds the screen.
library;

import 'package:flutter/foundation.dart';

import '../../app/catalog_store.dart';
import '../../data/normalize/facets.dart';
import '../../domain/product.dart';

/// What the product page shows.
@immutable
class ProductViewState {
  const ProductViewState({
    required this.product,
    required this.facets,
    required this.wishlisted,
    required this.variantIndex,
    required this.recent,
    required this.related,
  });

  /// The page's product in the store's current copy, or null when it left the
  /// catalog (live sync) or was never in it (stale link).
  final Product? product;

  /// The facets of [product], or null when there is no product.
  final CanonicalFacets? facets;

  /// Whether [product] is in the wishlist.
  final bool wishlisted;

  /// The chosen option, as passed to `selectedVariant`. Out-of-range values
  /// fall back to the first option at read time, exactly as before.
  final int variantIndex;

  /// Recently viewed pieces besides [product], for the lower rail.
  final List<Product> recent;

  /// Pieces of the same brand besides [product], for the upper rail.
  final List<Product> related;

  @override
  bool operator ==(Object other) =>
      other is ProductViewState &&
      identical(other.product, product) &&
      identical(other.facets, facets) &&
      other.wishlisted == wishlisted &&
      other.variantIndex == variantIndex &&
      listEquals(other.recent, recent) &&
      listEquals(other.related, related);

  @override
  int get hashCode => Object.hash(
        product,
        facets,
        wishlisted,
        variantIndex,
        Object.hashAll(recent),
        Object.hashAll(related),
      );
}

class ProductViewModel extends ChangeNotifier {
  ProductViewModel({
    required CatalogStore store,
    required String productId,
    int initialVariantIndex = 0,
  })  : _store = store,
        _productId = productId,
        _variantIndex = initialVariantIndex {
    _store.addListener(_refresh);
    _state = _derive();
  }

  final CatalogStore _store;
  String _productId;
  int _variantIndex;
  late ProductViewState _state;
  bool _disposed = false;

  ProductViewState get state => _state;

  /// Picks the option at [index]. Nothing notifies when it was already
  /// the choice.
  void selectVariant(int index) {
    if (index == _variantIndex) return;
    _variantIndex = index;
    _refresh();
  }

  /// The page was rebuilt for another product. The chosen variant stays,
  /// exactly as the screen's former `late` field did: a rebuild with another
  /// `initialVariantIndex` never reselects.
  void updateProductId(String productId) {
    _productId = productId;
    _refresh();
  }

  void _refresh() {
    if (_disposed) return;
    final next = _derive();
    if (next == _state) return;
    _state = next;
    notifyListeners();
  }

  ProductViewState _derive() {
    Product? found;
    for (final candidate in _store.products) {
      if (candidate.id == _productId) {
        found = candidate;
        break;
      }
    }
    final facets = found == null ? null : _store.facetsFor(found.id);
    return ProductViewState(
      product: found,
      facets: facets,
      wishlisted: found != null && _store.wishlist.contains(found.id),
      variantIndex: _variantIndex,
      recent: found == null
          ? const <Product>[]
          : _store.recentlyViewed(excluding: found.id),
      related: found == null || facets?.brand?.value == null
          ? const <Product>[]
          : _store.moreFromBrand(facets!.brand!.value, excluding: found.id),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _store.removeListener(_refresh);
    super.dispose();
  }
}
