/// Authorized order detail from Shopify Customer Account API 2026-07.
/// Summaries and mirror DTOs stay compatible; this read does not use current
/// product prices, variant photos or a customer's current default address.
library;

import 'customer_addresses.dart';
import 'customer_graphql_client.dart';

class CustomerOrderMoney {
  const CustomerOrderMoney(this.amount, this.currencyCode);
  final String amount;
  final String currencyCode;
  static CustomerOrderMoney? parse(Object? raw) {
    if (raw == null) return null;
    if (raw is! Map ||
        raw['amount'] is! String ||
        raw['currencyCode'] is! String ||
        double.tryParse(raw['amount'] as String)?.isFinite != true ||
        (raw['currencyCode'] as String).isEmpty) {
      throw const CustomerDataException('malformed_order_money');
    }
    return CustomerOrderMoney(
      raw['amount'] as String,
      raw['currencyCode'] as String,
    );
  }
}

class CustomerOrderLine {
  const CustomerOrderLine({
    required this.id,
    required this.name,
    required this.quantity,
    this.variantId,
    this.variantTitle,
    this.sku,
    this.imageUrl,
    this.price,
    this.totalPrice,
  });
  final String id;
  final String name;
  final int quantity;
  final String? variantId, variantTitle, sku;
  final Uri? imageUrl;
  final CustomerOrderMoney? price, totalPrice;
  factory CustomerOrderLine.parse(Object? raw) {
    if (raw is! Map ||
        raw['id'] is! String ||
        raw['name'] is! String ||
        raw['quantity'] is! int ||
        (raw['quantity'] as int) < 0) {
      throw const CustomerDataException('malformed_order_line');
    }
    final image = raw['image'];
    return CustomerOrderLine(
      id: raw['id'] as String,
      name: raw['name'] as String,
      quantity: raw['quantity'] as int,
      variantId: raw['variantId'] as String?,
      variantTitle: raw['variantTitle'] as String?,
      sku: raw['sku'] as String?,
      imageUrl: customerHttpsUri(image is Map ? image['url'] : null),
      price: CustomerOrderMoney.parse(raw['price']),
      totalPrice: CustomerOrderMoney.parse(raw['totalPrice']),
    );
  }
}

class CustomerOrderTracking {
  const CustomerOrderTracking({this.company, this.number, this.url});
  final String? company, number;
  final Uri? url;
}

class CustomerOrderShipment {
  const CustomerOrderShipment({
    required this.id,
    required this.status,
    required this.latestShipmentStatus,
    required this.tracking,
  });
  final String id;

  /// Provider statuses, independent of payment. SUCCESS means fulfillment
  /// succeeded; it does not establish delivery. latestShipmentStatus may.
  final String? status, latestShipmentStatus;
  final List<CustomerOrderTracking> tracking;
  factory CustomerOrderShipment.parse(Object? raw) {
    if (raw is! Map ||
        raw['id'] is! String ||
        raw['trackingInformation'] is! List) {
      throw const CustomerDataException('malformed_shipment');
    }
    final tracking = <CustomerOrderTracking>[];
    for (final item in raw['trackingInformation'] as List) {
      if (item is! Map) throw const CustomerDataException('malformed_tracking');
      tracking.add(
        CustomerOrderTracking(
          company: item['company'] as String?,
          number: item['number'] as String?,
          url: customerHttpsUri(item['url']),
        ),
      );
    }
    return CustomerOrderShipment(
      id: raw['id'] as String,
      status: raw['status'] as String?,
      latestShipmentStatus: raw['latestShipmentStatus'] as String?,
      tracking: List.unmodifiable(tracking),
    );
  }
}

class CustomerOrderDetails {
  const CustomerOrderDetails({
    required this.id,
    required this.name,
    required this.financialStatus,
    required this.fulfillmentStatus,
    required this.cancelledAt,
    required this.shippingAddress,
    required this.lines,
    required this.shipments,
  });
  final String id, name;
  final String? financialStatus, fulfillmentStatus;
  final DateTime? cancelledAt;
  final CustomerAddress? shippingAddress;
  final List<CustomerOrderLine> lines;
  final List<CustomerOrderShipment> shipments;
}

