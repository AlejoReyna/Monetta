/// State and actions of the full-catalog browser, away from its widgets.
///
/// The view model derives one immutable [CatalogBrowseViewState] from the
/// products and facets the browser was given, the shopper's applied filters
/// and the bag quantity. It notifies only when that state changed by value, so
/// a store notification that does not concern the browser (an event recorded
/// about some other piece, say) no longer rebuilds the screen.
library;

import 'package:flutter/foundation.dart';

import '../../app/catalog_store.dart';
import '../../data/normalize/facets.dart';
import '../../domain/product.dart';
import 'query/browse_filters.dart';

/// What the browser shows.
@immutable
class CatalogBrowseViewState {
  const CatalogBrowseViewState({
    required this.filters,
    required this.visible,
    required this.bagCount,
  });

  /// The sheet's applied choices.
  final CatalogBrowseFilters filters;

  /// What the grid draws: the products after [filters], ordered.
  final List<Product> visible;

  /// Units in the bag, for the bottom bar's badge.
  final int bagCount;

  /// Number of filters applied, for the header's badge.
  int get activeCount => filters.activeCount;

  @override
  bool operator ==(Object other) =>
      other is CatalogBrowseViewState &&
      other.filters == filters &&
      other.bagCount == bagCount &&
      listEquals(other.visible, visible);

  @override
  int get hashCode => Object.hash(filters, bagCount, Object.hashAll(visible));
}

class CatalogBrowseViewModel extends ChangeNotifier {
  /// [store] is optional: without one the bag quantity is [bagCount] as it
  /// was given; with one, the store's live quantity wins.
  CatalogBrowseViewModel({
    required List<Product> products,
    required Map<String, CanonicalFacets> facetsById,
    int bagCount = 0,
    CatalogStore? store,
  })  : _products = products,
        _facetsById = facetsById,
        _givenBagCount = bagCount,
        _store = store {
    _store?.addListener(_onStoreChanged);
    _state = _derive();
  }

  final CatalogStore? _store;
  List<Product> _products;
  Map<String, CanonicalFacets> _facetsById;
  int _givenBagCount;
  CatalogBrowseFilters _filters = const CatalogBrowseFilters();
  late CatalogBrowseViewState _state;
  bool _disposed = false;

  CatalogBrowseViewState get state => _state;

  /// Applies the sheet's choices to the grid.
  void applyFilters(CatalogBrowseFilters filters) {
    _filters = filters;
    _refresh();
  }

  /// Drops every applied choice.
  void resetFilters() => applyFilters(const CatalogBrowseFilters());

  /// The screen was rebuilt with other inputs. The applied filters stay as
  /// they are; the products, facets and the given bag count follow the widget.
  void updateInputs({
    required List<Product> products,
    required Map<String, CanonicalFacets> facetsById,
    required int bagCount,
  }) {
    _products = products;
    _facetsById = facetsById;
    _givenBagCount = bagCount;
    _refresh();
  }

  /// How many pieces [filters] would show, for the sheet's apply button. It
  /// never changes the state.
  int countFor(CatalogBrowseFilters filters) =>
      filterAndSortCatalog(_products, _facetsById, filters).length;

  int get _bagCount => _store?.bagQuantity ?? _givenBagCount;

  void _onStoreChanged() {
    if (_disposed) return;
    // Only the bag quantity can move with a store notification: the products
    // and facets belong to the widget, so the filter is not run again.
    final bagCount = _bagCount;
    if (bagCount == _state.bagCount) return;
    _commit(
      CatalogBrowseViewState(
        filters: _state.filters,
        visible: _state.visible,
        bagCount: bagCount,
      ),
    );
  }

  void _refresh() {
    if (_disposed) return;
    _commit(_derive());
  }

  void _commit(CatalogBrowseViewState next) {
    if (next == _state) return;
    _state = next;
    notifyListeners();
  }

  CatalogBrowseViewState _derive() => CatalogBrowseViewState(
        filters: _filters,
        visible: filterAndSortCatalog(_products, _facetsById, _filters),
        bagCount: _bagCount,
      );

  @override
  void dispose() {
    _disposed = true;
    _store?.removeListener(_onStoreChanged);
    super.dispose();
  }
}
