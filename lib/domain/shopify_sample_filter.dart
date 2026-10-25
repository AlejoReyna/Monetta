/// Shopify seed data that must stay out of shopper-facing catalog reads.
library;

import 'product.dart';

const _sampleVendors = <String>{
  'monetta staging',
  'snowboard vendor',
  'hydrogen vendor',
  'multi-managed vendor',
};

/// Uses the exact vendor list for Shopify's staging sample products.
/// Product titles and types are intentionally irrelevant.
bool isShopifySampleProduct(Product product) =>
    _sampleVendors.contains(product.vendor.trim().toLowerCase());

/// Shopify's seed collections, matched independently of their display titles.
bool isShopifySampleCollectionHandle(String handle) => const {
      'hydrogen',
      'automated-collection',
    }.contains(handle.trim().toLowerCase());
