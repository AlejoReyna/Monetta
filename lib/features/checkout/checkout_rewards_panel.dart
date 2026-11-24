/// Panel de cotización y canje de Monetta Rewards dentro del resumen de bolsa.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/account_controller.dart';
import '../../app/cart_controller.dart';
import '../../app/checkout_buyer_identity.dart';
import '../../data/accounts_orders/accounts_orders_config.dart';
import '../../data/shopify/cart/cart_repository.dart';
import '../../data/shopify/cart/cart_session_store.dart';
import '../../domain/cart.dart';
import '../boutique/boutique_tokens.dart';
import '../rewards/rewards_api.dart';
import '../rewards/rewards_components.dart';
import '../rewards/rewards_models.dart';
import '../rewards/rewards_section.dart';

/// Parses a decimal currency string (e.g. `"1250.00"` or `"149.5000"`) into
/// integer cents without binary floating-point drift.
int parseMoneyCents(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return 0;
  final negative = trimmed.startsWith('-');
  final unsigned = negative ? trimmed.substring(1) : trimmed;
  final parts = unsigned.split('.');
  final majorStr = parts[0].replaceAll(RegExp(r'[^0-9]'), '');
  final major = majorStr.isEmpty ? 0 : int.parse(majorStr);
  final fracRaw =
      parts.length > 1 ? parts[1].replaceAll(RegExp(r'[^0-9]'), '') : '';
  final padded = '${fracRaw}00'.substring(0, 2);
  final frac = int.parse(padded);
  final total = major * 100 + frac;
  return negative ? -total : total;
}

class CheckoutRewardsPanel extends StatefulWidget {
  const CheckoutRewardsPanel({
    required this.cartController,
    required this.scope,
    required this.localIntent,
    required this.cart,
    this.accountController,
    this.rewardsApi,
    super.key,
  });

  final CartController cartController;
  final CartSessionScope scope;
  final List<LocalCartIntent> localIntent;
  final Cart cart;
  final AccountController? accountController;
  final RewardsApi? rewardsApi;

  @override
  State<CheckoutRewardsPanel> createState() => _CheckoutRewardsPanelState();
}

class _CheckoutRewardsPanelState extends State<CheckoutRewardsPanel> {
  final math.Random _random = math.Random();
  RewardsApi? _ownedApi;
  RewardsApi? _effectiveApi;
  RewardsQuote? _quote;
  int _selectedCents = 0;
  bool _busy = false;
  bool _loadingQuote = false;
  String? _errorCode;
  String? _quotedRevision;
  String? _activeRedemptionId;
  String? _activeCode;
  int _activeAmountCents = 0;
  int _quoteGeneration = 0;

  @override
  void initState() {
    super.initState();
    widget.accountController?.addListener(_onAccountChanged);
    _resolveApi();
    _maybeFetchQuote();
  }

