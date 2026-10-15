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
    expect(outcome, isA<AccountDeletionOrderCheckUnavailable>());
    expect(outcome, isNot(isA<AccountDeletionClear>()));
    expect(outcome, isNot(isA<AccountDeletionDeleted>()));
  });

  test('reauth and too many orders are distinct from a failed check', () async {
    var call = 0;
    final client = HttpAccountDeletionClient(
      baseUrl: 'https://accounts.example',
      httpClient: MockClient((request) async {
        call += 1;
        if (call == 1) {
          return http.Response(
            jsonEncode({'result': 'reauth_required'}),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'result': 'blocked_open_order',
            'order': {
              'id': '9',
              'shopifyOrderId': '9',
              'reason': 'refund_in_progress',
            },
          }),
          200,
        );
      }),
    );
    addTearDown(client.close);

    expect(
      await client.precheck('shopper-token'),
      isA<AccountDeletionReauthRequired>(),
    );
    final blocked = await client.precheck('shopper-token');
    expect(blocked, isA<AccountDeletionBlocked>());
    expect(
        (blocked as AccountDeletionBlocked).order.reason, 'refund_in_progress');
  });

  test(
      'email mismatch returns the masked address and refund review keeps the order name',
      () async {
    var call = 0;
    String? matchPath;
    String? legacyHeader;
    final client = HttpAccountDeletionClient(
      baseUrl: 'https://accounts.example',
      httpClient: MockClient((request) async {
        call += 1;
        if (call == 1) {
          matchPath = request.url.path;
          for (final entry in request.headers.entries) {
            if (entry.key.toLowerCase() == 'x-monetta-legacy-session') {
              legacyHeader = entry.value;
            }
          }
          return http.Response(
            jsonEncode({
              'result': 'email_mismatch',
              'maskedEmail': 'a•••@gmail.com',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({
            'result': 'blocked_open_order',
            'order': {
              'id': '900',
              'shopifyOrderId': '900',
              'reason': 'refund_review',
              'orderName': '#1042',
            },
          }),
          200,
        );
      }),
    );
    addTearDown(client.close);

    final mismatch = await client.matchLegacyEmail(
      shopifyAccessToken: 'shopify',
      legacySessionToken: 'legacy-token',
    );
    expect(matchPath, '/customers/me/account-deletion/email-match');
    expect(legacyHeader, 'legacy-token');
    expect(mismatch, isA<AccountDeletionEmailMismatch>());
    expect(
      (mismatch as AccountDeletionEmailMismatch).maskedEmail,
      'a•••@gmail.com',
    );

    final blocked = await client.precheck('shopper-token');
    final order = (blocked as AccountDeletionBlocked).order;
    expect(order.reason, 'refund_review');
    expect(order.orderName, '#1042');
  });

  test('too many orders is its own result', () async {
    final client = HttpAccountDeletionClient(
      baseUrl: 'https://accounts.example',
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({'result': 'too_many_orders'}),
          200,
        );
      }),
    );
    addTearDown(client.close);

    expect(
      await client.precheck('shopper-token'),
      isA<AccountDeletionTooManyOrders>(),
    );
  });
}
