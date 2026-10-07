/// Cliente HTTP del contrato Rewards V1.
///
/// Identidad: el backend deriva la cuenta del bearer; este cliente nunca envía
/// customer ids como autoridad. Sin caché autoritativa: el saldo en memoria
/// es solo presentación con frescura explícita.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../data/http/timeout_http_client.dart';
import 'rewards_models.dart';

typedef RewardsTokenProvider = Future<String?> Function();

class RewardsApi {
  RewardsApi({
    required this.baseUrl,
    required this.tokenProvider,
    http.Client? client,
    Duration timeout = kDefaultHttpTimeout,
  }) : _client = TimeoutHttpClient(client ?? http.Client(), timeout: timeout);

  final String baseUrl;
  final RewardsTokenProvider tokenProvider;
  final http.Client _client;

  Future<Map<String, String>> _headers() async {
    final token = await tokenProvider();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Runs one HTTP call and turns transport failures (no connectivity, DNS,
  /// TLS, timeouts) into `RewardsApiError('network')`. Token lookup happens
  /// outside this wrapper so its failures are not mislabelled as network.
  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request();
    } on http.ClientException {
      throw const RewardsApiError('network');
    } on IOException {
      throw const RewardsApiError('network');
    } on TimeoutException {
      throw const RewardsApiError('network');
    }
  }

  /// Keeps the `error` code of a JSON body; otherwise derives it from the
  /// status so an HTML 404 or a bare 503 still gets a meaningful code.
  Never _throwFor(int status, String body) {
    String? code;
    String? message;
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) {
        final error = json['error'];
        if (error is String && error.isNotEmpty) code = error;
        final rawMessage = json['message'];
        if (rawMessage is String) message = rawMessage;
      }
    } on FormatException {
      // Non-JSON body: fall back to the status below.
    }
    throw RewardsApiError(code ?? _codeForStatus(status), message);
  }

  static String _codeForStatus(int status) {
    if (status == 401 || status == 403) return 'unauthorized';
    if (status == 404) return 'not_found';
    if (status >= 500) return 'service_unavailable';
    return 'internal_error';
  }

  Future<RewardsSummary> summary() async {
    final headers = await _headers();
    final res = await _send(
      () => _client.get(
        Uri.parse('$baseUrl/customers/me/rewards'),
        headers: headers,
      ),
    );
    if (res.statusCode != 200) _throwFor(res.statusCode, res.body);
    return RewardsSummary.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<({List<RewardsMovement> movements, String? nextCursor})> activity({
    int limit = 20,
    String? cursor,
  }) async {
    final uri = Uri.parse('$baseUrl/customers/me/rewards/activity').replace(
      queryParameters: {
        'limit': '$limit',
        if (cursor != null) 'cursor': cursor,
      },
    );
    final headers = await _headers();
    final res = await _send(() => _client.get(uri, headers: headers));
    if (res.statusCode != 200) _throwFor(res.statusCode, res.body);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (json['movements'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(RewardsMovement.fromJson)
        .toList(growable: false);
    return (movements: items, nextCursor: json['nextCursor'] as String?);
  }

  static final RegExp _numericOrderIdPattern = RegExp(r'^[0-9]+$');
  static final RegExp _orderGidPattern = RegExp(
    r'^gid://shopify/Order/([0-9]+)$',
  );

  /// Returns the numeric part of a Shopify order id, which is the canonical
  /// wire format. Accepts `8001` or `gid://shopify/Order/8001`.
  static String _numericOrderId(String orderShopifyId) {
    if (_numericOrderIdPattern.hasMatch(orderShopifyId)) {
      return orderShopifyId;
    }
    final gidMatch = _orderGidPattern.firstMatch(orderShopifyId);
    if (gidMatch != null) return gidMatch.group(1)!;
    throw ArgumentError.value(
      orderShopifyId,
      'orderShopifyId',
      'Expected a numeric Shopify order id or gid://shopify/Order/<n>',
    );
  }

  Future<OrderRewardsState> orderRewards(String orderShopifyId) async {
    // Validate before any request so malformed ids never reach the network.
    final numericId = _numericOrderId(orderShopifyId);
    final base = Uri.parse(baseUrl);
    final uri = base.replace(
      pathSegments: [
        ...base.pathSegments.where((segment) => segment.isNotEmpty),
        'customers',
        'me',
        'orders',
        numericId,
        'rewards',
      ],
    );
    final headers = await _headers();
    final res = await _send(() => _client.get(uri, headers: headers));
    if (res.statusCode != 200) _throwFor(res.statusCode, res.body);
    return OrderRewardsState.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<RewardsQuote> quote({
    required String cartRevision,
    required List<Map<String, Object?>> lines,
    bool isWholesaleCart = false,
  }) async {
    final headers = await _headers();
    final res = await _send(
      () => _client.post(
        Uri.parse('$baseUrl/customers/me/rewards/quotes'),
        headers: headers,
        body: jsonEncode({
          'cartRevision': cartRevision,
          'lines': lines,
          'isWholesaleCart': isWholesaleCart,
        }),
      ),
    );
    if (res.statusCode != 201) _throwFor(res.statusCode, res.body);
    return RewardsQuote.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<Map<String, dynamic>> redeem({
    required String quoteId,
    required int amountCents,
    required String idempotencyKey,
    bool isWholesaleCart = false,
  }) async {
    final headers = await _headers();
    final res = await _send(
      () => _client.post(
        Uri.parse('$baseUrl/customers/me/rewards/redemptions'),
        headers: headers,
        body: jsonEncode({
          'quoteId': quoteId,
          'amountCents': amountCents,
          'idempotencyKey': idempotencyKey,
          'isWholesaleCart': isWholesaleCart,
        }),
      ),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      _throwFor(res.statusCode, res.body);
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> releaseRedemption(String redemptionId) async {
    final headers = await _headers();
    final res = await _send(
      () => _client.post(
        Uri.parse(
          '$baseUrl/customers/me/rewards/redemptions/$redemptionId/release',
        ),
        headers: headers,
      ),
    );
    if (res.statusCode != 200) _throwFor(res.statusCode, res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  void close() => _client.close();
}
