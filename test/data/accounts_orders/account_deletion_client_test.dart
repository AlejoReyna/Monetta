import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monetta_app/data/accounts_orders/account_deletion_client.dart';

void main() {
  test('precheck reads only the order ids from a blocked response', () async {
    final client = HttpAccountDeletionClient(
      baseUrl: 'https://accounts.example',
      httpClient: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer shopper-token');
        expect(request.url.path, '/customers/me/account-deletion/precheck');
        return http.Response(
          jsonEncode({
            'result': 'blocked_open_order',
            'order': {'id': '15', 'shopifyOrderId': '900'},
            'email': 'ana@example.com',
            'totalAmount': 1999,
          }),
          200,
        );
      }),
    );
    addTearDown(client.close);

    final outcome = await client.precheck('shopper-token');
    expect(outcome, isA<AccountDeletionBlocked>());
    final blocked = outcome as AccountDeletionBlocked;
    expect(blocked.order.id, '15');
    expect(blocked.order.shopifyOrderId, '900');
    expect(blocked.toString(), isNot(contains('ana@example.com')));
    expect(blocked.toString(), isNot(contains('1999')));
  });

  test('delete reports Shopify erasure as requested and stale tokens as stale',
      () async {
    var call = 0;
    final client = HttpAccountDeletionClient(
      baseUrl: 'https://accounts.example',
      httpClient: MockClient((request) async {
        call += 1;
        expect(request.headers['X-Monetta-Id-Token'], 'id-token');
        if (call == 1) {
          return http.Response(
            jsonEncode({
              'result': 'deleted',
              'shopifyDataErasure': 'requested',
              'email': 'ana@example.com',
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({'error': 'stale_reauthentication'}),
          401,
        );
      }),
    );
    addTearDown(client.close);

    expect(
      await client.delete(accessToken: 'access', idToken: 'id-token'),
      isA<AccountDeletionDeleted>(),
    );
    expect(
      await client.delete(accessToken: 'access', idToken: 'id-token'),
      isA<AccountDeletionStale>(),
    );
  });

  test(
      'an unfinished Shopify order check is a failure, not permission to delete',
      () async {
    final client = HttpAccountDeletionClient(
      baseUrl: 'https://accounts.example',
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'order_check_unavailable'}),
          503,
        );
      }),
    );
    addTearDown(client.close);

    final outcome = await client.precheck('shopper-token');
    expect(outcome, isA<AccountDeletionFailed>());
    expect(outcome, isNot(isA<AccountDeletionClear>()));
    expect(outcome, isNot(isA<AccountDeletionDeleted>()));
  });
}
