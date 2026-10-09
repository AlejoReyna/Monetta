/// State and actions of the collection screen, away from its widgets.
///
/// The view model listens to the catalog store and derives one immutable
/// [CollectionViewState] from it and from the destination being viewed. It
/// notifies only when that state changed by value, so a store notification
/// that does not concern the collection (an event recorded about some other
/// piece, say) no longer rebuilds the screen.
library;

import 'package:flutter/foundation.dart';

import '../../app/catalog_store.dart';
import '../../app/shopper_copy.dart';
import '../../domain/product.dart';
import '../../reco/explainer.dart';
import 'query/collection_filter.dart';

/// How the grid is ordered.
enum CollectionSort { newest, priceAsc, priceDesc }

/// The choices a shopper can make without changing the collection route.
///
/// A [CollectionFilter] describes the destination that was opened (for
/// example, Bolsas or a specific brand). This value describes only the
/// temporary controls in the filter sheet, so cancelling the sheet never
/// changes the product grid, and "Limpiar" returns to the destination rather
/// than to the whole catalog.
@immutable
class CollectionFilters {
  const CollectionFilters({
    this.sort = CollectionSort.newest,
    this.inStockOnly = false,
    this.brand,
    this.silhouette,
  });

  final CollectionSort sort;
  final bool inStockOnly;
  final String? brand;
  final String? silhouette;

  CollectionFilters copyWith({
    CollectionSort? sort,
    bool? inStockOnly,
    Object? brand = _unchanged,
    Object? silhouette = _unchanged,
  }) {
    return CollectionFilters(
      sort: sort ?? this.sort,
      inStockOnly: inStockOnly ?? this.inStockOnly,
      brand: identical(brand, _unchanged) ? this.brand : brand as String?,
      silhouette: identical(silhouette, _unchanged)
          ? this.silhouette
          : silhouette as String?,
    );
  }

  /// Mirrors the catalog's badge convention: ordering is not a filter, while
  /// availability, brand, and bag type are.
  int activeCountComparedTo(CollectionFilters baseline) =>
      (inStockOnly ? 1 : 0) +
      (brand != baseline.brand ? 1 : 0) +
      (silhouette != baseline.silhouette ? 1 : 0);

  @override
  bool operator ==(Object other) =>
      other is CollectionFilters &&
      other.sort == sort &&
      other.inStockOnly == inStockOnly &&
      other.brand == brand &&
      other.silhouette == silhouette;

  @override
  int get hashCode => Object.hash(sort, inStockOnly, brand, silhouette);
}

const Object _unchanged = Object();

/// What the collection screen shows.
@immutable
class CollectionViewState {
  const CollectionViewState({
    required this.filters,
    required this.baseline,
    required this.scoped,
    required this.items,
    required this.brands,
    required this.silhouettes,
    required this.bagCount,
  });

  /// The sheet's applied choices.
  final CollectionFilters filters;

  /// The destination's own choices; "Limpiar" returns here.
  final CollectionFilters baseline;

  /// Everything the destination contains, before the sheet's choices.
  final List<Product> scoped;

  /// What the grid draws: [scoped] after [filters], ordered.
  final List<Product> items;

  /// Brands and silhouettes present in [scoped], sorted by label, for the
  /// sheet.
  final List<String> brands;
  final List<String> silhouettes;

  /// Units in the bag, for the bottom bar's badge.
  final int bagCount;

  /// Number of filters that differ from the destination.
  int get activeCount => filters.activeCountComparedTo(baseline);

  @override
  bool operator ==(Object other) =>
      other is CollectionViewState &&
      other.filters == filters &&
      other.baseline == baseline &&
      other.bagCount == bagCount &&
      listEquals(other.scoped, scoped) &&
      listEquals(other.items, items) &&
      listEquals(other.brands, brands) &&
      listEquals(other.silhouettes, silhouettes);