abstract interface class CustomerOrderDetailsService {
  /// Null means no visible authorized resource, never a fabricated empty order.
  Future<CustomerOrderDetails?> fetchOrderDetails(
    String accessToken,
    String orderId,
  );
}

class ShopifyCustomerOrderDetailsService
    implements CustomerOrderDetailsService {
  const ShopifyCustomerOrderDetailsService(this.client);
  final CustomerGraphqlClient client;
  static const query = '''
    query MonettaOrderDetail(\$id: ID!, \$linesAfter: String, \$shipmentsAfter: String) {
      order(id: \$id) {
        id name financialStatus fulfillmentStatus cancelledAt updatedAt
        shippingAddress { $customerAddressFields }
        lineItems(first: 100, after: \$linesAfter) {
          nodes { id name quantity variantId variantTitle sku image { url }
            price { amount currencyCode } totalPrice { amount currencyCode } }
          pageInfo { hasNextPage endCursor }
        }
        fulfillments(first: 100, after: \$shipmentsAfter) {
          nodes { id status latestShipmentStatus trackingInformation { company number url } }
          pageInfo { hasNextPage endCursor }
        }
      }
    }
  ''';

  @override
  Future<CustomerOrderDetails?> fetchOrderDetails(
    String accessToken,
    String orderId,
  ) async {
    if (!orderId.startsWith('gid://shopify/Order/')) {
      throw ArgumentError('Invalid order ID');
    }
    final lines = <String, CustomerOrderLine>{};
    final shipments = <String, CustomerOrderShipment>{};
    final lineCursors = <String>{}, shipmentCursors = <String>{};
    String? linesAfter, shipmentsAfter;
    Map<dynamic, dynamic>? first;
    var linesDone = false, shipmentsDone = false;
    do {
      final data = await client.execute(
        accessToken,
        query,
        variables: {
          'id': orderId,
          'linesAfter': linesAfter,
          'shipmentsAfter': shipmentsAfter,
        },
      );
      final order = data['order'];
      if (order == null && first == null) return null;
      if (order is! Map || order['id'] != orderId || order['name'] is! String) {
        throw const CustomerDataException('order_unavailable');
      }
      if (first != null && first['updatedAt'] != order['updatedAt']) {
        throw const CustomerDataException('order_changed_during_read');
      }
      first ??= order;
      if (!linesDone) {
        for (final raw in customerConnectionNodes(order['lineItems'])) {
          final line = CustomerOrderLine.parse(raw);
          lines[line.id] = line;
        }
        linesAfter = customerNextCursor(order['lineItems'], lineCursors);
        linesDone = linesAfter == null;
      }
      if (!shipmentsDone) {
        for (final raw in customerConnectionNodes(order['fulfillments'])) {
          final shipment = CustomerOrderShipment.parse(raw);
          shipments[shipment.id] = shipment;
        }
        shipmentsAfter =
            customerNextCursor(order['fulfillments'], shipmentCursors);
        shipmentsDone = shipmentsAfter == null;
      }
    } while (!linesDone || !shipmentsDone);
    final order = first;
    final cancelledRaw = order['cancelledAt'];
    final cancelled =
        cancelledRaw is String ? DateTime.tryParse(cancelledRaw) : null;
    if (cancelledRaw != null && cancelled == null) {
      throw const CustomerDataException('malformed_cancellation');
    }
    return CustomerOrderDetails(
      id: orderId,
      name: order['name'] as String,
      financialStatus: order['financialStatus'] as String?,
      fulfillmentStatus: order['fulfillmentStatus'] as String?,
      cancelledAt: cancelled,
      shippingAddress: order['shippingAddress'] == null
          ? null
          : CustomerAddress.fromJson(order['shippingAddress']),
      lines: List.unmodifiable(lines.values),
      shipments: List.unmodifiable(shipments.values),
    );
  }
}

Uri? customerHttpsUri(Object? raw) {
  final uri = raw is String ? Uri.tryParse(raw) : null;
  return uri != null &&
          uri.scheme == 'https' &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty
      ? uri
      : null;
}
