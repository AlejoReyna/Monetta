import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/cart_controller.dart';
import 'package:monetta_app/data/customer_auth/secure_token_store.dart';
import 'package:monetta_app/data/local/secure_cart_session_store.dart';
import 'package:monetta_app/data/shopify/cart/cart_api.dart';
import 'package:monetta_app/data/shopify/cart/cart_repository.dart';
import 'package:monetta_app/data/shopify/cart/cart_session_store.dart';
import 'package:monetta_app/data/shopify/cart/cart_write_coordinator.dart';
import 'package:monetta_app/data/shopify/cart_attribution.dart';
import 'package:monetta_app/data/shopify/shopify_gid.dart';
import 'package:monetta_app/domain/cart.dart';

void main() {
  const scope = CartSessionScope.guest(shopDomain: 'staging.invalid');
  final firstVariant = shopifyVariantGid(101);
  final secondVariant = shopifyVariantGid(202);

  group('CartRepository', () {
    test('creates a remote cart with canonical lines and non-PII attribution',
        () async {
      final api = _StatefulCartApi();
      final sessions = _MemorySessions();
      final repository = _repository(api, sessions);

      final result = await repository.reconcile(
        scope: scope,
        localIntent: [
          LocalCartIntent(variantId: firstVariant, quantity: 1),
          LocalCartIntent(variantId: firstVariant, quantity: 1),
        ],
        buyerIdentity: const GuestCartBuyerIdentity(),
      );

      expect(api.createCalls, 1);
      expect(api.lastCreateLines.single.merchandiseId, firstVariant);
      expect(api.lastCreateLines.single.quantity, 2);
      expect(api.lastCreateAttributes['_channel'], 'app');
      expect(api.lastCreateAttributes, contains('_device_id'));
      expect(result.status, CartReconciliationStatus.authoritative);
      expect(result.cart?.lines.single.quantity, 2);
      expect(await sessions.read(scope), isNotNull);
    });

    test('recovers an existing cart without duplicating matching quantities',
        () async {
      final api = _StatefulCartApi(initial: {firstVariant: 2});
      final sessions = _MemorySessions();
      await sessions.write(scope, SensitiveCartId(api.opaqueCartId));

      final result = await _repository(api, sessions).reconcile(
        scope: scope,
        localIntent: [LocalCartIntent(variantId: firstVariant, quantity: 2)],
      );

      expect(result.status, CartReconciliationStatus.authoritative);
      expect(api.getCalls, 1);
      expect(api.createCalls, 0);
      expect(api.addCalls, 0);
      expect(api.updateCalls, 0);
      expect(api.removeCalls, 0);
      expect(result.cart?.totalQuantity, 2);
      expect(api.discountCalls, 0, reason: 'unknown intent is discovered only');
    });

    test('restart discovers existing codes without sending replacement',
        () async {
      final api = _StatefulCartApi(initial: {firstVariant: 1})
        .._discountCodes = const [
          CartDiscountCode(code: 'DISCOVERED', applicable: true),
        ];
      final sessions = _MemorySessions();
      await sessions.write(scope, SensitiveCartId(api.opaqueCartId));

      final result = await _repository(api, sessions).reconcile(
        scope: scope,
        localIntent: [LocalCartIntent(variantId: firstVariant, quantity: 1)],
      );

      expect(api.events, ['get']);
      expect(api.discountCalls, 0);
      expect(result.cart?.discountCodes.single.code, 'DISCOVERED');
    });

    test('replaces an expired cart without losing local intent', () async {
      final api = _StatefulCartApi()..returnMissingOnce = true;
      final sessions = _MemorySessions();
      await sessions.write(scope, SensitiveCartId(api.opaqueCartId));

      final result = await _repository(api, sessions).reconcile(
        scope: scope,
        localIntent: [LocalCartIntent(variantId: secondVariant, quantity: 3)],
      );

      expect(api.getCalls, 1);
      expect(api.createCalls, 1);
      expect(api.lastCreateLines.single.quantity, 3);
      expect(result.cart?.lines.single.variantId, secondVariant);
      expect(result.status, CartReconciliationStatus.authoritative);
      expect(api.discountCalls, 0, reason: 'unknown intent is not guessed');
    });

    test('restart with expired cart does not guess old discount intent',
        () async {
      final api = _StatefulCartApi(initial: {firstVariant: 1})
        .._discountCodes = const [
          CartDiscountCode(code: 'OLD', applicable: true),
        ]
        ..returnMissingOnce = true;
      final sessions = _MemorySessions();
      await sessions.write(scope, SensitiveCartId(api.opaqueCartId));

      final result = await _repository(api, sessions).reconcile(
        scope: scope,
        localIntent: [LocalCartIntent(variantId: firstVariant, quantity: 1)],
      );

      expect(api.events, ['get', 'create']);
      expect(api.discountCalls, 0);
      expect(result.cart?.discountCodes, isEmpty);
    });

    test('adds, updates and removes using variant GIDs and quantities',
        () async {
      final removedVariant = shopifyVariantGid(303);
      final api = _StatefulCartApi(
        initial: {firstVariant: 1, removedVariant: 1},
      );
      final sessions = _MemorySessions();
      await sessions.write(scope, SensitiveCartId(api.opaqueCartId));

      final result = await _repository(api, sessions).reconcile(
        scope: scope,
        localIntent: [
          LocalCartIntent(variantId: firstVariant, quantity: 4),
          LocalCartIntent(variantId: secondVariant, quantity: 2),
        ],
      );

      expect(api.removeCalls, 1);
      expect(api.updateCalls, 1);
      expect(api.addCalls, 1);
      expect(result.cart?.totalQuantity, 6);
      expect(
        result.cart?.lines.map((line) => line.variantId),
        unorderedEquals([firstVariant, secondVariant]),
      );
    });

    test('publishes Shopify-recalculated costs after quantity changes',
        () async {
      final api = _StatefulCartApi(initial: {firstVariant: 1});
      final sessions = _MemorySessions();
      await sessions.write(scope, SensitiveCartId(api.opaqueCartId));

      final result = await _repository(api, sessions).reconcile(
        scope: scope,
        localIntent: [LocalCartIntent(variantId: firstVariant, quantity: 3)],
      );

      expect(api.updateCalls, 1);
      expect(result.cart?.cost.subtotal.amount, '30.0000');
      expect(result.cart?.cost.total.amount, '30.0000');
    });

    test('ambiguous add performs get and never repeats the write', () async {
      final api = _StatefulCartApi()..ambiguousAddOnce = true;
      final sessions = _MemorySessions();
      await sessions.write(scope, SensitiveCartId(api.opaqueCartId));

      final result = await _repository(api, sessions).reconcile(
        scope: scope,
        localIntent: [LocalCartIntent(variantId: firstVariant, quantity: 2)],
      );

      expect(api.events, ['get', 'add', 'get']);
      expect(api.getCalls, 2, reason: 'the second call is ambiguity recovery');
      expect(api.addCalls, 1, reason: 'the mutation must not be repeated');
      expect(result.cart?.totalQuantity, 2);
      expect(result.status, CartReconciliationStatus.authoritative);
    });

    test('out-of-stock and invalid variants remain explicit local intent',
        () async {
      final api = _StatefulCartApi()..rejectCreateAsOutOfStock = true;
      final result = await _repository(api, _MemorySessions()).reconcile(
        scope: scope,
        localIntent: [
          LocalCartIntent(variantId: firstVariant, quantity: 1),
          const LocalCartIntent(variantId: 'not-canonical', quantity: 1),
        ],
      );

      expect(result.status, CartReconciliationStatus.partiallyConfirmed);
      expect(result.cart, isNotNull);
      expect(
        result.unconfirmed.map((intent) => intent.reason),
        containsAll([
          UnconfirmedCartIntentReason.invalidVariant,
          UnconfirmedCartIntentReason.outOfStock,
        ]),
      );
      expect(
        result.unconfirmed.map((intent) => intent.userMessage),
        everyElement(isNotEmpty),
      );
    });

    test('replaces the complete discount set and supports removal', () async {
      final api = _StatefulCartApi(initial: {firstVariant: 1});
      final sessions = _MemorySessions();
      await sessions.write(scope, SensitiveCartId(api.opaqueCartId));

      final applied = await _repository(api, sessions).reconcile(
        scope: scope,
        localIntent: [LocalCartIntent(variantId: firstVariant, quantity: 1)],
        desiredDiscountCodes: const ['FIRST', 'SECOND'],
      );
      expect(api.discountSets, [
        ['FIRST', 'SECOND'],
      ]);
      expect(applied.cart?.discountCodes.map((item) => item.code), [
        'FIRST',
        'SECOND',
      ]);

      await _repository(api, sessions).reconcile(
        scope: scope,
        localIntent: [LocalCartIntent(variantId: firstVariant, quantity: 1)],
        desiredDiscountCodes: const [],
      );
      expect(api.discountSets.last, isEmpty);
    });

    test('reapplies still-desired codes after an expired cart is recreated',
        () async {
      final api = _StatefulCartApi()..returnMissingOnce = true;
      final sessions = _MemorySessions();
      await sessions.write(scope, SensitiveCartId(api.opaqueCartId));

      final result = await _repository(api, sessions).reconcile(
        scope: scope,
        localIntent: [LocalCartIntent(variantId: firstVariant, quantity: 2)],
        desiredDiscountCodes: const ['KEEP'],
      );

      expect(api.events, ['get', 'create', 'discount']);
      expect(api.discountSets.single, ['KEEP']);
      expect(result.cart?.discountCodes.single.code, 'KEEP');
    });

    test('controller reapplies known code once after expiry and quantity edit',
        () async {
      final api = _StatefulCartApi(initial: {firstVariant: 1});
      final sessions = _MemorySessions();
      await sessions.write(scope, SensitiveCartId(api.opaqueCartId));
      final controller = CartController(
        reconciler: _repository(api, sessions),
      );
      final local = [LocalCartIntent(variantId: firstVariant, quantity: 1)];
      await controller.replaceDiscountCodes(
        scope: scope,
        localIntent: local,
        discountCodes: const ['KEEP'],
      );

      api.events.clear();
      api.returnMissingOnce = true;
      await controller.reconcileLocalBag(
        scope: scope,
        localIntent: [
          LocalCartIntent(variantId: firstVariant, quantity: 2),
        ],
      );

      expect(api.events, ['get', 'create', 'discount']);
      expect(
        api.discountSets.where((set) => set.contains('KEEP')),
        hasLength(2),
      );
      expect(controller.snapshot?.cart?.discountCodes.single.code, 'KEEP');
      expect(controller.snapshot?.cart?.totalQuantity, 2);
    });

    test('ambiguous discount update reads once and never repeats mutation',
        () async {
      final api = _StatefulCartApi(initial: {firstVariant: 1})
        ..ambiguousDiscountOnce = true;
      final sessions = _MemorySessions();
      await sessions.write(scope, SensitiveCartId(api.opaqueCartId));

      final result = await _repository(api, sessions).reconcile(
        scope: scope,
        localIntent: [LocalCartIntent(variantId: firstVariant, quantity: 1)],
        desiredDiscountCodes: const ['RECOVER'],
      );

      expect(api.events, ['get', 'discount', 'get']);
      expect(api.discountCalls, 1);
      expect(api.getCalls, 2);
      expect(result.cart?.discountCodes.single.code, 'RECOVER');
    });

    test('ambiguous removal distinguishes retained and removed remote state',
        () async {
      Future<CartReconciliation> remove({required bool keepPrevious}) async {
        final api = _StatefulCartApi(initial: {firstVariant: 1})
          .._discountCodes = const [
            CartDiscountCode(code: 'KEEP', applicable: true),
          ]
          ..ambiguousDiscountOnce = true
          ..ambiguousDiscountKeepsPrevious = keepPrevious;
        final sessions = _MemorySessions();
        await sessions.write(scope, SensitiveCartId(api.opaqueCartId));
        final result = await _repository(api, sessions).reconcile(
          scope: scope,
          localIntent: [
            LocalCartIntent(variantId: firstVariant, quantity: 1),
          ],
          desiredDiscountCodes: const [],
        );
        expect(api.events, ['get', 'discount', 'get']);
        expect(api.discountCalls, 1);
        return result;
      }

      expect(
        (await remove(keepPrevious: true)).cart?.discountCodes.single.code,
        'KEEP',
      );
      expect(
        (await remove(keepPrevious: false)).cart?.discountCodes,
        isEmpty,
      );
    });

    test('rejected removal retains previous authoritative cart', () async {
      final api = _StatefulCartApi(initial: {firstVariant: 1})
        .._discountCodes = const [
          CartDiscountCode(code: 'KEEP', applicable: true),
        ]
        ..rejectDiscountRemoval = true;
      final sessions = _MemorySessions();
      await sessions.write(scope, SensitiveCartId(api.opaqueCartId));

      final result = await _repository(api, sessions).reconcile(
        scope: scope,
        localIntent: [LocalCartIntent(variantId: firstVariant, quantity: 1)],
        desiredDiscountCodes: const [],
      );

      expect(result.cart?.discountCodes.single.code, 'KEEP');
      expect(result.issues.single.kind, CartMutationIssueKind.userError);
    });

    test('null cart never confirms removal without authoritative evidence',
        () async {
      final api = _StatefulCartApi(initial: {firstVariant: 1})
        .._discountCodes = const [
          CartDiscountCode(code: 'KEEP', applicable: true),
        ]
        ..returnNullDiscountRemoval = true;
      final sessions = _MemorySessions();
      await sessions.write(scope, SensitiveCartId(api.opaqueCartId));

      final result = await _repository(api, sessions).reconcile(
        scope: scope,
        localIntent: [LocalCartIntent(variantId: firstVariant, quantity: 1)],
        desiredDiscountCodes: const [],
      );

      expect(result.cart?.discountCodes.single.code, 'KEEP');
      expect(result.issues.single.code, 'DISCOUNT_UPDATE_UNCONFIRMED');
    });

    test('serializes concurrent discount replacements for one session',
        () async {
      final api = _StatefulCartApi(initial: {firstVariant: 1})
        ..discountDelay = const Duration(milliseconds: 5);
      final sessions = _MemorySessions();
      await sessions.write(scope, SensitiveCartId(api.opaqueCartId));
      final repository = _repository(api, sessions);
      final local = [LocalCartIntent(variantId: firstVariant, quantity: 1)];

      await Future.wait([
        repository.reconcile(
          scope: scope,
          localIntent: local,
          desiredDiscountCodes: const ['ONE'],
        ),
        repository.reconcile(
          scope: scope,
          localIntent: local,
          desiredDiscountCodes: const ['TWO'],
        ),
      ]);

      expect(api.maximumActiveDiscounts, 1);
      expect(api.discountSets, [
        ['ONE'],
        ['TWO'],
      ]);
    });
  });

  group('secure sessions and serialization', () {
    test('survives restart and separates guest, stores and accounts', () async {
      final secureValues = _MemorySecureStore();
      final firstProcess = SecureCartSessionStore(secureValues);
      final opaqueId = SensitiveCartId(_opaque('persisted'));
      const accountA = CartSessionScope.authenticated(
        shopDomain: 'staging.invalid',
        localAccountId: 'account-a',
      );
      const accountB = CartSessionScope.authenticated(
        shopDomain: 'staging.invalid',
        localAccountId: 'account-b',
      );
      const otherStore = CartSessionScope.guest(shopDomain: 'other.invalid');
      await firstProcess.write(accountA, opaqueId);

      final restartedProcess = SecureCartSessionStore(secureValues);
      expect(await restartedProcess.read(accountA), opaqueId);
      expect(await restartedProcess.read(accountB), isNull);
      expect(await restartedProcess.read(scope), isNull);
      expect(await restartedProcess.read(otherStore), isNull);
      expect(secureValues.keys.join(), isNot(contains(_opaque('persisted'))));
    });

    test('allows only one operation in flight for the same session', () async {
      final coordinator = SerialCartWriteCoordinator();
      var active = 0;
      var maximumActive = 0;

      Future<int> operation(int value) => coordinator.run<int>(
            scope: scope,
            write: () async {
              active += 1;
              maximumActive = active > maximumActive ? active : maximumActive;
              await Future<void>.delayed(const Duration(milliseconds: 5));
              active -= 1;
              return value;
            },
            recoverAfterAmbiguousFailure: () async => -1,
          );

      expect(
        await Future.wait([operation(1), operation(2), operation(3)]),
        [1, 2, 3],
      );
      expect(maximumActive, 1);
    });
  });
}