  @override
  int get hashCode => Object.hash(
        filters,
        baseline,
        bagCount,
        Object.hashAll(scoped),
        Object.hashAll(items),
        Object.hashAll(brands),
        Object.hashAll(silhouettes),
      );
}

class CollectionViewModel extends ChangeNotifier {
  CollectionViewModel({
    required CatalogStore store,
    required CollectionFilter filter,
  })  : _store = store,
        _destination = filter,
        _filters = _baselineOf(filter) {
    _store.addListener(_refresh);
    _state = _derive();
  }

  final CatalogStore _store;
  CollectionFilter _destination;
  CollectionFilters _filters;
  late CollectionViewState _state;
  bool _disposed = false;

  CollectionViewState get state => _state;

  /// Applies the sheet's choices to the grid.
  void applyFilters(CollectionFilters filters) {
    _filters = filters;
    _refresh();
  }

  /// Returns to the destination: the sheet's choices are dropped, the brand
  /// and silhouette of the destination itself stay.
  void clearFilters() => applyFilters(_state.baseline);

  /// The screen was rebuilt for another destination. The applied choices stay
  /// as they are; the scope and the baseline follow the new destination.
  void updateDestination(CollectionFilter filter) {
    _destination = filter;
    _refresh();
  }

  /// How many pieces [filters] would show, for the sheet's apply button.
  int countFor(CollectionFilters filters) =>
      _itemsFor(_state.scoped, filters).length;

  static CollectionFilters _baselineOf(CollectionFilter filter) =>
      CollectionFilters(brand: filter.brand, silhouette: filter.silhouette);

  void _refresh() {
    if (_disposed) return;
    final next = _derive();
    if (next == _state) return;
    _state = next;
    notifyListeners();
  }

  CollectionViewState _derive() {
    final scoped = filterCollectionProducts(
      _store.products,
      _store.facetsFor,
      _destination,
    );
    return CollectionViewState(
      filters: _filters,
      baseline: _baselineOf(_destination),
      scoped: scoped,
      items: _itemsFor(scoped, _filters),
      brands: _brandsFor(scoped),
      silhouettes: _silhouettesFor(scoped),
      bagCount: _store.bagQuantity,
    );
  }

  List<Product> _itemsFor(
    Iterable<Product> scoped,
    CollectionFilters selection,
  ) {
    final items = scoped.where((product) {
      final facets = _store.facetsFor(product.id);
      if (selection.brand != null && facets?.brand?.value != selection.brand) {
        return false;
      }
      if (selection.silhouette != null &&
          facets?.silhouette?.value != selection.silhouette) {
        return false;
      }
      return !selection.inStockOnly || product.isInStock;
    }).toList();

    items.sort((a, b) {
      switch (selection.sort) {
        case CollectionSort.priceAsc:
          return a.price.compareTo(b.price);
        case CollectionSort.priceDesc:
          return b.price.compareTo(a.price);
        case CollectionSort.newest:
          return b.createdAt.compareTo(a.createdAt);
      }
    });
    return items;
  }

  List<String> _brandsFor(Iterable<Product> products) {
    final brands = <String>{
      for (final product in products)
        if (_store.facetsFor(product.id)?.brand?.value case final value?) value,
    }.toList();
    brands.sort(
      (a, b) => brandLabel(a).toLowerCase().compareTo(
            brandLabel(b).toLowerCase(),
          ),
    );
    return brands;
  }

  List<String> _silhouettesFor(Iterable<Product> products) {
    final silhouettes = <String>{
      for (final product in products)
        if (_store.facetsFor(product.id)?.silhouette?.value case final value?)
          value,
    }.toList();
    silhouettes.sort(
      (a, b) => silhouetteLabel(a).toLowerCase().compareTo(
            silhouetteLabel(b).toLowerCase(),
          ),
    );
    return silhouettes;
  }

  @override
  void dispose() {
    _disposed = true;
    _store.removeListener(_refresh);
    super.dispose();
  }
}
