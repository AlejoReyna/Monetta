import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/media/media_url.dart';

void main() {
  test('sized appends width on a Shopify snapshot URL', () {
    const raw =
        'https://cdn.shopify.com/s/files/1/0723/9165/5575/files/bag.jpg?v=1785364031';
    expect(
      MediaUrl.sized(raw, width: 800),
      'https://cdn.shopify.com/s/files/1/0723/9165/5575/files/bag.jpg?v=1785364031&width=800',
    );
  });

  test('sized rewrites an existing width', () {
    const raw =
        'https://cdn.shopify.com/s/files/1/x/files/bag.jpg?v=1&width=2400';
    expect(MediaUrl.sized(raw, width: 800), contains('width=800'));
    expect(MediaUrl.sized(raw, width: 800), isNot(contains('width=2400')));
  });

  test('sized leaves a non-Shopify URL alone', () {
    const raw = 'https://images.example.com/bag.jpg';
    expect(MediaUrl.sized(raw, width: 800), raw);
  });

  test('isHttps rejects schemes that are not https', () {
    expect(MediaUrl.isHttps('https://cdn.shopify.com/a.jpg'), isTrue);
    expect(MediaUrl.isHttps('http://cdn.shopify.com/a.jpg'), isFalse);
    expect(MediaUrl.isHttps('not a url'), isFalse);
  });
}
