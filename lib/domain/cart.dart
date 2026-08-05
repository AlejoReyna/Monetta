/// Cart entities. Payment never touches this codebase — we build a Shopify cart
/// and hand its [Cart.checkoutUrl] to Shopify's own checkout.
library;

class Cart {
  const Cart({
    required this.id,
    required this.checkoutUrl,
    required this.lines,
    required this.subtotalAmount,
    required this.totalQuantity,
    this.currencyCode = 'MXN',
  });

  final String id;

  /// Opened by `CheckoutLauncher`. Shopify owns everything past this point —
  /// Shop Pay, cards, MSI, and all PCI scope.
  final String checkoutUrl;

  final List<CartLine> lines;
  final double subtotalAmount;
  final int totalQuantity;
  final String currencyCode;

  bool get isEmpty => lines.isEmpty;
}

class CartLine {
  const CartLine({
    required this.id,
    required this.variantId,
    required this.productId,
    required this.title,
    required this.variantTitle,
    required this.quantity,
    required this.unitPrice,
    this.imageUrl,
  });

  final String id;
  final String variantId;
  final String productId;
  final String title;
  final String variantTitle;
  final int quantity;
  final double unitPrice;
  final String? imageUrl;

  double get lineTotal => unitPrice * quantity;
}