CartRepository _repository(CartApi api, CartSessionStore sessions) =>
    CartRepository(
      api: api,
      sessions: sessions,
      writes: SerialCartWriteCoordinator(),
      attribution: const CartAttribution(
        platform: 'test',
        deviceId: 'device-local',
        appVersion: '0',
      ),
    );

String _opaque(String suffix) => String.fromCharCodes([
      111,
      112,
      97,
      113,
      117,
      101,
      ...suffix.codeUnits,
    ]);

final class _StatefulCartApi implements CartApi {
  _StatefulCartApi({Map<String, int> initial = const {}})
      : _quantities = Map.of(initial);

  final Map<String, int> _quantities;
  final String opaqueCartId = _opaque('cart');
  bool returnMissingOnce = false;
  bool ambiguousAddOnce = false;
  bool rejectCreateAsOutOfStock = false;
  bool ambiguousDiscountOnce = false;
  bool ambiguousDiscountKeepsPrevious = false;
  bool rejectDiscountRemoval = false;
  bool returnNullDiscountRemoval = false;
  Duration discountDelay = Duration.zero;
  int getCalls = 0;
  int createCalls = 0;
  int addCalls = 0;
  int updateCalls = 0;
  int removeCalls = 0;
  int discountCalls = 0;
  int activeDiscounts = 0;
  int maximumActiveDiscounts = 0;
  List<CartDiscountCode> _discountCodes = const [];
  final List<List<String>> discountSets = [];
  final List<String> events = [];
  List<CartLineCreateInput> lastCreateLines = const [];
  Map<String, String> lastCreateAttributes = const {};

