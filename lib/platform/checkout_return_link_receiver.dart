// Native-to-Flutter receiver for offsite-payment return links (Fase 5).
//
// iOS forwards Universal Links (`continue userActivity`) and Android forwards
// App Link intents (`onCreate`/`onNewIntent`) over the shared checkout
// channel as `onReturnLink`. Cold starts (app killed) are covered by an
// explicit `drainReturnLink` pull right after attach: native keeps the link
// pending until either the push or the drain delivers it, so each return
// link is routed exactly once.
library;

import 'package:flutter/services.dart';

import '../app/checkout_return_router.dart';
import 'shopify_checkout_channel.dart';

final class CheckoutReturnLinkReceiver {
  CheckoutReturnLinkReceiver({
    required CheckoutReturnRouter router,
    MethodChannel? channel,
  })  : _router = router,
        _channel =
            channel ?? const MethodChannel(MethodChannelCheckoutLauncher.channelName);

  final CheckoutReturnRouter _router;
  final MethodChannel _channel;
  bool _attached = false;

  /// Starts listening for pushes and drains any cold-start pending link.
  Future<void> attach() async {
    _attached = true;
    _channel.setMethodCallHandler(_onCall);
    await drainPending();
  }

  Future<void> _onCall(MethodCall call) async {
    if (!_attached) return;
    if (call.method != 'onReturnLink') return;
    final arguments = call.arguments;
    final url = arguments is Map ? arguments['url'] : null;
    if (url is String && url.isNotEmpty) {
      await _router.handle(url);
    }
  }

  /// Pulls a link the OS delivered before Dart was listening. Safe to call
  /// any time; a missing bridge or no pending link resolves silently.
  Future<void> drainPending() async {
    try {
      final raw = await _channel.invokeMethod<Object?>('drainReturnLink');
      final url = raw is Map ? raw['url'] : null;
      if (url is String && url.isNotEmpty) {
        await _router.handle(url);
      }
    } on PlatformException {
      // No bridge or no pending link: nothing to resume.
    } on MissingPluginException {
      // Tests / builds without the native bridge.
    }
  }

  void detach() {
    _attached = false;
    _channel.setMethodCallHandler(null);
  }
}
