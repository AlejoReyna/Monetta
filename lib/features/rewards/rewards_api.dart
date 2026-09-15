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

  Future<Map<String, String>> _headers() async {
    final token = await tokenProvider();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Never _throwFor(int status, String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final code = '${json['error'] ?? 'internal_error'}';
      throw RewardsApiError(code, json['message'] as String?);
    } on RewardsApiError {
      rethrow;
    } on Object {
      throw RewardsApiError('internal_error');
    }
  }

  Future<RewardsSummary> summary() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/customers/me/rewards'),
      headers: await _headers(),
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
    final res = await _client.get(uri, headers: await _headers());
    if (res.statusCode != 200) _throwFor(res.statusCode, res.body);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (json['movements'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(RewardsMovement.fromJson)
        .toList(growable: false);
    return (movements: items, nextCursor: json['nextCursor'] as String?);
  }

  Future<OrderRewardsState> orderRewards(String orderShopifyId) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/customers/me/orders/$orderShopifyId/rewards'),
      headers: await _headers(),
    );
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
