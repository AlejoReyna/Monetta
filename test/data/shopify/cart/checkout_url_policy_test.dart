import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/shopify/cart/checkout_launcher.dart';

void main() {
  const allowedHost = 'checkout.invalid';
  final policy = CheckoutUrlPolicy(allowedHosts: const [allowedHost]);

  String url({
    String scheme = 'https',
    String host = allowedHost,
    String path = '/opaque',
    int? port,
    String? fragment,
  }) {
    if (port != null) {
      return '$scheme://$host:$port$path?key=redacted-fixture';
    }
    return Uri(
      scheme: scheme,
      host: host,
      path: path,
      fragment: fragment,
      queryParameters: const {'key': 'redacted-fixture'},
    ).toString();
  }

  test('accepts exact HTTPS host and keeps stringification redacted', () {
    final validated = policy.validate(url());

    expect('$validated', 'ValidatedCheckoutUrl(<redacted>)');
    expect('$validated', isNot(contains('redacted-fixture')));
  });

  test('rejects non-HTTPS, lookalikes, subdomains and explicit ports', () {
    for (final candidate in [
      url(scheme: 'http'),
      url(host: 'checkout.invalid.attacker.test'),
      url(host: 'sub.checkout.invalid'),
      url(port: 443),
    ]) {
      expect(
        () => policy.validate(candidate),
        throwsA(isA<CheckoutUrlPolicyException>()),
      );
    }
  });

  test('rejects credentials, fragments, empty paths and malformed input', () {
    final credentials =
        'https://buyer:secret@$allowedHost/opaque?key=redacted-fixture';
    for (final candidate in [
      credentials,
      'https://@$allowedHost/opaque?key=redacted-fixture',
      url(fragment: 'redirect'),
      url(path: '/'),
      'https:\\$allowedHost\\opaque',
      'not a checkout',
    ]) {
      expect(
        () => policy.validate(candidate),
        throwsA(isA<CheckoutUrlPolicyException>()),
      );
    }
  });

  test('rejects whitespace, controls and a redirect host outside the allowlist',
      () {
    for (final candidate in [
      'https://$allowedHost/opaque path?key=redacted-fixture',
      'https://$allowedHost/opaque?next=https://attacker.test',
      'https://$allowedHost\u0000/opaque?key=redacted-fixture',
      'https://$allowedHost\n/opaque?key=redacted-fixture',
    ]) {
      expect(
        () => policy.validate(candidate),
        throwsA(isA<CheckoutUrlPolicyException>()),
      );
    }
  });

  test('policy errors never include rejected input', () {
    const rejected = 'sensitive-fixture';
    try {
      policy.validate(rejected);
      fail('Expected policy rejection');
    } on CheckoutUrlPolicyException catch (error) {
      expect('$error', 'CheckoutUrlPolicyException(<redacted>)');
      expect('$error', isNot(contains(rejected)));
    }
  });
}
