/// Buyer order history from Shopify's Customer Account API — the primary
/// source for "Mis pedidos" (audit F13). The Monetta order mirror remains an
/// enrichment path for WhatsApp apartados, not the shopper's Shopify history.
///
/// Transport and discovery mirror `customer_identity.dart`: discover the
/// GraphQL endpoint from the storefront domain, send the access token without
/// a `Bearer ` prefix, and classify failures rather than leaking HTTP text.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'customer_account_config.dart';
import 'customer_auth_error.dart';
import 'customer_identity.dart' show kMaxCustomerApiResponseBytes;

/// One order as returned by Customer Account `customer.orders`.
class CustomerAccountOrder {
  const CustomerAccountOrder({
    required this.id,
    required this.name,
    required this.number,
    required this.processedAt,
    required this.financialStatus,
    required this.fulfillmentStatus,
    required this.totalAmount,
    required this.currencyCode,
    this.paymentMethod,
  });

  /// Globally unique `gid://shopify/Order/...`.
  final String id;

  /// Shop-facing name such as `#1001`.
  final String name;

  final int number;
  final DateTime processedAt;

  /// Shopify enum name (e.g. `PAID`) or null when absent.
  final String? financialStatus;
  final String? fulfillmentStatus;
  final double totalAmount;
  final String currencyCode;

  /// Comma-separated `Order.transactions.type` values (`bank_deposit`,
  /// `manual`, `card`, …). Null when Shopify did not return any.
  final String? paymentMethod;
}

abstract class CustomerOrdersService {
  /// Throws [CustomerAuthException] — never a raw socket/HTTP error.
  Future<List<CustomerAccountOrder>> fetchOrders(
    String accessToken, {
    int first = 25,
  });
}

