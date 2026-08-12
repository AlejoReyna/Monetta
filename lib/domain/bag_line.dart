/// A shopper-facing line in Monetta's local bag.
///
/// This is deliberately separate from Shopify's `CartLine`: the local bag is
/// editable before a Storefront Cart exists, while Shopify remains the source
/// of truth once checkout begins.
library;

import 'product.dart';

class BagLine {
  const BagLine({
    required this.product,
    required this.variant,
    required this.quantity,
  });

  final Product product;
  final ProductVariant variant;
  final int quantity;

  double get unitPrice => variant.price;
  double get lineTotal => unitPrice * quantity;
}
