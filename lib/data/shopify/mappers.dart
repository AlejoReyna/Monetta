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

    return CartLine(
      id: '${line['id']}',
      variantId: merchandise is Map ? '${merchandise['id']}' : '',
      productId: product is Map ? '${product['id']}' : '',
      title: product is Map ? '${product['title'] ?? ''}' : '',
      variantTitle: merchandise is Map ? '${merchandise['title'] ?? ''}' : '',
      quantity: (line['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: cost is Map ? money(cost['amountPerQuantity']) ?? 0 : 0,
      imageUrl: image is Map ? image['url'] as String? : null,
    );
  }).toList();

  final cost = json['cost'];
  final subtotal = cost is Map ? money(cost['subtotalAmount']) ?? 0 : 0.0;
  final currency = cost is Map && cost['subtotalAmount'] is Map
      ? '${(cost['subtotalAmount'] as Map)['currencyCode'] ?? 'MXN'}'
      : 'MXN';

  return Cart(
    id: '${json['id']}',
    checkoutUrl: '${json['checkoutUrl'] ?? ''}',
    lines: lines,
    subtotalAmount: subtotal,
    totalQuantity: (json['totalQuantity'] as num?)?.toInt() ?? 0,
    currencyCode: currency,
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
