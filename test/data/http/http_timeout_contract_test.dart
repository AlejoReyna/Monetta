/// CONTRACT-05 (objective state, red until RF-14): every first-party HTTP
/// client gives up on a call that never answers after 20 s and fails with its
/// own typed error, instead of leaving the caller waiting forever.
///
/// Each test hangs the transport, advances the simulated clock (no real
/// time), and reads the outcome of the call from a captured future: a call
/// that never ends must fail the assertion, not hang the test.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monetta_app/data/accounts_orders/order_history_client.dart';
import 'package:monetta_app/data/accounts_orders/system_account_client.dart';
import 'package:monetta_app/data/admin/admin_client.dart';
import 'package:monetta_app/data/notifications/admin_notification_client.dart';
import 'package:monetta_app/data/notifications/notification_api_client.dart';
import 'package:monetta_app/data/notifications/notification_models.dart';
import 'package:monetta_app/data/reviews/loox_reviews_repository.dart';
import 'package:monetta_app/features/rewards/rewards_api.dart';
import 'package:monetta_app/features/rewards/rewards_models.dart';

const _beforeTimeout = Duration(seconds: 19);
const _pastTimeout = Duration(seconds: 2);

const _host = 'service.example';
final _baseUri = Uri.parse('https://$_host');
const _baseUrl = 'https://$_host';

/// The result of a call, captured without awaiting it.
class _Outcome<T> {
  _Outcome(Future<T> call) {
    call.then<void>(
      (value) {
        done = true;
        this.value = value;
      },
      onError: (Object error, StackTrace _) {
        done = true;
        this.error = error;
      },
    );
  }

  bool done = false;
  T? value;
  Object? error;
}

/// A transport that accepts the request and never answers.
MockClient _silentClient() =>
    MockClient((_) => Completer<http.Response>().future);

/// A server that sends 200 and its headers, then never finishes the body.
MockClient _hungBodyClient() {
  final body = StreamController<List<int>>();
  addTearDown(() => unawaited(body.close()));
  return MockClient.streaming(
    (request, _) async => http.StreamedResponse(
      body.stream,
      200,
      headers: const {'content-type': 'application/json'},
    ),
  );
}

/// Asserts the 20 s contract on [call]: still pending at 19 s, failed with a
/// [E] by 21 s. Returns the captured error for message checks.
Future<Object?> _expectTimeoutAt20s<E extends Object>(
  WidgetTester tester,
  Future<Object?> Function() call,
) async {
  final outcome = _Outcome<Object?>(call());
  await tester.pump(_beforeTimeout);
  expect(
    outcome.done,
    isFalse,
    reason: 'the call must still be pending at $_beforeTimeout',
  );
  await tester.pump(_pastTimeout);
  expect(
    outcome.error,
    isA<E>(),
    reason: 'after 21 s the call must have failed with its typed error '
        '(done: ${outcome.done}); no timeout is applied today',
  );
  return outcome.error;
}

void _expectShopperSafeMessage(Object error, String message) {
  for (final leak in ['TimeoutException', 'Future', _host]) {
    expect(
      message,
      isNot(contains(leak)),
      reason: 'the UI shows this message; it must not leak "$leak"',
    );
  }
  expect(error.toString(), isNot(contains('TimeoutException')));
}

