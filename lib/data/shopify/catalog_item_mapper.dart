/// Maps a raw Shopify [Product] into the source-independent [CatalogItem].
///
/// Pure Dart, no Flutter — see the two-rules note in `docs/ARCHITECTURE.md`.
/// [CanonicalFacets] is optional so this stays usable in contexts that
/// haven't normalized yet, but every caller in `features/` should pass it:
/// `product.vendor` is the unreliable raw field (see `domain/product.dart`),
/// and falling back to it silently would reintroduce the exact bug
/// `data/normalize` exists to fix.
library;

import '../../domain/catalog_item.dart';
import '../../domain/product.dart';
import '../normalize/facets.dart';

const String _monettaMerchant = 'Monetta';
const String _monettaStoreBaseUrl = 'https://monetta.mx/products';
const Set<String> _bagsWalletCategories = {
  'bolsa',
  'bolsas',
  'cartera',
  'carteras',
  'monedero',
  'monederos',
  'cosmetiquera',
  'cosmetiqueras',
};

CatalogVertical _verticalFromFacets(CanonicalFacets? facets) {
  final category = facets?.category?.value.trim().toLowerCase();
  if (category == null) return CatalogVertical.general;
  if (_bagsWalletCategories.contains(category)) {
    return CatalogVertical.bagsWallets;
  }
  if (category == 'perfume' ||
      category == 'perfumes' ||
      category == 'fragancia' ||
      category == 'fragancias') {
    return CatalogVertical.perfumes;
  }
  return CatalogVertical.general;
}

CatalogItem catalogItemFromShopifyProduct(
  Product product, {
  CanonicalFacets? facets,
}) {
  return CatalogItem(
    sourceScopedId: 'monetta:${product.id}',
    source: CatalogSourceType.monettaShopify,
    merchant: _monettaMerchant,
    title: product.title,
    brand: facets?.brand?.value ?? product.vendor,
    category: facets?.category?.value,
    imageUrl: product.primaryImage,
    price: Money(amount: product.price, currency: Currency.mxn),
    availability: product.isInStock
        ? CatalogAvailability.inStock
        : CatalogAvailability.outOfStock,
    detailUrl: '$_monettaStoreBaseUrl/${product.handle}',
    marketRestriction: MarketRestriction.mexico,
    lastObservedAt: product.updatedAt,
    purchaseMode: PurchaseMode.monettaCheckout,
    shopifyProductId: product.id,
    vertical: _verticalFromFacets(facets),
  );
}
