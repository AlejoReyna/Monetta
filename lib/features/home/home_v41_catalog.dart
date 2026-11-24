/// v4.1 Home bindings and unique product lists for rails/feeds.
library;

import 'package:flutter/foundation.dart';

import '../../app/catalog_store.dart';
import '../../domain/product.dart';
import '../catalog/collection_screen.dart';

const int kHomeNewCollectionProductLimit = 40;
const int kFavoritesTasteProductLimit = 60;

/// The Home rail contains the five catalog families in editorial order.
const List<HomeCategoryPhotoEntry> kHomeCategoryPhotoEntries = [
  HomeCategoryPhotoEntry('F07', 'Bolsos', CollectionFilter(category: 'bolsa')),
  HomeCategoryPhotoEntry(
      'F08', 'Carteras', CollectionFilter(category: 'cartera')),
  HomeCategoryPhotoEntry(
      'B16', 'Perfumes', CollectionFilter(category: 'perfume')),
  HomeCategoryPhotoEntry(
      'F01', 'Calzado', CollectionFilter(category: 'calzado')),
  HomeCategoryPhotoEntry(
      'F05', 'Accesorios', CollectionFilter(category: 'accesorio')),
];

@immutable
class HomeCategoryPhotoEntry {
  const HomeCategoryPhotoEntry(this.assetId, this.label, this.filter);

  final String assetId;
  final String label;
  final CollectionFilter filter;
}

/// Newest unique in-stock products up to [limit], without padding duplicates.
List<Product> uniqueNewestProducts(CatalogStore store,
    {int limit = kHomeNewCollectionProductLimit}) {
  if (!store.ready) return const [];
  final inStock = store.products.where((p) => p.isInStock).toList();
  final sorted = (inStock.isNotEmpty ? inStock : [...store.products])
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final seen = <String>{};
  final out = <Product>[];
  for (final product in sorted) {
    if (!seen.add(product.id)) continue;
    out.add(product);
    if (out.length >= limit) break;
  }
  return out;
}

/// Ranked feed products, unique, optionally excluding ids (e.g. nueva colección).
List<Product> uniqueFeedProducts(
  CatalogStore store, {
  int limit = kHomeNewCollectionProductLimit,
  Set<String> excludeIds = const {},
}) {
  if (!store.ready) return const [];
  final seen = <String>{...excludeIds};
  final out = <Product>[];
  for (final recommendation in store.feed(limit: limit * 2)) {
    final id = recommendation.product.id;
    if (!seen.add(id)) continue;
    out.add(recommendation.product);
    if (out.length >= limit) break;
  }
  if (out.isNotEmpty) return out;
  // Editorial fallback when the profile cannot rank yet.
  for (final product in uniqueNewestProducts(store, limit: limit)) {
    if (!seen.add(product.id)) continue;
    out.add(product);
  }
  return out;
}

/// Taste recommendations for Favorites: ranked first, then editorial newest.
List<Product> uniqueTasteProducts(CatalogStore store,
    {int limit = kFavoritesTasteProductLimit}) {
  return uniqueFeedProducts(store, limit: limit);
}
