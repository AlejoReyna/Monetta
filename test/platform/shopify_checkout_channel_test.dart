import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/shopify/cart/checkout_launcher.dart';
import 'package:monetta_app/platform/shopify_checkout_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(MethodChannelCheckoutLauncher.channelName);
  final policy = CheckoutUrlPolicy(
    allowedHosts: const ['checkout.invalid'],
  );
  final checkoutUrl = policy.validate(
    Uri(
      scheme: 'https',
      host: 'checkout.invalid',
      path: '/opaque',
      queryParameters: const {'key': 'redacted-fixture'},
    ).toString(),
  );

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('maps only the three terminal lifecycle outcomes', () async {
    final responses = <Map<String, String>>[
      {'status': 'completed'},
      {'status': 'cancelled'},
      {'status': 'failed', 'code': 'cart_expired'},
    ];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => responses.removeAt(0));
    final launcher = MethodChannelCheckoutLauncher(channel: channel);

    expect(await launcher.present(checkoutUrl), isA<CheckoutCompleted>());
    expect(await launcher.present(checkoutUrl), isA<CheckoutCancelled>());
    final failed = await launcher.present(checkoutUrl) as CheckoutFailed;
    expect(failed.code, CheckoutFailureCode.cartExpired);
    expect(failed.userMessage, isNot(contains('redacted-fixture')));
  });

  test('serializes presentation and invokes native present once', () async {
    final terminal = Completer<Map<String, String>>();
    var nativeCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
      if (call.method == 'present') {
        nativeCalls += 1;
        return terminal.future;
      }
      return null;
    });
    final launcher = MethodChannelCheckoutLauncher(channel: channel);

    final first = launcher.present(checkoutUrl);
    await Future<void>.delayed(Duration.zero);
    final duplicate = await launcher.present(checkoutUrl) as CheckoutFailed;
    terminal.complete({'status': 'cancelled'});

    expect(await first, isA<CheckoutCancelled>());
    expect(duplicate.code, CheckoutFailureCode.unavailable);
    expect(nativeCalls, 1);
  });

  test('preload and invalidate expose no lifecycle or payload details',
      () async {
    final methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      return null;
    });
    final launcher = MethodChannelCheckoutLauncher(channel: channel);

    await launcher.preload(checkoutUrl);
    await launcher.invalidate();

    expect(methods, ['preload', 'invalidate']);
  });

  test('native errors are replaced with closed safe messages', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) {
      throw PlatformException(
        code: 'native',
        message: 'redacted-fixture',
      );
    });
    final launcher = MethodChannelCheckoutLauncher(channel: channel);

    final result = await launcher.present(checkoutUrl) as CheckoutFailed;

    expect(result.code, CheckoutFailureCode.unavailable);
    expect(result.userMessage, isNot(contains('redacted-fixture')));
  });

  test('a native lifecycle error releases the in-flight presentation guard',
      () async {
    var presentCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'present') return null;
      presentCalls += 1;
      if (presentCalls == 1) {
        throw PlatformException(code: 'native_lifecycle');
      }
      return <String, String>{'status': 'cancelled'};
    });
    final launcher = MethodChannelCheckoutLauncher(channel: channel);

    final first = await launcher.present(checkoutUrl) as CheckoutFailed;
    final retry = await launcher.present(checkoutUrl);

    expect(first.code, CheckoutFailureCode.unavailable);
    expect(retry, isA<CheckoutCancelled>());
    expect(presentCalls, 2);
  });

  test('missing native bridge is a safe configuration failure', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) {
      throw MissingPluginException();
    });
    final launcher = MethodChannelCheckoutLauncher(channel: channel);

    expect(
      await launcher.present(checkoutUrl),
      isA<CheckoutFailed>().having(
        (failure) => failure.code,
        'code',
        CheckoutFailureCode.configuration,
      ),
    );
    expect(
      launcher.preload(checkoutUrl),
      throwsA(isA<CheckoutBridgeException>()),
    );
  });

  test('unknown native status and code never cross as public details',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (_) async => <String, String>{
        'status': 'failed',
        'code': 'sensitive-fixture',
      },
    );
    final launcher = MethodChannelCheckoutLauncher(channel: channel);

    final result = await launcher.present(checkoutUrl) as CheckoutFailed;

    expect(result.code, CheckoutFailureCode.unknown);
    expect(result.userMessage, isNot(contains('sensitive-fixture')));
  });
}
