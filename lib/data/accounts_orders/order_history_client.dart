/// Injected client for `GET /customers/me/orders` on `services/accounts_orders`
/// — the backend that unifies real Shopify checkout orders and hand-entered
/// WhatsApp apartado orders (`docs/ACCOUNTS_AND_SYNC_PLAN.md` Phase 3).
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../http/timeout_http_client.dart';

class OrderHistoryException implements Exception {
  OrderHistoryException(this.message);
  final String message;

  @override
  String toString() => 'OrderHistoryException: $message';
}

/// A row from `orders_mirror` — either a real Shopify checkout order or a
/// hand-entered WhatsApp apartado order, indistinguishable to the shopper
/// except by [source].
class MirroredOrder {
  const MirroredOrder({
    required this.id,
    required this.shopifyOrderId,
    required this.source,
    required this.attributionCode,
    required this.financialStatus,
    required this.fulfillmentStatus,
    required this.totalAmount,
    required this.currencyCode,
    required this.placedAt,
  });

  final int id;
  final String? shopifyOrderId;

  /// `shopify_checkout` | `whatsapp_apartado`.
  final String source;

  /// The `MN-XXXX` code, set only for an apartado order.
  final String? attributionCode;

  final String? financialStatus;
  final String? fulfillmentStatus;
  final double? totalAmount;
  final String? currencyCode;
  final DateTime? placedAt;

  bool get isApartado => source == 'whatsapp_apartado';

  factory MirroredOrder.fromJson(Map<String, dynamic> json) => MirroredOrder(
        id: json['id'] as int,
        shopifyOrderId: json['shopifyOrderId'] as String?,
        source: json['source'] as String,
        attributionCode: json['attributionCode'] as String?,
        financialStatus: json['financialStatus'] as String?,
        fulfillmentStatus: json['fulfillmentStatus'] as String?,
        totalAmount: (json['totalAmount'] as num?)?.toDouble(),
        currencyCode: json['currencyCode'] as String?,
        placedAt: json['placedAt'] == null
            ? null
            : DateTime.parse(json['placedAt'] as String),
      );
}

abstract class OrderHistoryClient {
  Future<List<MirroredOrder>> fetchOrders(String accessToken);
}

class HttpOrderHistoryClient implements OrderHistoryClient {
  HttpOrderHistoryClient({
    required this.baseUrl,
    http.Client? httpClient,
    Duration timeout = kDefaultHttpTimeout,
  }) : _client = TimeoutHttpClient(
          httpClient ?? http.Client(),
          timeout: timeout,
        );

  final String baseUrl;
  final http.Client _client;

  @override
  Future<List<MirroredOrder>> fetchOrders(String accessToken) async {
    final uri = Uri.parse('$baseUrl/customers/me/orders');
    final http.Response response;
    try {
      response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );
    } on TimeoutException {
      throw OrderHistoryException('GET /customers/me/orders timed out');
    }

    if (response.statusCode != 200) {
      throw OrderHistoryException(
        'GET /customers/me/orders returned ${response.statusCode}',
      );
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw OrderHistoryException('Malformed response body: $e');
    }

    final orders = json['orders'];
    if (orders is! List) {
      throw OrderHistoryException('Response carried no "orders" array');
    }
    return orders
        .map((e) => MirroredOrder.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
