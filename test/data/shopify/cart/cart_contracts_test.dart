import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/shopify/cart/cart_api.dart';
import 'package:monetta_app/data/shopify/cart/cart_session_store.dart';
import 'package:monetta_app/data/shopify/cart/cart_write_coordinator.dart';
import 'package:monetta_app/data/shopify/cart/checkout_launcher.dart';

import '../../../support/shopify_cart_fakes.dart';

void main() {
  group('cart contracts', () {
    test('support guest and authenticated buyer identity without disclosure',
        () async {
      final api = FakeCartApi();
      const guest = GuestCartBuyerIdentity();
      final credential = SensitiveCustomerAccessToken(
        String.fromCharCodes(const [102, 97, 107, 101]),
      );
      final authenticated = AuthenticatedCartBuyerIdentity(
        accessToken: credential,
      );

      await api.create(
        lines: const [],
        attributes: const {},
        buyerIdentity: guest,
      );
      expect(api.lastBuyerIdentity?.isAuthenticated, isFalse);

      await api.updateBuyerIdentity(
        SensitiveCartId(
          String.fromCharCodes(const [111, 112, 97, 113, 117, 101]),
        ),
        authenticated,
      );
      expect(api.lastBuyerIdentity?.isAuthenticated, isTrue);
      expect(
        '$credential',
        isNot(contains(credential.revealForStorefrontRequest())),
      );
      expect('$authenticated', contains('<redacted>'));
    });

    test('session scopes separate guest, accounts and stores', () async {
      const guestA = CartSessionScope.guest(shopDomain: 'staging-a.invalid');
      const guestB = CartSessionScope.guest(shopDomain: 'staging-b.invalid');
      const accountA = CartSessionScope.authenticated(
        shopDomain: 'staging-a.invalid',
        localAccountId: 'local-a',
      );
      const accountB = CartSessionScope.authenticated(
        shopDomain: 'staging-a.invalid',
        localAccountId: 'local-b',
      );
      final cartId = SensitiveCartId(
        String.fromCharCodes(const [111, 112, 97, 113, 117, 101]),
      );
      final store = InMemoryCartSessionStore();

      await store.write(accountA, cartId);

      expect(await store.read(accountA), cartId);
      expect(await store.read(guestA), isNull);
      expect(await store.read(guestB), isNull);
      expect(await store.read(accountB), isNull);
      expect('$cartId', 'SensitiveCartId(<redacted>)');
      expect(
        '$cartId',
        isNot(contains(cartId.revealForStorefrontRequest())),
      );
      expect('$accountA', isNot(contains('local-a')));
    });

    test('mutation results distinguish user errors from warnings', () {
      final warningOnly = CartMutationResult(
        cart: null,
        issues: [
          CartMutationIssue(
            kind: CartMutationIssueKind.warning,
            code: 'QUANTITY_ADJUSTED',
            message: 'Shopify ajustó la cantidad disponible.',
          ),
        ],
      );
      final rejected = CartMutationResult(
        cart: null,
        issues: [
          CartMutationIssue(
            kind: CartMutationIssueKind.userError,
            code: 'INVALID_MERCHANDISE',
            message: 'La variante ya no está disponible.',
          ),
        ],
      );

      expect(warningOnly.hasUserErrors, isFalse);
      expect(rejected.hasUserErrors, isTrue);
    });

    test('ambiguous writes recover by reading instead of repeating mutation',
        () async {
      final coordinator = RecoveringCartWriteCoordinator();
      var writeCalls = 0;
      var recoveryCalls = 0;

      final result = await coordinator.run<String>(
        scope: const CartSessionScope.guest(shopDomain: 'staging.invalid'),
        write: () async {
          writeCalls += 1;
          throw const AmbiguousCartWriteException(
            CartWriteOperation.addLines,
          );
        },
        recoverAfterAmbiguousFailure: () async {
          recoveryCalls += 1;
          return 'recovered';
        },
      );

      expect(result, 'recovered');
      expect(writeCalls, 1);
      expect(recoveryCalls, 1);
    });
  });

  test('checkout launcher exposes completed, cancelled and failed outcomes',
      () async {
    final launcher = FakeCheckoutLauncher(const [
      CheckoutCompleted(),
      CheckoutCancelled(),
      CheckoutFailed(
        code: CheckoutFailureCode.unavailable,
        userMessage: 'No fue posible abrir el pago seguro.',
      ),
    ]);
    final opaquePath =
        String.fromCharCodes(const [111, 112, 97, 113, 117, 101]);
    const host = 'checkout.invalid';
    final target = CheckoutUrlPolicy(allowedHosts: const [host]).validate(
      Uri(scheme: 'https', host: host, path: '/$opaquePath').toString(),
    );

    await launcher.preload(target);
    expect(await launcher.present(target), isA<CheckoutCompleted>());
    expect(await launcher.present(target), isA<CheckoutCancelled>());
    expect(await launcher.present(target), isA<CheckoutFailed>());
    await launcher.invalidate();

    expect(launcher.preloadCalls, 1);
    expect(launcher.presentCalls, 3);
    expect(launcher.invalidateCalls, 1);
    expect('$target', 'ValidatedCheckoutUrl(<redacted>)');
    expect('$target', isNot(contains(opaquePath)));
  });
}
