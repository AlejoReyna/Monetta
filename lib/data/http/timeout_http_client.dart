/// Shared transport that puts one deadline on a whole HTTP exchange.
library;

import 'dart:async';

import 'package:http/http.dart' as http;

/// Default deadline for first-party HTTP calls. It is the same 20 s that
/// Customer Account orders and the Storefront transport already use.
const Duration kDefaultHttpTimeout = Duration(seconds: 20);

/// Wraps another [http.Client] and fails the exchange with a
/// [TimeoutException] when [timeout] elapses.
///
/// One deadline covers the response headers and the response body, so a
/// server that sends its headers and then stalls cannot keep a caller waiting
/// forever. The deadline is a [Timer], which a simulated clock controls.
///
/// Nothing about the request (URL, headers, body) is put in the exception.
class TimeoutHttpClient extends http.BaseClient {
  TimeoutHttpClient(this._inner, {this.timeout = kDefaultHttpTimeout});

  final http.Client _inner;
  final Duration timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final expired = Completer<void>();
    final timer = Timer(timeout, () {
      if (!expired.isCompleted) expired.complete();
    });
    var abandoned = false;

    final sending = _inner.send(request);
    // A response that arrives after the deadline is never read: drop it so the
    // connection is released.
    unawaited(
      sending.then<void>(
        (arrived) {
          if (abandoned) arrived.stream.listen(null).cancel().ignore();
        },
        onError: (Object _, StackTrace __) {},
      ),
    );

    final http.StreamedResponse response;
    try {
      response = await Future.any<http.StreamedResponse>([
        sending,
        expired.future.then<http.StreamedResponse>((_) {
          abandoned = true;
          throw TimeoutException('HTTP request timed out', timeout);
        }),
      ]);
    } catch (_) {
      timer.cancel();
      rethrow;
    }

    return http.StreamedResponse(
      _bodyWithin(response.stream, expired.future, timer),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  /// Forwards [source] until it ends or [expired] completes; on expiry the
  /// stream fails with a [TimeoutException] and the source is cancelled.
  Stream<List<int>> _bodyWithin(
    Stream<List<int>> source,
    Future<void> expired,
    Timer timer,
  ) {
    late final StreamController<List<int>> controller;
    StreamSubscription<List<int>>? subscription;
    var finished = false;

    void finish() {
      finished = true;
      timer.cancel();
    }

    void releaseSource() {
      final active = subscription;
      subscription = null;
      unawaited(active?.cancel());
    }

    controller = StreamController<List<int>>(
      onListen: () {
        subscription = source.listen(
          controller.add,
          onError: controller.addError,
          onDone: () {
            finish();
            unawaited(controller.close());
          },
        );
        unawaited(
          expired.then<void>((_) {
            if (finished) return;
            finish();
            releaseSource();
            controller.addError(
              TimeoutException('HTTP response timed out', timeout),
            );
            unawaited(controller.close());
          }),
        );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () {
        finish();
        // Not returned: a listener that cancels on error would wait for the
        // source to confirm its cancellation before seeing the error.
        releaseSource();
      },
    );
    return controller.stream;
  }

  @override
  void close() => _inner.close();
}
