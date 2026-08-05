/// Attribution is the evidence base for the revenue share, so its shape is a
/// contract, not an implementation detail.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/shopify/cart_attribution.dart';

void main() {
  group('CartAttribution', () {
    const attribution = CartAttribution(
      platform: 'ios',
      deviceId: 'b8f1-anon',
      appVersion: '1.0.3',
      recoSource: RecoSource.profile,
    );

    test('stamps the attributes an app-attributed order needs', () {
      final attributes = attribution.toAttributeInputs();
      final byKey = {
        for (final a in attributes) a['key']!: a['value']!,
      };

      expect(byKey['_channel'], 'app');
      expect(byKey['_platform'], 'ios');
      expect(byKey['_device_id'], 'b8f1-anon');
      expect(byKey['_rec_source'], 'profile');
      expect(byKey['_app_version'], '1.0.3');
    });

    test('every key is underscore-prefixed so Shopify keeps it private', () {
      // Private attributes stay out of the customer's order confirmation but
      // remain in Admin and the Orders export.
      for (final attribute in attribution.toAttributeInputs()) {
        expect(attribute['key'], startsWith('_'));
      }
    });

    test('omits campaign unless the session came from a push', () {
      expect(
        attribution.toAttributeInputs().map((a) => a['key']),
        isNot(contains('_campaign')),
      );
      expect(
        attribution
            .copyWith(campaignId: 'coach-restock')
            .toAttributeInputs()
            .map((a) => a['key']),
        contains('_campaign'),
      );
    });
  });

  group('ApartadoRequest', () {
    const request = ApartadoRequest(
      productTitle: 'Bolsa Guess Crossbody Negro',
      productHandle: 'bolsa-guess-crossbody-negro',
      price: 1749,
      attributionCode: 'MN-7K3Q',
    );

    test('states the retail deposit and carries the attribution code', () {
      expect(request.depositMxn, 400);
      expect(request.message, contains('\$400 MXN'));
      expect(request.message, contains('20 días'));
      expect(request.message, contains('MN-7K3Q'));
      expect(request.message, contains('bolsa-guess-crossbody-negro'));
    });

    test('uses the wholesale deposit for mayoreo', () {
      expect(
        const ApartadoRequest(
          productTitle: 'x',
          productHandle: 'x',
          price: 1,
          attributionCode: 'MN-0000',
          isWholesale: true,
        ).depositMxn,
        800,
      );
    });

    test('builds a wa.me link to the store number', () {
      final uri = request.uri;
      expect(uri.host, 'wa.me');
      expect(uri.path, '/528261066868');
      expect(uri.queryParameters['text'], contains('Monetta'));
    });
  });

  group('AttributionCodeGenerator', () {
    const generator = AttributionCodeGenerator();

    test('codes avoid vowels and easily-mistyped characters', () {
      // The owner reads these off a phone and types them into Shopify by hand.
      for (var seed = 0; seed < 500; seed++) {
        final code = generator.generate(seed);
        expect(code, startsWith('MN-'));
        expect(code, hasLength(7));
        final body = code.substring(3);
        expect(RegExp('[AEIOU01OI]').hasMatch(body), isFalse,
            reason: '$code contains an ambiguous character');
      }
    });

    test('is deterministic for a given seed', () {
      expect(generator.generate(12345), generator.generate(12345));
    });
  });
}
