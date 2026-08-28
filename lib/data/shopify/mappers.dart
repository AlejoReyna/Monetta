/// Storefront GraphQL JSON → domain entities.
///
/// Pure Dart. Every mapper is defensive: Shopify omits nullable fields entirely
/// rather than sending `null`, and a single missing image must never crash a
/// product grid.
library;

import '../../domain/cart.dart';
import '../../domain/collection.dart';
import '../../domain/product.dart';
import 'shopify_gid.dart';

/// Unwraps the `{edges: [{node: {...}}]}` shape Shopify uses everywhere.
List<Map<String, dynamic>> edgeNodes(Object? connection) {
  if (connection is! Map) return const [];
  final edges = connection['edges'];
  if (edges is! List) return const [];
  return edges
      .whereType<Map<String, dynamic>>()
      .map((e) => e['node'])
      .whereType<Map<String, dynamic>>()
      .toList();
}

/// Reads a Shopify `MoneyV2` amount. Amounts arrive as decimal *strings*
/// ("1749.00") — parsing them as num would be lossy on some locales.
double? money(Object? moneyV2) {
  if (moneyV2 is! Map) return null;
  final amount = moneyV2['amount'];
  if (amount is num) return amount.toDouble();
  if (amount is String) return double.tryParse(amount);
  return null;
}

/// Reads the `value` of a metafield, which is null when the owner hasn't set it.
String? metafieldValue(Object? metafield) {
  if (metafield is! Map) return null;
  final value = metafield['value'];
  return value is String && value.trim().isNotEmpty ? value : null;
}

Product productFromJson(Map<String, dynamic> json) {
  final variants = edgeNodes(json['variants']).map((v) {
    return ProductVariant(
      id: shopifyVariantGid(v['id']),
      title: '${v['title'] ?? ''}',
      price: money(v['price']) ?? 0,
      available: v['availableForSale'] == true,
      compareAtPrice: money(v['compareAtPrice']),
      sku: v['sku'] as String?,
    );
  }).toList();

  final images = edgeNodes(json['images'])
      .map((i) => i['url'])
      .whereType<String>()
      .toList();

  final collectionHandles = edgeNodes(json['collections'])
      .map((c) => c['handle'])
      .whereType<String>()
      .toList();

  return Product(
    id: shopifyProductGid(json['id']),
    handle: '${json['handle'] ?? ''}',
    title: '${json['title'] ?? ''}',
    vendor: '${json['vendor'] ?? ''}',
    productType: '${json['productType'] ?? ''}',
    tags: (json['tags'] as List?)?.whereType<String>().toList() ?? const [],
    variants: variants,
    images: images,
    descriptionHtml: '${json['descriptionHtml'] ?? ''}',
    collectionHandles: collectionHandles,
    brandOverride: metafieldValue(json['brandOverride']),
    categoryOverride: metafieldValue(json['categoryOverride']),
    createdAt: _date(json['createdAt']),
    updatedAt: _date(json['updatedAt']),
  );
}

Collection collectionFromJson(Map<String, dynamic> json) {
  // We ask for `products(first: 1)` purely to learn whether the collection is
  // empty — asking for a real count would cost a far more expensive query.
  final products = json['products'];
  int? count;
  if (products is Map) {
    final nodes = edgeNodes(products);
    final pageInfo = products['pageInfo'];
    final hasMore = pageInfo is Map && pageInfo['hasNextPage'] == true;
    count = nodes.isEmpty && !hasMore ? 0 : null;
  }

  final image = json['image'];

  return Collection(
    id: '${json['id']}',
    handle: '${json['handle'] ?? ''}',
    title: '${json['title'] ?? ''}',
    description: '${json['description'] ?? ''}',
    imageUrl: image is Map ? image['url'] as String? : null,
    productCount: count,
  );
}

MenuEntry menuEntryFromJson(Map<String, dynamic> json) {
  final resource = json['resource'];
  final children = (json['items'] as List?)
          ?.whereType<Map<String, dynamic>>()
          .map(menuEntryFromJson)
          .toList() ??
      const <MenuEntry>[];

  return MenuEntry(
    title: '${json['title'] ?? ''}',
    url: '${json['url'] ?? ''}',
    resourceHandle: resource is Map ? resource['handle'] as String? : null,
    type: _menuType('${json['type'] ?? ''}'),
    children: children,
  );
}

MenuEntryType _menuType(String raw) {
  switch (raw.toUpperCase()) {
    case 'COLLECTION':
      return MenuEntryType.collection;
    case 'PRODUCT':
      return MenuEntryType.product;
    case 'PAGE':
      return MenuEntryType.page;
    case 'HTTP':
      return MenuEntryType.http;
    default:
      return MenuEntryType.unknown;
  }
}

