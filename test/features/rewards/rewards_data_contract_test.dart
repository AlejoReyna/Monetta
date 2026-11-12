// Deterministic ledger/provider fixtures, never a live balance or financial action.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monetta_app/features/rewards/rewards_api.dart';
import 'package:monetta_app/features/rewards/rewards_models.dart';

Map<String, dynamic> summaryFixture() => {
      'program': {'redemptionEnabled': false},
      'balance': {
        'availableCents': 123,
        'pendingCents': 0,
        'reservedCents': 0,
        'asOf': '2026-11-11T00:00:00Z',
      },
    };
Matcher code(String code) =>
    isA<RewardsApiError>().having((e) => e.code, 'code', code);
void main() {
  test(
      'old V1 payload without optional capabilities stays compatible; exact ledger zero is valid',
      () {
    final summary = RewardsSummary.fromJson(summaryFixture());
    expect(summary.availableCents, 123);
    expect(summary.reservedCents, 0);
    expect(summary.membershipAvailable, isFalse);
    expect(summary.tierProgressAvailable, isFalse);
    expect(summary.tierBenefitsAvailable, isFalse);
    expect(summary.asOf, DateTime.utc(2026, 11, 11));
  });
  for (final key in [
    'availableCents',
    'pendingCents',
    'reservedCents',
    'asOf',
  ]) {
    test('missing $key fails without manufacturing zero or current time', () {
      final fixture = summaryFixture();
      (fixture['balance'] as Map).remove(key);
      expect(
        () => RewardsSummary.fromJson(fixture),
        throwsA(code('invalid_response')),
      );
    });
  }
  test('missing balance is failed data', () {
    expect(
      () => RewardsSummary.fromJson({}),
      throwsA(code('invalid_response')),
    );
  });
  test('fractional ledger cents are rejected rather than silently rounded', () {
    final fixture = summaryFixture();
    (fixture['balance'] as Map)['availableCents'] = 1.5;
    expect(
      () => RewardsSummary.fromJson(fixture),
      throwsA(code('invalid_response')),
    );
  });
  test('account change discards a late balance', () async {
    String? token = 'account-a';
    final pending = Completer<http.Response>();
    final api = RewardsApi(
      baseUrl: 'https://fixture.example',
      tokenProvider: () async => token,
      client: MockClient((_) => pending.future),
    );
    final read = api.summary();
    await Future<void>.delayed(Duration.zero);
    token = 'account-b';
    pending.complete(http.Response(jsonEncode(summaryFixture()), 200));
    await expectLater(read, throwsA(code('stale_session')));
  });
  test(
      'explicit session cleanup protects A-B-A while bearer happens to be identical',
      () async {
    final pending = Completer<http.Response>();
    final api = RewardsApi(
      baseUrl: 'https://fixture.example',
      tokenProvider: () async => 'account-a',
      client: MockClient((_) => pending.future),
    );
    final read = api.summary();
    await Future<void>.delayed(Duration.zero);
    api.clearSession();
    pending.complete(http.Response(jsonEncode(summaryFixture()), 200));
    await expectLater(read, throwsA(code('stale_session')));
  });
  test('guest performs no balance read', () async {
    final api = RewardsApi(
      baseUrl: 'https://fixture.example',
      tokenProvider: () async => null,
      client: MockClient((_) async => throw StateError('must not request')),
    );
    await expectLater(api.summary(), throwsA(code('unauthenticated')));
  });
  test(
      'paged movement cursor is retained and supplied, never manufacturing a row',
      () async {
    var calls = 0;
    final api = RewardsApi(
      baseUrl: 'https://fixture.example',
      tokenProvider: () async => 'account-a',
      client: MockClient((request) async {
        expect(
          request.url.queryParameters['cursor'],
          calls == 0 ? null : 'next',
        );
        calls++;
        return http.Response(
          jsonEncode({
            'movements': [
              if (calls == 1)
                {
                  'id': 1,
                  'type': 'earn',
                  'state': 'pending',
                  'amountCents': 123,
                  'createdAt': '2026-11-11T00:00:00Z',
                },
            ],
            'nextCursor': calls == 1 ? 'next' : null,
          }),
          200,
        );
      }),
    );
    final page = await api.activity();
    expect(page.movements.single.amountCents, 123);
    final last = await api.activity(cursor: page.nextCursor);
    expect(last.movements, isEmpty);
    expect(last.nextCursor, isNull);
  });
  test(
      'malformed activity is failed rather than silently dropping private rows',
      () async {
    final api = RewardsApi(
      baseUrl: 'https://fixture.example',
      tokenProvider: () async => 'account-a',
      client: MockClient(
        (_) async => http.Response('{"movements":[null]}', 200),
      ),
    );
    await expectLater(api.activity(), throwsA(code('invalid_response')));
  });
}