  @override
  Future<CartMutationResult> create({
    required List<CartLineCreateInput> lines,
    required Map<String, String> attributes,
    CartBuyerIdentity? buyerIdentity,
  }) async {
    createCalls += 1;
    events.add('create');
    lastCreateLines = List.of(lines);
    lastCreateAttributes = Map.of(attributes);
    _discountCodes = const [];
    if (!rejectCreateAsOutOfStock) {
      for (final line in lines) {
        _quantities[line.merchandiseId] = line.quantity;
      }
    }
    return CartMutationResult(
      cart: _cart(opaqueCartId, _quantities, discountCodes: _discountCodes),
      issues: rejectCreateAsOutOfStock
          ? [
              CartMutationIssue(
                kind: CartMutationIssueKind.warning,
                code: 'MERCHANDISE_OUT_OF_STOCK',
                message: 'Una variante está agotada.',
              ),
            ]
          : const [],
    );
  }

  @override
  Future<Cart?> get(SensitiveCartId cartId) async {
    getCalls += 1;
    events.add('get');
    if (returnMissingOnce) {
      returnMissingOnce = false;
      return null;
    }
    return _cart(opaqueCartId, _quantities, discountCodes: _discountCodes);
  }

  @override
  Future<CartMutationResult> addLines(
    SensitiveCartId cartId,
    List<CartLineCreateInput> lines,
  ) async {
    addCalls += 1;
    events.add('add');
    for (final line in lines) {
      _quantities.update(
        line.merchandiseId,
        (quantity) => quantity + line.quantity,
        ifAbsent: () => line.quantity,
      );
    }
    if (ambiguousAddOnce) {
      ambiguousAddOnce = false;
      throw const AmbiguousCartWriteException(CartWriteOperation.addLines);
    }
    return CartMutationResult(
      cart: _cart(opaqueCartId, _quantities, discountCodes: _discountCodes),
    );
  }

