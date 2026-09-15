import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/checkout_buyer_identity.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/shopify/cart/cart_api.dart';

void main() {
  final guestAccount = Account(
    localAccountId: 'local-guest-monetta',
    authProvider: 'monetta',
    email: 'legacy@example.invalid',
    createdAt: DateTime.utc(2026, 9, 1),
    lastSeenAt: DateTime.utc(2026, 9, 1),
  );
  final shopifyAccount = Account(
    localAccountId: 'local-shopify',
    authProvider: 'shopify',
    email: 'buyer@example.invalid',
    shopifyCustomerId: 'gid://shopify/Customer/1',
    createdAt: DateTime.utc(2026, 9, 1),
    lastSeenAt: DateTime.utc(2026, 9, 1),
  );

  test('guest and legacy Monetta accounts stay on GuestCartBuyerIdentity',
      () async {
    final guest = await resolveCheckoutBuyerIdentity(
      email: 'guest@example.invalid',
      phone: '8111111111',
    );
    expect(guest, isA<GuestCartBuyerIdentity>());
    expect(guest.isAuthenticated, isFalse);
    expect(guest.email, 'guest@example.invalid');

    final legacy = await resolveCheckoutBuyerIdentity(
      account: guestAccount,
      shopifyAccessToken: () async => 'should-not-be-used',
      email: 'override@example.invalid',
      phone: '8222222222',
    );
    expect(legacy, isA<GuestCartBuyerIdentity>());
    expect(legacy.email, 'override@example.invalid');
  });

  test('Shopify sessions supply AuthenticatedCartBuyerIdentity with a token',
      () async {
    final identity = await resolveCheckoutBuyerIdentity(
      account: shopifyAccount,
      shopifyAccessToken: () async => 'customer-access-token',
      phone: '8333333333',
    );

    expect(identity, isA<AuthenticatedCartBuyerIdentity>());
    expect(identity.isAuthenticated, isTrue);
    expect(identity.email, 'buyer@example.invalid');
    expect(identity.phone, '8333333333');
    final authenticated = identity as AuthenticatedCartBuyerIdentity;
    expect(
      authenticated.accessToken.revealForStorefrontRequest(),
      'customer-access-token',
    );
  });

  test('missing or failing Shopify token falls back to guest identity',
      () async {
    final missing = await resolveCheckoutBuyerIdentity(
      account: shopifyAccount,
      shopifyAccessToken: () async => null,
      email: 'fallback@example.invalid',
    );
    expect(missing, isA<GuestCartBuyerIdentity>());

    final failing = await resolveCheckoutBuyerIdentity(
      account: shopifyAccount,
      shopifyAccessToken: () async => throw StateError('refresh failed'),
      email: 'fallback@example.invalid',
    );
    expect(failing, isA<GuestCartBuyerIdentity>());
    expect(failing.email, 'fallback@example.invalid');
  });
}
