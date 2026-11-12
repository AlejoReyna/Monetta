/// Cliente HTTP del contrato Rewards V1.
///
/// Identidad: el backend deriva la cuenta del bearer; este cliente nunca envía
/// customer ids como autoridad. Sin caché autoritativa: el saldo en memoria
/// es solo presentación con frescura explícita.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'rewards_models.dart';

typedef RewardsTokenProvider = Future<String?> Function();

class RewardsApi {
  RewardsApi({
    required this.baseUrl,
    required this.tokenProvider,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final RewardsTokenProvider tokenProvider;
  final http.Client _client;

  int _sessionGeneration = 0;

  /// Called by the app on sign-out/account change, including A -> B -> A.
  void clearSession() => _sessionGeneration++;

  Future<Map<String, String>> _headers() async {
    final token = await tokenProvider();
    if (token == null || token.isEmpty) {
      throw const RewardsApiError('unauthenticated');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Never _throwFor(int status, String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final code = '${json['error'] ?? 'internal_error'}';
      throw RewardsApiError(code);
    } on RewardsApiError {
      rethrow;
    } on Object {
      throw RewardsApiError('internal_error');
    }
  }

  Future<Map<String, dynamic>> _read(Uri uri) async {
    final generation = _sessionGeneration;
    final headers = await _headers();
    final res = await _client.get(uri, headers: headers);
    final currentHeaders = await _headers();
    if (generation != _sessionGeneration ||
        headers['Authorization'] != currentHeaders['Authorization']) {
      throw const RewardsApiError('stale_session');
    }
    if (res.statusCode != 200) _throwFor(res.statusCode, res.body);
    if (res.bodyBytes.length > 2 * 1024 * 1024) {
      throw const RewardsApiError('invalid_response');
    }
    try {
      final value = jsonDecode(res.body);
      if (value is Map<String, dynamic>) return value;
    } catch (_) {/* classified below */}
    throw const RewardsApiError('invalid_response');
  }

  Future<RewardsSummary> summary() async => RewardsSummary.fromJson(
        await _read(Uri.parse('$baseUrl/customers/me/rewards')),
      );

  Future<({List<RewardsMovement> movements, String? nextCursor})> activity({
    int limit = 20,
    String? cursor,
  }) async {
    if (limit < 1 || limit > 100) throw ArgumentError.value(limit, 'limit');
    final uri = Uri.parse('$baseUrl/customers/me/rewards/activity').replace(
      queryParameters: {
        'limit': '$limit',
        if (cursor != null) 'cursor': cursor,
      },
    );
    final json = await _read(uri);
    final rows = json['movements'];
    final next = json['nextCursor'];
    if (rows is! List ||
        rows.any((r) => r is! Map<String, dynamic>) ||
        (next != null && (next is! String || next.isEmpty))) {
      throw const RewardsApiError('invalid_response');
    }
    final items = rows
        .cast<Map<String, dynamic>>()
        .map(RewardsMovement.fromJson)
        .toList(growable: false);
    return (movements: items, nextCursor: next as String?);
  }

  Future<OrderRewardsState> orderRewards(String orderShopifyId) async {
    final data = await _read(
      Uri.parse(
        '$baseUrl/customers/me/orders/${Uri.encodeComponent(orderShopifyId)}/rewards',
      ),
    );
    return OrderRewardsState.fromJson(data);
  }

  Future<RewardsQuote> quote({
    required String cartRevision,
    required List<Map<String, Object?>> lines,
    bool isWholesaleCart = false,
  }) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/customers/me/rewards/quotes'),
      headers: await _headers(),
      body: jsonEncode({
        'cartRevision': cartRevision,
        'lines': lines,
        'isWholesaleCart': isWholesaleCart,
      }),
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
    final res = await _client.post(
      Uri.parse('$baseUrl/customers/me/rewards/redemptions'),
      headers: await _headers(),
      body: jsonEncode({
        'quoteId': quoteId,
        'amountCents': amountCents,
        'idempotencyKey': idempotencyKey,
        'isWholesaleCart': isWholesaleCart,
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      _throwFor(res.statusCode, res.body);
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> releaseRedemption(String redemptionId) async {
    final res = await _client.post(
      Uri.parse(
        '$baseUrl/customers/me/rewards/redemptions/$redemptionId/release',
      ),
      headers: await _headers(),
    );
    if (res.statusCode != 200) _throwFor(res.statusCode, res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  void close() => _client.close();
}
