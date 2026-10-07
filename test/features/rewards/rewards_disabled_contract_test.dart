import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/features/rewards/rewards_account.dart';
import 'package:monetta_app/features/rewards/rewards_api.dart';
import 'package:monetta_app/features/rewards/rewards_balance_card.dart';
import 'package:monetta_app/features/rewards/rewards_models.dart';
import 'package:monetta_app/features/rewards/rewards_section.dart';

// CONTRACT-02: the same fixture is read by
// services/accounts_orders/test/rewardsDisabledContract.test.ts.
final String _fixtureSource =
    File('test/fixtures/contracts/rewards_disabled.json').readAsStringSync();
final Map<String, dynamic> _fixture =
    jsonDecode(_fixtureSource) as Map<String, dynamic>;
final Map<String, dynamic> _disabled =
    _fixture['disabled'] as Map<String, dynamic>;
final String _legacyHtml404 = _fixture['legacyHtml404'] as String;

const _unavailableText = 'Monetta Rewards aún no está disponible';

http.Response _disabledResponse() => http.Response(
      jsonEncode({'error': _disabled['error'], 'requestId': 'req_test'}),
      _disabled['status'] as int,
      headers: {'content-type': 'application/json'},
    );

http.Response _htmlResponse(int status, String body) => http.Response(
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

RewardsApi _networkDown() => _api(
      (_) async => throw http.ClientException('offline'),
    );

Widget _host(Widget child) => MaterialApp(
      theme: buildTheme(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

Future<void> _pumpSection(WidgetTester tester, RewardsApi api) async {
  await tester.pumpWidget(
    _host(RewardsSection(controller: null, reader: ApiRewardsReader(api))),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpCard(WidgetTester tester, RewardsApi api) async {
  await tester.pumpWidget(
    _host(
      RewardsBalanceCard(accountId: '77', service: ApiRewardsService(api)),
    ),
  );
  await tester.pumpAndSettle();
}

Matcher _apiErrorCode(String code) => isA<RewardsApiError>().having(
      (e) => e.code,
      'code',
      code,
    );

void main() {
  group('CONTRACT-02 RewardsApi classification', () {
    test('CONTRACT-02 disabled JSON 404 keeps feature_disabled', () async {
      final api = _api((_) async => _disabledResponse());
      await expectLater(
        api.summary(),
        throwsA(_apiErrorCode(_disabled['error'] as String)),
      );
    });

    test('CONTRACT-02 legacy HTML 404 maps to not_found', () async {
      final api = _api((_) async => _htmlResponse(404, _legacyHtml404));
      await expectLater(api.summary(), throwsA(_apiErrorCode('not_found')));
    });

    test('CONTRACT-02 503 without JSON maps to service_unavailable', () async {
      final api = _api((_) async => _htmlResponse(503, 'Service Unavailable'));
      await expectLater(
        api.summary(),
        throwsA(_apiErrorCode('service_unavailable')),
      );
    });

    test('CONTRACT-02 401 without JSON maps to unauthorized', () async {
      final api = _api((_) async => _htmlResponse(401, 'Unauthorized'));
      await expectLater(api.summary(), throwsA(_apiErrorCode('unauthorized')));
    });

    test('CONTRACT-02 transport failure maps to network', () async {
      await expectLater(
        _networkDown().summary(),
        throwsA(_apiErrorCode('network')),
      );
    });
  });

  group('CONTRACT-02 RewardsSection states', () {
    testWidgets('CONTRACT-02 disabled shows unavailable, never connection',
        (tester) async {
      await _pumpSection(tester, _api((_) async => _disabledResponse()));

      expect(find.textContaining('Revisa tu conexión'), findsNothing);
      expect(find.textContaining('No pudimos consultar'), findsNothing);
      expect(find.text(_unavailableText), findsOneWidget);
    });

    testWidgets('CONTRACT-02 legacy HTML 404 shows unavailable',
        (tester) async {
      await _pumpSection(
        tester,
        _api((_) async => _htmlResponse(404, _legacyHtml404)),
      );

      expect(find.textContaining('Revisa tu conexión'), findsNothing);
      expect(find.textContaining('No pudimos consultar'), findsNothing);
      expect(find.text(_unavailableText), findsOneWidget);
    });

    testWidgets('CONTRACT-02 offline shows the connection message',
        (tester) async {
      await _pumpSection(tester, _networkDown());

      expect(find.textContaining('Revisa tu conexión'), findsWidgets);
    });

    testWidgets('CONTRACT-02 503 shows service down, not connection',
        (tester) async {
      await _pumpSection(
        tester,
        _api((_) async => _htmlResponse(503, 'Service Unavailable')),
      );

      expect(find.textContaining('Revisa tu conexión'), findsNothing);
      expect(find.textContaining('no responde en este momento'), findsWidgets);
    });

    testWidgets('CONTRACT-02 401 without JSON shows session ended',
        (tester) async {
      await _pumpSection(
        tester,
        _api((_) async => _htmlResponse(401, 'Unauthorized')),
      );

      expect(find.text('Tu sesión terminó'), findsOneWidget);
    });
  });

  group('CONTRACT-02 RewardsBalanceCard states', () {
    testWidgets('CONTRACT-02 disabled shows unavailable, never connection',
        (tester) async {
      await _pumpCard(tester, _api((_) async => _disabledResponse()));

      expect(find.textContaining('Revisa tu conexión'), findsNothing);
      expect(find.text(_unavailableText), findsOneWidget);
    });

    testWidgets('CONTRACT-02 offline shows the connection message',
        (tester) async {
      await _pumpCard(tester, _networkDown());

      expect(find.textContaining('Revisa tu conexión'), findsWidgets);
    });

    testWidgets('CONTRACT-02 503 shows service down, not connection',
        (tester) async {
      await _pumpCard(
        tester,
        _api((_) async => _htmlResponse(503, 'Service Unavailable')),
      );

      expect(find.textContaining('Revisa tu conexión'), findsNothing);
      expect(find.textContaining('no responde en este momento'), findsWidgets);
    });

    testWidgets('CONTRACT-02 401 without JSON shows session ended',
        (tester) async {
      await _pumpCard(
        tester,
        _api((_) async => _htmlResponse(401, 'Unauthorized')),
      );

      expect(find.textContaining('Tu sesión terminó'), findsWidgets);
    });
  });
}