  @override
  Future<CartMutationResult> updateLines(
    SensitiveCartId cartId,
    List<CartLineUpdateInput> lines,
  ) async {
    updateCalls += 1;
    events.add('update');
    for (final line in lines) {
      _quantities[_variantForLine(line.lineId)] = line.quantity;
    }
    return CartMutationResult(
      cart: _cart(opaqueCartId, _quantities, discountCodes: _discountCodes),
    );
  }

  @override
  Future<CartMutationResult> removeLines(
    SensitiveCartId cartId,
    List<String> lineIds,
  ) async {
    removeCalls += 1;
    events.add('remove');
    for (final lineId in lineIds) {
      _quantities.remove(_variantForLine(lineId));
    }
    return CartMutationResult(
      cart: _cart(opaqueCartId, _quantities, discountCodes: _discountCodes),
    );
  }

  @override
  Future<CartMutationResult> updateBuyerIdentity(
    SensitiveCartId cartId,
    CartBuyerIdentity identity,
  ) async =>
      CartMutationResult(
        cart: _cart(opaqueCartId, _quantities, discountCodes: _discountCodes),
      );

  @override
  Future<CartMutationResult> replaceDiscountCodes(
    SensitiveCartId cartId,
    List<String> discountCodes,
  ) async {
    discountCalls += 1;
    activeDiscounts += 1;
    maximumActiveDiscounts = activeDiscounts > maximumActiveDiscounts
        ? activeDiscounts
        : maximumActiveDiscounts;
    events.add('discount');
    discountSets.add(List.of(discountCodes));
    try {
      if (discountDelay > Duration.zero) {
        await Future<void>.delayed(discountDelay);
      }
      if (rejectDiscountRemoval && discountCodes.isEmpty) {
        return CartMutationResult(
          cart: null,
          issues: [
            CartMutationIssue(
              kind: CartMutationIssueKind.userError,
              code: 'INVALID',
              message: 'No se pudo actualizar el descuento.',
            ),
          ],
        );
      }
      if (returnNullDiscountRemoval && discountCodes.isEmpty) {
        return CartMutationResult(cart: null);
      }
      if (ambiguousDiscountOnce && ambiguousDiscountKeepsPrevious) {
        ambiguousDiscountOnce = false;
        throw const AmbiguousCartWriteException(
          CartWriteOperation.replaceDiscountCodes,
        );
      }
      _discountCodes = [
        for (final code in discountCodes)
          CartDiscountCode(code: code, applicable: code != 'NOT_APPLICABLE'),
      ];
      if (ambiguousDiscountOnce) {
        ambiguousDiscountOnce = false;
        throw const AmbiguousCartWriteException(
          CartWriteOperation.replaceDiscountCodes,
        );
      }
      return CartMutationResult(
        cart: _cart(opaqueCartId, _quantities, discountCodes: _discountCodes),
      );
    } finally {
      activeDiscounts -= 1;
    }
  }

