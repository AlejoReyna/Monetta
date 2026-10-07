import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/features/rewards/rewards_account.dart';
import 'package:monetta_app/features/rewards/rewards_api.dart';
import 'package:monetta_app/features/rewards/rewards_balance_card.dart';
import 'package:monetta_app/features/rewards/rewards_error_kind.dart';
import 'package:monetta_app/features/rewards/rewards_models.dart';
import 'package:monetta_app/features/rewards/rewards_section.dart';

// CONTRACT-03: the Rewards parsers reject missing or malformed required
// fields with a typed RewardsContractError instead of inventing values
// (DateTime.now(), 0 or the string "null"). The valid bodies below are the
// examples of docs/redesign/REWARDS_CONTRACT_V1.md section 3.

const String _summaryJson = '''
{
  "program": { "enabled": true, "redemptionEnabled": false, "currency": "MXN",
    "earnBps": 300, "maxRedeemBps": 2000, "expiryMonths": 12,
    "wholesaleEarns": false, "ruleVersion": 1 },
  "balance": { "availableCents": 18400, "pendingCents": 5400,
    "reservedCents": 0,
    "nextExpiry": { "cents": 5400, "at": "2027-03-02T12:00:00.000Z" },
    "asOf": "2026-09-14T08:00:00.000Z" },
  "incentives": {
    "firstPurchase": { "enabled": false, "amountCents": 5000 },
    "review": { "enabled": false, "amountCents": 2000 },
    "referral": { "enabled": false, "amountCents": 5000 }
  }
}
''';

const String _movementJson = '''
{ "id": 41, "type": "earn_released", "state": "available",
  "amountCents": 5400, "orderShopifyId": "8001",
  "reason": "delivered", "createdAt": "2026-09-10T09:30:00.000Z" }
''';

const String _quoteJson = '''
{ "quoteId": "7d0c3f0e-6f5b-4f6f-9d1c-2b6f8f3f9a11",
  "cartRevision": "cart_abc:7",
  "subtotalEligibleCents": 90000, "availableCents": 18400,
  "maxAllowedCents": 18000, "estimatedEarnCents": 2160,
  "isWholesaleCart": false, "redemptionEnabled": false,
  "expiresAt": "2026-09-14T08:10:00.000Z" }
''';

const String _orderJson = '''
{ "orderShopifyId": "8001", "isWholesale": false,
  "earnedPendingCents": 5400, "earnedReleasedCents": 0,
  "earnedReversedCents": 0, "usedCents": 0, "state": "pending" }
''';

Map<String, dynamic> _decode(String source) =>
    jsonDecode(source) as Map<String, dynamic>;

/// Returns a deep copy of [source] after [mutate] ran on it.
Map<String, dynamic> _mutated(
  String source,
  void Function(Map<String, dynamic> json) mutate,
) {
  final json = _decode(source);
  mutate(json);
  return json;
}

Map<String, dynamic> _map(Map<String, dynamic> json, String key) =>
    json[key] as Map<String, dynamic>;

Matcher _contractError(String field) => isA<RewardsContractError>()
    .having((e) => e.code, 'code', 'invalid_response')
    .having((e) => e.field, 'field', field);

class _Case {
  const _Case(this.name, this.field, this.mutate);

  final String name;
  final String field;
  final void Function(Map<String, dynamic> json) mutate;
}

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

http.Response _html(String body, [int status = 200]) => http.Response(
      body,
      status,
      headers: {'content-type': 'text/html; charset=utf-8'},
    );

RewardsApi _api(Future<http.Response> Function(http.Request) handler) =>
    RewardsApi(
      baseUrl: 'https://rewards.test',
      tokenProvider: () async => 'tok-77',
      client: MockClient(handler),
    );

