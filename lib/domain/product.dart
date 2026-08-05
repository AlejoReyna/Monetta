/// Core catalog entities.
///
/// Pure Dart — no Flutter, no codegen. These are hand-written on purpose so the
/// domain and the pure-Dart core (`data/normalize`, `reco`) compile and test
/// without running `build_runner` first.
library;

/// A product as we care about it, mapped from either the Storefront GraphQL API
/// or the public Ajax `/products.json` shape.
///
/// Every field here is *raw Shopify data*. Do not read [vendor] or [productType]
/// directly in feature code — they are unreliable on this store. Go through
/// `data/normalize` and read [CanonicalFacets] instead. See
/// `lib/data/normalize/README.md` for the measurements behind that warning.
class Product {
  const Product({
    required this.id,
    required this.handle,
    required this.title,
    required this.vendor,
    required this.productType,
    required this.tags,
    required this.variants,
    required this.images,
    required this.createdAt,
    required this.updatedAt,
    this.descriptionHtml = '',
    this.collectionHandles = const [],
    this.brandOverride,
    this.categoryOverride,
  });

  final String id;
  final String handle;
  final String title;

  /// Raw Shopify `vendor`. On this store it is the *store name* ("Monetta ",
  /// with a trailing space) for 36 products, not the brand. Never trust it alone.
  final String vendor;

  /// Raw Shopify `product_type`. Free text; 20 distinct values for ~6 real
  /// categories, and empty on 36 products.
  final String productType;

  final List<String> tags;
  final List<ProductVariant> variants;
  final List<String> images;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String descriptionHtml;

  /// Handles of the collections this product belongs to. Used as a weak
  /// normalization signal when tags and product_type are both empty.
  final List<String> collectionHandles;

  /// Value of the `app.brand_override` metafield, if the owner set one.
  /// Wins over all inference. See `lib/data/normalize/README.md`.
  final String? brandOverride;

  /// Value of the `app.category_override` metafield, if the owner set one.
  final String? categoryOverride;

  /// Lowest current variant price, in MXN.
  double get price => variants.isEmpty
      ? 0
      : variants.map((v) => v.price).reduce((a, b) => a < b ? a : b);

  /// The `compare_at` price of the cheapest variant, if it is on sale.
  double? get compareAtPrice {
    for (final v in variants) {
      if (v.price == price && v.compareAtPrice != null) return v.compareAtPrice;
    }
    return null;
  }

  bool get isOnSale {
    final compare = compareAtPrice;
    return compare != null && compare > price;
  }

  bool get isInStock => variants.any((v) => v.available);

  /// Fraction off, 0..1. Zero when not on sale.
  double get discountFraction {
    final compare = compareAtPrice;
    if (compare == null || compare <= 0 || compare <= price) return 0;
    return (compare - price) / compare;
  }

  String? get primaryImage => images.isEmpty ? null : images.first;
}

class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.title,
    required this.price,
    required this.available,
    this.compareAtPrice,
    this.sku,
  });

  final String id;
  final String title;
  final double price;
  final bool available;
  final double? compareAtPrice;

  /// Null for every variant on this store today — do not build logic on it.
  final String? sku;

  /// Shopify's placeholder title for single-variant products. Such products
  /// should not render a variant picker.
  bool get isDefault => title == 'Default Title';
}
