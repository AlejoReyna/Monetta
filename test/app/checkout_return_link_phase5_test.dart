// Fase 5 — retorno de pagos externos con fakes.
//
// Proves: only HTTPS allowlisted return links enter a privileged flow,
// thank-you pages never reopen checkout, foreign/deep links are dropped,
// arrival is never treated as payment proof, and cold-start drain works.
// No network, no devices, no staging mutations.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monetta_app/app/checkout_return_router.dart';
import 'package:monetta_app/app/shopify_cart_composition.dart';
import 'package:monetta_app/data/customer_auth/secure_token_store.dart';
import 'package:monetta_app/data/shopify/cart/checkout_launcher.dart';
import 'package:monetta_app/data/shopify/cart/checkout_return_policy.dart';
import 'package:monetta_app/data/shopify/cart_attribution.dart';
import 'package:monetta_app/data/shopify/http_storefront_transport.dart';
import 'package:monetta_app/data/shopify/storefront_config.dart';
import 'package:monetta_app/platform/checkout_return_link_receiver.dart';
import 'package:monetta_app/platform/shopify_checkout_channel.dart';

const _shop = 'staging.invalid';
const _opaquePath = 'opaque-fase5-path';

String _url(String path, {String host = _shop}) =>
    'https://$host$path?key=fase5-fixture';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('fase 5: policy de retorno', () {
    late CheckoutReturnPolicy policy;

    setUp(() {
      policy = CheckoutReturnPolicy.forHosts(const [_shop]);
    });

    test('checkout del mismo shop reanuda', () {
      final decision = policy.decide(_url('/checkouts/$_opaquePath'));
      expect(decision.route, CheckoutReturnRoute.resumeCheckout);
      expect(decision.checkoutUrl, isNotNull);
    });

    test('thank-you nunca reabre checkout: va al navegador', () {
      for (final path in [
        '/checkouts/abc/thank-you',
        '/checkouts/abc/thank_you',
        '/checkouts/abc/THANK-YOU',
      ]) {
        final decision = policy.decide(_url(path));
        expect(
          decision.route,
          CheckoutReturnRoute.openBrowser,
          reason: path,
        );
        expect(decision.checkoutUrl, isNotNull);
      }
    });

    test('/cart abre la bolsa', () {
      final decision = policy.decide(_url('/cart'));
      expect(decision.route, CheckoutReturnRoute.openBag);
      expect(decision.checkoutUrl, isNull);
    });

    test('ruta desconocida del mismo host va al navegador', () {
      final decision = policy.decide(_url('/products/some-bag'));
      expect(decision.route, CheckoutReturnRoute.openBrowser);
    });

    test('host ajeno nunca entra a flujo privilegiado', () {
      for (final raw in [
        _url('/checkouts/abc', host: 'evil.invalid'),
        _url('/cart', host: 'evil.invalid'),
        'https://staging.invalid.evil.invalid/checkouts/abc',
      ]) {
        expect(policy.decide(raw).route, CheckoutReturnRoute.rejected);
      }
    });

    test('esquemas no permitidos se rechazan', () {
      for (final raw in [
        'http://$_shop/checkouts/abc',
        'shop.90228850722.oauth://callback?code=fase5',
        'monetta://checkouts/abc',
        'intent://$_shop/checkouts/abc#Intent;scheme=https;end',
        '',
      ]) {
        expect(
          policy.decide(raw).route,
          CheckoutReturnRoute.rejected,
          reason: raw.isEmpty ? '(empty)' : raw,
        );
      }
    });

    test('userinfo, puerto, fragmento y longitud se rechazan', () {
      final long = 'https://$_shop/checkouts/${'a' * 5000}';
      for (final raw in [
        'https://buyer:secret@$_shop/checkouts/abc',
        'https://buyer@$_shop/checkouts/abc',
        'https://$_shop:8443/checkouts/abc',
        'https://$_shop/checkouts/abc#fragment',
        'https://$_shop/',
        'https://$_shop',
        long,
      ]) {
        expect(
          policy.decide(raw).route,
          CheckoutReturnRoute.rejected,
          reason: raw.length > 80 ? '${raw.substring(0, 80)}…' : raw,
        );
      }
    });

    test('host de retorno dedicado también reanuda', () {
      final dedicated = CheckoutReturnPolicy.forHosts(
        const [_shop, 'return.invalid'],
      );
      expect(
        dedicated.decide(_url('/checkouts/abc', host: 'return.invalid')).route,
        CheckoutReturnRoute.resumeCheckout,
      );
      expect(
        dedicated.decide(_url('/checkouts/abc')).route,
        CheckoutReturnRoute.resumeCheckout,
      );
    });

    test('decisiones nunca exponen la URL', () {
      final resume = policy.decide(_url('/checkouts/$_opaquePath'));
      final browser = policy.decide(_url('/thank-you'));
      for (final rendered in ['$resume', '$browser']) {
        expect(rendered, isNot(contains(_opaquePath)));
        expect(rendered, isNot(contains('fase5-fixture')));
      }
    });
  });

  group('fase 5: router', () {
    late CheckoutReturnPolicy policy;

    setUp(() {
      policy = CheckoutReturnPolicy.forHosts(const [_shop]);
    });

    CheckoutReturnRouter router({
      Future<CheckoutResult> Function(ValidatedCheckoutUrl)? onResume,
      Future<void> Function()? onBag,
      ExternalCheckoutOpener? opener,
    }) =>
        CheckoutReturnRouter(
          policy: policy,
          onResumeCheckout: onResume ??
              (_) async => const CheckoutFailed(
                    code: CheckoutFailureCode.unavailable,
                    userMessage: 'x',
                  ),
          onOpenBag: onBag ?? () async {},
          externalOpener: opener ?? _FakeOpener(),
        );

    test('resume invoca el callback con URL validada', () async {
      ValidatedCheckoutUrl? seen;
      final outcome = await router(
        onResume: (url) async {
          seen = url;
          return const CheckoutCancelled();
        },
      ).handle(_url('/checkouts/abc'));
      expect(outcome, CheckoutReturnOutcome.resumed);
      expect(seen, isNotNull);
      expect('$seen', isNot(contains('abc')));
    });

    test('fallo del resume no limpia ni confirma nada', () async {
      var bagCalls = 0;
      final outcome = await router(
        onResume: (_) async => throw Exception('native gone'),
        onBag: () async => bagCalls += 1,
      ).handle(_url('/checkouts/abc'));
      expect(outcome, CheckoutReturnOutcome.rejected);
      expect(bagCalls, 0);
    });

    test('/cart abre bolsa y nada más', () async {
      var bagCalls = 0;
      var resumeCalls = 0;
      final outcome = await router(
        onResume: (_) async {
          resumeCalls += 1;
          return const CheckoutCancelled();
        },
        onBag: () async => bagCalls += 1,
      ).handle(_url('/cart'));
      expect(outcome, CheckoutReturnOutcome.bag);
      expect(bagCalls, 1);
      expect(resumeCalls, 0);
    });

    test('ruta de navegador usa el opener explícito', () async {
      final opener = _FakeOpener();
      final outcome = await router(opener: opener)
          .handle(_url('/checkouts/abc/thank-you'));
      expect(outcome, CheckoutReturnOutcome.browser);
      expect(opener.calls, 1);
    });

    test('link ajeno no toca ningún callback', () async {
      var resumeCalls = 0;
      var bagCalls = 0;
      final opener = _FakeOpener();
      final outcome = await router(
        onResume: (_) async {
          resumeCalls += 1;
          return const CheckoutCancelled();
        },
        onBag: () async => bagCalls += 1,
        opener: opener,
      ).handle('https://evil.invalid/checkouts/abc');
      expect(outcome, CheckoutReturnOutcome.rejected);
      expect(resumeCalls, 0);
      expect(bagCalls, 0);
      expect(opener.calls, 0);
    });

    test('router nunca lanza ante basura', () async {
      final r = router();
      for (final raw in ['', ':::', 'https://', 'x' * 5000]) {
        expect(await r.handle(raw), CheckoutReturnOutcome.rejected);
      }
    });
  });

  group('fase 5: receiver del channel', () {
    const channelName = MethodChannelCheckoutLauncher.channelName;
    late MethodChannel channel;

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        channel = const MethodChannel(channelName),
        (call) async => null,
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    Future<void> pushNative(String method, Object? arguments) {
      final data =
          const StandardMethodCodec().encodeMethodCall(
            MethodCall(method, arguments),
          );
      return TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .handlePlatformMessage(channelName, data, (_) {});
    }

    test('push nativo en caliente enruta una vez', () async {
      final spy = _SpyActions();
      final recording = CheckoutReturnLinkReceiver(
        router: spy.router(),
        channel: channel,
      );
      await recording.attach();
      await pushNative('onReturnLink', {'url': _url('/cart')});
      // Allow the async handler to finish.
      await Future<void>.delayed(Duration.zero);
      expect(spy.bagCalls, 1);
      expect(spy.resumeCalls, 0);
      expect(spy.browserCalls, 0);
      recording.detach();
    });

    test('drain recoge el pendiente de un arranque en frío', () async {
      final spy = _SpyActions();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'drainReturnLink') {
          return {'url': _url('/checkouts/abc')};
        }
        return null;
      });
      final receiver = CheckoutReturnLinkReceiver(
        router: spy.router(),
        channel: channel,
      );
      await receiver.drainPending();
      expect(spy.resumeCalls, 1);
      expect(spy.resumedUrl, isNotNull);
      expect(spy.bagCalls, 0);
      receiver.detach();
    });

    test('métodos ajenos y URLs vacías se ignoran', () async {
      final spy = _SpyActions();
      final receiver = CheckoutReturnLinkReceiver(
        router: spy.router(),
        channel: channel,
      );
      await receiver.attach();
      await pushNative('otherMethod', {'url': _url('/cart')});
      await pushNative('onReturnLink', {'url': ''});
      await pushNative('onReturnLink', {'nope': 1});
      await Future<void>.delayed(Duration.zero);
      expect(spy.bagCalls, 0);
      expect(spy.resumeCalls, 0);
      expect(spy.browserCalls, 0);
      receiver.detach();
    });

    test('detach deja de enrutar', () async {
      final spy = _SpyActions();
      final receiver = CheckoutReturnLinkReceiver(
        router: spy.router(),
        channel: channel,
      );
      await receiver.attach();
      receiver.detach();
      await pushNative('onReturnLink', {'url': _url('/cart')});
      await Future<void>.delayed(Duration.zero);
      expect(spy.bagCalls, 0);
      expect(spy.resumeCalls, 0);
    });
  });

  group('fase 5: composición expone la policy del shop', () {
    test('mismo allowlist que presentación', () {
      final composition = ShopifyCartComposition.production(
        config: const StorefrontConfig(
          shopDomain: _shop,
          accessToken: 'public',
        ),
        transport: HttpStorefrontTransport(
          client: MockClient((_) async => http.Response('{}', 200)),
        ),
        secureStore: _MemorySecureStore(),
        attribution: const CartAttribution(
          platform: 'test',
          deviceId: 'device-local',
          appVersion: '0',
        ),
      );
      expect(
        composition.returnPolicy
            .decide(_url('/checkouts/abc'))
            .route,
        CheckoutReturnRoute.resumeCheckout,
      );
      expect(
        composition.returnPolicy
            .decide(_url('/checkouts/abc', host: 'evil.invalid'))
            .route,
        CheckoutReturnRoute.rejected,
      );
      composition.controller.dispose();
    });
  });
}

final class _MemorySecureStore implements SecureTokenStore {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

final class _FakeOpener implements ExternalCheckoutOpener {  int calls = 0;

  @override
  Future<bool> open(ValidatedCheckoutUrl checkoutUrl) async {
    calls += 1;
    return true;
  }
}

final class _SpyActions {
  int resumeCalls = 0;
  int bagCalls = 0;
  int browserCalls = 0;
  ValidatedCheckoutUrl? resumedUrl;

  CheckoutReturnRouter router() => CheckoutReturnRouter(
        policy: CheckoutReturnPolicy.forHosts(const [_shop]),
        onResumeCheckout: (url) async {
          resumeCalls += 1;
          resumedUrl = url;
          return const CheckoutCancelled();
        },
        onOpenBag: () async => bagCalls += 1,
        externalOpener: _SpyOpener(() => browserCalls += 1),
      );
}

final class _SpyOpener implements ExternalCheckoutOpener {
  _SpyOpener(this.onOpen);

  final void Function() onOpen;

  @override
  Future<bool> open(ValidatedCheckoutUrl checkoutUrl) async {
    onOpen();
    return true;
  }
}