void main() {
  testWidgets(
    'CONTRACT-05 NotificationApiClient times out after 20 s with '
    'NotificationException',
    (tester) async {
      final api = NotificationApiClient(
        baseUrl: _baseUri,
        appCheckTokenProvider: () async => 'app-check',
        client: _silentClient(),
      );
      final error = await _expectTimeoutAt20s<NotificationException>(
        tester,
        api.fetchConfig,
      );
      _expectShopperSafeMessage(
        error!,
        (error as NotificationException).message,
      );
    },
  );

  testWidgets(
    'CONTRACT-05 NotificationApiClient times out after 20 s when the server '
    'sends headers but the body never ends',
    (tester) async {
      final api = NotificationApiClient(
        baseUrl: _baseUri,
        appCheckTokenProvider: () async => 'app-check',
        client: _hungBodyClient(),
      );
      final error = await _expectTimeoutAt20s<NotificationException>(
        tester,
        api.fetchConfig,
      );
      _expectShopperSafeMessage(
        error!,
        (error as NotificationException).message,
      );
    },
  );

  testWidgets(
    'CONTRACT-05 AdminNotificationClient times out after 20 s with '
    'NotificationException',
    (tester) async {
      final api = AdminNotificationClient(
        baseUrl: _baseUri,
        accessTokenProvider: () async => 'owner-token',
        client: _silentClient(),
      );
      final error = await _expectTimeoutAt20s<NotificationException>(
        tester,
        api.overview,
      );
      _expectShopperSafeMessage(
        error!,
        (error as NotificationException).message,
      );
    },
  );

  testWidgets(
    'CONTRACT-05 HttpAdminClient times out after 20 s with '
    'AdminClientException',
    (tester) async {
      final api = HttpAdminClient(
        baseUrl: _baseUri,
        accessTokenProvider: () async => 'owner-token',
        client: _silentClient(),
      );
      await _expectTimeoutAt20s<AdminClientException>(tester, api.fetchMe);
    },
  );

  testWidgets(
    'CONTRACT-05 HttpOrderHistoryClient times out after 20 s with '
    'OrderHistoryException',
    (tester) async {
      final api = HttpOrderHistoryClient(
        baseUrl: _baseUrl,
        httpClient: _silentClient(),
      );
      await _expectTimeoutAt20s<OrderHistoryException>(
        tester,
        () => api.fetchOrders('access-token'),
      );
    },
  );

  testWidgets(
    'CONTRACT-05 HttpSystemAccountClient times out after 20 s with '
    'SystemAccountException',
    (tester) async {
      final api = HttpSystemAccountClient(
        baseUrl: _baseUrl,
        httpClient: _silentClient(),
      );
      await _expectTimeoutAt20s<SystemAccountException>(
        tester,
        () => api.login(
          email: 'shopper@example.com',
          password: 'correct horse',
          deviceId: 'device-1',
        ),
      );
    },
  );

  testWidgets(
    'CONTRACT-05 RewardsApi times out after 20 s with RewardsApiError(network)',
    (tester) async {
      final api = RewardsApi(
        baseUrl: _baseUrl,
        tokenProvider: () async => 'access-token',
        client: _silentClient(),
      );
      final error = await _expectTimeoutAt20s<RewardsApiError>(
        tester,
        api.summary,
      );
      expect((error! as RewardsApiError).code, 'network');
    },
  );

  testWidgets(
    'CONTRACT-05 LooxReviewsRepository times out after 20 s with '
    'http.ClientException',
    (tester) async {
      final repository = LooxReviewsRepository(
        config: const LooxConfig(publicStoreId: 'store-id'),
        get: (_) => Completer<http.Response>().future,
      );
      await _expectTimeoutAt20s<http.ClientException>(
        tester,
        repository.fetch,
      );
    },
  );

  testWidgets(
    'CONTRACT-05 HttpSystemAccountClient.register times out after 20 s with '
    'SystemAccountException',
    (tester) async {
      final api = HttpSystemAccountClient(
        baseUrl: _baseUrl,
        httpClient: _silentClient(),
      );
      await _expectTimeoutAt20s<SystemAccountException>(
        tester,
        () => api.register(
          email: 'shopper@example.com',
          password: 'correct horse',
          displayName: null,
          deviceId: 'device-1',
        ),
      );
    },
  );

  testWidgets(
    'CONTRACT-05 HttpSystemAccountClient.logout times out after 20 s with '
    'SystemAccountException',
    (tester) async {
      final api = HttpSystemAccountClient(
        baseUrl: _baseUrl,
        httpClient: _silentClient(),
      );
      await _expectTimeoutAt20s<SystemAccountException>(
        tester,
        () => api.logout('session-token'),
      );
    },
  );

  testWidgets(
    'CONTRACT-05 LooxReviewsRepository.fetchPage times out after 20 s with '
    'http.ClientException',
    (tester) async {
      final repository = LooxReviewsRepository(
        config: const LooxConfig(publicStoreId: 'store-id'),
        get: (_) => Completer<http.Response>().future,
      );
      await _expectTimeoutAt20s<http.ClientException>(
        tester,
        repository.fetchPage,
      );
    },
  );
}