Cart cartFromJson(Map<String, dynamic> json) {
  final lines = edgeNodes(json['lines']).map((line) {
    final merchandise = line['merchandise'];
    final product = merchandise is Map ? merchandise['product'] : null;
    final image = merchandise is Map ? merchandise['image'] : null;
    final cost = line['cost'];
    final discountAllocations = (line['discountAllocations'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(
              (allocation) => CartDiscountAllocation(
                discountedAmount: _cartMoney(
                  allocation['discountedAmount'],
                ),
              ),
            )
            .toList() ??
        const <CartDiscountAllocation>[];

    final amountPerQuantity = _cartMoney(
      cost is Map ? cost['amountPerQuantity'] : null,
    );
    return CartLine(
      id: '${line['id']}',
      variantId: shopifyVariantGid(
        merchandise is Map ? merchandise['id'] : null,
      ),
      productId: shopifyProductGid(product is Map ? product['id'] : null),
      title: product is Map ? '${product['title'] ?? ''}' : '',
      variantTitle: merchandise is Map ? '${merchandise['title'] ?? ''}' : '',
      quantity: (line['quantity'] as num?)?.toInt() ?? 0,
      cost: CartLineCost(
        amountPerQuantity: amountPerQuantity,
        compareAt: cost is Map && cost['compareAtAmountPerQuantity'] != null
            ? _cartMoney(cost['compareAtAmountPerQuantity'])
            : null,
        subtotal: _cartMoney(
          cost is Map ? cost['subtotalAmount'] : null,
          fallback: amountPerQuantity,
        ),
        total: _cartMoney(
          cost is Map ? cost['totalAmount'] : null,
          fallback: amountPerQuantity,
        ),
      ),
      imageUrl: image is Map ? image['url'] as String? : null,
      discountAllocations: discountAllocations,
    );
  }).toList();

  final cost = json['cost'];
  final subtotal = _cartMoney(cost is Map ? cost['subtotalAmount'] : null);
  final buyer = json['buyerIdentity'];
  final discountCodes = (json['discountCodes'] as List?)
          ?.whereType<Map<String, dynamic>>()
          .map(
            (code) => CartDiscountCode(
              code: '${code['code'] ?? ''}',
              applicable: code['applicable'] == true,
            ),
          )
          .toList() ??
      const <CartDiscountCode>[];
  final discountApplications = (json['discountApplications'] as List?)
          ?.whereType<Map<String, dynamic>>()
          .map(_cartDiscountApplication)
          .toList() ??
      const <CartDiscountApplication>[];

  return Cart(
    id: '${json['id']}',
    checkoutUrl: '${json['checkoutUrl'] ?? ''}',
    createdAt: _date(json['createdAt']),
    updatedAt: _date(json['updatedAt']),
    lines: lines,
    totalQuantity: (json['totalQuantity'] as num?)?.toInt() ?? 0,
    buyerIdentity: CartBuyerSummary(
      countryCode: buyer is Map ? buyer['countryCode'] as String? : null,
      isAuthenticated: buyer is Map && buyer['customer'] is Map,
    ),
    cost: CartCost(
      subtotal: subtotal,
      total: _cartMoney(
        cost is Map ? cost['totalAmount'] : null,
        fallback: subtotal,
      ),
      checkoutCharge: cost is Map && cost['checkoutChargeAmount'] != null
          ? _cartMoney(cost['checkoutChargeAmount'])
          : null,
      subtotalEstimated: cost is Map && cost['subtotalAmountEstimated'] == true,
      totalEstimated: cost is Map && cost['totalAmountEstimated'] == true,
    ),
    discountCodes: discountCodes,
    discountApplications: discountApplications,
  );
}

CartMoney _cartMoney(Object? value, {CartMoney? fallback}) {
  if (value is Map) {
    final amount = value['amount'];
    final currency = value['currencyCode'];
    if (amount is String && currency is String && currency.isNotEmpty) {
      return CartMoney(amount: amount, currencyCode: currency);
    }
  }
  if (fallback != null) return fallback;
  throw const FormatException('Invalid Shopify cart money');
}

CartDiscountApplication _cartDiscountApplication(Map<String, dynamic> json) {
  final value = json['value'];
  final kind = switch (json['__typename']) {
    'CartAutomaticDiscountApplication' => CartDiscountApplicationKind.automatic,
    'CartCodeDiscountApplication' => CartDiscountApplicationKind.code,
    'CartCustomDiscountApplication' => CartDiscountApplicationKind.custom,
    _ => CartDiscountApplicationKind.unknown,
  };
  return CartDiscountApplication(
    kind: kind,
    allocationMethod: '${json['allocationMethod'] ?? ''}',
    targetSelection: '${json['targetSelection'] ?? ''}',
    targetType: '${json['targetType'] ?? ''}',
    amount: value is Map && value['amount'] != null ? _cartMoney(value) : null,
    percentage: value is Map && value['percentage'] != null
        ? '${value['percentage']}'
        : null,
    title: json['title'] is String ? json['title'] as String : null,
    code: json['code'] is String ? json['code'] as String : null,
    totalAllocatedAmount: json['totalAllocatedAmount'] is Map
        ? _cartMoney(json['totalAllocatedAmount'])
        : null,
  );
}

/// Shopify sends ISO-8601 with an offset. Fall back to the epoch rather than
/// throwing — a malformed date must not take down a catalog sync.
DateTime _date(Object? raw) {
  if (raw is String) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed;
  }
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