  @override
  void didUpdateWidget(covariant CheckoutRewardsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountController != widget.accountController) {
      oldWidget.accountController?.removeListener(_onAccountChanged);
      widget.accountController?.addListener(_onAccountChanged);
    }
    if (oldWidget.rewardsApi != widget.rewardsApi ||
        oldWidget.accountController != widget.accountController) {
      _resolveApi();
    }
    _syncExternalRemoval();
    _maybeFetchQuote();
  }

  @override
  void dispose() {
    widget.accountController?.removeListener(_onAccountChanged);
    _quoteGeneration++;
    _ownedApi?.close();
    super.dispose();
  }

  void _onAccountChanged() {
    if (!mounted) return;
    _resolveApi();
    setState(() {
      _quote = null;
      _quotedRevision = null;
      _selectedCents = 0;
      _errorCode = null;
      _activeRedemptionId = null;
      _activeCode = null;
      _activeAmountCents = 0;
    });
    _maybeFetchQuote();
  }

  void _resolveApi() {
    _ownedApi?.close();
    _ownedApi = null;
    final injected = widget.rewardsApi;
    if (injected != null) {
      _effectiveApi = injected;
      return;
    }
    final account = widget.accountController;
    if (account == null || !account.isSignedIn) {
      _effectiveApi = null;
      return;
    }
    final api = resolveRewardsApi(
      config: AccountsOrdersConfig.fromEnvironment(),
      tokenProvider: account.accessTokenForBackend,
    );
    _ownedApi = api;
    _effectiveApi = api;
  }

  String _cartRevision() {
    final linesKey =
        widget.cart.lines.map((l) => '${l.variantId}x${l.quantity}').join(',');
    return '${widget.cart.id}:${widget.cart.cost.subtotal.amount}:$linesKey';
  }

  List<Map<String, Object?>> _quoteLines() => [
        for (final line in widget.cart.lines)
          <String, Object?>{
            'variantId': line.variantId,
            'productId': line.productId,
            'quantity': line.quantity,
            'unitPriceCents':
                parseMoneyCents(line.cost.amountPerQuantity.amount),
            'discountCents': line.discountAllocations.fold<int>(
              0,
              (sum, alloc) =>
                  sum + parseMoneyCents(alloc.discountedAmount.amount),
            ),
            'eligible': true,
          },
      ];

  void _syncExternalRemoval() {
    if (_busy) return;
    final activeCode = _activeCode;
    final redemptionId = _activeRedemptionId;
    if (activeCode == null || redemptionId == null) return;
    final stillRequested = widget.cartController.requestedDiscountCodes
        .any((c) => c.toUpperCase() == activeCode.toUpperCase());
    if (!stillRequested) {
      final api = _effectiveApi;
      setState(() {
        _activeRedemptionId = null;
        _activeCode = null;
        _activeAmountCents = 0;
      });
      if (api != null) {
        unawaited(
          api.releaseRedemption(redemptionId).catchError(
                (_) => <String, dynamic>{},
              ),
        );
      }
      _quotedRevision = null;
    }
  }

  void _maybeFetchQuote() {
    final api = _effectiveApi;
    if (api == null || widget.cart.lines.isEmpty) return;
    final revision = _cartRevision();
    if (revision == _quotedRevision && _quote != null) return;
    _quotedRevision = revision;
    final gen = ++_quoteGeneration;
    _loadingQuote = true;
    unawaited(
      api
          .quote(
        cartRevision: revision,
        lines: _quoteLines(),
      )
          .then<void>(
        (quote) {
          if (!mounted || gen != _quoteGeneration) return;
          setState(() {
            _quote = quote;
            _loadingQuote = false;
            _errorCode = null;
            if (_selectedCents > quote.maxAllowedCents) {
              _selectedCents = quote.maxAllowedCents;
            }
          });
        },
        onError: (Object _) {
          if (!mounted || gen != _quoteGeneration) return;
          setState(() {
            _loadingQuote = false;
          });
        },
      ),
    );
  }

  String _idempotencyKey() {
    final micros = DateTime.now().microsecondsSinceEpoch;
    final salt = _random.nextInt(0x7fffffff).toRadixString(16);
    return 'redeem-$micros-$salt';
  }

  Future<void> _confirmRedemption() async {
    final api = _effectiveApi;
    final quote = _quote;
    if (api == null || quote == null || _busy || _selectedCents <= 0) return;

    final requestedCents = _selectedCents;
    setState(() {
      _busy = true;
      _errorCode = null;
    });

    try {
      final res = await api.redeem(
        quoteId: quote.quoteId,
        amountCents: requestedCents,
        idempotencyKey: _idempotencyKey(),
      );
      if (!mounted) return;
      final redemptionMap = res['redemption'] as Map<String, dynamic>?;
      final discountMap = res['discount'] as Map<String, dynamic>?;
      final redemptionId = redemptionMap?['redemptionId'] as String?;
      final code = discountMap?['code'] as String?;
      if (redemptionId == null || code == null || code.isEmpty) {
        if (redemptionId != null) {
          unawaited(
            api
                .releaseRedemption(redemptionId)
                .catchError((_) => <String, dynamic>{}),
          );
        }
        setState(() {
          _busy = false;
          _errorCode = 'redemption_disabled';
        });
        return;
      }

      final account = widget.accountController;
      final buyerIdentity = account != null && account.isSignedIn
          ? await resolveCheckoutBuyerIdentity(
              account: account.account,
              shopifyAccessToken: account.accessTokenForShopifyCheckout,
            )
          : null;
      if (!mounted) return;

      await widget.cartController.applyDiscountCode(
        scope: widget.scope,
        localIntent: widget.localIntent,
        code: code,
        buyerIdentity: buyerIdentity,
      );
      if (!mounted) return;

      final cartCodes = widget.cartController.snapshot?.cart?.discountCodes ??
          const <CartDiscountCode>[];
      final applied = cartCodes.any(
        (item) =>
            item.code.toUpperCase() == code.toUpperCase() && item.applicable,
      );
      if (!applied) {
        await api
            .releaseRedemption(redemptionId)
            .catchError((_) => <String, dynamic>{});
        await widget.cartController.removeDiscountCode(
          scope: widget.scope,
          localIntent: widget.localIntent,
          code: code,
          buyerIdentity: buyerIdentity,
        );
        if (!mounted) return;
        setState(() {
          _busy = false;
          _errorCode = 'internal_error';
        });
        return;
      }

      setState(() {
        _busy = false;
        _activeRedemptionId = redemptionId;
        _activeCode = code;
        _activeAmountCents = requestedCents;
        _errorCode = null;
      });
    } on RewardsApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorCode = error.code;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorCode = 'internal_error';
      });
    }
  }

  Future<void> _removeRedemption() async {
    final api = _effectiveApi;
    final code = _activeCode;
    final redemptionId = _activeRedemptionId;
    if (_busy || code == null || redemptionId == null) return;
    setState(() {
      _busy = true;
      _errorCode = null;
    });
    try {
      final account = widget.accountController;
      final buyerIdentity = account != null && account.isSignedIn
          ? await resolveCheckoutBuyerIdentity(
              account: account.account,
              shopifyAccessToken: account.accessTokenForShopifyCheckout,
            )
          : null;
      if (!mounted) return;
      await widget.cartController.removeDiscountCode(
        scope: widget.scope,
        localIntent: widget.localIntent,
        code: code,
        buyerIdentity: buyerIdentity,
      );
      if (api != null) {
        await api
            .releaseRedemption(redemptionId)
            .catchError((_) => <String, dynamic>{});
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _activeRedemptionId = null;
        _activeCode = null;
        _activeAmountCents = 0;
        _selectedCents = 0;
        _quotedRevision = null;
      });
      _maybeFetchQuote();
    } on Object {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorCode = 'internal_error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_effectiveApi == null || widget.cart.lines.isEmpty) {
      return const SizedBox.shrink();
    }
    final palette = context.boutique;

    if (_activeCode != null && _activeRedemptionId != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          key: const ValueKey('checkout-rewards-applied'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.surfaceDeep,
            borderRadius: BoutiqueRadius.control,
            border: Border.all(color: palette.hairline, width: .5),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.card_giftcard_outlined,
                size: 18,
                color: Color(0xFF3B7030),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rewards aplicado: −\$${(_activeAmountCents / 100).toStringAsFixed(0)} Monetta',
                      style: boutiqueText(
                        size: 13,
                        weight: FontWeight.w600,
                        color: const Color(0xFF3B7030),
                      ),
                    ),
                    Text(
                      'Cupón $_activeCode',
                      style: boutiqueText(size: 11, color: palette.inkMuted),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const ValueKey('checkout-rewards-remove'),
                onPressed: _busy ? null : () => unawaited(_removeRedemption()),
                child: Text(
                  _busy ? 'Quitando…' : 'Quitar',
                  style: boutiqueText(size: 12, color: palette.ink),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final quote = _quote;
    if (quote == null || _loadingQuote || quote.availableCents <= 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        key: const ValueKey('checkout-rewards-panel'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.surfaceDeep,
          borderRadius: BoutiqueRadius.control,
          border: Border.all(color: palette.hairline, width: .5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MONETTA REWARDS',
              style: boutiqueEyebrow(size: 9, color: palette.goldText),
            ),
            const SizedBox(height: 8),
            RewardsRedemptionControl(
              quote: quote,
              selectedCents: _selectedCents,
              busy: _busy,
              errorCode: _errorCode,
              onAmountChanged: (next) => setState(() {
                _selectedCents = next;
                _errorCode = null;
              }),
              onConfirm: () => unawaited(_confirmRedemption()),
            ),
            if (quote.estimatedEarnCents > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Estimación de esta compra: +\$${(quote.estimatedEarnCents / 100).toStringAsFixed(0)} Monetta al entregar.',
                style: boutiqueText(size: 11, color: palette.inkMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
