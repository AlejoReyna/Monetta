/// Immutable Shopify Cart snapshot.
///
/// Prices remain decimal strings. Commercial totals must never pass through a
/// binary `double`, and Shopify remains the online source of truth.
library;

final class CartMoney {
  const CartMoney({required this.amount, required this.currencyCode});

  final String amount;
  final String currencyCode;
}

final class CartCost {
  const CartCost({
    required this.subtotal,
    required this.total,
    this.checkoutCharge,
    this.subtotalEstimated = false,
    this.totalEstimated = false,
  });

  final CartMoney subtotal;
  final CartMoney total;
  final CartMoney? checkoutCharge;
  final bool subtotalEstimated;
  final bool totalEstimated;
}

final class CartBuyerSummary {
  const CartBuyerSummary({
    required this.countryCode,
    required this.isAuthenticated,
  });

  final String? countryCode;
  final bool isAuthenticated;
}

final class CartDiscountCode {
  const CartDiscountCode({required this.code, required this.applicable});

  final String code;
  final bool applicable;
}

enum CartDiscountApplicationKind { automatic, code, custom, unknown }

final class CartDiscountApplication {
  const CartDiscountApplication({
    required this.kind,
    required this.allocationMethod,
    required this.targetSelection,
    required this.targetType,
    this.amount,
    this.percentage,
    this.title,
    this.code,
    this.totalAllocatedAmount,
  });

  final CartDiscountApplicationKind kind;
  final String allocationMethod;
  final String targetSelection;
  final String targetType;
  final CartMoney? amount;
  final String? percentage;
  final String? title;
  final String? code;
  final CartMoney? totalAllocatedAmount;
}

/// The amount Shopify actually allocated to a line, distinct from the
/// percentage or fixed value that defines the discount application.
final class CartDiscountAllocation {
  const CartDiscountAllocation({required this.discountedAmount});

  final CartMoney discountedAmount;
}

final class Cart {
  Cart({
    required this.id,
    required this.checkoutUrl,
    required this.createdAt,
    required this.updatedAt,
    required List<CartLine> lines,
    required this.totalQuantity,
    required this.buyerIdentity,
    required this.cost,
    List<CartDiscountCode> discountCodes = const [],
    List<CartDiscountApplication> discountApplications = const [],
  })  : lines = List.unmodifiable(lines),
        discountCodes = List.unmodifiable(discountCodes),
        discountApplications = List.unmodifiable(discountApplications);

  /// Sensitive bearer-like value. It is revealed only at the API boundary.
  final String id;

  /// Sensitive URL. It is not persisted and Phase 1 never opens it.
  final String checkoutUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<CartLine> lines;
  final int totalQuantity;
  final CartBuyerSummary buyerIdentity;
  final CartCost cost;
  final List<CartDiscountCode> discountCodes;
  final List<CartDiscountApplication> discountApplications;

  bool get isEmpty => lines.isEmpty;

  @override
  String toString() => 'Cart(<redacted>, lines: ${lines.length}, '
      'totalQuantity: $totalQuantity)';
}

final class CartLine {
  CartLine({
    required this.id,
    required this.variantId,
    required this.productId,
    required this.title,
    required this.variantTitle,
    required this.quantity,
    required this.cost,
    this.imageUrl,
    List<CartDiscountAllocation> discountAllocations = const [],
  }) : discountAllocations = List.unmodifiable(discountAllocations);

  /// Shopify line IDs can contain cart-scoped information and are redacted.
  final String id;
  final String variantId;
  final String productId;
  final String title;
  final String variantTitle;
  final int quantity;
  final CartLineCost cost;
  final String? imageUrl;
  final List<CartDiscountAllocation> discountAllocations;

  @override
  String toString() => 'CartLine(<redacted>, quantity: $quantity)';
}

final class CartLineCost {
  const CartLineCost({
    required this.amountPerQuantity,
    required this.subtotal,
    required this.total,
    this.compareAt,
  });

  final CartMoney amountPerQuantity;
  final CartMoney subtotal;
  final CartMoney total;
  final CartMoney? compareAt;
}
