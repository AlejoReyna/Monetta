import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monetta_app/features/rewards/rewards_api.dart';

/// CONTRACT-01: the app sends the numeric order id as a single path segment.
/// Shared fixture with `services/accounts_orders/test/rewardsOrderIdContract.test.ts`.
void main() {
  final fixture = jsonDecode(
    File('test/fixtures/contracts/rewards_order_id.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final storedOrderId = fixture['storedOrderId'] as String;
  final requestPath = fixture['requestPath'] as String;
  final acceptedIds = (fixture['acceptedIds'] as List).cast<String>();
  final rejectedIds = (fixture['rejectedIds'] as List).cast<String>();

  late List<http.Request> requests;
  late RewardsApi api;

  setUp(() {
    requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode({
          'orderShopifyId': storedOrderId,
          'isWholesale': false,
          'earnedPendingCents': 0,
          'earnedReleasedCents': 0,
          'usedCents': 0,
          'state': 'none',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    api = RewardsApi(
      baseUrl: 'https://rewards.test',
      tokenProvider: () async => 'tok-77',
      client: client,
    );
  });

  for (final id in acceptedIds) {
    test(
        'CONTRACT-01 orderRewards("$id") requests the numeric id as one '
        'path segment', () async {
      await api.orderRewards(id);

      expect(requests, hasLength(1));
      final request = requests.single;
      expect(request.method, 'GET');
      expect(request.url.path, requestPath);
      expect(request.url.pathSegments, [
        'customers',
        'me',
        'orders',
        storedOrderId,
        'rewards',
      ]);
    });
  }

  for (final id in rejectedIds) {
    test(
        'CONTRACT-01 orderRewards("$id") throws ArgumentError before any '
        'request', () async {
      await expectLater(api.orderRewards(id), throwsArgumentError);
      expect(requests, isEmpty);
    });
  }
}