Widget _host(Widget child) => MaterialApp(
      theme: buildTheme(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

final List<_Case> _summaryCases = [
  _Case('balance missing', 'balance', (j) => j.remove('balance')),
  _Case('balance null', 'balance', (j) => j['balance'] = null),
  _Case('balance is a list', 'balance', (j) => j['balance'] = <Object>[]),
  _Case(
    'availableCents missing',
    'balance.availableCents',
    (j) => _map(j, 'balance').remove('availableCents'),
  ),
  _Case(
    'availableCents null',
    'balance.availableCents',
    (j) => _map(j, 'balance')['availableCents'] = null,
  ),
  _Case(
    'availableCents is a string',
    'balance.availableCents',
    (j) => _map(j, 'balance')['availableCents'] = '18400',
  ),
  _Case(
    'availableCents is not an integer',
    'balance.availableCents',
    (j) => _map(j, 'balance')['availableCents'] = 18400.5,
  ),
  _Case(
    'pendingCents missing',
    'balance.pendingCents',
    (j) => _map(j, 'balance').remove('pendingCents'),
  ),
  _Case(
    'pendingCents is a bool',
    'balance.pendingCents',
    (j) => _map(j, 'balance')['pendingCents'] = true,
  ),
  _Case(
    'reservedCents missing',
    'balance.reservedCents',
    (j) => _map(j, 'balance').remove('reservedCents'),
  ),
  _Case(
    'reservedCents null',
    'balance.reservedCents',
    (j) => _map(j, 'balance')['reservedCents'] = null,
  ),
  _Case(
    'asOf missing',
    'balance.asOf',
    (j) => _map(j, 'balance').remove('asOf'),
  ),
  _Case(
    'asOf null',
    'balance.asOf',
    (j) => _map(j, 'balance')['asOf'] = null,
  ),
  _Case(
    'asOf not a date',
    'balance.asOf',
    (j) => _map(j, 'balance')['asOf'] = 'not-a-date',
  ),
  _Case(
    'asOf is a number',
    'balance.asOf',
    (j) => _map(j, 'balance')['asOf'] = 20260914,
  ),
  _Case(
    'nextExpiry is not an object',
    'balance.nextExpiry',
    (j) => _map(j, 'balance')['nextExpiry'] = 'soon',
  ),
  _Case(
    'nextExpiry.at missing',
    'balance.nextExpiry.at',
    (j) => _map(_map(j, 'balance'), 'nextExpiry').remove('at'),
  ),
  _Case(
    'nextExpiry.at not a date',
    'balance.nextExpiry.at',
    (j) => _map(_map(j, 'balance'), 'nextExpiry')['at'] = 'not-a-date',
  ),
  _Case(
    'nextExpiry.cents missing',
    'balance.nextExpiry.cents',
    (j) => _map(_map(j, 'balance'), 'nextExpiry').remove('cents'),
  ),
];

final List<_Case> _movementCases = [
  _Case('id missing', 'id', (j) => j.remove('id')),
  _Case('id null', 'id', (j) => j['id'] = null),
  _Case('id is a string', 'id', (j) => j['id'] = '41'),
  _Case('amountCents missing', 'amountCents', (j) => j.remove('amountCents')),
  _Case(
    'amountCents is a string',
    'amountCents',
    (j) => j['amountCents'] = '1',
  ),
  _Case('createdAt missing', 'createdAt', (j) => j.remove('createdAt')),
  _Case('createdAt null', 'createdAt', (j) => j['createdAt'] = null),
  _Case(
    'createdAt not a date',
    'createdAt',
    (j) => j['createdAt'] = 'not-a-date',
  ),
  _Case(
    'orderShopifyId is a number',
    'orderShopifyId',
    (j) => j['orderShopifyId'] = 8001,
  ),
  _Case('reason is a number', 'reason', (j) => j['reason'] = 7),
];

final List<_Case> _quoteCases = [
  _Case('quoteId missing', 'quoteId', (j) => j.remove('quoteId')),
  _Case('quoteId null', 'quoteId', (j) => j['quoteId'] = null),
  _Case('quoteId empty', 'quoteId', (j) => j['quoteId'] = ''),
  _Case(
    'cartRevision missing',
    'cartRevision',
    (j) => j.remove('cartRevision'),
  ),
  _Case('cartRevision null', 'cartRevision', (j) => j['cartRevision'] = null),
  _Case(
    'subtotalEligibleCents missing',
    'subtotalEligibleCents',
    (j) => j.remove('subtotalEligibleCents'),
  ),
  _Case(
    'availableCents missing',
    'availableCents',
    (j) => j.remove('availableCents'),
  ),
  _Case(
    'maxAllowedCents missing',
    'maxAllowedCents',
    (j) => j.remove('maxAllowedCents'),
  ),
  _Case(
    'maxAllowedCents is a string',
    'maxAllowedCents',
    (j) => j['maxAllowedCents'] = '18000',
  ),
  _Case(
    'estimatedEarnCents missing',
    'estimatedEarnCents',
    (j) => j.remove('estimatedEarnCents'),
  ),
  _Case('expiresAt missing', 'expiresAt', (j) => j.remove('expiresAt')),
  _Case('expiresAt null', 'expiresAt', (j) => j['expiresAt'] = null),
  _Case(
    'expiresAt not a date',
    'expiresAt',
    (j) => j['expiresAt'] = 'not-a-date',
  ),
];

final List<_Case> _orderCases = [
  _Case(
    'orderShopifyId missing',
    'orderShopifyId',
    (j) => j.remove('orderShopifyId'),
  ),
  _Case(
    'orderShopifyId null',
    'orderShopifyId',
    (j) => j['orderShopifyId'] = null,
  ),
  _Case(
    'orderShopifyId empty',
    'orderShopifyId',
    (j) => j['orderShopifyId'] = '',
  ),
  _Case(
    'orderShopifyId is a number',
    'orderShopifyId',
    (j) => j['orderShopifyId'] = 8001,
  ),
  _Case(
    'earnedPendingCents missing',
    'earnedPendingCents',
    (j) => j.remove('earnedPendingCents'),
  ),
  _Case(
    'earnedReleasedCents missing',
    'earnedReleasedCents',
    (j) => j.remove('earnedReleasedCents'),
  ),
  _Case('usedCents missing', 'usedCents', (j) => j.remove('usedCents')),
  _Case('usedCents is a string', 'usedCents', (j) => j['usedCents'] = '0'),
];

void main() {
  group('CONTRACT-03 RewardsContractError', () {
    test('CONTRACT-03 is a RewardsApiError with code invalid_response', () {
      const error = RewardsContractError('balance.asOf');
      expect(error, isA<RewardsApiError>());
      expect(error.code, 'invalid_response');
      expect(error.field, 'balance.asOf');
    });

    test('CONTRACT-03 friendly message is recoverable, not a generic failure',
        () {
      expect(
        RewardsApiError.friendly('invalid_response'),
        'Recibimos una respuesta inesperada de Monetta Rewards. '
        'Inténtalo de nuevo.',
      );
    });

    test('CONTRACT-03 classifier maps it to serviceDown, never network', () {
      expect(
        classifyRewardsError(const RewardsContractError('quoteId')),
        RewardsErrorKind.serviceDown,
      );
      expect(
        classifyRewardsError(const RewardsException('invalid_response')),
        RewardsErrorKind.serviceDown,
      );
    });
  });

  group('CONTRACT-03 valid contract bodies keep parsing', () {
    test('CONTRACT-03 summary example', () {
      final summary = RewardsSummary.fromJson(_decode(_summaryJson));
      expect(summary.availableCents, 18400);
      expect(summary.pendingCents, 5400);
      expect(summary.reservedCents, 0);
      expect(summary.redemptionEnabled, isFalse);
      expect(summary.asOf, DateTime.utc(2026, 9, 14, 8));
      expect(summary.nextExpiry?.cents, 5400);
      expect(summary.nextExpiry?.at, DateTime.utc(2027, 3, 2, 12));
      expect(summary.firstPurchaseEnabled, isFalse);
      expect(summary.reviewEnabled, isFalse);
      expect(summary.referralEnabled, isFalse);
    });

    test('CONTRACT-03 summary with nextExpiry null is valid', () {
      final summary = RewardsSummary.fromJson(
        _mutated(_summaryJson, (j) => _map(j, 'balance')['nextExpiry'] = null),
      );
      expect(summary.nextExpiry, isNull);
      expect(summary.availableCents, 18400);
    });

    test('CONTRACT-03 summary with nextExpiry absent is valid', () {
      final summary = RewardsSummary.fromJson(
        _mutated(_summaryJson, (j) => _map(j, 'balance').remove('nextExpiry')),
      );
      expect(summary.nextExpiry, isNull);
    });

    test('CONTRACT-03 movement example', () {
      final movement = RewardsMovement.fromJson(_decode(_movementJson));
      expect(movement.id, 41);
      expect(movement.type, 'earn_released');
      expect(movement.state, 'available');
      expect(movement.amountCents, 5400);
      expect(movement.orderShopifyId, '8001');
      expect(movement.reason, 'delivered');
      expect(movement.createdAt, DateTime.utc(2026, 9, 10, 9, 30));
    });

    test('CONTRACT-03 movement with null orderShopifyId and reason is valid',
        () {
      final movement = RewardsMovement.fromJson(
        _mutated(_movementJson, (j) {
          j['orderShopifyId'] = null;
          j['reason'] = null;
        }),
      );
      expect(movement.orderShopifyId, isNull);
      expect(movement.reason, isNull);
      expect(movement.amountCents, 5400);
    });

    test('CONTRACT-03 quote example', () {
      final quote = RewardsQuote.fromJson(_decode(_quoteJson));
      expect(quote.quoteId, '7d0c3f0e-6f5b-4f6f-9d1c-2b6f8f3f9a11');
      expect(quote.cartRevision, 'cart_abc:7');
      expect(quote.subtotalEligibleCents, 90000);
      expect(quote.availableCents, 18400);
      expect(quote.maxAllowedCents, 18000);
      expect(quote.estimatedEarnCents, 2160);
      expect(quote.redemptionEnabled, isFalse);
      expect(quote.expiresAt, DateTime.utc(2026, 9, 14, 8, 10));
    });

    test('CONTRACT-03 order rewards example', () {
      final state = OrderRewardsState.fromJson(_decode(_orderJson));
      expect(state.orderShopifyId, '8001');
      expect(state.isWholesale, isFalse);
      expect(state.earnedPendingCents, 5400);
      expect(state.earnedReleasedCents, 0);
      expect(state.usedCents, 0);
      expect(state.state, 'pending');
    });
  });

  group('CONTRACT-03 RewardsSummary rejects invalid bodies', () {
    for (final c in _summaryCases) {
      test('CONTRACT-03 summary: ${c.name} -> ${c.field}', () {
        final json = _mutated(_summaryJson, c.mutate);
        expect(
          () => RewardsSummary.fromJson(json),
          throwsA(_contractError(c.field)),
        );
      });
    }
  });

  group('CONTRACT-03 RewardsMovement rejects invalid bodies', () {
    for (final c in _movementCases) {
      test('CONTRACT-03 movement: ${c.name} -> ${c.field}', () {
        final json = _mutated(_movementJson, c.mutate);
        expect(
          () => RewardsMovement.fromJson(json),
          throwsA(_contractError(c.field)),
        );
      });
    }
  });

  group('CONTRACT-03 RewardsQuote rejects invalid bodies', () {
    for (final c in _quoteCases) {
      test('CONTRACT-03 quote: ${c.name} -> ${c.field}', () {
        final json = _mutated(_quoteJson, c.mutate);
        expect(
          () => RewardsQuote.fromJson(json),
          throwsA(_contractError(c.field)),
        );
      });
    }
  });

  group('CONTRACT-03 OrderRewardsState rejects invalid bodies', () {
    for (final c in _orderCases) {
      test('CONTRACT-03 order rewards: ${c.name} -> ${c.field}', () {
        final json = _mutated(_orderJson, c.mutate);
        expect(
          () => OrderRewardsState.fromJson(json),
          throwsA(_contractError(c.field)),
        );
      });
    }
  });

  group('CONTRACT-03 RewardsApi wraps invalid responses', () {
    test('CONTRACT-03 summary 200 with valid example parses', () async {
      final api = _api((_) async => http.Response(_summaryJson, 200));
      final summary = await api.summary();
      expect(summary.availableCents, 18400);
      expect(summary.asOf, DateTime.utc(2026, 9, 14, 8));
    });

    test('CONTRACT-03 summary 200 with HTML body', () async {
      final api = _api((_) async => _html('<html>'));
      await expectLater(api.summary(), throwsA(isA<RewardsContractError>()));
    });

    test('CONTRACT-03 summary 200 with a JSON list', () async {
      final api = _api((_) async => _json(<Object>[]));
      await expectLater(api.summary(), throwsA(isA<RewardsContractError>()));
    });

    test('CONTRACT-03 summary 200 without asOf names the field', () async {
      final api = _api(
        (_) async => _json(
          _mutated(_summaryJson, (j) => _map(j, 'balance').remove('asOf')),
        ),
      );
      await expectLater(api.summary(), throwsA(_contractError('balance.asOf')));
    });

    test('CONTRACT-03 activity 200 with HTML body', () async {
      final api = _api((_) async => _html('<html>'));
      await expectLater(api.activity(), throwsA(isA<RewardsContractError>()));
    });

    test('CONTRACT-03 activity 200 with a JSON list', () async {
      final api = _api((_) async => _json(<Object>[]));
      await expectLater(api.activity(), throwsA(isA<RewardsContractError>()));
    });

    test('CONTRACT-03 activity 200 with movements not a list', () async {
      final api = _api((_) async => _json({'movements': 'none'}));
      await expectLater(api.activity(), throwsA(isA<RewardsContractError>()));
    });

    test('CONTRACT-03 activity 200 with a non-object movement is rejected',
        () async {
      final api = _api(
        (_) async => _json({
          'movements': [_decode(_movementJson), 'oops'],
          'nextCursor': null,
        }),
      );
      await expectLater(api.activity(), throwsA(isA<RewardsContractError>()));
    });

    test('CONTRACT-03 activity 200 with an invalid movement is not dropped',
        () async {
      final api = _api(
        (_) async => _json({
          'movements': [
            _decode(_movementJson),
            _mutated(_movementJson, (j) => j['createdAt'] = 'not-a-date'),
          ],
          'nextCursor': null,
        }),
      );
      await expectLater(
        api.activity(),
        throwsA(_contractError('movements[1].createdAt')),
      );
    });

    test('CONTRACT-03 activity 200 with valid movements parses', () async {
      final api = _api(
        (_) async => _json({
          'movements': [
            _decode(_movementJson),
            _mutated(_movementJson, (j) {
              j['id'] = 40;
              j['orderShopifyId'] = null;
              j['reason'] = null;
            }),
          ],
          'nextCursor': '40',
        }),
      );
      final page = await api.activity();
      expect(page.movements.map((m) => m.id), [41, 40]);
      expect(page.movements.last.orderShopifyId, isNull);
      expect(page.nextCursor, '40');
    });

    test('CONTRACT-03 orderRewards 200 with HTML body', () async {
      final api = _api((_) async => _html('<html>'));
      await expectLater(
        api.orderRewards('8001'),
        throwsA(isA<RewardsContractError>()),
      );
    });

    test('CONTRACT-03 orderRewards 200 without orderShopifyId', () async {
      final api = _api(
        (_) async => _json(
          _mutated(_orderJson, (j) => j.remove('orderShopifyId')),
        ),
      );
      await expectLater(
        api.orderRewards('8001'),
        throwsA(_contractError('orderShopifyId')),
      );
    });

    test('CONTRACT-03 quote 201 with HTML body', () async {
      final api = _api((_) async => _html('<html>', 201));
      await expectLater(
        api.quote(cartRevision: 'cart_abc:7', lines: const []),
        throwsA(isA<RewardsContractError>()),
      );
    });

    test('CONTRACT-03 quote 201 without quoteId is not the string "null"',
        () async {
      final api = _api(
        (_) async => _json(
          _mutated(_quoteJson, (j) => j.remove('quoteId')),
          201,
        ),
      );
      await expectLater(
        api.quote(cartRevision: 'cart_abc:7', lines: const []),
        throwsA(_contractError('quoteId')),
      );
    });

    test('CONTRACT-03 quote 201 without expiresAt', () async {
      final api = _api(
        (_) async => _json(
          _mutated(_quoteJson, (j) => j.remove('expiresAt')),
          201,
        ),
      );
      await expectLater(
        api.quote(cartRevision: 'cart_abc:7', lines: const []),
        throwsA(_contractError('expiresAt')),
      );
    });

    test('CONTRACT-03 quote 201 with valid example parses', () async {
      final api = _api((_) async => http.Response(_quoteJson, 201));
      final quote = await api.quote(
        cartRevision: 'cart_abc:7',
        lines: const [],
      );
      expect(quote.quoteId, '7d0c3f0e-6f5b-4f6f-9d1c-2b6f8f3f9a11');
      expect(quote.maxAllowedCents, 18000);
    });

    test('CONTRACT-03 error statuses keep their classification', () async {
      final api = _api((_) async => _html('Service Unavailable', 503));
      await expectLater(
        api.summary(),
        throwsA(
          isA<RewardsApiError>()
              .having((e) => e.code, 'code', 'service_unavailable'),
        ),
      );
    });
  });

  group('CONTRACT-03 ApiRewardsService converts contract errors', () {
    test('CONTRACT-03 balance with HTML 200 throws invalid_response', () async {
      final service = ApiRewardsService(_api((_) async => _html('<html>')));
      await expectLater(
        service.balance(accountId: '77'),
        throwsA(
          isA<RewardsException>()
              .having((e) => e.code, 'code', 'invalid_response'),
        ),
      );
    });

    test('CONTRACT-03 balance without asOf throws invalid_response', () async {
      final service = ApiRewardsService(
        _api(
          (_) async => _json(
            _mutated(_summaryJson, (j) => _map(j, 'balance').remove('asOf')),
          ),
        ),
      );
      await expectLater(
        service.balance(accountId: '77'),
        throwsA(
          isA<RewardsException>()
              .having((e) => e.code, 'code', 'invalid_response'),
        ),
      );
    });

    test('CONTRACT-03 balance with valid example returns the amounts',
        () async {
      final service = ApiRewardsService(
        _api((_) async => http.Response(_summaryJson, 200)),
      );
      final balance = await service.balance(accountId: '77');
      expect(balance.availableCents, 18400);
      expect(balance.asOf, DateTime.utc(2026, 9, 14, 8));
    });

    test('CONTRACT-03 forOrder with invalid body throws invalid_response',
        () async {
      final service = ApiRewardsService(
        _api(
          (_) async => _json(
            _mutated(_orderJson, (j) => j.remove('orderShopifyId')),
          ),
        ),
      );
      await expectLater(
        service.forOrder(accountId: '77', orderId: '8001'),
        throwsA(
          isA<RewardsException>()
              .having((e) => e.code, 'code', 'invalid_response'),
        ),
      );
    });
  });

  group('CONTRACT-03 UI shows a recoverable state', () {
    final invalidBodies =
        <String, Future<http.Response> Function(http.Request)>{
      'HTML 200': (_) async => _html('<html>'),
      'summary without asOf': (_) async => _json(
            _mutated(_summaryJson, (j) => _map(j, 'balance').remove('asOf')),
          ),
    };

    for (final entry in invalidBodies.entries) {
      testWidgets(
        'CONTRACT-03 RewardsSection with ${entry.key} is service down, '
        'not connection',
        (tester) async {
          await tester.pumpWidget(
            _host(
              RewardsSection(
                controller: null,
                reader: ApiRewardsReader(_api(entry.value)),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.textContaining('Revisa tu conexión'), findsNothing);
          expect(
            find.textContaining('no responde en este momento'),
            findsWidgets,
          );
          expect(
            find.byKey(const ValueKey('rewards-balance-card')),
            findsNothing,
          );
        },
      );

      testWidgets(
        'CONTRACT-03 RewardsBalanceCard with ${entry.key} is service down, '
        'not connection',
        (tester) async {
          await tester.pumpWidget(
            _host(
              RewardsBalanceCard(
                accountId: '77',
                service: ApiRewardsService(_api(entry.value)),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.textContaining('Revisa tu conexión'), findsNothing);
          expect(
            find.textContaining('no responde en este momento'),
            findsWidgets,
          );
        },
      );
    }

    testWidgets(
        'CONTRACT-03 RewardsSection with the valid example shows '
        'the balance', (tester) async {
      await tester.pumpWidget(
        _host(
          RewardsSection(
            controller: null,
            reader: ApiRewardsReader(
              _api((_) async => http.Response(_summaryJson, 200)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('rewards-balance-card')),
        findsOneWidget,
      );
      expect(find.textContaining('Revisa tu conexión'), findsNothing);
    });
  });
}
