import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/domain/shopper_scope.dart';

void main() {
  group('ShopperScope', () {
    test('CHAR-16b equal scopes share equality and hash code', () {
      const a = ShopperScope(shopDomain: 'monetta.mx', accountId: 'A');
      const b = ShopperScope(shopDomain: 'monetta.mx', accountId: 'A');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('CHAR-16b a different account or store is a different scope', () {
      const a = ShopperScope(shopDomain: 'monetta.mx', accountId: 'A');

      expect(
        a == const ShopperScope(shopDomain: 'monetta.mx', accountId: 'B'),
        isFalse,
      );
      expect(
        a == const ShopperScope(shopDomain: 'other.mx', accountId: 'A'),
        isFalse,
      );
      expect(
        a == const ShopperScope(shopDomain: 'monetta.mx'),
        isFalse,
      );
    });

    test('CHAR-16b the guest has no account and the empty bag key', () {
      const guest = ShopperScope(shopDomain: 'monetta.mx');

      expect(guest.isGuest, isTrue);
      expect(guest.accountId, isNull);
      expect(guest.bagAccountKey, '');
    });

    test('CHAR-16b a signed-in scope keys the bag by its account id', () {
      const scope = ShopperScope(shopDomain: 'monetta.mx', accountId: 'A');

      expect(scope.isGuest, isFalse);
      expect(scope.bagAccountKey, 'A');
    });

    test('CHAR-16b the domain is kept exactly as given', () {
      const scope = ShopperScope(shopDomain: ' Monetta.MX ');

      expect(scope.shopDomain, ' Monetta.MX ');
      expect(scope.toString(), contains(' Monetta.MX '));
    });
  });
}