  static String _variantForLine(String lineId) =>
      lineId.substring(_opaque('line-').length);
}

Cart _cart(
  String id,
  Map<String, int> quantities, {
  List<CartDiscountCode> discountCodes = const [],
}) {
  final timestamp = DateTime.utc(2026, 8, 27);
  final totalQuantity = quantities.values.fold(0, (sum, value) => sum + value);
  final totalMoney = CartMoney(
    amount: '${totalQuantity * 10}.0000',
    currencyCode: 'MXN',
  );
  return Cart(
    id: id,
    checkoutUrl: Uri(path: _opaque('checkout')).toString(),
    createdAt: timestamp,
    updatedAt: timestamp,
    lines: quantities.entries.map(
      (entry) {
        const unit = CartMoney(amount: '10.0000', currencyCode: 'MXN');
        final lineTotal = CartMoney(
          amount: '${entry.value * 10}.0000',
          currencyCode: 'MXN',
        );
        return CartLine(
          id: '${_opaque('line-')}${entry.key}',
          variantId: entry.key,
          productId: shopifyProductGid(1),
          title: 'Producto',
          variantTitle: 'Variante',
          quantity: entry.value,
          cost: CartLineCost(
            amountPerQuantity: unit,
            subtotal: lineTotal,
            total: lineTotal,
          ),
        );
      },
    ).toList(),
    totalQuantity: totalQuantity,
    buyerIdentity: const CartBuyerSummary(
      countryCode: 'MX',
      isAuthenticated: false,
    ),
    cost: CartCost(subtotal: totalMoney, total: totalMoney),
    discountCodes: discountCodes,
  );
}

final class _MemorySessions implements CartSessionStore {
  final Map<CartSessionScope, SensitiveCartId> values = {};

  @override
  Future<void> delete(CartSessionScope scope) async => values.remove(scope);

  @override
  Future<SensitiveCartId?> read(CartSessionScope scope) async => values[scope];

  @override
  Future<void> write(CartSessionScope scope, SensitiveCartId cartId) async {
    values[scope] = cartId;
  }
}

final class _MemorySecureStore implements SecureTokenStore {
  final Map<String, String> values = {};

  Iterable<String> get keys => values.keys;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
