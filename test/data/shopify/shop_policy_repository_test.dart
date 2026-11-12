// Deterministic merchant-policy fixture; no live content verification.
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/customer_auth/customer_graphql_client.dart';
import 'package:monetta_app/data/shopify/shop_policy_repository.dart';
import 'package:monetta_app/data/shopify/storefront_client.dart';
import 'package:monetta_app/data/shopify/storefront_config.dart';

ShopPolicyRepository repository(Map<String, dynamic> envelope) =>
    ShopPolicyRepository(
      StorefrontClient(
        config: const StorefrontConfig(
          shopDomain: 'fixture.example',
          accessToken: 'fixture-public-token',
        ),
        transport: (_, __, body) async {
          expect(body, contains('shippingPolicy'));
          return envelope;
        },
      ),
    );
void main() {
  test('reads published merchant body verbatim by semantic kind', () async {
    final results = await repository({
      'data': {
        'shop': {
          'shipping': {
            'id': 'policy-1',
            'title': 'Merchant shipping title',
            'body': '<p>Approved fixture copy</p>',
            'url': 'https://fixture.example/policies/shipping-policy',
          },
        },
      },
    }).fetch();
    expect(
      results[ShopPolicyKind.shipping]!.status,
      CapabilityReadStatus.supported,
    );
    expect(
      results[ShopPolicyKind.shipping]!.value!.bodyHtml,
      '<p>Approved fixture copy</p>',
    );
    expect(
      results[ShopPolicyKind.privacy]!.status,
      CapabilityReadStatus.unavailable,
    );
  });
  test('missing/empty published content is unavailable with no fallback copy',
      () async {
    final results = await repository({
      'data': {
        'shop': {
          'refund': {
            'id': 'policy-2',
            'title': 'Refund',
            'body': '<p> &nbsp; </p>',
            'url': 'https://fixture.example/policy',
          },
        },
      },
    }).fetch();
    expect(
      results.values.every((r) => r.status == CapabilityReadStatus.unavailable),
      isTrue,
    );
  });
  test('provider failure differs from unavailable content', () async {
    await expectLater(
      repository({
        'errors': [
          {'message': 'denied'},
        ],
      }).fetch(),
      throwsA(isA<StorefrontException>()),
    );
  });
  test(
      'malformed/unsafe policy data fails rather than producing a clickable URL',
      () async {
    await expectLater(
      repository({
        'data': {
          'shop': {
            'terms': {
              'id': 'policy-3',
              'title': 'Terms',
              'body': 'copy',
              'url': 'javascript:fixture',
            },
          },
        },
      }).fetch(),
      throwsA(isA<StorefrontException>()),
    );
  });
}