class HttpCustomerOrdersService implements CustomerOrdersService {
  HttpCustomerOrdersService({
    required this.config,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final CustomerAccountConfig config;
  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;

  Uri? _graphQlEndpoint;
  Future<Uri>? _discoveryInFlight;

  static const String ordersQuery = r'''
query MonettaCustomerOrders($first: Int!, $after: String) {
  customer {
    orders(first: $first, after: $after, sortKey: PROCESSED_AT, reverse: true) {
      pageInfo { hasNextPage endCursor }
      nodes {
        id
        name
        number
        processedAt
        financialStatus
        fulfillmentStatus
        transactions { type }
        totalPrice {
          amount
          currencyCode
        }
      }
    }
  }
}''';

  @override
  Future<List<CustomerAccountOrder>> fetchOrders(
    String accessToken, {
    int first = 25,
  }) async {
    final endpoint = await _resolveGraphQlEndpoint();
    final all = <String, CustomerAccountOrder>{};
    final seen = <String>{};
    String? after;
    while (true) {
      final http.Response response;
      try {
        response = await _client
            .post(
              endpoint,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                // Raw token — same Customer Account API rule as identity.
                'Authorization': accessToken,
              },
              body: jsonEncode({
                'query': ordersQuery,
                'variables': {
                  'first': first,
                  if (after != null) 'after': after,
                },
              }),
            )
            .timeout(timeout);
      } on TimeoutException {
        throw const CustomerAuthException(
          CustomerAuthErrorKind.offline,
          debugDetail: 'customer orders request timed out',
        );
      } catch (error) {
        throw CustomerAuthException(
          CustomerAuthErrorKind.offline,
          debugDetail:
              'customer orders transport failure: ${error.runtimeType}',
        );
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const CustomerAuthException(
          CustomerAuthErrorKind.sessionExpired,
          debugDetail: 'customer orders rejected the access token',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CustomerAuthException(
          CustomerAuthErrorKind.server,
          debugDetail: 'customer orders HTTP ${response.statusCode}',
        );
      }
      if (response.bodyBytes.length > kMaxCustomerApiResponseBytes) {
        throw const CustomerAuthException(
          CustomerAuthErrorKind.server,
          debugDetail: 'customer orders response exceeded size limit',
        );
      }

      final page = parseOrders(response.bodyBytes);
      final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
      final data = decoded['data'] as Map;
      final customer = data['customer'] as Map;
      final connection = customer['orders'] as Map;
      final info = connection['pageInfo'];
      if (info is! Map ||
          info['hasNextPage'] is! bool ||
          (info['endCursor'] != null && info['endCursor'] is! String)) {
        throw const CustomerAuthException(
          CustomerAuthErrorKind.server,
          debugDetail: 'Invalid order pagination metadata',
        );
      }
      for (final order in page) {
        all[order.id] = order;
      }
      if (info['hasNextPage'] == false) return all.values.toList();
      final next = info['endCursor'];
      if (next is! String ||
          next.isEmpty ||
          !seen.add(next) ||
          seen.length >= 1000) {
        throw const CustomerAuthException(
          CustomerAuthErrorKind.server,
          debugDetail: 'Incomplete order pagination',
        );
      }
      after = next;
    }
  }

  Future<Uri> _resolveGraphQlEndpoint() {
    final cached = _graphQlEndpoint;
    if (cached != null) return Future.value(cached);

    final inFlight = _discoveryInFlight;
    if (inFlight != null) return inFlight;

    late final Future<Uri> future;
    future = _discoverGraphQlEndpoint().then((endpoint) {
      _graphQlEndpoint = endpoint;
      return endpoint;
    }).whenComplete(() {
      if (identical(_discoveryInFlight, future)) {
        _discoveryInFlight = null;
      }
    });
    _discoveryInFlight = future;
    return future;
  }

  Future<Uri> _discoverGraphQlEndpoint() async {
    final http.Response response;
    try {
      response = await _client.get(
        config.customerApiDiscoveryEndpoint,
        headers: const {'Accept': 'application/json'},
      ).timeout(timeout);
    } on TimeoutException {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.offline,
        debugDetail: 'customer API discovery timed out',
      );
    } catch (error) {
      throw CustomerAuthException(
        CustomerAuthErrorKind.offline,
        debugDetail:
            'customer API discovery transport failure: ${error.runtimeType}',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'customer API discovery HTTP ${response.statusCode}',
      );
    }
    if (response.bodyBytes.length > kMaxCustomerApiResponseBytes) {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'customer API discovery response exceeded size limit',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'customer API discovery returned non-JSON',
      );
    }
    final endpointValue =
        decoded is Map<String, dynamic> ? decoded['graphql_api'] : null;
    final endpoint =
        endpointValue is String ? Uri.tryParse(endpointValue) : null;
    if (endpoint == null ||
        endpoint.scheme != 'https' ||
        endpoint.host.isEmpty ||
        endpoint.hasFragment) {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'customer API discovery carried no valid graphql_api',
      );
    }
    return endpoint;
  }

  /// Separated so parsing rules are unit-testable without a socket.
  static List<CustomerAccountOrder> parseOrders(List<int> bodyBytes) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bodyBytes));
    } catch (_) {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'customer orders returned a non-JSON body',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'customer orders JSON root was not an object',
      );
    }

    final errors = decoded['errors'];
    if (errors is List && errors.isNotEmpty) {
      final text = errors.join(' ').toUpperCase();
      final unauthenticated = text.contains('UNAUTHENTICATED') ||
          text.contains('ACCESS_DENIED') ||
          text.contains('UNAUTHORIZED');
      throw CustomerAuthException(
        unauthenticated
            ? CustomerAuthErrorKind.sessionExpired
            : CustomerAuthErrorKind.server,
        debugDetail:
            'customer orders returned ${errors.length} GraphQL error(s)',
      );
    }

    final data = decoded['data'];
    final customer = data is Map<String, dynamic> ? data['customer'] : null;
    if (customer is! Map<String, dynamic>) {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'customer orders response carried no customer object',
      );
    }
    final orders = customer['orders'];
    final nodes = orders is Map<String, dynamic> ? orders['nodes'] : null;
    if (nodes is! List) {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'customer orders response carried no orders.nodes array',
      );
    }

    final parsed = <CustomerAccountOrder>[];
    for (final raw in nodes) {
      if (raw is! Map<String, dynamic>) continue;
      final id = raw['id'];
      final name = raw['name'];
      final number = raw['number'];
      final processedAtRaw = raw['processedAt'];
      final totalPrice = raw['totalPrice'];
      if (id is! String ||
          id.isEmpty ||
          name is! String ||
          number is! num ||
          processedAtRaw is! String ||
          totalPrice is! Map<String, dynamic>) {
        continue;
      }
      final amountRaw = totalPrice['amount'];
      final currency = totalPrice['currencyCode'];
      final amount = amountRaw is num
          ? amountRaw.toDouble()
          : double.tryParse('$amountRaw');
      if (amount == null || currency is! String || currency.isEmpty) {
        continue;
      }
      final processedAt = DateTime.tryParse(processedAtRaw);
      if (processedAt == null) continue;

      final financial = raw['financialStatus'];
      final fulfillment = raw['fulfillmentStatus'];
      parsed.add(
        CustomerAccountOrder(
          id: id,
          name: name,
          number: number.toInt(),
          processedAt: processedAt.toUtc(),
          financialStatus: financial is String ? financial : null,
          fulfillmentStatus: fulfillment is String ? fulfillment : null,
          totalAmount: amount,
          currencyCode: currency,
          paymentMethod: _paymentMethodOf(raw['transactions']),
        ),
      );
    }
    if (parsed.length != nodes.length) {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'Malformed order row; refusing partial history',
      );
    }
    return parsed;
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}

/// `Order.transactions.type` joined in source order. Missing or empty
/// lists stay null so a pending order is not guessed to be a transfer.
String? _paymentMethodOf(Object? raw) {
  if (raw is! List) return null;
  final types = <String>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final type = item['type'];
    if (type is! String) continue;
    final normalized = type.toLowerCase().trim().replaceAll('-', '_');
    if (normalized.isEmpty || types.contains(normalized)) continue;
    types.add(normalized);
  }
  if (types.isEmpty) return null;
  return types.join(',');
}
